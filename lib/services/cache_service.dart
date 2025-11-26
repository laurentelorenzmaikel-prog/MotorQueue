import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';

enum CacheStrategy {
  cacheFirst,     // Use cache first, fallback to network
  networkFirst,   // Use network first, fallback to cache
  cacheOnly,      // Use cache only
  networkOnly,    // Use network only
  staleWhileRevalidate, // Return cache immediately, update in background
}

class CacheEntry {
  final String key;
  final dynamic data;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? etag;
  final int size;

  CacheEntry({
    required this.key,
    required this.data,
    required this.createdAt,
    required this.expiresAt,
    this.etag,
    required this.size,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'data': data,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      'etag': etag,
      'size': size,
    };
  }

  factory CacheEntry.fromMap(Map<String, dynamic> map) {
    return CacheEntry(
      key: map['key'],
      data: map['data'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expiresAt']),
      etag: map['etag'],
      size: map['size'],
    );
  }
}

class CacheConfig {
  final Duration defaultTtl;
  final int maxMemorySize;
  final int maxDiskSize;
  final Duration cleanupInterval;
  final bool enableCompression;
  final List<String> excludePatterns;

  const CacheConfig({
    this.defaultTtl = const Duration(hours: 1),
    this.maxMemorySize = 50 * 1024 * 1024, // 50MB
    this.maxDiskSize = 200 * 1024 * 1024,  // 200MB
    this.cleanupInterval = const Duration(hours: 6),
    this.enableCompression = true,
    this.excludePatterns = const [],
  });
}

class CacheService {
  static CacheService? _instance;
  static CacheService get instance => _instance ??= CacheService._();

  CacheService._();

  late Box<String> _memoryCache;
  late Box<String> _diskCache;
  late Box<Map<dynamic, dynamic>> _metadataCache;

  final CacheConfig _config = const CacheConfig();
  final Map<String, Future<dynamic>> _inflightRequests = {};

  int _currentMemorySize = 0;
  DateTime? _lastCleanup;

  Future<void> initialize() async {
    await Hive.initFlutter();

    _memoryCache = await Hive.openBox<String>('memory_cache');
    _diskCache = await Hive.openBox<String>('disk_cache');
    _metadataCache = await Hive.openBox<Map<dynamic, dynamic>>('cache_metadata');

    _calculateCurrentSize();
    _scheduleCleanup();
  }

  // Generic caching method
  Future<T?> get<T>(
    String key, {
    Duration? ttl,
    CacheStrategy strategy = CacheStrategy.cacheFirst,
  }) async {
    final cacheKey = _normalizeKey(key);

    switch (strategy) {
      case CacheStrategy.cacheFirst:
        return await _getCacheFirst<T>(cacheKey, ttl);
      case CacheStrategy.networkFirst:
        // This would require a network provider parameter
        return await _getCacheFirst<T>(cacheKey, ttl);
      case CacheStrategy.cacheOnly:
        return await _getCacheOnly<T>(cacheKey);
      case CacheStrategy.networkOnly:
        return null; // Network implementation would go here
      case CacheStrategy.staleWhileRevalidate:
        return await _getStaleWhileRevalidate<T>(cacheKey, ttl);
    }
  }

  Future<void> set<T>(
    String key,
    T data, {
    Duration? ttl,
    String? etag,
    bool useMemory = true,
    bool useDisk = true,
  }) async {
    final cacheKey = _normalizeKey(key);
    final effectiveTtl = ttl ?? _config.defaultTtl;
    final expiresAt = DateTime.now().add(effectiveTtl);

    final serializedData = await _serializeData(data);
    final dataSize = _calculateSize(serializedData);

    final entry = CacheEntry(
      key: cacheKey,
      data: serializedData,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      etag: etag,
      size: dataSize,
    );

    // Store metadata
    await _metadataCache.put(cacheKey, {
      'createdAt': entry.createdAt.millisecondsSinceEpoch,
      'expiresAt': entry.expiresAt.millisecondsSinceEpoch,
      'etag': entry.etag,
      'size': entry.size,
      'inMemory': useMemory,
      'onDisk': useDisk,
    });

    // Store in memory cache if enabled and within size limits
    if (useMemory && _canStoreInMemory(dataSize)) {
      await _memoryCache.put(cacheKey, serializedData);
      _currentMemorySize += dataSize;
    }

    // Store in disk cache if enabled
    if (useDisk) {
      await _diskCache.put(cacheKey, serializedData);
    }

    await _enforceMemoryLimit();
  }

  Future<void> invalidate(String key) async {
    final cacheKey = _normalizeKey(key);

    final metadata = _metadataCache.get(cacheKey);
    if (metadata != null) {
      _currentMemorySize -= metadata['size'] as int? ?? 0;
    }

    await _memoryCache.delete(cacheKey);
    await _diskCache.delete(cacheKey);
    await _metadataCache.delete(cacheKey);
  }

  Future<void> invalidatePattern(String pattern) async {
    final regex = RegExp(pattern);
    final keysToDelete = <String>[];

    for (final key in _metadataCache.keys) {
      if (regex.hasMatch(key)) {
        keysToDelete.add(key);
      }
    }

    for (final key in keysToDelete) {
      await invalidate(key);
    }
  }

  Future<void> clear() async {
    await _memoryCache.clear();
    await _diskCache.clear();
    await _metadataCache.clear();
    _currentMemorySize = 0;
  }

  // Cache with function execution
  Future<T> remember<T>(
    String key,
    Future<T> Function() fetcher, {
    Duration? ttl,
    CacheStrategy strategy = CacheStrategy.cacheFirst,
    String? etag,
  }) async {
    final cacheKey = _normalizeKey(key);

    // Check if request is already in flight
    if (_inflightRequests.containsKey(cacheKey)) {
      return await _inflightRequests[cacheKey] as T;
    }

    switch (strategy) {
      case CacheStrategy.cacheFirst:
        return await _rememberCacheFirst(cacheKey, fetcher, ttl, etag);
      case CacheStrategy.networkFirst:
        return await _rememberNetworkFirst(cacheKey, fetcher, ttl, etag);
      case CacheStrategy.cacheOnly:
        final cached = await _getCacheOnly<T>(cacheKey);
        if (cached != null) return cached;
        throw Exception('Cache miss and cache-only strategy specified');
      case CacheStrategy.networkOnly:
        return await _executeAndCache(cacheKey, fetcher, ttl, etag);
      case CacheStrategy.staleWhileRevalidate:
        return await _rememberStaleWhileRevalidate(cacheKey, fetcher, ttl, etag);
    }
  }

  // Cache statistics
  Map<String, dynamic> getStats() {
    final memoryKeys = _memoryCache.keys.length;
    final diskKeys = _diskCache.keys.length;
    final totalKeys = _metadataCache.keys.length;

    return {
      'memory_entries': memoryKeys,
      'disk_entries': diskKeys,
      'total_entries': totalKeys,
      'memory_size_bytes': _currentMemorySize,
      'memory_size_mb': (_currentMemorySize / (1024 * 1024)).toStringAsFixed(2),
      'max_memory_mb': (_config.maxMemorySize / (1024 * 1024)).toStringAsFixed(2),
      'memory_usage_percent': ((_currentMemorySize / _config.maxMemorySize) * 100).toStringAsFixed(1),
      'last_cleanup': _lastCleanup?.toIso8601String(),
    };
  }

  // Preload cache entries
  Future<void> preload(Map<String, Future<dynamic> Function()> entries) async {
    final futures = entries.entries.map((entry) async {
      try {
        final data = await entry.value();
        await set(entry.key, data);
      } catch (e) {
        // Silently ignore preload failures
      }
    });

    await Future.wait(futures);
  }

  // Export cache for debugging
  Future<Map<String, dynamic>> exportCache() async {
    final export = <String, dynamic>{};

    for (final key in _metadataCache.keys) {
      final metadata = _metadataCache.get(key);
      final memoryData = _memoryCache.get(key);
      final diskData = _diskCache.get(key);

      export[key] = {
        'metadata': metadata,
        'in_memory': memoryData != null,
        'on_disk': diskData != null,
        'data_preview': _getDataPreview(memoryData ?? diskData),
      };
    }

    return export;
  }

  // Private helper methods
  Future<T?> _getCacheFirst<T>(String key, Duration? ttl) async {
    // Try memory first
    final memoryData = _memoryCache.get(key);
    if (memoryData != null && await _isValidCache(key)) {
      return await _deserializeData<T>(memoryData);
    }

    // Try disk
    final diskData = _diskCache.get(key);
    if (diskData != null && await _isValidCache(key)) {
      // Move to memory for faster access next time
      final dataSize = _calculateSize(diskData);
      if (_canStoreInMemory(dataSize)) {
        await _memoryCache.put(key, diskData);
        _currentMemorySize += dataSize;
      }
      return await _deserializeData<T>(diskData);
    }

    return null;
  }

  Future<T?> _getCacheOnly<T>(String key) async {
    return await _getCacheFirst<T>(key, null);
  }

  Future<T?> _getStaleWhileRevalidate<T>(String key, Duration? ttl) async {
    final cached = await _getCacheFirst<T>(key, ttl);
    // In a real implementation, you would trigger background revalidation here
    return cached;
  }

  Future<T> _rememberCacheFirst<T>(
    String key,
    Future<T> Function() fetcher,
    Duration? ttl,
    String? etag,
  ) async {
    final cached = await _getCacheFirst<T>(key, ttl);
    if (cached != null) return cached;

    return await _executeAndCache(key, fetcher, ttl, etag);
  }

  Future<T> _rememberNetworkFirst<T>(
    String key,
    Future<T> Function() fetcher,
    Duration? ttl,
    String? etag,
  ) async {
    try {
      return await _executeAndCache(key, fetcher, ttl, etag);
    } catch (e) {
      final cached = await _getCacheFirst<T>(key, ttl);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<T> _rememberStaleWhileRevalidate<T>(
    String key,
    Future<T> Function() fetcher,
    Duration? ttl,
    String? etag,
  ) async {
    final cached = await _getCacheFirst<T>(key, ttl);

    if (cached != null) {
      // Return cached data immediately and revalidate in background
      _revalidateInBackground(key, fetcher, ttl, etag);
      return cached;
    }

    return await _executeAndCache(key, fetcher, ttl, etag);
  }

  Future<T> _executeAndCache<T>(
    String key,
    Future<T> Function() fetcher,
    Duration? ttl,
    String? etag,
  ) async {
    _inflightRequests[key] = fetcher();

    try {
      final result = await _inflightRequests[key] as T;
      await set(key, result, ttl: ttl, etag: etag);
      return result;
    } finally {
      _inflightRequests.remove(key);
    }
  }

  void _revalidateInBackground<T>(
    String key,
    Future<T> Function() fetcher,
    Duration? ttl,
    String? etag,
  ) {
    // Don't await this - it runs in the background
    _executeAndCache(key, fetcher, ttl, etag).then((_) {
      // Background revalidation succeeded
    }).catchError((e) {
      // Silently ignore background revalidation errors
    });
  }

  Future<bool> _isValidCache(String key) async {
    final metadata = _metadataCache.get(key);
    if (metadata == null) return false;

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(metadata['expiresAt']);
    return DateTime.now().isBefore(expiresAt);
  }

  Future<String> _serializeData(dynamic data) async {
    if (data is String) return data;

    final jsonString = jsonEncode(data);

    if (_config.enableCompression && jsonString.length > 1024) {
      // In a real implementation, you would use compression here
      return jsonString;
    }

    return jsonString;
  }

  Future<T?> _deserializeData<T>(String data) async {
    try {
      if (T == String) return data as T;
      return jsonDecode(data) as T;
    } catch (e) {
      return null;
    }
  }

  String _normalizeKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[^\w\-\.]'), '_');
  }

  int _calculateSize(String data) {
    return Uint8List.fromList(utf8.encode(data)).length;
  }

  bool _canStoreInMemory(int size) {
    return _currentMemorySize + size <= _config.maxMemorySize;
  }

  void _calculateCurrentSize() {
    _currentMemorySize = 0;
    for (final key in _memoryCache.keys) {
      final metadata = _metadataCache.get(key);
      if (metadata != null) {
        _currentMemorySize += metadata['size'] as int? ?? 0;
      }
    }
  }

  Future<void> _enforceMemoryLimit() async {
    while (_currentMemorySize > _config.maxMemorySize) {
      // Remove least recently used items
      String? oldestKey;
      DateTime? oldestTime;

      for (final key in _metadataCache.keys) {
        final metadata = _metadataCache.get(key);
        if (metadata != null && metadata['inMemory'] == true) {
          final createdAt = DateTime.fromMillisecondsSinceEpoch(metadata['createdAt']);
          if (oldestTime == null || createdAt.isBefore(oldestTime)) {
            oldestTime = createdAt;
            oldestKey = key;
          }
        }
      }

      if (oldestKey != null) {
        final metadata = _metadataCache.get(oldestKey);
        if (metadata != null) {
          _currentMemorySize -= metadata['size'] as int? ?? 0;
          await _memoryCache.delete(oldestKey);

          // Update metadata
          metadata['inMemory'] = false;
          await _metadataCache.put(oldestKey, metadata);
        }
      } else {
        break; // No more items to remove
      }
    }
  }

  void _scheduleCleanup() {
    final now = DateTime.now();
    if (_lastCleanup == null ||
        now.difference(_lastCleanup!) > _config.cleanupInterval) {
      _performCleanup();
    }
  }

  Future<void> _performCleanup() async {
    final now = DateTime.now();
    final keysToDelete = <String>[];

    for (final key in _metadataCache.keys) {
      final metadata = _metadataCache.get(key);
      if (metadata != null) {
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(metadata['expiresAt']);
        if (now.isAfter(expiresAt)) {
          keysToDelete.add(key);
        }
      }
    }

    for (final key in keysToDelete) {
      await invalidate(key);
    }

    _lastCleanup = now;
  }

  String _getDataPreview(String? data) {
    if (data == null) return 'null';
    if (data.length <= 100) return data;
    return '${data.substring(0, 100)}...';
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';

enum LogLevel { debug, info, warning, error, critical }

enum EventType {
  userAction,
  systemEvent,
  error,
  performance,
  security,
  business,
}

class LogEntry {
  final String id;
  final LogLevel level;
  final EventType type;
  final String message;
  final DateTime timestamp;
  final String? userId;
  final String? userEmail;
  final Map<String, dynamic> metadata;
  final String? stackTrace;
  final String? source;

  LogEntry({
    required this.id,
    required this.level,
    required this.type,
    required this.message,
    required this.timestamp,
    this.userId,
    this.userEmail,
    required this.metadata,
    this.stackTrace,
    this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'level': level.toString().split('.').last,
      'type': type.toString().split('.').last,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'userId': userId,
      'userEmail': userEmail,
      'metadata': metadata,
      'stackTrace': stackTrace,
      'source': source,
    };
  }
}

class PerformanceMetric {
  final String name;
  final double value;
  final String unit;
  final DateTime timestamp;
  final Map<String, dynamic> attributes;

  PerformanceMetric({
    required this.name,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.attributes,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'value': value,
      'unit': unit,
      'timestamp': Timestamp.fromDate(timestamp),
      'attributes': attributes,
    };
  }
}

class MonitoringService {
  final FirebaseFirestore _firestore;
  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics? _crashlytics;
  final FirebasePerformance? _performance;

  static const int _maxLocalLogs = 1000;
  static const Duration _batchUploadInterval = Duration(minutes: 5);

  final List<LogEntry> _localLogs = [];
  DateTime? _lastUpload;

  MonitoringService({
    FirebaseFirestore? firestore,
    FirebaseAnalytics? analytics,
    FirebaseCrashlytics? crashlytics,
    FirebasePerformance? performance,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _analytics = analytics ?? FirebaseAnalytics.instance,
        _crashlytics = kDebugMode ? null : FirebaseCrashlytics.instance,
        _performance = kDebugMode ? null : FirebasePerformance.instance {
    _initializeMonitoring();
  }

  void _initializeMonitoring() {
    // Set up global error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      logError(
        'Flutter Error',
        details.exception,
        stackTrace: details.stack,
        metadata: {
          'library': details.library,
          'context': details.context?.toString(),
        },
      );
    };

    // Set up isolate error handling
    if (!kDebugMode) {
      _crashlytics?.setCrashlyticsCollectionEnabled(true);
    }
  }

  // Logging methods
  Future<void> logDebug(
    String message, {
    String? source,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      level: LogLevel.debug,
      type: EventType.systemEvent,
      message: message,
      source: source,
      metadata: metadata ?? {},
    );
  }

  Future<void> logInfo(
    String message, {
    String? source,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      level: LogLevel.info,
      type: EventType.systemEvent,
      message: message,
      source: source,
      metadata: metadata ?? {},
    );
  }

  Future<void> logWarning(
    String message, {
    String? source,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      level: LogLevel.warning,
      type: EventType.systemEvent,
      message: message,
      source: source,
      metadata: metadata ?? {},
    );
  }

  Future<void> logError(
    String message,
    dynamic error, {
    StackTrace? stackTrace,
    String? source,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      level: LogLevel.error,
      type: EventType.error,
      message: message,
      source: source,
      metadata: {
        'error': error.toString(),
        ...?metadata,
      },
      stackTrace: stackTrace?.toString(),
    );

    // Report to Crashlytics in production
    if (!kDebugMode && _crashlytics != null) {
      await _crashlytics.recordError(error, stackTrace, fatal: false);
    }
  }

  Future<void> logCritical(
    String message,
    dynamic error, {
    StackTrace? stackTrace,
    String? source,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      level: LogLevel.critical,
      type: EventType.error,
      message: message,
      source: source,
      metadata: {
        'error': error.toString(),
        ...?metadata,
      },
      stackTrace: stackTrace?.toString(),
    );

    // Report to Crashlytics as fatal in production
    if (!kDebugMode && _crashlytics != null) {
      await _crashlytics.recordError(error, stackTrace, fatal: true);
    }
  }

  // User action logging
  Future<void> logUserAction(
    String action, {
    String? userId,
    String? userEmail,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      level: LogLevel.info,
      type: EventType.userAction,
      message: 'User action: $action',
      userId: userId,
      userEmail: userEmail,
      metadata: {
        'action': action,
        ...?metadata,
      },
    );

    // Log to Firebase Analytics
    final parameters = <String, Object>{
      'action': action,
    };
    if (userId != null) {
      parameters['user_id'] = userId;
    }
    if (metadata != null) {
      parameters.addAll(metadata.cast<String, Object>());
    }

    await _analytics.logEvent(
      name: 'user_action',
      parameters: parameters,
    );
  }

  // Security event logging
  Future<void> logSecurityEvent(
    String event, {
    String? userId,
    String? userEmail,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      level: LogLevel.warning,
      type: EventType.security,
      message: 'Security event: $event',
      userId: userId,
      userEmail: userEmail,
      metadata: {
        'event': event,
        'severity': 'high',
        ...?metadata,
      },
    );
  }

  // Business event logging
  Future<void> logBusinessEvent(
    String event, {
    String? userId,
    double? value,
    String? currency,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      level: LogLevel.info,
      type: EventType.business,
      message: 'Business event: $event',
      userId: userId,
      metadata: {
        'event': event,
        'value': value,
        'currency': currency,
        ...?metadata,
      },
    );

    // Log to Firebase Analytics for business intelligence
    final analyticsParams = <String, Object>{};
    if (value != null) {
      analyticsParams['value'] = value;
    }
    if (currency != null) {
      analyticsParams['currency'] = currency;
    }
    if (userId != null) {
      analyticsParams['user_id'] = userId;
    }
    if (metadata != null) {
      analyticsParams.addAll(metadata.cast<String, Object>());
    }

    await _analytics.logEvent(
      name: event.toLowerCase().replaceAll(' ', '_'),
      parameters: analyticsParams,
    );
  }

  // Performance monitoring
  Future<void> logPerformanceMetric(
    String name,
    double value, {
    String unit = 'ms',
    Map<String, dynamic>? attributes,
  }) async {
    final metric = PerformanceMetric(
      name: name,
      value: value,
      unit: unit,
      timestamp: DateTime.now(),
      attributes: attributes ?? {},
    );

    await _firestore.collection('performance_metrics').add(metric.toMap());

    // Log to Firebase Performance if available
    if (_performance != null) {
      final trace = _performance.newTrace(name);
      trace.start();

      // Add custom attributes
      attributes?.forEach((key, value) {
        if (value is String) {
          trace.putAttribute(key, value);
        }
      });

      // Simulate metric recording
      await Future.delayed(Duration(milliseconds: value.toInt()));
      trace.stop();
    }
  }

  // Start performance trace
  Trace? startTrace(String name, {Map<String, String>? attributes}) {
    if (_performance == null) return null;

    final trace = _performance.newTrace(name);
    attributes?.forEach((key, value) {
      trace.putAttribute(key, value);
    });
    trace.start();
    return trace;
  }

  // Application lifecycle logging
  Future<void> logAppLifecycle(String event) async {
    await _log(
      level: LogLevel.info,
      type: EventType.systemEvent,
      message: 'App lifecycle: $event',
      metadata: {
        'lifecycle_event': event,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Database operation logging
  Future<void> logDatabaseOperation(
    String operation,
    String collection, {
    String? documentId,
    bool success = true,
    String? error,
    int? duration,
  }) async {
    await _log(
      level: success ? LogLevel.info : LogLevel.error,
      type: EventType.systemEvent,
      message: 'Database $operation on $collection',
      metadata: {
        'operation': operation,
        'collection': collection,
        'document_id': documentId,
        'success': success,
        'error': error,
        'duration_ms': duration,
      },
    );
  }

  // API call logging
  Future<void> logApiCall(
    String endpoint,
    String method, {
    int? statusCode,
    int? duration,
    String? error,
  }) async {
    await _log(
      level: (statusCode != null && statusCode >= 400) ? LogLevel.error : LogLevel.info,
      type: EventType.systemEvent,
      message: '$method $endpoint',
      metadata: {
        'endpoint': endpoint,
        'method': method,
        'status_code': statusCode,
        'duration_ms': duration,
        'error': error,
      },
    );
  }

  // System resource monitoring
  Future<void> logSystemResources() async {
    try {
      final memoryInfo = await Process.run('free', ['-m']);
      final diskInfo = await Process.run('df', ['-h']);

      await _log(
        level: LogLevel.info,
        type: EventType.performance,
        message: 'System resources snapshot',
        metadata: {
          'memory_info': memoryInfo.stdout,
          'disk_info': diskInfo.stdout,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      // Silently ignore on platforms where these commands aren't available
    }
  }

  // Get logs with filtering
  Future<List<LogEntry>> getLogs({
    LogLevel? minLevel,
    EventType? type,
    DateTime? startTime,
    DateTime? endTime,
    String? userId,
    int limit = 100,
  }) async {
    Query query = _firestore.collection('logs').orderBy('timestamp', descending: true);

    if (minLevel != null) {
      final levelIndex = LogLevel.values.indexOf(minLevel);
      final allowedLevels = LogLevel.values.skip(levelIndex).map((l) => l.toString().split('.').last).toList();
      query = query.where('level', whereIn: allowedLevels);
    }

    if (type != null) {
      query = query.where('type', isEqualTo: type.toString().split('.').last);
    }

    if (startTime != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startTime));
    }

    if (endTime != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endTime));
    }

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    final snapshot = await query.limit(limit).get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return LogEntry(
        id: data['id'],
        level: LogLevel.values.firstWhere((l) => l.toString().split('.').last == data['level']),
        type: EventType.values.firstWhere((t) => t.toString().split('.').last == data['type']),
        message: data['message'],
        timestamp: (data['timestamp'] as Timestamp).toDate(),
        userId: data['userId'],
        userEmail: data['userEmail'],
        metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
        stackTrace: data['stackTrace'],
        source: data['source'],
      );
    }).toList();
  }

  // Clean up old logs
  Future<void> cleanupOldLogs({Duration retention = const Duration(days: 30)}) async {
    final cutoffDate = DateTime.now().subtract(retention);
    final query = _firestore
        .collection('logs')
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate));

    final snapshot = await query.get();
    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();

    await logInfo('Cleaned up ${snapshot.docs.length} old log entries');
  }

  // Private methods
  Future<void> _log({
    required LogLevel level,
    required EventType type,
    required String message,
    String? userId,
    String? userEmail,
    String? source,
    Map<String, dynamic>? metadata,
    String? stackTrace,
  }) async {
    final logEntry = LogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      level: level,
      type: type,
      message: message,
      timestamp: DateTime.now(),
      userId: userId,
      userEmail: userEmail,
      source: source,
      metadata: metadata ?? {},
      stackTrace: stackTrace,
    );

    // Add to local cache
    _localLogs.add(logEntry);

    // Maintain local cache size
    if (_localLogs.length > _maxLocalLogs) {
      _localLogs.removeAt(0);
    }

    // Print to console in debug mode
    if (kDebugMode) {
      print('[${level.toString().split('.').last.toUpperCase()}] $message');
      if (metadata?.isNotEmpty == true) {
        print('Metadata: ${jsonEncode(metadata)}');
      }
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }

    // Batch upload to Firestore
    await _batchUploadLogs();
  }

  Future<void> _batchUploadLogs() async {
    final now = DateTime.now();
    if (_lastUpload != null &&
        now.difference(_lastUpload!) < _batchUploadInterval &&
        _localLogs.length < 50) {
      return; // Don't upload yet
    }

    if (_localLogs.isEmpty) return;

    // Skip Firestore upload in debug mode to avoid permission errors
    if (kDebugMode) {
      _localLogs.clear(); // Clear logs to prevent memory buildup
      _lastUpload = now;
      return;
    }

    try {
      final batch = _firestore.batch();
      final logsToUpload = List<LogEntry>.from(_localLogs);

      for (final log in logsToUpload) {
        final docRef = _firestore.collection('logs').doc(log.id);
        batch.set(docRef, log.toMap());
      }

      await batch.commit();
      _localLogs.clear();
      _lastUpload = now;
    } catch (e) {
      // Keep logs in local cache if upload fails
      print('Failed to upload logs: $e');
    }
  }

  // Force upload remaining logs
  Future<void> flushLogs() async {
    if (_localLogs.isNotEmpty) {
      _lastUpload = null; // Force upload
      await _batchUploadLogs();
    }
  }
}
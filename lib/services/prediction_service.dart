import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lorenz_app/services/dart_prediction_client.dart';

/// Inventory Forecast and Analytics Service
///
/// This service provides:
/// 1. Inventory restock forecasts from ML model
/// 2. Top frequently used services
/// 3. Top frequently used spare parts
class PredictionService {
  final FirebaseFirestore _firestore;

  PredictionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get inventory restock forecast from ML API
  Future<RestockForecast?> getInventoryForecast({
    int forecastDays = 30,
  }) async {
    try {
      return await fetchRestockForecast(forecastDays: forecastDays);
    } catch (e) {
      print('Error fetching inventory forecast: $e');
      return null;
    }
  }

  /// Get top 3 most frequently used services from appointments
  Future<List<ServiceUsage>> getTopServices({int limit = 3}) async {
    try {
      final snapshot = await _firestore.collection('appointments').get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      // Count service usage - normalize names to avoid duplicates
      Map<String, int> serviceCounts = {};
      Map<String, String> normalizedToOriginal =
          {}; // Track original name for display

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final service = data['service'] as String?;

        if (service != null && service.isNotEmpty) {
          // Normalize: trim whitespace and convert to lowercase for comparison
          final normalized = service.trim().toLowerCase();
          final original =
              service.trim(); // Keep original with trimmed whitespace

          // Use normalized key for counting, but store original for display
          if (!normalizedToOriginal.containsKey(normalized)) {
            normalizedToOriginal[normalized] = original;
          }

          serviceCounts[normalized] = (serviceCounts[normalized] ?? 0) + 1;
        }
      }

      // Convert to list using original names and sort
      List<ServiceUsage> services = serviceCounts.entries.map((entry) {
        return ServiceUsage(
          name: normalizedToOriginal[entry.key] ?? entry.key,
          count: entry.value,
        );
      }).toList();

      services.sort((a, b) => b.count.compareTo(a.count));

      return services.take(limit).toList();
    } catch (e) {
      print('Error getting top services: $e');
      return [];
    }
  }

  /// Get top 3 most frequently used spare parts from completed appointments
  Future<List<SparePartUsage>> getTopSpareParts({int limit = 3}) async {
    try {
      final snapshot = await _firestore
          .collection('appointments')
          .where('status', isEqualTo: 'completed')
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      // Count spare parts usage - normalize names to avoid duplicates
      Map<String, int> partCounts = {};
      Map<String, String> normalizedToOriginal =
          {}; // Track original name for display

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final spareParts = data['spareParts'] as List?;

        if (spareParts != null) {
          for (final part in spareParts) {
            if (part is Map<String, dynamic>) {
              final partName = part['name'] as String?;
              final quantity = part['quantity'] as int? ?? 1;

              if (partName != null && partName.isNotEmpty) {
                // Normalize: trim whitespace and convert to lowercase for comparison
                final normalized = partName.trim().toLowerCase();
                final original =
                    partName.trim(); // Keep original with trimmed whitespace

                // Use normalized key for counting, but store original for display
                if (!normalizedToOriginal.containsKey(normalized)) {
                  normalizedToOriginal[normalized] = original;
                }

                partCounts[normalized] =
                    (partCounts[normalized] ?? 0) + quantity;
              }
            }
          }
        }
      }

      // Convert to list using original names and sort
      List<SparePartUsage> parts = partCounts.entries.map((entry) {
        return SparePartUsage(
          name: normalizedToOriginal[entry.key] ?? entry.key,
          count: entry.value,
        );
      }).toList();

      parts.sort((a, b) => b.count.compareTo(a.count));

      return parts.take(limit).toList();
    } catch (e) {
      print('Error getting top spare parts: $e');
      return [];
    }
  }

  /// Check if API is available
  Future<bool> isApiAvailable() async {
    return await checkApiHealth();
  }
}

/// Service usage data
class ServiceUsage {
  final String name;
  final int count;

  ServiceUsage({
    required this.name,
    required this.count,
  });
}

/// Spare part usage data
class SparePartUsage {
  final String name;
  final int count;

  SparePartUsage({
    required this.name,
    required this.count,
  });
}

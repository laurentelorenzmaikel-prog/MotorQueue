// ignore_for_file: avoid_print

/*
 * Inventory Forecast Dart Client
 * ===============================
 * 
 * This file contains the client-side logic for fetching inventory forecasts
 * from the Python prediction API service.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

// ============================================================================
// CONFIGURATION
// ============================================================================

/// Base URL of the Python prediction API service
/// Update this to match your deployment
const String API_BASE_URL = 'http://127.0.0.1:5057';

/// Forecast endpoint path
const String FORECAST_ENDPOINT = '/forecast_restock_demand';

/// Request timeout duration
const Duration REQUEST_TIMEOUT = Duration(seconds: 30);

/// Exponential backoff configuration
const int MAX_RETRY_ATTEMPTS = 4;
const int INITIAL_BACKOFF_MS = 500;
const int MAX_BACKOFF_MS = 8000;

// ============================================================================
// DATA MODELS
// ============================================================================

/// Response model for restock forecast
class RestockForecast {
  final String status;
  final int forecastPeriodDays;
  final String? startDate;
  final String? endDate;
  final Map<String, int> totalRestockDemand;
  final List<DailyPrediction>? dailyBreakdown;
  final String? timestamp;

  RestockForecast({
    required this.status,
    required this.forecastPeriodDays,
    required this.totalRestockDemand,
    this.startDate,
    this.endDate,
    this.dailyBreakdown,
    this.timestamp,
  });

  factory RestockForecast.fromJson(Map<String, dynamic> json) {
    try {
      Map<String, int> demand = {};
      if (json['total_restock_demand'] != null) {
        final demandMap = json['total_restock_demand'] as Map<String, dynamic>;
        demandMap.forEach((key, value) {
          demand[key] = (value is int) ? value : (value as num).toInt();
        });
      }

      List<DailyPrediction>? breakdown;
      if (json['daily_breakdown'] != null) {
        breakdown = (json['daily_breakdown'] as List)
            .map((item) =>
                DailyPrediction.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      return RestockForecast(
        status: json['status'] as String? ?? 'unknown',
        forecastPeriodDays: json['forecast_period_days'] as int? ?? 0,
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
        totalRestockDemand: demand,
        dailyBreakdown: breakdown,
        timestamp: json['timestamp'] as String?,
      );
    } catch (e) {
      print('⚠ Error parsing RestockForecast: $e');
      rethrow;
    }
  }
}

/// Model for daily prediction breakdown
class DailyPrediction {
  final String date;
  final double totalUsage;
  final Map<String, double> parts;

  DailyPrediction({
    required this.date,
    required this.totalUsage,
    required this.parts,
  });

  factory DailyPrediction.fromJson(Map<String, dynamic> json) {
    Map<String, double> partsMap = {};
    if (json['parts'] != null) {
      final parts = json['parts'] as Map<String, dynamic>;
      parts.forEach((key, value) {
        partsMap[key] = (value is double) ? value : (value as num).toDouble();
      });
    }

    return DailyPrediction(
      date: json['date'] as String? ?? '',
      totalUsage: (json['total_usage'] is double)
          ? json['total_usage']
          : (json['total_usage'] as num).toDouble(),
      parts: partsMap,
    );
  }
}

// ============================================================================
// RETRY LOGIC WITH EXPONENTIAL BACKOFF
// ============================================================================

bool _shouldRetry(int statusCode) {
  return statusCode >= 500 && statusCode < 600;
}

bool _shouldRetryException(dynamic exception) {
  return exception is SocketException ||
      exception is TimeoutException ||
      exception is HttpException;
}

Duration _calculateBackoff(int attemptNumber) {
  int delay = INITIAL_BACKOFF_MS * pow(2, attemptNumber).toInt();
  delay = min(delay, MAX_BACKOFF_MS);
  final random = Random();
  final jitter = delay * 0.2 * (random.nextDouble() * 2 - 1);
  delay = (delay + jitter).toInt();
  return Duration(milliseconds: delay);
}

// ============================================================================
// MAIN API FUNCTION
// ============================================================================

/// Fetch inventory restock forecast from the prediction API
Future<RestockForecast?> fetchRestockForecast({
  int forecastDays = 30,
  String? currentDate,
  String? apiBaseUrl,
}) async {
  final String baseUrl = apiBaseUrl ?? API_BASE_URL;
  final String url = '$baseUrl$FORECAST_ENDPOINT';

  final Map<String, dynamic> requestBody = {'forecast_days': forecastDays};

  if (currentDate != null && currentDate.isNotEmpty) {
    requestBody['current_date'] = currentDate;
  } else {
    final now = DateTime.now();
    requestBody['current_date'] =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  for (int attempt = 0; attempt < MAX_RETRY_ATTEMPTS; attempt++) {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

          if (jsonResponse['status'] == 'success') {
            return RestockForecast.fromJson(jsonResponse);
          } else {
            final errorMessage = jsonResponse['message'] ?? 'Unknown API error';
            print('✗ API error: $errorMessage');
            return null;
          }
        } catch (e) {
          print('✗ Error parsing response JSON: $e');
          return null;
        }
      } else if (response.statusCode >= 400 && response.statusCode < 500) {
        print('✗ Client error (${response.statusCode}): ${response.body}');
        return null;
      } else if (_shouldRetry(response.statusCode)) {
        if (attempt < MAX_RETRY_ATTEMPTS - 1) {
          final backoffDelay = _calculateBackoff(attempt);
          await Future.delayed(backoffDelay);
          continue;
        } else {
          return null;
        }
      } else {
        return null;
      }
    } on TimeoutException {
      if (attempt < MAX_RETRY_ATTEMPTS - 1) {
        final backoffDelay = _calculateBackoff(attempt);
        await Future.delayed(backoffDelay);
        continue;
      } else {
        return null;
      }
    } on SocketException {
      if (attempt < MAX_RETRY_ATTEMPTS - 1) {
        final backoffDelay = _calculateBackoff(attempt);
        await Future.delayed(backoffDelay);
        continue;
      } else {
        return null;
      }
    } catch (e) {
      if (_shouldRetryException(e) && attempt < MAX_RETRY_ATTEMPTS - 1) {
        final backoffDelay = _calculateBackoff(attempt);
        await Future.delayed(backoffDelay);
        continue;
      } else {
        return null;
      }
    }
  }

  return null;
}

/// Check if the API service is healthy
Future<bool> checkApiHealth({String? apiBaseUrl}) async {
  final String baseUrl = apiBaseUrl ?? API_BASE_URL;
  final String url = '$baseUrl/health';

  try {
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final status = jsonResponse['status'] as String?;
      return status == 'healthy' || status == 'degraded';
    } else {
      return false;
    }
  } catch (_) {
    return false;
  }
}

/// Fetch the list of active parts from the API
Future<List<String>?> fetchActiveParts({String? apiBaseUrl}) async {
  final String baseUrl = apiBaseUrl ?? API_BASE_URL;
  final String url = '$baseUrl/parts';

  try {
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['status'] == 'success') {
        final parts =
            (jsonResponse['parts'] as List).map((p) => p.toString()).toList();
        return parts;
      } else {
        return null;
      }
    } else {
      return null;
    }
  } catch (e) {
    return null;
  }
}

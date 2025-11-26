import 'package:flutter/material.dart';
import 'package:lorenz_app/services/monitoring_service.dart';
import 'dart:async';

/// Global error boundary widget that catches and displays errors gracefully
///
/// Wraps the entire app to catch Flutter framework errors and provide
/// a user-friendly error screen with recovery options.
///
/// Example usage:
/// ```dart
/// runApp(
///   ErrorBoundary(
///     child: MyApp(),
///     onError: (error, stackTrace) {
///       // Custom error handling
///       print('Error caught: $error');
///     },
///   ),
/// );
/// ```
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stackTrace, VoidCallback reset)? errorBuilder;
  final Function(Object error, StackTrace? stackTrace)? onError;

  const ErrorBoundary({
    required this.child,
    this.errorBuilder,
    this.onError,
    super.key,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;
  final _monitoring = MonitoringService();

  @override
  void initState() {
    super.initState();

    // Set up Flutter error handler
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // Call original handler first
      originalOnError?.call(details);

      // Then capture the error
      _captureError(details.exception, details.stack);
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(
            _error!,
            _stackTrace,
            _reset,
          ) ??
          _buildDefaultErrorScreen();
    }

    return widget.child;
  }

  void _captureError(Object error, StackTrace? stackTrace) {
    // Skip certain recoverable errors
    final errorStr = error.toString();

    // Skip layout errors
    if (errorStr.contains('RenderBox was not laid out') ||
        errorStr.contains('hasSize') ||
        errorStr.contains('NEEDS-LAYOUT')) {
      // These are usually transient layout errors that resolve themselves
      _monitoring.logWarning(
        'Transient layout error (recovered)',
        metadata: {
          'error': errorStr,
          'component': 'ErrorBoundary',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      return;
    }

    // Skip Flutter web gesture/pointer routing errors
    if (errorStr.contains('pointer_router.dart') ||
        errorStr.contains('_globalRoutes') ||
        errorStr.contains('_routePointer') ||
        errorStr.contains('gestures/') ||
        errorStr.contains('mouse_tracker.dart')) {
      // These are internal Flutter web gesture issues that are non-critical
      _monitoring.logWarning(
        'Flutter web gesture error (recovered)',
        metadata: {
          'error': errorStr,
          'component': 'ErrorBoundary',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      return;
    }

    // Log to monitoring service
    _monitoring.logError(
      'UI Error Caught by ErrorBoundary',
      error,
      stackTrace: stackTrace,
      metadata: {
        'component': 'ErrorBoundary',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    // Call custom error handler
    widget.onError?.call(error, stackTrace);

    // Update state to show error screen
    if (mounted) {
      setState(() {
        _error = error;
        _stackTrace = stackTrace;
      });
    }
  }

  void _reset() {
    if (mounted) {
      setState(() {
        _error = null;
        _stackTrace = null;
      });
    }
  }

  Widget _buildDefaultErrorScreen() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Error Icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'Oops! Something went wrong',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Description
                  Text(
                    'We encountered an unexpected error. This has been logged and we\'ll look into it.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Try Again Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh, size: 24),
                      label: const Text(
                        'Try Again',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Go Home Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _reset();
                        // Note: Navigation will work once error is cleared
                      },
                      icon: const Icon(Icons.home, size: 24),
                      label: const Text(
                        'Go to Home',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade600,
                        side: BorderSide(
                          color: Colors.blue.shade600,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Technical Details (Expandable)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            Icon(
                              Icons.code,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Technical Details',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Error:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  _error.toString(),
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                if (_stackTrace != null) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Stack Trace:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    _stackTrace.toString(),
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Help Text
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'If this problem persists, please contact support',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrapper function to run app with error boundary and zone error handling
///
/// Example usage:
/// ```dart
/// void main() async {
///   await Firebase.initializeApp();
///
///   runAppWithErrorHandling(
///     child: ProviderScope(child: MyApp()),
///   );
/// }
/// ```
void runAppWithErrorHandling({
  required Widget child,
  Function(Object error, StackTrace stackTrace)? onError,
}) {
  final monitoring = MonitoringService();

  runZonedGuarded(
    () {
      runApp(
        ErrorBoundary(
          onError: (error, stackTrace) {
            // Log to monitoring service
            monitoring.logCritical(
              'App-level error',
              error,
              stackTrace: stackTrace,
              metadata: {
                'source': 'ErrorBoundary',
                'timestamp': DateTime.now().toIso8601String(),
              },
            );

            // Call custom error handler
            onError?.call(error, stackTrace ?? StackTrace.empty);
          },
          child: child,
        ),
      );
    },
    (error, stackTrace) {
      // Capture uncaught async errors
      monitoring.logCritical(
        'Uncaught Async Error',
        error,
        stackTrace: stackTrace,
        metadata: {
          'source': 'runZonedGuarded',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Call custom error handler
      onError?.call(error, stackTrace);
    },
  );
}

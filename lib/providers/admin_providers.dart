import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorenz_app/services/admin_service.dart';
import 'package:lorenz_app/services/secure_auth_service.dart';
import 'package:lorenz_app/providers/auth_providers.dart';

// Admin Service Provider
final adminServiceProvider = Provider<AdminService>((ref) {
  // Use ref.read() to avoid creating circular dependencies
  final authService = ref.read(secureAuthServiceProvider);
  return AdminService(authService: authService);
});

// All Users Provider
final allUsersProvider = FutureProvider<List<UserProfile>>((ref) async {
  final adminService = ref.read(adminServiceProvider);
  return await adminService.getAllUsers();
});

// Users by Role Provider
final usersByRoleProvider = FutureProvider.family<List<UserProfile>, UserRole>(
  (ref, role) async {
    final adminService = ref.read(adminServiceProvider);
    return await adminService.getUsersByRole(role);
  },
);

// Active Users Count Provider
final activeUsersCountProvider = FutureProvider<int>((ref) async {
  final adminService = ref.read(adminServiceProvider);
  return await adminService.getActiveUsersCount();
});

// Inactive Users Count Provider
final inactiveUsersCountProvider = FutureProvider<int>((ref) async {
  final adminService = ref.read(adminServiceProvider);
  return await adminService.getInactiveUsersCount();
});

// All Appointments Provider
final allAppointmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final adminService = ref.read(adminServiceProvider);
  return await adminService.getAllAppointments();
});

// Appointment Statistics Provider
final appointmentStatisticsProvider = FutureProvider<Map<String, int>>((ref) async {
  final adminService = ref.read(adminServiceProvider);
  return await adminService.getAppointmentStatistics();
});

// All Feedback Provider
final allFeedbackProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final adminService = ref.read(adminServiceProvider);
  return await adminService.getAllFeedback();
});

// Feedback Statistics Provider
final feedbackStatisticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final adminService = ref.read(adminServiceProvider);
  return await adminService.getFeedbackStatistics();
});

// User Registration Trend Provider
final userRegistrationTrendProvider = FutureProvider<Map<String, int>>((ref) async {
  final adminService = ref.read(adminServiceProvider);
  return await adminService.getUserRegistrationTrend();
});

// Appointments by Service Type Provider
final appointmentsByServiceTypeProvider = FutureProvider<Map<String, int>>((ref) async {
  final adminService = ref.read(adminServiceProvider);
  return await adminService.getAppointmentsByServiceType();
});

// System Statistics Provider
final systemStatisticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final adminService = ref.read(adminServiceProvider);
  return await adminService.getSystemStatistics();
});

// Security Events Provider
final securityEventsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>(
  (ref, limit) async {
    final adminService = ref.read(adminServiceProvider);
    return await adminService.getSecurityEvents(limit: limit);
  },
);

// Failed Login Attempts Provider
final failedLoginAttemptsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final adminService = ref.read(adminServiceProvider);
  return await adminService.getFailedLoginAttempts();
});

// Stream Providers for real-time data
final appointmentsStreamProvider = StreamProvider((ref) {
  final adminService = ref.read(adminServiceProvider);
  return adminService.streamAppointments();
});

final usersStreamProvider = StreamProvider((ref) {
  final adminService = ref.read(adminServiceProvider);
  return adminService.streamUsers();
});

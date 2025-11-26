import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lorenz_app/services/secure_auth_service.dart';

class AdminService {
  final FirebaseFirestore _firestore;
  final SecureAuthService _authService;

  AdminService({
    FirebaseFirestore? firestore,
    SecureAuthService? authService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authService = authService ?? SecureAuthService();

  // ==================== USER MANAGEMENT ====================

  /// Get all users (admin only)
  Future<List<UserProfile>> getAllUsers() async {
    await _ensureAdmin();

    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs.map((doc) => UserProfile.fromMap(doc.data())).toList();
  }

  /// Get users by role
  Future<List<UserProfile>> getUsersByRole(UserRole role) async {
    await _ensureAdmin();

    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: role.toString().split('.').last)
        .get();

    return snapshot.docs.map((doc) => UserProfile.fromMap(doc.data())).toList();
  }

  /// Get active users count
  Future<int> getActiveUsersCount() async {
    await _ensureAdmin();

    final snapshot = await _firestore
        .collection('users')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.length;
  }

  /// Get inactive users count
  Future<int> getInactiveUsersCount() async {
    await _ensureAdmin();

    final snapshot = await _firestore
        .collection('users')
        .where('isActive', isEqualTo: false)
        .get();

    return snapshot.docs.length;
  }

  /// Update user role
  Future<void> updateUserRole(String userId, UserRole newRole) async {
    await _ensureAdmin();
    await _authService.updateUserRole(userId, newRole);
  }

  /// Activate user account
  Future<void> activateUser(String userId) async {
    await _ensureAdmin();

    await _firestore.collection('users').doc(userId).update({
      'isActive': true,
    });
  }

  /// Deactivate user account
  Future<void> deactivateUser(String userId) async {
    await _ensureAdmin();
    await _authService.deactivateUser(userId);
  }

  /// Delete user account (soft delete)
  Future<void> deleteUser(String userId) async {
    await _ensureAdmin();

    await _firestore.collection('users').doc(userId).update({
      'isActive': false,
      'deletedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ==================== APPOINTMENT MANAGEMENT ====================

  /// Get all appointments
  Future<List<Map<String, dynamic>>> getAllAppointments() async {
    await _ensureAdmin();

    final snapshot = await _firestore
        .collection('appointments')
        .orderBy('dateTime', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Get appointments for a specific date range
  Future<List<Map<String, dynamic>>> getAppointmentsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    await _ensureAdmin();

    final snapshot = await _firestore
        .collection('appointments')
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('dateTime', isLessThan: Timestamp.fromDate(endDate))
        .orderBy('dateTime')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Get appointments statistics
  Future<Map<String, int>> getAppointmentStatistics() async {
    await _ensureAdmin();

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 1);
      final yearStart = DateTime(now.year, 1, 1);
      final yearEnd = DateTime(now.year + 1, 1, 1);

      // Fetch all appointments once to avoid multiple queries and index requirements
      final snapshot = await _firestore.collection('appointments').get();

      int todayCount = 0;
      int monthCount = 0;
      int yearCount = 0;
      final totalCount = snapshot.docs.length;

      // Filter in memory to avoid composite index requirements
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['dateTime'] != null) {
          final dateTime = data['dateTime'] is Timestamp
              ? (data['dateTime'] as Timestamp).toDate()
              : DateTime.tryParse(data['dateTime']?.toString() ?? '') ?? DateTime.now();

          if (dateTime.isAfter(todayStart) && dateTime.isBefore(todayEnd)) {
            todayCount++;
          }
          if (dateTime.isAfter(monthStart) && dateTime.isBefore(monthEnd)) {
            monthCount++;
          }
          if (dateTime.isAfter(yearStart) && dateTime.isBefore(yearEnd)) {
            yearCount++;
          }
        }
      }

      return {
        'today': todayCount,
        'thisMonth': monthCount,
        'thisYear': yearCount,
        'total': totalCount,
      };
    } catch (e) {
      // Return zeros if there's an error
      return {
        'today': 0,
        'thisMonth': 0,
        'thisYear': 0,
        'total': 0,
      };
    }
  }

  /// Update appointment status
  Future<void> updateAppointmentStatus(String appointmentId, String status) async {
    await _ensureAdmin();

    await _firestore.collection('appointments').doc(appointmentId).update({
      'status': status,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Delete appointment
  Future<void> deleteAppointment(String appointmentId) async {
    await _ensureAdmin();

    await _firestore.collection('appointments').doc(appointmentId).delete();
  }

  // ==================== FEEDBACK MANAGEMENT ====================

  /// Get all feedback
  Future<List<Map<String, dynamic>>> getAllFeedback() async {
    await _ensureAdmin();

    final snapshot = await _firestore
        .collection('feedback')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Get feedback statistics
  Future<Map<String, dynamic>> getFeedbackStatistics() async {
    await _ensureAdmin();

    final snapshot = await _firestore.collection('feedback').get();
    final feedbacks = snapshot.docs;

    if (feedbacks.isEmpty) {
      return {
        'total': 0,
        'averageRating': 0.0,
        'ratingDistribution': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
      };
    }

    int totalRating = 0;
    Map<String, int> distribution = {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0};

    for (var doc in feedbacks) {
      final rating = (doc.data()['rating'] ?? 0) as int;
      totalRating += rating;
      distribution[rating.toString()] = (distribution[rating.toString()] ?? 0) + 1;
    }

    return {
      'total': feedbacks.length,
      'averageRating': totalRating / feedbacks.length,
      'ratingDistribution': distribution,
    };
  }

  /// Delete feedback
  Future<void> deleteFeedback(String feedbackId) async {
    await _ensureAdmin();

    await _firestore.collection('feedback').doc(feedbackId).delete();
  }

  // ==================== ANALYTICS ====================

  /// Get user registration trend (last 30 days)
  Future<Map<String, int>> getUserRegistrationTrend() async {
    await _ensureAdmin();

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final snapshot = await _firestore
        .collection('users')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    Map<String, int> trend = {};
    for (var doc in snapshot.docs) {
      final createdAt = (doc.data()['createdAt'] as Timestamp).toDate();
      final dateKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
      trend[dateKey] = (trend[dateKey] ?? 0) + 1;
    }

    return trend;
  }

  /// Get appointment trend by service type
  Future<Map<String, int>> getAppointmentsByServiceType() async {
    await _ensureAdmin();

    final snapshot = await _firestore.collection('appointments').get();

    Map<String, int> serviceCount = {};
    for (var doc in snapshot.docs) {
      final service = doc.data()['service'] as String? ?? 'Unknown';
      serviceCount[service] = (serviceCount[service] ?? 0) + 1;
    }

    return serviceCount;
  }

  /// Get revenue statistics (if payment data exists)
  Future<Map<String, dynamic>> getRevenueStatistics() async {
    await _ensureAdmin();

    // This is a placeholder - implement based on your payment structure
    // final now = DateTime.now();
    // final monthStart = DateTime(now.year, now.month, 1);
    // final yearStart = DateTime(now.year, 1, 1);

    return {
      'todayRevenue': 0.0,
      'monthRevenue': 0.0,
      'yearRevenue': 0.0,
      'totalRevenue': 0.0,
    };
  }

  // ==================== SECURITY & AUDIT ====================

  /// Get recent security events
  Future<List<Map<String, dynamic>>> getSecurityEvents({int limit = 50}) async {
    await _ensureAdmin();

    final snapshot = await _firestore
        .collection('security_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Get failed login attempts
  Future<Map<String, dynamic>> getFailedLoginAttempts() async {
    await _ensureAdmin();

    final doc = await _firestore.collection('security').doc('failed_attempts').get();
    return doc.data() ?? {};
  }

  /// Clear failed login attempts for a user
  Future<void> clearFailedLoginAttempts(String email) async {
    await _ensureAdmin();

    final docRef = _firestore.collection('security').doc('failed_attempts');
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (doc.exists) {
        final data = doc.data()!;
        data.remove(email);
        transaction.set(docRef, data);
      }
    });
  }

  // ==================== SYSTEM MANAGEMENT ====================

  /// Get system statistics
  Future<Map<String, dynamic>> getSystemStatistics() async {
    await _ensureAdmin();

    final futures = await Future.wait([
      _firestore.collection('users').get(),
      _firestore.collection('appointments').get(),
      _firestore.collection('feedback').get(),
      _firestore.collection('security_logs').get(),
    ]);

    return {
      'totalUsers': futures[0].docs.length,
      'totalAppointments': futures[1].docs.length,
      'totalFeedback': futures[2].docs.length,
      'totalSecurityEvents': futures[3].docs.length,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Stream appointments (real-time)
  Stream<QuerySnapshot> streamAppointments() {
    return _firestore
        .collection('appointments')
        .orderBy('dateTime', descending: true)
        .limit(100)
        .snapshots();
  }

  /// Stream users (real-time)
  Stream<QuerySnapshot> streamUsers() {
    return _firestore.collection('users').snapshots();
  }

  // ==================== HELPER METHODS ====================

  /// Ensure current user is admin
  Future<void> _ensureAdmin() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      throw Exception('Authentication required');
    }

    final userProfile = await _authService.getUserProfile(currentUser.uid);
    if (!userProfile.canAccessAdmin()) {
      throw Exception('Admin access required');
    }
  }

  /// Create default admin account (use once during setup)
  Future<UserProfile> createAdminAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return await _authService.signUpWithEmail(
      email: email,
      password: password,
      displayName: displayName,
      role: UserRole.admin,
    );
  }
}

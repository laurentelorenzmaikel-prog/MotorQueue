import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lorenz_app/services/monitoring_service.dart';

enum AuditEventType {
  authentication,
  authorization,
  dataAccess,
  dataModification,
  systemAccess,
  configuration,
  adminAction,
  securityEvent,
  businessProcess,
}

enum AuditSeverity { low, medium, high, critical }

class AuditEvent {
  final String id;
  final AuditEventType eventType;
  final AuditSeverity severity;
  final String action;
  final String description;
  final DateTime timestamp;
  final String userId;
  final String userEmail;
  final String? userRole;
  final String? targetResource;
  final String? targetId;
  final Map<String, dynamic> beforeData;
  final Map<String, dynamic> afterData;
  final Map<String, dynamic> metadata;
  final String ipAddress;
  final String userAgent;
  final bool success;
  final String? errorMessage;

  AuditEvent({
    required this.id,
    required this.eventType,
    required this.severity,
    required this.action,
    required this.description,
    required this.timestamp,
    required this.userId,
    required this.userEmail,
    this.userRole,
    this.targetResource,
    this.targetId,
    this.beforeData = const {},
    this.afterData = const {},
    this.metadata = const {},
    required this.ipAddress,
    required this.userAgent,
    this.success = true,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventType': eventType.toString().split('.').last,
      'severity': severity.toString().split('.').last,
      'action': action,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'userId': userId,
      'userEmail': userEmail,
      'userRole': userRole,
      'targetResource': targetResource,
      'targetId': targetId,
      'beforeData': beforeData,
      'afterData': afterData,
      'metadata': metadata,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'success': success,
      'errorMessage': errorMessage,
    };
  }

  factory AuditEvent.fromMap(Map<String, dynamic> map) {
    return AuditEvent(
      id: map['id'],
      eventType: AuditEventType.values.firstWhere(
        (e) => e.toString().split('.').last == map['eventType'],
      ),
      severity: AuditSeverity.values.firstWhere(
        (s) => s.toString().split('.').last == map['severity'],
      ),
      action: map['action'],
      description: map['description'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      userId: map['userId'],
      userEmail: map['userEmail'],
      userRole: map['userRole'],
      targetResource: map['targetResource'],
      targetId: map['targetId'],
      beforeData: Map<String, dynamic>.from(map['beforeData'] ?? {}),
      afterData: Map<String, dynamic>.from(map['afterData'] ?? {}),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      ipAddress: map['ipAddress'],
      userAgent: map['userAgent'],
      success: map['success'] ?? true,
      errorMessage: map['errorMessage'],
    );
  }
}

class ComplianceReport {
  final String reportId;
  final DateTime generatedAt;
  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<String, int> eventCounts;
  final List<AuditEvent> criticalEvents;
  final List<AuditEvent> failedLogins;
  final List<AuditEvent> privilegedActions;
  final Map<String, dynamic> statistics;

  ComplianceReport({
    required this.reportId,
    required this.generatedAt,
    required this.periodStart,
    required this.periodEnd,
    required this.eventCounts,
    required this.criticalEvents,
    required this.failedLogins,
    required this.privilegedActions,
    required this.statistics,
  });

  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
      'eventCounts': eventCounts,
      'criticalEvents': criticalEvents.map((e) => e.toMap()).toList(),
      'failedLogins': failedLogins.map((e) => e.toMap()).toList(),
      'privilegedActions': privilegedActions.map((e) => e.toMap()).toList(),
      'statistics': statistics,
    };
  }
}

class AuditService {
  final FirebaseFirestore _firestore;
  final MonitoringService _monitoring;

  static const String _auditCollection = 'audit_logs';
  static const String _complianceCollection = 'compliance_reports';

  AuditService({
    FirebaseFirestore? firestore,
    MonitoringService? monitoring,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _monitoring = monitoring ?? MonitoringService();

  // Authentication Events
  Future<void> logLoginAttempt({
    required String email,
    required bool success,
    String? errorMessage,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) async {
    await _logEvent(
      eventType: AuditEventType.authentication,
      severity: success ? AuditSeverity.low : AuditSeverity.medium,
      action: 'LOGIN_ATTEMPT',
      description: 'User login attempt',
      userId: success ? FirebaseAuth.instance.currentUser?.uid ?? 'unknown' : 'unknown',
      userEmail: email,
      success: success,
      errorMessage: errorMessage,
      ipAddress: ipAddress,
      userAgent: userAgent,
      metadata: {
        'login_method': 'email_password',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> logLogout({
    required String userId,
    required String userEmail,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) async {
    await _logEvent(
      eventType: AuditEventType.authentication,
      severity: AuditSeverity.low,
      action: 'LOGOUT',
      description: 'User logout',
      userId: userId,
      userEmail: userEmail,
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  Future<void> logPasswordChange({
    required String userId,
    required String userEmail,
    required bool success,
    String? errorMessage,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) async {
    await _logEvent(
      eventType: AuditEventType.authentication,
      severity: AuditSeverity.medium,
      action: 'PASSWORD_CHANGE',
      description: 'Password change attempt',
      userId: userId,
      userEmail: userEmail,
      success: success,
      errorMessage: errorMessage,
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  // Authorization Events
  Future<void> logAccessDenied({
    required String userId,
    required String userEmail,
    required String resource,
    required String action,
    String? reason,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) async {
    await _logEvent(
      eventType: AuditEventType.authorization,
      severity: AuditSeverity.medium,
      action: 'ACCESS_DENIED',
      description: 'Access denied to resource',
      userId: userId,
      userEmail: userEmail,
      targetResource: resource,
      success: false,
      errorMessage: reason,
      ipAddress: ipAddress,
      userAgent: userAgent,
      metadata: {
        'attempted_action': action,
        'resource': resource,
      },
    );
  }

  Future<void> logRoleChange({
    required String adminUserId,
    required String adminEmail,
    required String targetUserId,
    required String targetEmail,
    required String oldRole,
    required String newRole,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) async {
    await _logEvent(
      eventType: AuditEventType.adminAction,
      severity: AuditSeverity.high,
      action: 'ROLE_CHANGE',
      description: 'User role changed',
      userId: adminUserId,
      userEmail: adminEmail,
      userRole: 'admin',
      targetResource: 'user',
      targetId: targetUserId,
      beforeData: {'role': oldRole, 'targetUser': targetEmail},
      afterData: {'role': newRole, 'targetUser': targetEmail},
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  // Data Access Events
  Future<void> logDataAccess({
    required String userId,
    required String userEmail,
    required String resource,
    required String resourceId,
    String? userRole,
    Map<String, dynamic>? additionalData,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) async {
    await _logEvent(
      eventType: AuditEventType.dataAccess,
      severity: AuditSeverity.low,
      action: 'DATA_ACCESS',
      description: 'Data access operation',
      userId: userId,
      userEmail: userEmail,
      userRole: userRole,
      targetResource: resource,
      targetId: resourceId,
      metadata: additionalData ?? {},
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  // Data Modification Events
  Future<void> logDataModification({
    required String userId,
    required String userEmail,
    required String action,
    required String resource,
    required String resourceId,
    Map<String, dynamic>? beforeData,
    Map<String, dynamic>? afterData,
    String? userRole,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) async {
    await _logEvent(
      eventType: AuditEventType.dataModification,
      severity: AuditSeverity.medium,
      action: action.toUpperCase(),
      description: 'Data modification operation',
      userId: userId,
      userEmail: userEmail,
      userRole: userRole,
      targetResource: resource,
      targetId: resourceId,
      beforeData: beforeData ?? {},
      afterData: afterData ?? {},
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  Future<void> logAppointmentCreated({
    required String userId,
    required String userEmail,
    required String appointmentId,
    required Map<String, dynamic> appointmentData,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) async {
    await logDataModification(
      userId: userId,
      userEmail: userEmail,
      action: 'CREATE',
      resource: 'appointment',
      resourceId: appointmentId,
      afterData: appointmentData,
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  Future<void> logAppointmentUpdated({
    required String userId,
    required String userEmail,
    required String appointmentId,
    required Map<String, dynamic> beforeData,
    required Map<String, dynamic> afterData,
    String? userRole,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) async {
    await logDataModification(
      userId: userId,
      userEmail: userEmail,
      action: 'UPDATE',
      resource: 'appointment',
      resourceId: appointmentId,
      beforeData: beforeData,
      afterData: afterData,
      userRole: userRole,
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  Future<void> logAppointmentDeleted({
    required String userId,
    required String userEmail,
    required String appointmentId,
    required Map<String, dynamic> appointmentData,
    String? userRole,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) async {
    await _logEvent(
      eventType: AuditEventType.dataModification,
      severity: AuditSeverity.high,
      action: 'DELETE',
      description: 'Appointment deleted',
      userId: userId,
      userEmail: userEmail,
      userRole: userRole,
      targetResource: 'appointment',
      targetId: appointmentId,
      beforeData: appointmentData,
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  // Admin Actions
  Future<void> logAdminDashboardAccess({
    required String userId,
    required String userEmail,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) async {
    await _logEvent(
      eventType: AuditEventType.systemAccess,
      severity: AuditSeverity.medium,
      action: 'ADMIN_DASHBOARD_ACCESS',
      description: 'Admin dashboard accessed',
      userId: userId,
      userEmail: userEmail,
      userRole: 'admin',
      targetResource: 'admin_dashboard',
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  Future<void> logSystemConfiguration({
    required String userId,
    required String userEmail,
    required String configKey,
    required String oldValue,
    required String newValue,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) async {
    await _logEvent(
      eventType: AuditEventType.configuration,
      severity: AuditSeverity.high,
      action: 'SYSTEM_CONFIG_CHANGE',
      description: 'System configuration changed',
      userId: userId,
      userEmail: userEmail,
      userRole: 'admin',
      targetResource: 'system_config',
      targetId: configKey,
      beforeData: {'value': oldValue},
      afterData: {'value': newValue},
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  // Security Events
  Future<void> logSecurityIncident({
    required String userId,
    required String userEmail,
    required String incidentType,
    required String description,
    Map<String, dynamic>? incidentData,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) async {
    await _logEvent(
      eventType: AuditEventType.securityEvent,
      severity: AuditSeverity.critical,
      action: 'SECURITY_INCIDENT',
      description: description,
      userId: userId,
      userEmail: userEmail,
      metadata: {
        'incident_type': incidentType,
        ...?incidentData,
      },
      ipAddress: ipAddress,
      userAgent: userAgent,
    );

    // Also log to monitoring service for immediate alerts
    await _monitoring.logSecurityEvent(
      incidentType,
      userId: userId,
      userEmail: userEmail,
      metadata: incidentData,
    );
  }

  // Business Process Events
  Future<void> logBusinessProcess({
    required String userId,
    required String userEmail,
    required String processName,
    required String action,
    Map<String, dynamic>? processData,
    String ipAddress = 'unknown',
    String userAgent = 'unknown',
  }) async {
    await _logEvent(
      eventType: AuditEventType.businessProcess,
      severity: AuditSeverity.low,
      action: action.toUpperCase(),
      description: 'Business process executed',
      userId: userId,
      userEmail: userEmail,
      targetResource: processName,
      metadata: processData ?? {},
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  // Query Methods
  Future<List<AuditEvent>> getAuditLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
    AuditEventType? eventType,
    AuditSeverity? minSeverity,
    String? targetResource,
    int limit = 100,
  }) async {
    Query query = _firestore.collection(_auditCollection)
        .orderBy('timestamp', descending: true);

    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    if (eventType != null) {
      query = query.where('eventType', isEqualTo: eventType.toString().split('.').last);
    }

    if (targetResource != null) {
      query = query.where('targetResource', isEqualTo: targetResource);
    }

    final snapshot = await query.limit(limit).get();

    return snapshot.docs.map((doc) {
      return AuditEvent.fromMap(doc.data() as Map<String, dynamic>);
    }).where((event) {
      if (minSeverity != null) {
        final severityIndex = AuditSeverity.values.indexOf(event.severity);
        final minSeverityIndex = AuditSeverity.values.indexOf(minSeverity);
        return severityIndex >= minSeverityIndex;
      }
      return true;
    }).toList();
  }

  Future<List<AuditEvent>> getFailedLoginAttempts({
    DateTime? since,
    int limit = 50,
  }) async {
    Query query = _firestore.collection(_auditCollection)
        .where('action', isEqualTo: 'LOGIN_ATTEMPT')
        .where('success', isEqualTo: false)
        .orderBy('timestamp', descending: true);

    if (since != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    }

    final snapshot = await query.limit(limit).get();

    return snapshot.docs.map((doc) {
      return AuditEvent.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  Future<List<AuditEvent>> getPrivilegedActions({
    DateTime? since,
    int limit = 100,
  }) async {
    Query query = _firestore.collection(_auditCollection)
        .where('userRole', isEqualTo: 'admin')
        .orderBy('timestamp', descending: true);

    if (since != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    }

    final snapshot = await query.limit(limit).get();

    return snapshot.docs.map((doc) {
      return AuditEvent.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  // Compliance Reporting
  Future<ComplianceReport> generateComplianceReport({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final reportId = DateTime.now().millisecondsSinceEpoch.toString();

    // Get all events in the period
    final allEvents = await getAuditLogs(
      startDate: periodStart,
      endDate: periodEnd,
      limit: 10000,
    );

    // Get specific event types
    final criticalEvents = allEvents.where((e) => e.severity == AuditSeverity.critical).toList();
    final failedLogins = allEvents.where((e) =>
        e.action == 'LOGIN_ATTEMPT' && !e.success).toList();
    final privilegedActions = allEvents.where((e) => e.userRole == 'admin').toList();

    // Count events by type
    final eventCounts = <String, int>{};
    for (final eventType in AuditEventType.values) {
      final count = allEvents.where((e) => e.eventType == eventType).length;
      eventCounts[eventType.toString().split('.').last] = count;
    }

    // Generate statistics
    final statistics = {
      'total_events': allEvents.length,
      'total_users': allEvents.map((e) => e.userId).toSet().length,
      'failed_login_rate': failedLogins.length / (allEvents.where((e) => e.action == 'LOGIN_ATTEMPT').length + 1),
      'critical_events_count': criticalEvents.length,
      'privileged_actions_count': privilegedActions.length,
      'most_active_user': _getMostActiveUser(allEvents),
      'peak_activity_hour': _getPeakActivityHour(allEvents),
    };

    final report = ComplianceReport(
      reportId: reportId,
      generatedAt: DateTime.now(),
      periodStart: periodStart,
      periodEnd: periodEnd,
      eventCounts: eventCounts,
      criticalEvents: criticalEvents,
      failedLogins: failedLogins,
      privilegedActions: privilegedActions,
      statistics: statistics,
    );

    // Store the report
    await _firestore.collection(_complianceCollection).doc(reportId).set(report.toMap());

    return report;
  }

  // Cleanup Methods
  Future<void> cleanupOldAuditLogs({Duration retention = const Duration(days: 365)}) async {
    final cutoffDate = DateTime.now().subtract(retention);
    final query = _firestore.collection(_auditCollection)
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate));

    final snapshot = await query.get();
    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();

    await _monitoring.logInfo('Cleaned up ${snapshot.docs.length} old audit log entries');
  }

  // Private helper methods
  Future<void> _logEvent({
    required AuditEventType eventType,
    required AuditSeverity severity,
    required String action,
    required String description,
    required String userId,
    required String userEmail,
    String? userRole,
    String? targetResource,
    String? targetId,
    Map<String, dynamic> beforeData = const {},
    Map<String, dynamic> afterData = const {},
    Map<String, dynamic> metadata = const {},
    required String ipAddress,
    required String userAgent,
    bool success = true,
    String? errorMessage,
  }) async {
    final event = AuditEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      eventType: eventType,
      severity: severity,
      action: action,
      description: description,
      timestamp: DateTime.now(),
      userId: userId,
      userEmail: userEmail,
      userRole: userRole,
      targetResource: targetResource,
      targetId: targetId,
      beforeData: beforeData,
      afterData: afterData,
      metadata: metadata,
      ipAddress: ipAddress,
      userAgent: userAgent,
      success: success,
      errorMessage: errorMessage,
    );

    try {
      await _firestore.collection(_auditCollection).doc(event.id).set(event.toMap());

      // Log critical events to monitoring service for immediate attention
      if (severity == AuditSeverity.critical) {
        await _monitoring.logCritical(
          'Critical audit event: $action',
          description,
          metadata: event.toMap(),
        );
      }
    } catch (e) {
      // Fallback to monitoring service if Firestore fails
      await _monitoring.logError('Failed to log audit event', e, metadata: event.toMap());
    }
  }

  String _getMostActiveUser(List<AuditEvent> events) {
    final userCounts = <String, int>{};
    for (final event in events) {
      userCounts[event.userEmail] = (userCounts[event.userEmail] ?? 0) + 1;
    }

    if (userCounts.isEmpty) return 'none';

    return userCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  int _getPeakActivityHour(List<AuditEvent> events) {
    final hourCounts = List.filled(24, 0);
    for (final event in events) {
      hourCounts[event.timestamp.hour]++;
    }

    int peakHour = 0;
    int maxCount = 0;
    for (int i = 0; i < 24; i++) {
      if (hourCounts[i] > maxCount) {
        maxCount = hourCounts[i];
        peakHour = i;
      }
    }

    return peakHour;
  }
}
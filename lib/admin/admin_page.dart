import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorenz_app/admin/analytics_page.dart';
import 'package:lorenz_app/admin/admin_dashboard_pages.dart';
import 'package:lorenz_app/admin/users_management_page.dart';
import 'package:lorenz_app/widgets/auth_guard.dart';
import 'package:lorenz_app/services/audit_service.dart';
import 'package:lorenz_app/services/monitoring_service.dart';
import 'package:lorenz_app/services/cache_service.dart';
import 'package:lorenz_app/providers/auth_providers.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int todayCount = 0;
  int monthCount = 0;
  int yearCount = 0;
  bool isLoading = true;
  String? errorMessage;

  late AuditService _auditService;
  late MonitoringService _monitoringService;
  late CacheService _cacheService;

  @override
  void initState() {
    super.initState();
    _auditService = AuditService();
    _monitoringService = MonitoringService();
    _cacheService = CacheService.instance;

    _initializeServices();
    _loadAppointmentStats();
  }

  Future<void> _initializeServices() async {
    try {
      await _cacheService.initialize();
      await _logDashboardAccess();
    } catch (e) {
      await _monitoringService.logError('Failed to initialize services', e);
    }
  }

  Future<void> _logDashboardAccess() async {
    final userProfileAsync = ref.read(userProfileProvider);
    userProfileAsync.whenData((userProfile) async {
      if (userProfile != null) {
        await _auditService.logAdminDashboardAccess(
          userId: userProfile.uid,
          userEmail: userProfile.email,
        );

        await _monitoringService.logUserAction(
          'admin_dashboard_access',
          userId: userProfile.uid,
          userEmail: userProfile.email,
          metadata: {'dashboard_section': 'main'},
        );
      }
    });
  }

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  DateTime _startOfYear(DateTime date) {
    return DateTime(date.year, 1, 1);
  }

  Future<void> _loadAppointmentStats() async {
    final trace = _monitoringService.startTrace('load_appointment_stats');
    final startTime = DateTime.now();

    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Try to load from cache first
      final cacheKey =
          'admin_dashboard_stats_${_startOfDay(DateTime.now()).toIso8601String()}';
      final cachedStats = await _cacheService.get<Map<String, dynamic>>(
        cacheKey,
        ttl: const Duration(minutes: 5), // Cache for 5 minutes
      );

      if (cachedStats != null) {
        if (mounted) {
          setState(() {
            todayCount = cachedStats['todayCount'] ?? 0;
            monthCount = cachedStats['monthCount'] ?? 0;
            yearCount = cachedStats['yearCount'] ?? 0;
            isLoading = false;
          });
        }

        await _monitoringService.logInfo('Dashboard stats loaded from cache');
        return;
      }

      final now = DateTime.now();
      final collection = FirebaseFirestore.instance.collection('appointments');

      // Define date ranges
      final todayStart = _startOfDay(now);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final monthStart = _startOfMonth(now);
      final monthEnd = DateTime(now.year, now.month + 1, 1);

      final yearStart = _startOfYear(now);
      final yearEnd = DateTime(now.year + 1, 1, 1);

      // Fetch all appointments once and filter in memory to avoid composite index requirements
      final snapshot = await collection.get();

      int todayCountVar = 0;
      int monthCountVar = 0;
      int yearCountVar = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['dateTime'] != null) {
          final dateTime = data['dateTime'] is Timestamp
              ? (data['dateTime'] as Timestamp).toDate()
              : DateTime.tryParse(data['dateTime']?.toString() ?? '') ?? DateTime.now();

          if (dateTime.isAfter(todayStart) && dateTime.isBefore(todayEnd)) {
            todayCountVar++;
          }
          if (dateTime.isAfter(monthStart) && dateTime.isBefore(monthEnd)) {
            monthCountVar++;
          }
          if (dateTime.isAfter(yearStart) && dateTime.isBefore(yearEnd)) {
            yearCountVar++;
          }
        }
      }

      final stats = {
        'todayCount': todayCountVar,
        'monthCount': monthCountVar,
        'yearCount': yearCountVar,
      };

      // Cache the results
      await _cacheService.set(cacheKey, stats, ttl: const Duration(minutes: 5));

      if (mounted) {
        setState(() {
          todayCount = stats['todayCount']!;
          monthCount = stats['monthCount']!;
          yearCount = stats['yearCount']!;
          isLoading = false;
        });
      }

      // Log successful data load
      final duration = DateTime.now().difference(startTime);
      await _monitoringService.logPerformanceMetric(
        'admin_dashboard_load_time',
        duration.inMilliseconds.toDouble(),
        attributes: {
          'cache_hit': 'false',
          'today_count': stats['todayCount'].toString(),
          'month_count': stats['monthCount'].toString(),
          'year_count': stats['yearCount'].toString(),
        },
      );

      final userProfileAsync = ref.read(userProfileProvider);
      userProfileAsync.whenData((userProfile) async {
        if (userProfile != null) {
          await _auditService.logDataAccess(
            userId: userProfile.uid,
            userEmail: userProfile.email,
            resource: 'appointment_statistics',
            resourceId: 'dashboard_stats',
            userRole: userProfile.role.toString(),
            additionalData: stats,
          );
        }
      });
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          errorMessage =
              'Failed to load appointment statistics: ${e.toString()}';
          isLoading = false;
        });
      }

      await _monitoringService.logError(
        'Failed to load admin dashboard stats',
        e,
        stackTrace: stackTrace,
        metadata: {
          'user_id': ref.read(currentUserIdProvider),
          'function': '_loadAppointmentStats',
        },
      );
    } finally {
      trace?.stop();
    }
  }

  void _logout(BuildContext context) async {
    var sessionBox = await Hive.openBox('session');
    await sessionBox.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _navigateTo(BuildContext context, String title) {
    final Widget page;
    switch (title) {
      case 'Appointment Analytics':
        page = const AnalyticsPage();
        break;
      case 'Today\'s Appointments':
        page = AppointmentsTodayPage();
        break;
      case 'This Month\'s Appointments':
        page = AdminFeedbackPage(); // Temporary placeholder
        break;
      case 'This Year\'s Appointments':
        // Navigate to User Management instead of placeholder
        page = const UsersManagementPage();
        break;
      case 'User Management':
        page = const UsersManagementPage();
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Page "$title" is under development'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: _buildAdminDashboard(context),
    );
  }

  Widget _buildAdminDashboard(BuildContext context) {
    final dashboardItems = [
      {
        'title': 'Today\'s Appointments',
        'subtitle': 'Scheduled for today',
        'value': isLoading ? '...' : todayCount.toString(),
        'icon': Icons.today,
        'gradient': [const Color(0xFF2196F3), const Color(0xFF64B5F6)],
      },
      {
        'title': 'This Month\'s Appointments',
        'subtitle': 'Total this month',
        'value': isLoading ? '...' : monthCount.toString(),
        'icon': Icons.calendar_month,
        'gradient': [const Color(0xFFFF5722), const Color(0xFFFF8A65)],
      },
      {
        'title': 'This Year\'s Appointments',
        'subtitle': 'Total this year',
        'value': isLoading ? '...' : yearCount.toString(),
        'icon': Icons.date_range,
        'gradient': [const Color(0xFF009688), const Color(0xFF4DB6AC)],
      },
      {
        'title': 'User Management',
        'subtitle': 'Manage users & roles',
        'value': '',
        'icon': Icons.people,
        'gradient': [const Color(0xFF9C27B0), const Color(0xFFBA68C8)],
      },
      {
        'title': 'Appointment Analytics',
        'subtitle': 'View detailed reports',
        'value': '',
        'icon': Icons.bar_chart,
        'gradient': [const Color(0xFFE91E63), const Color(0xFFF48FB1)],
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Enhanced header with gradient
          Container(
            padding:
                const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 30),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF225FFF), const Color(0xFF1E88E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF225FFF).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Admin Dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Welcome back, Admin',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon:
                                const Icon(Icons.refresh, color: Colors.white),
                            onPressed: _loadAppointmentStats,
                            tooltip: 'Refresh Data',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.logout, color: Colors.white),
                            onPressed: () => _logout(context),
                            tooltip: 'Logout',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Error message banner
          if (errorMessage != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.error_outline,
                        color: Colors.red.shade600, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => errorMessage = null),
                    color: Colors.red.shade400,
                  ),
                ],
              ),
            ),

          // Dashboard cards with enhanced design
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAppointmentStats,
              color: const Color(0xFF225FFF),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Stats cards grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: dashboardItems.length,
                    itemBuilder: (context, index) {
                      final item = dashboardItems[index];
                      final gradient = item['gradient'] as List<Color>;

                      return GestureDetector(
                        onTap: () =>
                            _navigateTo(context, item['title'] as String),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: gradient[0].withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () =>
                                  _navigateTo(context, item['title'] as String),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.3),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            item['icon'] as IconData,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                        if ((item['value'] as String)
                                            .isNotEmpty)
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            color:
                                                Colors.white.withOpacity(0.7),
                                            size: 16,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if ((item['value'] as String)
                                            .isNotEmpty)
                                          Text(
                                            isLoading
                                                ? '...'
                                                : item['value'] as String,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item['title'] as String,
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.95),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            height: 1.3,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item['subtitle'] as String,
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.7),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

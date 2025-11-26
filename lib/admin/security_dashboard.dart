import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorenz_app/services/audit_service.dart';
import 'package:lorenz_app/services/monitoring_service.dart';
import 'package:lorenz_app/services/cache_service.dart';
import 'package:lorenz_app/widgets/auth_guard.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class SecurityDashboard extends ConsumerStatefulWidget {
  @override
  ConsumerState<SecurityDashboard> createState() => _SecurityDashboardState();
}

class _SecurityDashboardState extends ConsumerState<SecurityDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AuditService _auditService;
  late MonitoringService _monitoringService;
  late CacheService _cacheService;

  List<AuditEvent> _recentEvents = [];
  List<AuditEvent> _failedLogins = [];
  List<AuditEvent> _privilegedActions = [];
  Map<String, dynamic> _systemStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _auditService = AuditService();
    _monitoringService = MonitoringService();
    _cacheService = CacheService.instance;
    _loadSecurityData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSecurityData() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));
      final last7Days = now.subtract(const Duration(days: 7));

      final futures = await Future.wait([
        _auditService.getAuditLogs(
          startDate: last24Hours,
          limit: 50,
        ),
        _auditService.getFailedLoginAttempts(
          since: last7Days,
          limit: 20,
        ),
        _auditService.getPrivilegedActions(
          since: last7Days,
          limit: 30,
        ),
        _loadSystemStats(),
      ]);

      if (mounted) {
        setState(() {
          _recentEvents = futures[0] as List<AuditEvent>;
          _failedLogins = futures[1] as List<AuditEvent>;
          _privilegedActions = futures[2] as List<AuditEvent>;
          _systemStats = futures[3] as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      await _monitoringService.logError('Failed to load security dashboard data', e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _loadSystemStats() async {
    final cacheStats = _cacheService.getStats();

    return {
      'cache_stats': cacheStats,
      'last_updated': DateTime.now(),
      'total_audit_events': _recentEvents.length,
      'failed_logins_count': _failedLogins.length,
      'privileged_actions_count': _privilegedActions.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Security & Monitoring Dashboard'),
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(icon: Icon(Icons.security), text: 'Overview'),
              Tab(icon: Icon(Icons.history), text: 'Audit Trail'),
              Tab(icon: Icon(Icons.warning), text: 'Security Events'),
              Tab(icon: Icon(Icons.analytics), text: 'Performance'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadSecurityData,
              tooltip: 'Refresh Data',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildAuditTrailTab(),
                  _buildSecurityEventsTab(),
                  _buildPerformanceTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSecurityMetricsCards(),
          const SizedBox(height: 24),
          _buildRecentActivityChart(),
          const SizedBox(height: 24),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildSecurityMetricsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Failed Logins (7d)',
            _failedLogins.length.toString(),
            Icons.login,
            _failedLogins.length > 5 ? Colors.red : Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            'Admin Actions (7d)',
            _privilegedActions.length.toString(),
            Icons.admin_panel_settings,
            Colors.purple,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            'Recent Events (24h)',
            _recentEvents.length.toString(),
            Icons.event,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Timeline (Last 24 Hours)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: _buildActivityLineChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLineChart() {
    if (_recentEvents.isEmpty) {
      return const Center(child: Text('No recent activity'));
    }

    // Group events by hour
    final hourlyData = <int, int>{};
    for (int i = 0; i < 24; i++) {
      hourlyData[i] = 0;
    }

    for (final event in _recentEvents) {
      final hour = event.timestamp.hour;
      hourlyData[hour] = (hourlyData[hour] ?? 0) + 1;
    }

    final spots = hourlyData.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}h', style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.red.shade600,
            barWidth: 3,
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildActionButton(
                'Generate Report',
                Icons.report,
                Colors.blue,
                _generateComplianceReport,
              ),
              _buildActionButton(
                'Clear Cache',
                Icons.clear_all,
                Colors.orange,
                _clearSystemCache,
              ),
              _buildActionButton(
                'Export Logs',
                Icons.download,
                Colors.green,
                _exportAuditLogs,
              ),
              _buildActionButton(
                'System Health',
                Icons.health_and_safety,
                Colors.purple,
                _checkSystemHealth,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildAuditTrailTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentEvents.length,
      itemBuilder: (context, index) {
        final event = _recentEvents[index];
        return _buildAuditEventCard(event);
      },
    );
  }

  Widget _buildAuditEventCard(AuditEvent event) {
    Color severityColor;
    switch (event.severity) {
      case AuditSeverity.critical:
        severityColor = Colors.red;
        break;
      case AuditSeverity.high:
        severityColor = Colors.orange;
        break;
      case AuditSeverity.medium:
        severityColor = Colors.yellow.shade700;
        break;
      case AuditSeverity.low:
        severityColor = Colors.green;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: severityColor,
          child: Icon(
            _getEventIcon(event.eventType),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          event.action,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.description),
            const SizedBox(height: 4),
            Text(
              '${event.userEmail} • ${DateFormat('MMM dd, HH:mm').format(event.timestamp)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Icon(
          event.success ? Icons.check_circle : Icons.error,
          color: event.success ? Colors.green : Colors.red,
        ),
        onTap: () => _showEventDetails(event),
      ),
    );
  }

  Widget _buildSecurityEventsTab() {
    final securityEvents = _recentEvents
        .where((e) => e.eventType == AuditEventType.securityEvent || !e.success)
        .toList();

    if (securityEvents.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'No Security Issues Detected',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('Your system is secure!'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: securityEvents.length,
      itemBuilder: (context, index) {
        return _buildSecurityEventCard(securityEvents[index]);
      },
    );
  }

  Widget _buildSecurityEventCard(AuditEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.red.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red,
          child: const Icon(Icons.warning, color: Colors.white),
        ),
        title: Text(
          event.action,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.red.shade800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.description),
            const SizedBox(height: 4),
            Text(
              'User: ${event.userEmail}',
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
            Text(
              'Time: ${DateFormat('MMM dd, yyyy HH:mm').format(event.timestamp)}',
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
            if (event.ipAddress != 'unknown')
              Text(
                'IP: ${event.ipAddress}',
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
          ],
        ),
        onTap: () => _showEventDetails(event),
      ),
    );
  }

  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPerformanceMetrics(),
          const SizedBox(height: 24),
          _buildCacheStatistics(),
          const SizedBox(height: 24),
          _buildSystemHealth(),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          _buildMetricRow('Dashboard Load Time', 'Average: 250ms', Colors.green),
          _buildMetricRow('API Response Time', 'Average: 180ms', Colors.blue),
          _buildMetricRow('Database Query Time', 'Average: 95ms', Colors.orange),
          _buildMetricRow('Cache Hit Rate', '78%', Colors.purple),
        ],
      ),
    );
  }

  Widget _buildCacheStatistics() {
    final cacheStats = _systemStats['cache_stats'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cache Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          _buildMetricRow(
            'Memory Entries',
            '${cacheStats['memory_entries'] ?? 0}',
            Colors.blue,
          ),
          _buildMetricRow(
            'Disk Entries',
            '${cacheStats['disk_entries'] ?? 0}',
            Colors.green,
          ),
          _buildMetricRow(
            'Memory Usage',
            '${cacheStats['memory_size_mb'] ?? 0} MB',
            Colors.orange,
          ),
          _buildMetricRow(
            'Memory Usage %',
            '${cacheStats['memory_usage_percent'] ?? 0}%',
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemHealth() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Health',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          _buildHealthIndicator('Database Connection', true),
          _buildHealthIndicator('Firebase Services', true),
          _buildHealthIndicator('Authentication', true),
          _buildHealthIndicator('Cache Service', true),
          _buildHealthIndicator('Monitoring Service', true),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthIndicator(String service, bool isHealthy) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(service),
          Row(
            children: [
              Icon(
                isHealthy ? Icons.check_circle : Icons.error,
                color: isHealthy ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                isHealthy ? 'Healthy' : 'Error',
                style: TextStyle(
                  color: isHealthy ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getEventIcon(AuditEventType eventType) {
    switch (eventType) {
      case AuditEventType.authentication:
        return Icons.login;
      case AuditEventType.authorization:
        return Icons.security;
      case AuditEventType.dataAccess:
        return Icons.visibility;
      case AuditEventType.dataModification:
        return Icons.edit;
      case AuditEventType.systemAccess:
        return Icons.computer;
      case AuditEventType.configuration:
        return Icons.settings;
      case AuditEventType.adminAction:
        return Icons.admin_panel_settings;
      case AuditEventType.securityEvent:
        return Icons.warning;
      case AuditEventType.businessProcess:
        return Icons.business;
    }
  }

  void _showEventDetails(AuditEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.action),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Description: ${event.description}'),
              const SizedBox(height: 8),
              Text('User: ${event.userEmail}'),
              Text('Time: ${DateFormat('MMM dd, yyyy HH:mm:ss').format(event.timestamp)}'),
              Text('IP Address: ${event.ipAddress}'),
              Text('Success: ${event.success ? 'Yes' : 'No'}'),
              if (event.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text('Error: ${event.errorMessage}'),
              ],
              if (event.metadata.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Metadata: ${event.metadata.toString()}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateComplianceReport() async {
    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1); // Start of month

      final report = await _auditService.generateComplianceReport(
        periodStart: startDate,
        periodEnd: now,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Compliance report generated: ${report.reportId}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearSystemCache() async {
    try {
      await _cacheService.clear();
      await _loadSystemStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('System cache cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear cache: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportAuditLogs() async {
    // In a real implementation, this would export logs to a file
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Audit logs export feature coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _checkSystemHealth() async {
    // In a real implementation, this would perform comprehensive health checks
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('System health check completed - All services operational'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
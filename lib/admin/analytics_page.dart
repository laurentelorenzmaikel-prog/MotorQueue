import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool isLoading = true;
  String? errorMessage;

  // Analytics data
  Map<String, int> serviceTypeData = {};
  List<FlSpot> appointmentTrendData = [];
  Map<String, double> revenueData = {};
  int totalAppointments = 0;
  int completedAppointments = 0;
  int pendingAppointments = 0;
  int rejectedAppointments = 0;
  Map<int, int> monthlyCounts = {};

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      await Future.wait([
        _loadServiceTypeAnalytics(),
        _loadAppointmentTrends(),
        _loadAppointmentStatus(),
        _loadMonthlyData(),
      ]);

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load analytics: ${e.toString()}';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadServiceTypeAnalytics() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .get();

    Map<String, int> tempServiceData = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final service = data['service'] as String? ?? 'Other';
      tempServiceData[service] = (tempServiceData[service] ?? 0) + 1;
    }

    serviceTypeData = tempServiceData;
    totalAppointments = snapshot.docs.length;
  }

  Future<void> _loadAppointmentTrends() async {
    final now = DateTime.now();
    List<FlSpot> tempTrendData = [];

    // Get data for the last 7 days
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('dateTime', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      tempTrendData.add(FlSpot((6 - i).toDouble(), snapshot.docs.length.toDouble()));
    }

    appointmentTrendData = tempTrendData;
  }

  Future<void> _loadAppointmentStatus() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .get();

    int completed = 0;
    int pending = 0;
    int rejected = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final status = data['status'] as String? ?? 'pending';

      if (status == 'completed') {
        completed++;
      } else if (status == 'rejected') {
        rejected++;
      } else {
        pending++;
      }
    }

    completedAppointments = completed;
    pendingAppointments = pending;
    rejectedAppointments = rejected;
  }

  Future<void> _loadMonthlyData() async {
    final now = DateTime.now();
    Map<int, int> counts = {};

    for (var i = 1; i <= 12; i++) {
      counts[i] = 0;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(now.year, 1, 1)))
        .where('dateTime', isLessThan: Timestamp.fromDate(DateTime(now.year + 1, 1, 1)))
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final dateTime = data['dateTime'] is Timestamp
          ? (data['dateTime'] as Timestamp).toDate()
          : DateTime.tryParse(data['dateTime']?.toString() ?? '') ?? DateTime.now();
      counts[dateTime.month] = (counts[dateTime.month] ?? 0) + 1;
    }

    monthlyCounts = counts;
  }

  List<BarChartGroupData> _buildBarData() {
    return List.generate(12, (i) {
      final month = i + 1;
      final count = monthlyCounts[month] ?? 0;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: Colors.blueAccent,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: isLoading
          ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading analytics...'),
              ],
            ),
          )
        : errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadAnalyticsData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadAnalyticsData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      _buildMonthlyChart(),
                      const SizedBox(height: 24),
                      _buildServiceTypeChart(),
                      const SizedBox(height: 24),
                      _buildAppointmentStatusChart(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildSummaryCards() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: 150,
          child: _buildSummaryCard(
            'Total\nAppointments',
            totalAppointments.toString(),
            Icons.event,
            Colors.blue,
          ),
        ),
        SizedBox(
          width: 150,
          child: _buildSummaryCard(
            'Completed',
            completedAppointments.toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ),
        SizedBox(
          width: 150,
          child: _buildSummaryCard(
            'Pending',
            pendingAppointments.toString(),
            Icons.pending,
            Colors.orange,
          ),
        ),
        SizedBox(
          width: 150,
          child: _buildSummaryCard(
            'Rejected',
            rejectedAppointments.toString(),
            Icons.cancel,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
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

  Widget _buildMonthlyChart() {
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
          Row(
            children: [
              Icon(Icons.bar_chart, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Text(
                'Appointments per Month (This Year)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final months = [
                          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                        ];
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            months[value.toInt()],
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _buildBarData(),
                gridData: FlGridData(show: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTypeChart() {
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
          Row(
            children: [
              Icon(Icons.pie_chart, color: Colors.green.shade600),
              const SizedBox(width: 8),
              Text(
                'Service Types Distribution',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: serviceTypeData.isEmpty
                ? const Center(child: Text('No data available'))
                : PieChart(
                    PieChartData(
                      sections: _buildPieChartSections(),
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          _buildServiceTypeLegend(),
        ],
      ),
    );
  }

  Widget _buildAppointmentStatusChart() {
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
          Row(
            children: [
              Icon(Icons.donut_small, color: Colors.purple.shade600),
              const SizedBox(width: 8),
              Text(
                'Appointment Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: totalAppointments == 0
                ? const Center(child: Text('No data available'))
                : PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: completedAppointments.toDouble(),
                          title: '${(completedAppointments / totalAppointments * 100).toStringAsFixed(1)}%',
                          color: Colors.green,
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: pendingAppointments.toDouble(),
                          title: '${(pendingAppointments / totalAppointments * 100).toStringAsFixed(1)}%',
                          color: Colors.orange,
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: rejectedAppointments.toDouble(),
                          title: '${(rejectedAppointments / totalAppointments * 100).toStringAsFixed(1)}%',
                          color: Colors.red,
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildStatusLegendItem('Completed', Colors.green, completedAppointments),
              _buildStatusLegendItem('Pending', Colors.orange, pendingAppointments),
              _buildStatusLegendItem('Rejected', Colors.red, rejectedAppointments),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.teal,
    ];

    final entries = serviceTypeData.entries.toList();
    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final serviceEntry = entry.value;
      final percentage = (serviceEntry.value / totalAppointments * 100);

      return PieChartSectionData(
        value: serviceEntry.value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        color: colors[index % colors.length],
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildServiceTypeLegend() {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.teal,
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: serviceTypeData.entries.toList().asMap().entries.map((entry) {
        final index = entry.key;
        final serviceEntry = entry.value;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${serviceEntry.key} (${serviceEntry.value})',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildStatusLegendItem(String label, Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

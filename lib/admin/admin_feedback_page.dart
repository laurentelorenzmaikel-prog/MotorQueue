import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminFeedbackPage extends StatefulWidget {
  const AdminFeedbackPage({super.key});

  @override
  State<AdminFeedbackPage> createState() => _AdminFeedbackPageState();
}

class _AdminFeedbackPageState extends State<AdminFeedbackPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> feedbackList = [];
  bool isLoading = true;

  // Pagination
  int currentPage = 0;
  final int rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  int get totalPages => (feedbackList.length / rowsPerPage).ceil();

  List<Map<String, dynamic>> get paginatedFeedback {
    final startIndex = currentPage * rowsPerPage;
    final endIndex = (startIndex + rowsPerPage).clamp(0, feedbackList.length);
    if (startIndex >= feedbackList.length) return [];
    return feedbackList.sublist(startIndex, endIndex);
  }

  Widget _buildFeedbackDataTable() {
    final dataRows = paginatedFeedback.map((f) {
      final rating = (f['rating'] is int)
          ? f['rating'] as int
          : int.tryParse(f['rating']?.toString() ?? '') ?? 0;
      final message = (f['message'] ?? f['feedback'] ?? '').toString();
      final user = (f['userName'] ?? 'Anonymous').toString();
      final email = (f['userEmail'] ?? 'No email').toString();
      final service = (f['service'] ?? '—').toString();
      final createdAt = _formatDate(f['createdAt']);
      return DataRow(cells: [
        DataCell(Text(user, overflow: TextOverflow.ellipsis)),
        DataCell(Text(email, overflow: TextOverflow.ellipsis)),
        DataCell(Text(service, overflow: TextOverflow.ellipsis)),
        DataCell(Row(
          children: List.generate(
            5,
            (i) => Icon(
              i < rating ? Icons.star_rounded : Icons.star_border_rounded,
              color: Colors.amber.shade600,
              size: 16,
            ),
          ),
        )),
        DataCell(Text(message, maxLines: 2, overflow: TextOverflow.ellipsis)),
        DataCell(Text(createdAt)),
      ]);
    }).toList();

    // Add empty rows to maintain fixed table size
    final emptyRowsCount = rowsPerPage - dataRows.length;
    final emptyRows = List.generate(
      emptyRowsCount,
      (index) => DataRow(cells: [
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('')),
      ]),
    );

    final rows = [...dataRows, ...emptyRows];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: double.infinity,
              child: DataTable(
                headingRowColor: WidgetStateProperty.resolveWith(
                    (states) => Colors.grey.shade100),
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('User')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Service')),
                  DataColumn(label: Text('Rating')),
                  DataColumn(label: Text('Comment')),
                  DataColumn(label: Text('Date')),
                ],
                rows: rows,
              ),
            ),
            // Pagination Controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${feedbackList.isEmpty ? 0 : currentPage * rowsPerPage + 1} - ${((currentPage + 1) * rowsPerPage).clamp(0, feedbackList.length)} of ${feedbackList.length} entries',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Row(
                    children: [
                      // First page button
                      IconButton(
                        onPressed: currentPage > 0
                            ? () => setState(() => currentPage = 0)
                            : null,
                        icon: const Icon(Icons.first_page_rounded),
                        tooltip: 'First page',
                        iconSize: 20,
                        splashRadius: 20,
                        color: const Color(0xFF225FFF),
                        disabledColor: Colors.grey.shade400,
                      ),
                      // Previous page button
                      IconButton(
                        onPressed: currentPage > 0
                            ? () => setState(() => currentPage--)
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        tooltip: 'Previous page',
                        iconSize: 20,
                        splashRadius: 20,
                        color: const Color(0xFF225FFF),
                        disabledColor: Colors.grey.shade400,
                      ),
                      // Page indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'Page ${totalPages == 0 ? 0 : currentPage + 1} of $totalPages',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Next page button
                      IconButton(
                        onPressed: currentPage < totalPages - 1
                            ? () => setState(() => currentPage++)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: 'Next page',
                        iconSize: 20,
                        splashRadius: 20,
                        color: const Color(0xFF225FFF),
                        disabledColor: Colors.grey.shade400,
                      ),
                      // Last page button
                      IconButton(
                        onPressed: currentPage < totalPages - 1
                            ? () => setState(() => currentPage = totalPages - 1)
                            : null,
                        icon: const Icon(Icons.last_page_rounded),
                        tooltip: 'Last page',
                        iconSize: 20,
                        splashRadius: 20,
                        color: const Color(0xFF225FFF),
                        disabledColor: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadFeedback() async {
    setState(() => isLoading = true);
    try {
      final snapshot = await _firestore
          .collection('feedback')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        feedbackList = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        isLoading = false;
        currentPage = 0; // Reset to first page on refresh
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: Column(
        children: [
          // Header with refresh button only
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadFeedback,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF225FFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content - Table only
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : feedbackList.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.feedback_outlined,
                                size: 64, color: Color(0xFF9CA3AF)),
                            SizedBox(height: 16),
                            Text(
                              'No feedback yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'User feedback will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: _buildFeedbackDataTable(),
                      ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';
    try {
      final date = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lorenz_app/models/remote_appointment.dart';
import 'package:lorenz_app/providers/app_providers.dart';
import 'package:lorenz_app/BookAppointmentsPage.dart';

class MyAppointmentsPage extends ConsumerStatefulWidget {
  const MyAppointmentsPage({Key? key, required this.appointments})
      : super(key: key);

  // Kept for backward compatibility; not used anymore
  final List<dynamic> appointments;

  @override
  ConsumerState<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends ConsumerState<MyAppointmentsPage> {
  // Cache the stream to prevent recreation on every build
  Stream<QuerySnapshot<Map<String, dynamic>>>? _appointmentsStream;
  bool _streamInitialized = false;

  @override
  void initState() {
    super.initState();
    // DON'T call ref.read() here - causes _dependents.isEmpty error
    // Schedule for after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeStream();
    });
  }

  Widget _buildRatingPreviewOrPrompt(BuildContext context,
      RemoteAppointment appointment, Map<String, dynamic> data) {
    final rating = (data['rating'] is int)
        ? data['rating'] as int
        : int.tryParse(data['rating']?.toString() ?? '') ?? 0;
    if (rating > 0) {
      return Row(
        children: [
          Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 18),
          const SizedBox(width: 4),
          ...List.generate(
              5,
              (i) => Icon(
                    i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber.shade600,
                    size: 18,
                  )),
          const SizedBox(width: 8),
          Text(
            '$rating/5',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          )
        ],
      );
    }
    if (!appointment.isCompleted) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.star_border_rounded, color: Colors.amber.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Rate your service experience',
              style: TextStyle(
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _navigateToDetailPage(appointment, data),
            child: Text(
              'Rate now',
              style: TextStyle(
                color: Colors.amber.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        ],
      ),
    );
  }

  void _initializeStream() {
    if (!_streamInitialized && mounted) {
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        _appointmentsStream = ref
            .read(firestoreServiceProvider)
            .streamAppointments(userId: user?.uid);
        _streamInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading if stream not yet initialized
    if (!_streamInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: Colors.blue.shade600,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.event_note,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'My Appointments',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.blue.shade100,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _appointmentsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }
          final docs = snapshot.data!.docs;
          final items = docs.map((d) {
            final data = d.data();
            final date =
                DateTime.tryParse(data['dateTime']?.toString() ?? '') ??
                    (data['dateTime'] is Timestamp
                        ? (data['dateTime'] as Timestamp).toDate()
                        : DateTime.now());
            final motorDetails = data['motorDetails'] ??
                _composeMotorDetails(
                  data['motorBrand'] as String?,
                  data['plateNumber'] as String?,
                );
            return RemoteAppointment(
              id: d.id,
              service: (data['service'] ?? '') as String,
              dateTime: date,
              motorDetails: motorDetails,
              status: (data['status'] ?? 'pending') as String,
              reference: data['reference'] as String?,
              date: data['date'] as String?,
              timeSlot: data['timeSlot'] as String?,
            );
          }).toList();

          final now = DateTime.now();

          // Filter out cancelled/rejected appointments from main view
          final activeAppointments = items.where((a) => a.isActive).toList();

          // Upcoming: Future date AND not completed yet
          final upcoming = activeAppointments
              .where((a) => a.dateTime.isAfter(now) && !a.isCompleted)
              .toList()
            ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

          // Completed: Status is 'completed' OR past date (auto-complete)
          final completed = activeAppointments
              .where((a) => a.isCompleted || a.dateTime.isBefore(now))
              .toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

          // Cancelled/Rejected appointments
          final cancelled = items.where((a) => !a.isActive).toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (upcoming.isNotEmpty)
                  _buildModernList(
                      "Upcoming Appointments", upcoming, true, docs),
                if (upcoming.isNotEmpty && completed.isNotEmpty)
                  const SizedBox(height: 24),
                if (completed.isNotEmpty)
                  _buildModernList(
                      "Completed Appointments", completed, false, docs),
                if (cancelled.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildCancelledList(
                      "Cancelled Appointments", cancelled, docs),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.event_busy_outlined,
                size: 64,
                color: Colors.blue.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Appointments Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Book your first motorcycle service appointment to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _composeMotorDetails(String? brand, String? plate) {
    final b = brand?.trim();
    final p = plate?.trim();
    if ((b ?? '').isEmpty && (p ?? '').isEmpty) return '—';
    if ((b ?? '').isEmpty) return 'Plate: $p';
    if ((p ?? '').isEmpty) return b!;
    return '$b - Plate: $p';
  }

  Widget _buildModernList(String title, List<RemoteAppointment> list,
      bool isUpcoming, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    isUpcoming ? Colors.green.shade600 : Colors.grey.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isUpcoming ? Icons.schedule : Icons.history,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isUpcoming ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isUpcoming ? Colors.green.shade200 : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Text(
                '${list.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color:
                      isUpcoming ? Colors.green.shade700 : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...list.map((appointment) {
          // Find the corresponding document data for spare parts
          final doc = docs.firstWhere((d) => d.id == appointment.id);
          return _buildModernAppointmentCard(
              appointment, isUpcoming, doc.data());
        }),
      ],
    );
  }

  Widget _buildModernAppointmentCard(RemoteAppointment appointment,
      bool isUpcoming, Map<String, dynamic> data) {
    // Extract spare parts from appointment data
    final spareParts = data['spareParts'] as List<dynamic>?;
    final hasSpare = spareParts != null && spareParts.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.shade100.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade50.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToDetailPage(appointment, data),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.build_circle_outlined,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        appointment.service,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    _buildAppointmentStatusBadge(appointment, isUpcoming),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM dd, yyyy • hh:mm a')
                          .format(appointment.dateTime),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.two_wheeler,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appointment.motorDetails,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                // Display spare parts for completed appointments
                if (!isUpcoming && hasSpare) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.shade100,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.construction,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Spare Parts Used',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...spareParts!.map((part) {
                          if (part is! Map<String, dynamic>)
                            return const SizedBox.shrink();

                          final partName =
                              part['name']?.toString() ?? 'Unknown Part';
                          final quantity = part['quantity']?.toString() ?? '0';
                          final imageUrl = part['imageUrl']?.toString();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Part Image - REMOVED SETTINGS ICON
                                if (imageUrl != null && imageUrl.isNotEmpty)
                                  Container(
                                    width: 50,
                                    height: 50,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                      color: Colors.grey.shade100,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            // Image successfully loaded
                                            return child;
                                          }
                                          // Show loading indicator
                                          return Container(
                                            color: Colors.grey.shade100,
                                            child: Center(
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.blue.shade400,
                                                  value: loadingProgress
                                                              .expectedTotalBytes !=
                                                          null
                                                      ? loadingProgress
                                                              .cumulativeBytesLoaded /
                                                          loadingProgress
                                                              .expectedTotalBytes!
                                                      : null,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          print(
                                              'Failed to load image: $imageUrl');
                                          print('Error: $error');
                                          return Container(
                                            color: Colors.grey.shade200,
                                            child: Icon(
                                              Icons.broken_image,
                                              color: Colors.grey.shade400,
                                              size: 24,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    width: 50,
                                    height: 50,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.construction,
                                      color: Colors.grey.shade400,
                                      size: 24,
                                    ),
                                  ),

                                // Part Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        partName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Qty: $quantity',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                if (!isUpcoming)
                  _buildRatingPreviewOrPrompt(context, appointment, data),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isUpcoming) ...[
                      TextButton.icon(
                        onPressed: () => _editAppointment(appointment),
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Colors.blue.shade600,
                        ),
                        label: Text(
                          'Reschedule',
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _cancelAppointment(appointment),
                        icon: Icon(
                          Icons.cancel_outlined,
                          size: 16,
                          color: Colors.red.shade600,
                        ),
                        label: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ] else ...[
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookingAppointmentsPage(
                                preselectedService: appointment.service,
                              ),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.refresh,
                          size: 16,
                          color: Colors.green.shade600,
                        ),
                        label: Text(
                          'Book Again',
                          style: TextStyle(
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (data['rating'] == null && appointment.isCompleted)
                        TextButton.icon(
                          onPressed: () =>
                              _navigateToDetailPage(appointment, data),
                          icon: Icon(
                            Icons.star_rate_rounded,
                            size: 16,
                            color: Colors.amber.shade700,
                          ),
                          label: Text(
                            'Rate',
                            style: TextStyle(
                              color: Colors.amber.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // NEW METHOD: Navigate to detail page
  void _navigateToDetailPage(
      RemoteAppointment appointment, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppointmentDetailFullPage(
          appointment: appointment,
          appointmentData: data,
        ),
      ),
    );
  }

  Widget _buildAppointmentStatusBadge(
      RemoteAppointment appointment, bool isUpcoming) {
    Color bgColor;
    Color textColor;
    String statusText;
    IconData icon;

    if (appointment.isCompleted) {
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
      statusText = 'Completed';
      icon = Icons.check_circle;
    } else if (appointment.isConfirmed) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      statusText = 'Confirmed';
      icon = Icons.verified;
    } else if (appointment.isPending && isUpcoming) {
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade700;
      statusText = 'Pending';
      icon = Icons.schedule;
    } else if (isUpcoming) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      statusText = 'Upcoming';
      icon = Icons.event_available;
    } else {
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade600;
      statusText = 'Past';
      icon = Icons.history;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledList(String title, List<RemoteAppointment> list,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.shade200, width: 1),
              ),
              child: Text(
                '${list.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...list.map((appointment) {
          // Find the corresponding document data for rejection reason
          final doc = docs.firstWhere((d) => d.id == appointment.id);
          return _buildCancelledAppointmentCard(appointment, doc.data());
        }),
      ],
    );
  }

  Widget _buildCancelledAppointmentCard(
      RemoteAppointment appointment, Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    final isRejected = status == 'rejected';
    final statusText = isRejected ? 'Rejected' : 'Cancelled';
    final statusColor = Colors.red.shade600;
    final rejectionReason = data['rejectionReason'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.shade100.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade50.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.cancel_outlined,
                    color: Colors.red.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    appointment.service,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a')
                      .format(appointment.dateTime),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.two_wheeler,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appointment.motorDetails,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            // Show rejection reason if available and status is rejected
            if (isRejected &&
                rejectionReason != null &&
                rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.shade200,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.red.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Rejection Reason',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rejectionReason,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _editAppointment(RemoteAppointment appointment) {
    final _dateController = TextEditingController(
      text: DateFormat('MMM dd, yyyy').format(appointment.dateTime),
    );
    final _timeController = TextEditingController(
      text: DateFormat('hh:mm a').format(appointment.dateTime),
    );
    final _motorController = TextEditingController(
      text: appointment.motorDetails,
    );
    DateTime selectedDate = appointment.dateTime;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.edit_calendar,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Reschedule Appointment',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    prefixIcon:
                        Icon(Icons.calendar_today, color: Colors.blue.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      selectedDate = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        selectedDate.hour,
                        selectedDate.minute,
                      );
                      _dateController.text =
                          DateFormat('MMM dd, yyyy').format(date);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _timeController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Time',
                    prefixIcon:
                        Icon(Icons.access_time, color: Colors.blue.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                  ),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: dialogContext,
                      initialTime: TimeOfDay.fromDateTime(selectedDate),
                    );
                    if (time != null) {
                      selectedDate = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        time.hour,
                        time.minute,
                      );
                      _timeController.text =
                          DateFormat('hh:mm a').format(selectedDate);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _motorController,
                  decoration: InputDecoration(
                    labelText: 'Motor Details',
                    prefixIcon:
                        Icon(Icons.two_wheeler, color: Colors.blue.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'Update',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: () async {
                await ref.read(firestoreServiceProvider).updateAppointment(
                  appointment.id,
                  {
                    'dateTime': selectedDate.toIso8601String(),
                    'motorDetails': _motorController.text.trim(),
                  },
                );
                if (mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Appointment updated.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _cancelAppointment(RemoteAppointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Cancel Appointment',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel this appointment?',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.service,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a')
                        .format(appointment.dateTime),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Keep Appointment',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
            ),
            child: const Text(
              'Cancel Appointment',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Cancelling appointment...'),
                ],
              ),
              backgroundColor: Colors.orange.shade600,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        await ref
            .read(firestoreServiceProvider)
            .deleteAppointment(appointment.id);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text('Appointment cancelled successfully'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Failed to cancel: ${e.toString()}'),
                  ),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }
}

// NEW: Full Appointment Detail Page
class AppointmentDetailFullPage extends StatefulWidget {
  final RemoteAppointment appointment;
  final Map<String, dynamic> appointmentData;

  const AppointmentDetailFullPage({
    Key? key,
    required this.appointment,
    required this.appointmentData,
  }) : super(key: key);

  @override
  State<AppointmentDetailFullPage> createState() =>
      _AppointmentDetailFullPageState();
}

class _AppointmentDetailFullPageState extends State<AppointmentDetailFullPage> {
  int _selectedRating = 0;
  bool _submitting = false;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final appointmentData = widget.appointmentData;
    final spareParts = appointmentData['spareParts'] as List<dynamic>?;
    final hasSpare = spareParts != null && spareParts.isNotEmpty;
    final reference = appointmentData['reference']?.toString() ?? 'N/A';
    final motorBrand = appointmentData['motorBrand']?.toString() ?? '';
    final plateNumber = appointmentData['plateNumber']?.toString() ?? '';
    final existingRating = (appointmentData['rating'] is int)
        ? appointmentData['rating'] as int
        : int.tryParse(appointmentData['rating']?.toString() ?? '') ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: Colors.blue.shade600,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Appointment Details',
          style: TextStyle(
            color: Colors.blue.shade800,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _getStatusColor(appointment.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getStatusColor(appointment.status),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(appointment.status),
                      color: _getStatusColor(appointment.status),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      appointment.status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(appointment.status),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Service Info Card
            _buildInfoCard(
              title: 'Service Information',
              icon: Icons.build_circle,
              iconColor: Colors.blue.shade600,
              children: [
                _buildDetailRow('Service Type', appointment.service),
                _buildDetailRow('Reference Number', reference),
                _buildDetailRow(
                  'Date & Time',
                  DateFormat('MMMM dd, yyyy • hh:mm a')
                      .format(appointment.dateTime),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Motorcycle Info Card
            _buildInfoCard(
              title: 'Motorcycle Information',
              icon: Icons.two_wheeler,
              iconColor: Colors.orange.shade600,
              children: [
                if (motorBrand.isNotEmpty) _buildDetailRow('Brand', motorBrand),
                if (plateNumber.isNotEmpty)
                  _buildDetailRow('Plate Number', plateNumber),
                if (motorBrand.isEmpty && plateNumber.isEmpty)
                  _buildDetailRow('Details', appointment.motorDetails),
              ],
            ),

            // Rating section (only when completed)
            const SizedBox(height: 16),
            if (appointment.isCompleted)
              _buildInfoCard(
                title: existingRating > 0 ? 'Your Rating' : 'Rate this Service',
                icon: Icons.star_rate_rounded,
                iconColor: Colors.amber.shade700,
                children: [
                  if (existingRating > 0)
                    Row(
                      children: [
                        ...List.generate(
                            5,
                            (i) => Icon(
                                  i < existingRating
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: Colors.amber.shade600,
                                )),
                        const SizedBox(width: 8),
                        Text(
                          '$existingRating/5',
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(5, (index) {
                            final starIndex = index + 1;
                            return IconButton(
                              onPressed: _submitting
                                  ? null
                                  : () => setState(
                                      () => _selectedRating = starIndex),
                              icon: Icon(
                                starIndex <= _selectedRating
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: Colors.amber.shade700,
                                size: 28,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _commentController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Optional comment about your experience',
                            filled: true,
                            fillColor: Colors.amber.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.amber.shade100),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: Colors.amber.shade400, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send, size: 18),
                              label: Text(_submitting
                                  ? 'Submitting...'
                                  : 'Submit Rating'),
                              onPressed: _selectedRating == 0 || _submitting
                                  ? null
                                  : () => _submitRating(
                                      context, appointment, appointmentData),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text('Later'),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),

            // Spare Parts Section (if available)
            if (hasSpare) ...[
              const SizedBox(height: 16),
              _buildInfoCard(
                title: 'Spare Parts Used',
                icon: Icons.construction,
                iconColor: Colors.green.shade600,
                children: [
                  ...spareParts!.map((part) {
                    if (part is! Map<String, dynamic>)
                      return const SizedBox.shrink();

                    final partName = part['name']?.toString() ?? 'Unknown Part';
                    final quantity =
                        int.tryParse(part['quantity']?.toString() ?? '0') ?? 0;
                    final price =
                        double.tryParse(part['price']?.toString() ?? '0') ??
                            0.0;
                    final imageUrl = part['imageUrl']?.toString();
                    final subtotal = quantity * price;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Part Image - Square box with same width and height
                          Container(
                            width: 70,
                            height: 70,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                              color: Colors.grey.shade100,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: (imageUrl != null && imageUrl.isNotEmpty)
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          // Image has successfully loaded
                                          return child;
                                        }
                                        // Show loading indicator while image is loading
                                        return Container(
                                          color: Colors.grey.shade100,
                                          child: Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.blue.shade400,
                                                value: loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        // Show error icon if image fails to load
                                        print(
                                            'Failed to load image: $imageUrl');
                                        print('Error: $error');
                                        return Container(
                                          color: Colors.grey.shade200,
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Colors.grey.shade400,
                                            size: 30,
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: Colors.grey.shade100,
                                      child: Icon(
                                        Icons.construction,
                                        color: Colors.grey.shade400,
                                        size: 32,
                                      ),
                                    ),
                            ),
                          ),

                          // Part Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  partName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Qty: $quantity',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '₱${price.toStringAsFixed(2)} each',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Subtotal: ₱${subtotal.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  // Total Price Section
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.shade200,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              color: Colors.green.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Total Price',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '₱${_calculateTotalPrice(spareParts).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotalPrice(List<dynamic>? spareParts) {
    if (spareParts == null || spareParts.isEmpty) return 0.0;

    double total = 0.0;
    for (var part in spareParts) {
      if (part is Map<String, dynamic>) {
        final quantity = int.tryParse(part['quantity']?.toString() ?? '0') ?? 0;
        final price = double.tryParse(part['price']?.toString() ?? '0') ?? 0.0;
        total += quantity * price;
      }
    }
    return total;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.blue.shade600;
      case 'in_process':
      case 'confirmed':
        return Colors.green.shade600;
      case 'pending':
        return Colors.orange.shade600;
      case 'cancelled':
      case 'rejected':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'in_process':
        return Icons.settings;
      case 'confirmed':
        return Icons.verified;
      case 'pending':
        return Icons.schedule;
      case 'cancelled':
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Future<void> _submitRating(
      BuildContext context,
      RemoteAppointment appointment,
      Map<String, dynamic> appointmentData) async {
    setState(() => _submitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('feedback').add({
        'appointmentId': appointment.id,
        'service': appointment.service,
        'rating': _selectedRating,
        'message': _commentController.text.trim(),
        'userName': user?.displayName ?? 'Anonymous',
        'userEmail': user?.email ?? 'No email',
        'userId': user?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointment.id)
          .update({
        'rating': _selectedRating,
        'ratedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _submitting = false;
        widget.appointmentData['rating'] = _selectedRating;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Thanks for your rating!'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit rating: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }
}

class RemoteAppointment {
  final String id;
  final String service;
  final DateTime dateTime;
  final String motorDetails;
  final String status;
  final String? reference;
  final String? date;
  final String? timeSlot;

  RemoteAppointment({
    required this.id,
    required this.service,
    required this.dateTime,
    required this.motorDetails,
    this.status = 'pending',
    this.reference,
    this.date,
    this.timeSlot,
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isRejected => status == 'rejected';

  /// Check if appointment is active (not cancelled/rejected)
  bool get isActive => !isCancelled && !isRejected;
}

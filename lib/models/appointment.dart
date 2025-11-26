import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'appointment.g.dart';

@HiveType(typeId: 0)
class Appointment extends HiveObject {
  @HiveField(0)
  final String service;

  @HiveField(1)
  final DateTime dateTime;

  @HiveField(2)
  final String motorDetails; // Deprecated: use motorBrand instead

  @HiveField(3)
  final String? motorBrand;

  @HiveField(4)
  final String? plateNumber;

  @HiveField(5)
  final String? reference;

  @HiveField(6)
  final String? status;

  @HiveField(7)
  final String? userId;

  @HiveField(8)
  final DateTime? createdAt;

  @HiveField(9)
  final String? id; // Firestore document ID

  Appointment({
    required this.service,
    required this.dateTime,
    this.motorDetails = '', // Keep for backwards compatibility
    this.motorBrand,
    this.plateNumber,
    this.reference,
    this.status = 'pending',
    this.userId,
    this.createdAt,
    this.id,
  });

  /// Create Appointment from Firestore document
  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Appointment(
      id: doc.id,
      service: data['service'] ?? '',
      dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      motorBrand: data['motorBrand'],
      plateNumber: data['plateNumber'],
      reference: data['reference'],
      status: data['status'] ?? 'pending',
      userId: data['userId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      motorDetails: data['motorBrand'] ?? '', // Map to old field
    );
  }

  /// Convert Appointment to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'service': service,
      'dateTime': Timestamp.fromDate(dateTime),
      'motorBrand': motorBrand ?? motorDetails,
      'plateNumber': plateNumber,
      'reference': reference,
      'status': status,
      'userId': userId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  /// Create a copy with modified fields
  Appointment copyWith({
    String? id,
    String? service,
    DateTime? dateTime,
    String? motorDetails,
    String? motorBrand,
    String? plateNumber,
    String? reference,
    String? status,
    String? userId,
    DateTime? createdAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      service: service ?? this.service,
      dateTime: dateTime ?? this.dateTime,
      motorDetails: motorDetails ?? this.motorDetails,
      motorBrand: motorBrand ?? this.motorBrand,
      plateNumber: plateNumber ?? this.plateNumber,
      reference: reference ?? this.reference,
      status: status ?? this.status,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert to JSON for display
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service': service,
      'dateTime': dateTime.toIso8601String(),
      'motorBrand': motorBrand ?? motorDetails,
      'plateNumber': plateNumber,
      'reference': reference,
      'status': status,
      'userId': userId,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Appointment(id: $id, service: $service, dateTime: $dateTime, status: $status, reference: $reference)';
  }
}

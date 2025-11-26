// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppointmentAdapter extends TypeAdapter<Appointment> {
  @override
  final int typeId = 0;

  @override
  Appointment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Appointment(
      service: fields[0] as String,
      dateTime: fields[1] as DateTime,
      motorDetails: fields[2] as String,
      motorBrand: fields[3] as String?,
      plateNumber: fields[4] as String?,
      reference: fields[5] as String?,
      status: fields[6] as String?,
      userId: fields[7] as String?,
      createdAt: fields[8] as DateTime?,
      id: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Appointment obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.service)
      ..writeByte(1)
      ..write(obj.dateTime)
      ..writeByte(2)
      ..write(obj.motorDetails)
      ..writeByte(3)
      ..write(obj.motorBrand)
      ..writeByte(4)
      ..write(obj.plateNumber)
      ..writeByte(5)
      ..write(obj.reference)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.userId)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppointmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

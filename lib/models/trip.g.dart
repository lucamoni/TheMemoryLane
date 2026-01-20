// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TripAdapter extends TypeAdapter<Trip> {
  @override
  final int typeId = 0;

  @override
  Trip read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Trip(
      id: fields[0] as String?,
      title: fields[1] as String?,
      description: fields[2] as String?,
      startDate: fields[3] as DateTime?,
      endDate: fields[4] as DateTime?,
      moments: (fields[5] as List?)?.cast<Moment>(),
      gpsTrack: (fields[6] as List?)
          ?.map((dynamic e) => (e as List).cast<double>())
          ?.toList(),
      totalDistance: fields[7] as double,
      isActive: fields[8] as bool,
      tripType: fields[9] as TripType,
    );
  }

  @override
  void write(BinaryWriter writer, Trip obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.startDate)
      ..writeByte(4)
      ..write(obj.endDate)
      ..writeByte(5)
      ..write(obj.moments)
      ..writeByte(6)
      ..write(obj.gpsTrack)
      ..writeByte(7)
      ..write(obj.totalDistance)
      ..writeByte(8)
      ..write(obj.isActive)
      ..writeByte(9)
      ..write(obj.tripType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

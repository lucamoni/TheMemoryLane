// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'no_travel_period.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NoTravelPeriodAdapter extends TypeAdapter<NoTravelPeriod> {
  @override
  final int typeId = 3;

  @override
  NoTravelPeriod read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NoTravelPeriod(
      id: fields[0] as String,
      startDate: fields[1] as DateTime,
      endDate: fields[2] as DateTime,
      label: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, NoTravelPeriod obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startDate)
      ..writeByte(2)
      ..write(obj.endDate)
      ..writeByte(3)
      ..write(obj.label)
      ..writeByte(4)
      ..write(obj.durationInDays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoTravelPeriodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MomentAdapter extends TypeAdapter<Moment> {
  @override
  final int typeId = 1;

  @override
  Moment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Moment(
      id: fields[0] as String?,
      tripId: fields[1] as String?,
      type: fields[2] as MomentType?,
      content: fields[3] as String?,
      timestamp: fields[4] as DateTime?,
      latitude: fields[5] as double?,
      longitude: fields[6] as double?,
      title: fields[7] as String?,
      description: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Moment obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tripId)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.latitude)
      ..writeByte(6)
      ..write(obj.longitude)
      ..writeByte(7)
      ..write(obj.title)
      ..writeByte(8)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MomentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

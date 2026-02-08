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

class MomentTypeAdapter extends TypeAdapter<MomentType> {
  @override
  final int typeId = 2;

  @override
  MomentType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MomentType.note;
      case 1:
        return MomentType.photo;
      case 2:
        return MomentType.audio;
      case 3:
        return MomentType.video;
      case 4:
        return MomentType.dayEnd;
      default:
        return MomentType.note;
    }
  }

  @override
  void write(BinaryWriter writer, MomentType obj) {
    switch (obj) {
      case MomentType.note:
        writer.writeByte(0);
        break;
      case MomentType.photo:
        writer.writeByte(1);
        break;
      case MomentType.audio:
        writer.writeByte(2);
        break;
      case MomentType.video:
        writer.writeByte(3);
        break;
      case MomentType.dayEnd:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MomentTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

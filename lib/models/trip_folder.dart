import 'package:hive/hive.dart';

part 'trip_folder.g.dart';

@HiveType(typeId: 5)
class TripFolder {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final int color; // Colore hex della cartella

  TripFolder({
    required this.id,
    required this.name,
    this.description,
    this.color = 0xFF16697A,
  });

  TripFolder copyWith({
    String? id,
    String? name,
    String? description,
    int? color,
  }) {
    return TripFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
    );
  }
}

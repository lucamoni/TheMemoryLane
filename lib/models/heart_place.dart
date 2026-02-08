import 'package:hive/hive.dart';

part 'heart_place.g.dart';

/// Modello per i "Luoghi del Cuore" (Geofencing).
@HiveType(typeId: 4)
class HeartPlace extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late double latitude;

  @HiveField(3)
  late double longitude;

  @HiveField(4)
  double radius = 100.0; // Raggio predefinito in metri
}

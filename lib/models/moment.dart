import 'package:hive/hive.dart';

part 'moment.g.dart';

/// Tipi di momenti che possono essere catturati durante un viaggio.
@HiveType(typeId: 2)
enum MomentType {
  @HiveField(0)
  note,
  @HiveField(1)
  photo,
  @HiveField(2)
  audio,
  @HiveField(3)
  video,
  @HiveField(4)
  dayEnd, // Marcatore di fine giornata per viaggi multi-day
}

/// Rappresenta un singolo istante memorabile catturato dall'utente.
@HiveType(typeId: 1)
class Moment {
  @HiveField(0)
  final String? id;

  @HiveField(1)
  final String? tripId;

  @HiveField(2)
  final MomentType? type;

  @HiveField(3)
  final String? content; // Può contenere il testo di una nota o il percorso di un file multimediale

  @HiveField(4)
  final DateTime? timestamp;

  @HiveField(5)
  final double? latitude;

  @HiveField(6)
  final double? longitude;

  @HiveField(7)
  final String? title;

  @HiveField(8)
  final String? description;

  Moment({
    required this.id,
    required this.tripId,
    required this.type,
    required this.content,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.title,
    this.description,
  });

  factory Moment.fromJson(Map<String, dynamic> json) {
    return Moment(
      id: json['id'] ?? '',
      tripId: json['tripId'] ?? '',
      type: MomentType.values[json['type'] ?? 0],
      content: json['content'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      latitude: json['latitude'] ?? 0.0,
      longitude: json['longitude'] ?? 0.0,
      title: json['title'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'type': type?.index,
      'content': content,
      'timestamp': timestamp?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'title': title,
      'description': description,
    };
  }
}

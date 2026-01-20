import 'package:hive/hive.dart';
import 'moment.dart';

part 'trip.g.dart';

enum TripType {
  localTrip,    // Brevi spostamenti, passeggiate
  dayTrip,      // Gite di un giorno
  multiDayTrip  // Vacanze di più giorni
}

@HiveType(typeId: 0)
class Trip {
  @HiveField(0)
  final String? id;

  @HiveField(1)
  final String? title;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final DateTime? startDate;

  @HiveField(4)
  final DateTime? endDate;

  @HiveField(5)
  final List<Moment> moments;

  @HiveField(6)
  final List<List<double>> gpsTrack; // Lista di [lat, lng]

  @HiveField(7)
  final double totalDistance; // in km

  @HiveField(8)
  final bool isActive;

  @HiveField(9)
  final TripType tripType;

  Trip({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    this.endDate,
    List<Moment>? moments,
    List<List<double>>? gpsTrack,
    this.totalDistance = 0.0,
    this.isActive = true,
    this.tripType = TripType.dayTrip,
  })  : moments = moments ?? [],
        gpsTrack = gpsTrack ?? [];

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      moments: (json['moments'] as List?)
              ?.map((m) => Moment.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      gpsTrack: (json['gpsTrack'] as List?)
              ?.map((track) => List<double>.from(track as List))
              .toList() ??
          [],
      totalDistance: json['totalDistance'] ?? 0.0,
      isActive: json['isActive'] ?? true,
      tripType: TripType.values[json['tripType'] ?? 1],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'moments': moments.map((m) => m.toJson()).toList(),
      'gpsTrack': gpsTrack,
      'totalDistance': totalDistance,
      'isActive': isActive,
      'tripType': tripType.index,
    };
  }

  Trip copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<Moment>? moments,
    List<List<double>>? gpsTrack,
    double? totalDistance,
    bool? isActive,
    TripType? tripType,
  }) {
    return Trip(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      moments: moments ?? this.moments,
      gpsTrack: gpsTrack ?? this.gpsTrack,
      totalDistance: totalDistance ?? this.totalDistance,
      isActive: isActive ?? this.isActive,
      tripType: tripType ?? this.tripType,
    );
  }
}


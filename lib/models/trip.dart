import 'package:hive/hive.dart';
import 'moment.dart';

part 'trip.g.dart';

/// Classificazione delle tipologie di viaggio per una migliore organizzazione.
@HiveType(typeId: 3)
enum TripType {
  @HiveField(0)
  localTrip, // Spostamenti urbani, passeggiate vicino casa
  @HiveField(1)
  dayTrip, // Gite fuori porta di una giornata
  @HiveField(2)
  multiDayTrip, // Viaggi lunghi, vacanze di più giorni
}

/// Modello principale che rappresenta un'avventura o un viaggio.
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
  final List<List<double>> gpsTrack; // Storico dei punti GPS [latitudine, longitudine]

  @HiveField(7)
  final double totalDistance; // Distanza cumulativa in chilometri

  @HiveField(8)
  final bool isActive; // Indica se il viaggio è attualmente in fase di registrazione

  @HiveField(9)
  final TripType tripType;

  @HiveField(10)
  final String? folderId; // ID della cartella di appartenenza (opzionale)

  @HiveField(11)
  final String? coverPath; // Percorso dell'immagine di copertina personalizzata

  @HiveField(12)
  final bool isPaused; // Indica se la registrazione è temporaneamente sospesa (es. fine giornata)

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
    this.isPaused = false,
    this.tripType = TripType.dayTrip,
    this.folderId,
    this.coverPath,
  }) : moments = moments ?? [],
       gpsTrack = gpsTrack ?? [];

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      moments:
          (json['moments'] as List?)
              ?.map((m) => Moment.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      gpsTrack:
          (json['gpsTrack'] as List?)
              ?.map((track) => List<double>.from(track as List))
              .toList() ??
          [],
      totalDistance: json['totalDistance'] ?? 0.0,
      isActive: json['isActive'] ?? true,
      isPaused: json['isPaused'] ?? false,
      tripType: TripType.values[json['tripType'] ?? 1],
      folderId: json['folderId'],
      coverPath: json['coverPath'],
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
      'isPaused': isPaused,
      'tripType': tripType.index,
      'folderId': folderId,
      'coverPath': coverPath,
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
    String? folderId,
    String? coverPath,
    bool? isPaused,
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
      isPaused: isPaused ?? this.isPaused,
      tripType: tripType ?? this.tripType,
      folderId: folderId ?? this.folderId,
      coverPath: coverPath ?? this.coverPath,
    );
  }
}

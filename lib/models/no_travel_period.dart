import 'package:hive/hive.dart';

part 'no_travel_period.g.dart';

@HiveType(typeId: 3)
class NoTravelPeriod {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime startDate;

  @HiveField(2)
  final DateTime endDate;

  @HiveField(3)
  final String label;

  @HiveField(4)
  final int durationInDays;

  NoTravelPeriod({
    required this.id,
    required this.startDate,
    required this.endDate,
    this.label = 'Momenti di riflessione',
  }) : durationInDays = endDate.difference(startDate).inDays;

  factory NoTravelPeriod.fromJson(Map<String, dynamic> json) {
    return NoTravelPeriod(
      id: json['id'] ?? '',
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      label: json['label'] ?? 'Momenti di riflessione',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'label': label,
      'durationInDays': durationInDays,
    };
  }

  NoTravelPeriod copyWith({
    String? id,
    DateTime? startDate,
    DateTime? endDate,
    String? label,
  }) {
    return NoTravelPeriod(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      label: label ?? this.label,
    );
  }
}

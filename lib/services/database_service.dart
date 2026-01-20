import 'package:hive_flutter/hive_flutter.dart';
import '../models/trip.dart';
import '../models/moment.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  static DatabaseService get instance => _instance;

  DatabaseService._internal();

  // Costruttore factory pubblico per testing
  factory DatabaseService() {
    return DatabaseService._internal();
  }

  late Box<Trip> _tripsBox;
  late Box<Moment> _momentsBox;

  Future<void> init() async {
    _tripsBox = await Hive.openBox<Trip>('trips');
    _momentsBox = await Hive.openBox<Moment>('moments');

    // Clear old data if schema has changed (to prevent type cast errors)
    // This is a safety measure to handle schema migrations
    try {
      // Try to read one trip to check if data is valid
      if (_tripsBox.isNotEmpty) {
        final firstTrip = _tripsBox.values.first;
        // Access the moments field to trigger any type cast errors
        final _ = firstTrip.moments;
      }
    } catch (e) {
      // If there's a type cast error, clear the boxes
      print('Schema mismatch detected, clearing old data...');
      await _tripsBox.clear();
      await _momentsBox.clear();
    }
  }

  // Trip methods
  Future<void> saveTrip(Trip trip) async {
    await _tripsBox.put(trip.id, trip);
  }

  Future<Trip?> getTrip(String tripId) async {
    return _tripsBox.get(tripId);
  }

  List<Trip> getAllTrips() {
    return _tripsBox.values.toList();
  }

  Future<void> deleteTrip(String tripId) async {
    await _tripsBox.delete(tripId);
    // Elimina anche i momenti associati
    final momentsToDelete = _momentsBox.values
        .where((moment) => moment.tripId == tripId)
        .toList();
    for (var moment in momentsToDelete) {
      await _momentsBox.delete(moment.id);
    }
  }

  // Moment methods
  Future<void> saveMoment(Moment moment) async {
    await _momentsBox.put(moment.id, moment);

    // Aggiorna il viaggio con il nuovo momento
    if (moment.tripId != null) {
      final trip = await getTrip(moment.tripId!);
      if (trip != null) {
      final updatedMoments = List<Moment>.from(trip.moments);
      if (!updatedMoments.any((m) => m.id == moment.id)) {
        updatedMoments.add(moment);
      } else {
        updatedMoments[updatedMoments.indexWhere((m) => m.id == moment.id)] = moment;
      }
      await saveTrip(trip.copyWith(moments: updatedMoments));
      }
    }
  }

  Moment? getMoment(String momentId) {
    return _momentsBox.get(momentId);
  }

  List<Moment> getMomentsByTrip(String tripId) {
    return _momentsBox.values
        .where((moment) => moment.tripId == tripId)
        .toList();
  }

  Future<void> deleteMoment(String momentId) async {
    await _momentsBox.delete(momentId);
  }

  Future<void> clear() async {
    await _tripsBox.clear();
    await _momentsBox.clear();
  }
}


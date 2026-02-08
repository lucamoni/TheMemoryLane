import 'package:hive_flutter/hive_flutter.dart';
import '../models/trip.dart';
import '../models/moment.dart';
import '../models/trip_folder.dart';
import '../models/heart_place.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  static DatabaseService get instance => _instance;

  DatabaseService._internal();

  // Costruttore factory pubblico per testing
  factory DatabaseService() {
    return DatabaseService._internal();
  }

  Box<Trip>? _tripsBox;
  Box<Moment>? _momentsBox;
  Box<TripFolder>? _foldersBox;
  Box<HeartPlace>? _heartPlacesBox;

  /// Inizializza i box di Hive per la persistenza dei dati.
  Future<void> init() async {
    try {
      _tripsBox = await Hive.openBox<Trip>('trips');
      _momentsBox = await Hive.openBox<Moment>('moments');
      _foldersBox = await Hive.openBox<TripFolder>('folders');
      _heartPlacesBox = await Hive.openBox<HeartPlace>('heart_places');

      // Migrazione: Aggiorna i vecchi colori delle cartelle al nuovo Teal del brand
      if (_foldersBox != null) {
        for (var folder in _foldersBox!.values) {
          if (folder.color == 0xFF6366F1) {
            await _foldersBox!.put(
              folder.id,
              folder.copyWith(color: 0xFF16697A),
            );
          }
        }
      }
    } catch (e) {
      // In caso di errore critico (es. corruzione file), tenta di resettare i box
      try {
        await Hive.deleteBoxFromDisk('trips');
        await Hive.deleteBoxFromDisk('moments');
        await Hive.deleteBoxFromDisk('folders');
        if (_heartPlacesBox != null) {
          await Hive.deleteBoxFromDisk('heart_places');
        }
      } catch (_) {}

      // Riprova l'apertura dopo la pulizia
      _tripsBox = await Hive.openBox<Trip>('trips');
      _momentsBox = await Hive.openBox<Moment>('moments');
      _foldersBox = await Hive.openBox<TripFolder>('folders');
      _heartPlacesBox = await Hive.openBox<HeartPlace>('heart_places');
    }
  }

  // Metodi per i Luoghi del Cuore (HeartPlace)
  Future<void> saveHeartPlace(HeartPlace place) async {
    if (_heartPlacesBox == null) return;
    await _heartPlacesBox!.put(place.id, place);
  }

  List<HeartPlace> getAllHeartPlaces() {
    if (_heartPlacesBox == null) return [];
    return _heartPlacesBox!.values.toList();
  }

  Future<void> deleteHeartPlace(String id) async {
    if (_heartPlacesBox == null) return;
    await _heartPlacesBox!.delete(id);
  }

  // Metodi per i Viaggi (Trip)
  Future<void> saveTrip(Trip trip) async {
    if (_tripsBox == null) return;
    await _tripsBox!.put(trip.id, trip);
  }

  Future<Trip?> getTrip(String tripId) async {
    return _tripsBox?.get(tripId);
  }

  List<Trip> getAllTrips() {
    return _tripsBox?.values.toList() ?? [];
  }

  Future<void> deleteTrip(String tripId) async {
    if (_tripsBox == null || _momentsBox == null) return;
    await _tripsBox!.delete(tripId);
    // Elimina anche tutti i momenti associati a questo viaggio
    final momentsToDelete = _momentsBox!.values
        .where((moment) => moment.tripId == tripId)
        .toList();
    for (var moment in momentsToDelete) {
      await _momentsBox!.delete(moment.id);
    }
  }

  // Metodi per le Cartelle (Folder)
  Future<void> saveFolder(TripFolder folder) async {
    if (_foldersBox == null) return;
    await _foldersBox!.put(folder.id, folder);
  }

  List<TripFolder> getAllFolders() {
    return _foldersBox?.values.toList() ?? [];
  }

  Future<void> deleteFolder(String folderId) async {
    if (_foldersBox == null || _tripsBox == null) return;
    await _foldersBox!.delete(folderId);
    // Rimuovi il riferimento alla cartella dai viaggi associati
    final tripsInFolder = _tripsBox!.values
        .where((trip) => trip.folderId == folderId)
        .toList();
    for (var trip in tripsInFolder) {
      // Usa clearFolderId per rimuovere correttamente l'associazione
      await saveTrip(trip.copyWith(clearFolderId: true));
    }
  }

  // Metodi per i Momenti (Moment)
  Future<void> saveMoment(Moment moment) async {
    if (moment.id == null || _momentsBox == null) return;
    await _momentsBox!.put(moment.id, moment);

    // Aggiorna la lista dei momenti nel rispettivo viaggio per mantenere la coerenza in Hive
    if (moment.tripId != null) {
      final trip = await getTrip(moment.tripId!);
      if (trip != null) {
        final updatedMoments = List<Moment>.from(trip.moments);
        if (!updatedMoments.any((m) => m.id == moment.id)) {
          updatedMoments.add(moment);
        } else {
          updatedMoments[updatedMoments.indexWhere((m) => m.id == moment.id)] =
              moment;
        }
        await saveTrip(trip.copyWith(moments: updatedMoments));
      }
    }
  }

  Moment? getMoment(String momentId) {
    return _momentsBox?.get(momentId);
  }

  List<Moment> getMomentsByTrip(String tripId) {
    if (_momentsBox == null) return [];
    return _momentsBox!.values
        .where((moment) => moment.tripId == tripId)
        .toList();
  }

  Future<void> deleteMoment(String momentId, String tripId) async {
    if (_momentsBox == null) return;
    await _momentsBox!.delete(momentId);

    // Aggiorna anche la lista dei momenti nel viaggio per coerenza
    final trip = await getTrip(tripId);
    if (trip != null) {
      final updatedMoments = trip.moments
          .where((m) => m.id != momentId)
          .toList();
      await saveTrip(trip.copyWith(moments: updatedMoments));
    }
  }

  /// Cancella tutti i dati salvati (Reset totale)
  Future<void> clear() async {
    await _tripsBox?.clear();
    await _momentsBox?.clear();
    await _foldersBox?.clear();
    if (_heartPlacesBox != null) await _heartPlacesBox!.clear();
  }
}

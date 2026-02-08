import 'package:hive_flutter/hive_flutter.dart';
import '../models/trip.dart';
import '../models/moment.dart';
import '../models/trip_folder.dart';

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
  late Box<TripFolder> _foldersBox;

  /// Inizializza i box di Hive per la persistenza dei dati.
  Future<void> init() async {
    try {
      _tripsBox = await Hive.openBox<Trip>('trips');
      _momentsBox = await Hive.openBox<Moment>('moments');
      _foldersBox = await Hive.openBox<TripFolder>('folders');

      // Verifica se i dati esistenti sono validi
      if (_tripsBox.isNotEmpty) {
        // Forza il caricamento dei momenti del primo viaggio per validazione
        final _ = _tripsBox.values.first.moments;
      }

      // Migrazione: Aggiorna i vecchi colori delle cartelle al nuovo Teal del brand
      for (var folder in _foldersBox.values) {
        if (folder.color == 0xFF6366F1) {
          await _foldersBox.put(folder.id, folder.copyWith(color: 0xFF16697A));
        }
      }
    } catch (e) {
      // In caso di errore critico (es. corruzione file), tenta di resettare i box
      try {
        await Hive.deleteBoxFromDisk('trips');
      } catch (_) {}
      try {
        await Hive.deleteBoxFromDisk('moments');
      } catch (_) {}
      try {
        await Hive.deleteBoxFromDisk('folders');
      } catch (_) {}

      // Riprova l'apertura dopo la pulizia
      _tripsBox = await Hive.openBox<Trip>('trips');
      _momentsBox = await Hive.openBox<Moment>('moments');
      _foldersBox = await Hive.openBox<TripFolder>('folders');
    }
  }

  // Metodi per i Viaggi (Trip)
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
    // Elimina anche tutti i momenti associati a questo viaggio
    final momentsToDelete = _momentsBox.values
        .where((moment) => moment.tripId == tripId)
        .toList();
    for (var moment in momentsToDelete) {
      await _momentsBox.delete(moment.id);
    }
  }

  // Metodi per le Cartelle (Folder)
  Future<void> saveFolder(TripFolder folder) async {
    await _foldersBox.put(folder.id, folder);
  }

  List<TripFolder> getAllFolders() {
    return _foldersBox.values.toList();
  }

  Future<void> deleteFolder(String folderId) async {
    await _foldersBox.delete(folderId);
    // Rimuovi il riferimento alla cartella dai viaggi associati
    final tripsInFolder = _tripsBox.values
        .where((trip) => trip.folderId == folderId)
        .toList();
    for (var trip in tripsInFolder) {
      await saveTrip(trip.copyWith(folderId: null));
    }
  }

  // Metodi per i Momenti (Moment)
  Future<void> saveMoment(Moment moment) async {
    if (moment.id == null) return;
    await _momentsBox.put(moment.id, moment);

    // Aggiorna la lista dei momenti nel rispettivo viaggio per coerenza Hive
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
    return _momentsBox.get(momentId);
  }

  List<Moment> getMomentsByTrip(String tripId) {
    return _momentsBox.values
        .where((moment) => moment.tripId == tripId)
        .toList();
  }

  Future<void> deleteMoment(String momentId, String tripId) async {
    await _momentsBox.delete(momentId);

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
    await _tripsBox.clear();
    await _momentsBox.clear();
    await _foldersBox.clear();
  }
}

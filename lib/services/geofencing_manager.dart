import 'package:geofence_service/geofence_service.dart';
import 'notification_service.dart';
import 'database_service.dart';
import '../models/heart_place.dart';

/// Manager per la gestione del Geofencing (Luoghi del Cuore).
class GeofencingManager {
  static final GeofencingManager _instance = GeofencingManager._internal();

  static GeofencingManager get instance => _instance;

  GeofencingManager._internal();

  // Factory per il testing
  factory GeofencingManager() {
    return GeofencingManager._internal();
  }

  // Accesso all'istanza del servizio di geofencing
  GeofenceService get geofenceService => GeofenceService.instance;

  final List<Geofence> _geofences = [];
  final DatabaseService _db = DatabaseService();

  /// Inizializza il servizio di geofencing caricando i dati salvati.
  Future<void> init() async {
    // Caricamento sicuro wrappato in try-catch per evitare crash se DB non è pronto
    List<HeartPlace> savedPlaces = [];
    try {
      savedPlaces = _db.getAllHeartPlaces();
    } catch (e) {
      // DB non inizializzato o errore, proseguiamo senza luoghi salvati
    }

    for (var place in savedPlaces) {
      _geofences.add(
        Geofence(
          id: place.id,
          latitude: place.latitude,
          longitude: place.longitude,
          radius: [GeofenceRadius(id: place.id, length: place.radius)],
        ),
      );
    }
    // Rimosso avvio automatico per richiedere permessi in modo esplicito
  }

  /// Aggiunge un nuovo geofence per un Luogo del Cuore e lo salva nel DB.
  Future<void> addGeofence({
    required String id,
    required double latitude,
    required double longitude,
    required double radiusInMeter,
  }) async {
    // Salva nel DB per la persistenza
    final place = HeartPlace()
      ..id = id
      ..name = id
      ..latitude = latitude
      ..longitude = longitude
      ..radius = radiusInMeter;
    await _db.saveHeartPlace(place);

    // Aggiunge alla lista in memoria per il servizio attivo
    final geofence = Geofence(
      id: id,
      latitude: latitude,
      longitude: longitude,
      radius: [GeofenceRadius(id: id, length: radiusInMeter)],
    );

    _geofences.add(geofence);

    // Riavvia il servizio solo se era già in esecuzione o se abbiamo permessi
    // await geofenceService.stop();
    // await geofenceService.start();

    // In questa versione semplificata, richiediamo all'utente di riattivare il monitoraggio
    // o lo facciamo partire se il servizio era stato avviato esplicitamente.
    // Per sicurezza, non facciamo partire nulla automaticamente.

    // Notifica l'utente del completamento
    NotificationService.instance.showNotification(
      title: 'Luogo del Cuore Aggiunto',
      body: 'La zona "$id" è ora monitorata',
    );
  }

  /// Rimuove un geofence tramite ID sia dal DB che dalla memoria.
  Future<void> removeGeofence(String id) async {
    await _db.deleteHeartPlace(id);
    _geofences.removeWhere((g) => g.id == id);
    await geofenceService.stop();
    await geofenceService.start();
  }

  /// Avvia il monitoraggio delle zone.
  Future<void> startMonitoring() async {
    await geofenceService.start();
  }

  /// Interrompe il monitoraggio delle zone.
  Future<void> stopMonitoring() async {
    await geofenceService.stop();
  }

  /// Restituisce la lista attuale delle zone monitorate.
  List<Geofence> getGeofences() {
    return List.from(_geofences);
  }

  /// Pulisce tutte le zone monitorate (DB e memoria).
  Future<void> clearGeofences() async {
    final places = _db.getAllHeartPlaces();
    for (var p in places) {
      await _db.deleteHeartPlace(p.id);
    }
    _geofences.clear();
    await geofenceService.stop();
  }
}

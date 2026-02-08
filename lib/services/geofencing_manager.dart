import 'package:geofence_service/geofence_service.dart';
import 'notification_service.dart';

/// Manager per la gestione del Geofencing (Luoghi del Cuore).
class GeofencingManager {
  static final GeofencingManager _instance = GeofencingManager._internal();

  static GeofencingManager get instance => _instance;

  GeofencingManager._internal();

  // Costruttore factory pubblico per testing
  factory GeofencingManager() {
    return GeofencingManager._internal();
  }

  final GeofenceService geofenceService = GeofenceService.instance;
  final List<Geofence> _geofences = [];

  /// Inizializza il servizio di geofencing.
  Future<void> init() async {
    await geofenceService.start();
  }

  /// Aggiunge un nuovo geofence per un Luogo del Cuore.
  Future<void> addGeofence({
    required String id,
    required double latitude,
    required double longitude,
    required double radiusInMeter,
  }) async {
    final geofence = Geofence(
      id: id,
      latitude: latitude,
      longitude: longitude,
      radius: [GeofenceRadius(id: id, length: radiusInMeter)],
    );

    _geofences.add(geofence);

    // Riavvia il servizio per registrare le nuove zone
    await geofenceService.stop();
    await geofenceService.start();

    // Notifica l'utente del completamento
    NotificationService.instance.showNotification(
      title: 'Luogo del Cuore Aggiunto',
      body: 'La zona "$id" è ora monitorata',
    );
  }

  /// Rimuove un geofence tramite ID.
  Future<void> removeGeofence(String id) async {
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

  /// Pulisce tutte le zone monitorate.
  void clearGeofences() {
    _geofences.clear();
  }
}

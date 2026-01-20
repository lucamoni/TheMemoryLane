import 'package:geofence_service/geofence_service.dart';
import 'notification_service.dart';

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

  Future<void> init() async {
    // Inizializza il servizio di geofencing
    await geofenceService.start();
  }

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
    // Ricrea tutta la lista di geofences
    await geofenceService.stop();
    await geofenceService.start();

    NotificationService.instance.showNotification(
      title: 'Geofence Aggiunto',
      body: 'Area aggiunta: $id',
    );
  }

  Future<void> removeGeofence(String id) async {
    _geofences.removeWhere((g) => g.id == id);
    await geofenceService.stop();
    await geofenceService.start();
  }

  Future<void> startMonitoring() async {
    await geofenceService.start();
  }

  Future<void> stopMonitoring() async {
    await geofenceService.stop();
  }

  List<Geofence> getGeofences() {
    return List.from(_geofences);
  }

  void clearGeofences() {
    _geofences.clear();
  }
}


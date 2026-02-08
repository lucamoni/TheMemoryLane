import 'package:location/location.dart';
import 'dart:math' as math;
import 'dart:async';

/// Servizio per la gestione della geolocalizzazione e del tracciamento GPS.
class LocationService {
  static final LocationService _instance = LocationService._internal();

  static LocationService get instance => _instance;

  LocationService._internal();

  final Location _location = Location();
  bool _isTracking = false;
  List<List<double>> _gpsTrack = [];

  bool get isTracking => _isTracking;
  List<List<double>> get gpsTrack => _gpsTrack;
  StreamSubscription<LocationData>? _locationSubscription;

  /// Richiede i permessi per la localizzazione e configura il modulo GPS.
  Future<bool> requestLocationPermission() async {
    // Configura il modulo GPS per ottimizzare il consumo batteria
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 5000, // Aggiornamento ogni 5 secondi
      distanceFilter: 15, // Filtro di 15 metri per ridurre il rumore
    );

    final hasPermission = await _location.hasPermission();
    if (hasPermission == PermissionStatus.denied) {
      final permissionStatus = await _location.requestPermission();
      return permissionStatus == PermissionStatus.granted;
    }
    return hasPermission == PermissionStatus.granted;
  }

  /// Avvia la registrazione del percorso GPS.
  Future<void> startTracking() async {
    if (_isTracking) return; // Già in esecuzione

    final hasPermission = await requestLocationPermission();
    if (!hasPermission) {
      throw Exception('Permesso di localizzazione negato');
    }

    _isTracking = true;

    // Cattura la posizione iniziale immediatamente se il tracciato è vuoto
    if (_gpsTrack.isEmpty) {
      final initialLoc = await _location.getLocation();
      if (initialLoc.latitude != null && initialLoc.longitude != null) {
        _gpsTrack.add([initialLoc.latitude!, initialLoc.longitude!]);
      }
    }

    await _locationSubscription?.cancel();

    // Monitora le posizioni con filtro di distanza per efficienza
    _locationSubscription = _location.onLocationChanged.listen((
      LocationData currentLocation,
    ) {
      if (!_isTracking) return;
      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        if (_gpsTrack.isEmpty) {
          _gpsTrack.add([
            currentLocation.latitude!,
            currentLocation.longitude!,
          ]);
        } else {
          final last = _gpsTrack.last;
          final dist = calculateDistance(
            last[0],
            last[1],
            currentLocation.latitude!,
            currentLocation.longitude!,
          );
          // Aggiungi un punto solo se lo spostamento è superiore a 10 metri per pulizia del tracciato
          if (dist > 0.01) {
            _gpsTrack.add([
              currentLocation.latitude!,
              currentLocation.longitude!,
            ]);
          }
        }
      }
    });
  }

  /// Interrompe la registrazione del percorso.
  Future<void> stopTracking() async {
    _isTracking = false;
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  /// Ottiene la posizione GPS attuale.
  Future<LocationData?> getCurrentLocation() async {
    final hasPermission = await requestLocationPermission();
    if (!hasPermission) {
      return null;
    }
    return await _location.getLocation();
  }

  /// Restituisce la lista dei punti del tracciato attuale.
  List<List<double>> getTrack() {
    return List.from(_gpsTrack);
  }

  /// Restituisce l'ultima posizione registrata se disponibile.
  LocationData? getLastLocation() {
    if (_gpsTrack.isEmpty) return null;
    return _location.getLocation() as LocationData?;
  }

  /// Resetta il tracciato memorizzato.
  void clearTrack() {
    _gpsTrack = [];
  }

  /// Imposta un tracciato iniziale (es. per riprendere un viaggio salvato).
  void setInitialTrack(List<List<double>> track) {
    _gpsTrack = List.from(track);
  }

  /// Calcola la distanza tra due punti GPS usando la formula di Haversine.
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2));

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  /// Calcola la distanza totale percorsa nel tracciato attuale.
  double getTotalDistance() {
    if (_gpsTrack.length < 2) return 0.0;

    double total = 0.0;
    for (int i = 0; i < _gpsTrack.length - 1; i++) {
      total += calculateDistance(
        _gpsTrack[i][0],
        _gpsTrack[i][1],
        _gpsTrack[i + 1][0],
        _gpsTrack[i + 1][1],
      );
    }
    return total;
  }
}

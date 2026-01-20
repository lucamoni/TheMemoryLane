import 'package:location/location.dart';
import 'dart:math' as math;

class LocationService {
  static final LocationService _instance = LocationService._internal();

  static LocationService get instance => _instance;

  LocationService._internal();

  final Location _location = Location();
  bool _isTracking = false;
  List<List<double>> _gpsTrack = [];

  bool get isTracking => _isTracking;
  List<List<double>> get gpsTrack => _gpsTrack;

  Future<bool> requestLocationPermission() async {
    final hasPermission = await _location.hasPermission();
    if (hasPermission == PermissionStatus.denied) {
      final permissionStatus = await _location.requestPermission();
      return permissionStatus == PermissionStatus.granted;
    }
    return hasPermission == PermissionStatus.granted;
  }

  Future<void> startTracking() async {
    final hasPermission = await requestLocationPermission();
    if (!hasPermission) {
      throw Exception('Location permission denied');
    }

    _isTracking = true;
    _gpsTrack = [];

    // Monitora le posizioni
    _location.onLocationChanged.listen((LocationData currentLocation) {
      if (_isTracking && currentLocation.latitude != null && currentLocation.longitude != null) {
        _gpsTrack.add([currentLocation.latitude!, currentLocation.longitude!]);
      }
    });
  }

  Future<void> stopTracking() async {
    _isTracking = false;
  }

  Future<LocationData?> getCurrentLocation() async {
    final hasPermission = await requestLocationPermission();
    if (!hasPermission) {
      return null;
    }
    return await _location.getLocation();
  }

  List<List<double>> getTrack() {
    return List.from(_gpsTrack);
  }

  LocationData? getLastLocation() {
    if (_gpsTrack.isEmpty) return null;
    return _location.getLocation() as LocationData?;
  }

  void clearTrack() {
    _gpsTrack = [];
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
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


import 'package:location/location.dart';
import 'database_service.dart';
import 'location_service.dart';
import 'geofencing_manager.dart';
import 'notification_service.dart';

class MissingMemoryService {
  static final MissingMemoryService _instance = MissingMemoryService._internal();

  static MissingMemoryService get instance => _instance;

  MissingMemoryService._internal();

  LocationData? _lastKnownLocation;
  DateTime? _lastMovementCheck;
  static const double _movementThresholdKm = 0.5; // 500 metri

  Future<void> checkMissingMemories() async {
    try {
      final currentLocation = await LocationService.instance.getCurrentLocation();
      if (currentLocation == null) return;

      final trips = DatabaseService.instance.getAllTrips();

      for (var trip in trips) {
        for (var geofence in GeofencingManager.instance.getGeofences()) {
          final distance = LocationService.instance.calculateDistance(
            currentLocation.latitude!,
            currentLocation.longitude!,
            double.parse(geofence.latitude.toString()),
            double.parse(geofence.longitude.toString()),
          );

          // Se siamo a 200m da un geofence
          if (distance < 0.2) {
            // Verifica se ci sono momenti salvati qui
            final nearbyMoments = trip.moments.where((m) {
              final mDistance = LocationService.instance.calculateDistance(
                m.latitude ?? 0.0,
                m.longitude ?? 0.0,
                double.parse(geofence.latitude.toString()),
                double.parse(geofence.longitude.toString()),
              );
              return mDistance < 0.2;
            }).toList();

            if (nearbyMoments.isNotEmpty) {
              NotificationService.instance.showNotification(
                title: 'Ricordo Mancante!',
                body: 'Sei tornato qui! Hai nuovi ricordi da condividere?',
                payload: trip.id,
              );
            }
          }
        }
      }
    } catch (e) {
      // Errore nel controllo dei missing memories
    }
  }

  /// Rileva movimento significativo e suggerisce di iniziare un nuovo viaggio
  Future<void> checkForMovement() async {
    try {
      final currentLocation = await LocationService.instance.getCurrentLocation();
      if (currentLocation == null ||
          currentLocation.latitude == null ||
          currentLocation.longitude == null) {
        return;
      }

      // Prima volta che controlliamo
      if (_lastKnownLocation == null) {
        _lastKnownLocation = currentLocation;
        _lastMovementCheck = DateTime.now();
        return;
      }

      // Calcola la distanza dall'ultima posizione
      final distance = LocationService.instance.calculateDistance(
        _lastKnownLocation!.latitude!,
        _lastKnownLocation!.longitude!,
        currentLocation.latitude!,
        currentLocation.longitude!,
      );

      // Se ci siamo mossi di più di 500m
      if (distance >= _movementThresholdKm) {
        // Controlla se c'è un viaggio attivo
        final trips = DatabaseService.instance.getAllTrips();
        final hasActiveTrip = trips.any((trip) => trip.isActive);

        if (!hasActiveTrip) {
          // Suggerisci di iniziare un nuovo viaggio
          await NotificationService.instance.showNotification(
            title: '🚀 Nuovo Viaggio?',
            body: 'Sembra che tu ti stia muovendo! Vuoi iniziare a registrare un nuovo viaggio?',
            payload: 'start_new_trip',
          );
        }

        // Aggiorna la posizione
        _lastKnownLocation = currentLocation;
        _lastMovementCheck = DateTime.now();
      }
    } catch (e) {
      // Errore nel controllo del movimento
    }
  }

  /// Resetta il tracking del movimento
  void resetMovementTracking() {
    _lastKnownLocation = null;
    _lastMovementCheck = null;
  }
}


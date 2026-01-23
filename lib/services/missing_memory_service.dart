import 'package:flutter/foundation.dart';
import 'package:location/location.dart';
import 'database_service.dart';
import 'location_service.dart';
import 'geofencing_manager.dart';
import 'notification_service.dart';

class MissingMemoryService {
  static final MissingMemoryService _instance =
      MissingMemoryService._internal();

  static MissingMemoryService get instance => _instance;

  MissingMemoryService._internal();

  LocationData? _lastKnownLocation;
  static const double _movementThresholdKm = 0.5; // 500 metri

  Future<void> checkMissingMemories() async {
    try {
      final loc = LocationService.instance;
      final currentLocation = await loc.getCurrentLocation();
      if (currentLocation == null) return;

      final lat = currentLocation.latitude!;
      final lon = currentLocation.longitude!;

      final activeTrips = DatabaseService.instance
          .getAllTrips()
          .where((t) => t.isActive)
          .toList();
      if (activeTrips.isEmpty) return;

      final geofences = GeofencingManager.instance.getGeofences();
      if (geofences.isEmpty) return;

      for (var geofence in geofences) {
        final distance = loc.calculateDistance(
          lat,
          lon,
          geofence.latitude,
          geofence.longitude,
        );

        // Se siamo a 200m da un geofence
        if (distance < 0.2) {
          for (var trip in activeTrips) {
            // Verifica se ci sono momenti salvati qui (perimetro di 200m)
            final hasNearbyMoment = trip.moments.any((m) {
              final mLat = m.latitude;
              final mLng = m.longitude;
              if (mLat == null || mLng == null) return false;

              return loc.calculateDistance(
                    mLat,
                    mLng,
                    geofence.latitude,
                    geofence.longitude,
                  ) <
                  0.2;
            });

            if (!hasNearbyMoment) {
              NotificationService.instance.showNotification(
                title: 'Nuovo Ricordo?',
                body:
                    'Sei tornato in un tuo Luogo del Cuore! Vuoi aggiungere un nuovo ricordo?',
                payload: trip.id,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking missing memories: $e');
    }
  }

  /// Rileva movimento significativo e suggerisce di iniziare un nuovo viaggio
  Future<void> checkForMovement() async {
    try {
      final currentLocation = await LocationService.instance
          .getCurrentLocation();
      if (currentLocation == null ||
          currentLocation.latitude == null ||
          currentLocation.longitude == null) {
        return;
      }

      // Prima volta che controlliamo
      if (_lastKnownLocation == null) {
        _lastKnownLocation = currentLocation;
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
            body:
                'Sembra che tu ti stia muovendo! Vuoi iniziare a registrare un nuovo viaggio?',
            payload: 'start_new_trip',
          );
        }

        // Aggiorna la posizione
        _lastKnownLocation = currentLocation;
      }
    } catch (e) {
      // Errore nel controllo del movimento
    }
  }

  /// Resetta il tracking del movimento
  void resetMovementTracking() {
    _lastKnownLocation = null;
  }
}

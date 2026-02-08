import 'package:location/location.dart';
import 'database_service.dart';
import 'location_service.dart';
import 'geofencing_manager.dart';
import 'notification_service.dart';

/// Servizio che monitora i "ricordi mancanti" e il movimento dell'utente.
class MissingMemoryService {
  static final MissingMemoryService _instance =
      MissingMemoryService._internal();

  static MissingMemoryService get instance => _instance;

  MissingMemoryService._internal();

  LocationData? _lastKnownLocation;
  static const double _movementThresholdKm = 0.5; // Soglia di 500 metri

  /// Controlla se l'utente si trova vicino a un "Luogo del Cuore" senza aver aggiunto ricordi.
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

        // Se siamo entro 200m da un Luogo del Cuore
        if (distance < 0.2) {
          for (var trip in activeTrips) {
            // Verifica se ci sono già momenti salvati in questa zona (raggio 200m)
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

            // Se non ci sono momenti vicini, suggerisci di aggiungerne uno
            if (!hasNearbyMoment) {
              NotificationService.instance.showNotification(
                title: 'Nuovo Ricordo?',
                body:
                    'Sei tornato in un tuo Luogo del Cuore! Vuoi aggiungere un nuovo ricordo al viaggio in corso?',
                payload: trip.id,
              );
            }
          }
        }
      }
    } catch (e) {
      // Errore silenzioso per non disturbare l'esperienza utente
    }
  }

  /// Rileva movimento significativo e suggerisce di iniziare un nuovo viaggio se non ce n'è uno attivo.
  Future<void> checkForMovement() async {
    try {
      final currentLocation = await LocationService.instance
          .getCurrentLocation();
      if (currentLocation == null ||
          currentLocation.latitude == null ||
          currentLocation.longitude == null) {
        return;
      }

      // Inizializzazione della posizione di riferimento
      if (_lastKnownLocation == null) {
        _lastKnownLocation = currentLocation;
        return;
      }

      // Calcola la distanza dall'ultima posizione nota
      final distance = LocationService.instance.calculateDistance(
        _lastKnownLocation!.latitude!,
        _lastKnownLocation!.longitude!,
        currentLocation.latitude!,
        currentLocation.longitude!,
      );

      // Se lo spostamento supera la soglia (500m)
      if (distance >= _movementThresholdKm) {
        // Controlla se c'è già un viaggio attivo in registrazione
        final trips = DatabaseService.instance.getAllTrips();
        final hasActiveTrip = trips.any((trip) => trip.isActive);

        if (!hasActiveTrip) {
          // Suggerisci di avviare una nuova avventura
          await NotificationService.instance.showNotification(
            title: '🚀 Inizia un nuovo viaggio?',
            body:
                'Sembra che tu sia in movimento! Vuoi iniziare a registrare questa nuova esperienza?',
            payload: 'start_new_trip',
          );
        }

        // Aggiorna la posizione di riferimento per il prossimo controllo
        _lastKnownLocation = currentLocation;
      }
    } catch (e) {
      // Errore nel controllo del movimento ignorato per stabilità
    }
  }

  /// Resetta il tracciamento del movimento.
  void resetMovementTracking() {
    _lastKnownLocation = null;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:the_memory_lane/main.dart';
import 'package:the_memory_lane/models/trip.dart';
import 'package:the_memory_lane/models/moment.dart';
import 'package:the_memory_lane/services/database_service.dart';
import 'package:the_memory_lane/services/geofencing_manager.dart';

import 'package:the_memory_lane/models/trip_folder.dart';
import 'package:the_memory_lane/models/heart_place.dart';

// Mock implementations that do nothing.
class MockDatabaseService implements DatabaseService {
  @override
  Future<void> init() async {}

  @override
  List<Trip> getAllTrips() {
    return <Trip>[];
  }

  @override
  Future<void> saveTrip(Trip trip) async {}

  @override
  Future<Trip?> getTrip(String tripId) async => null;

  @override
  Future<void> deleteTrip(String tripId) async {}

  @override
  Future<void> saveMoment(Moment moment) async {}

  @override
  Future<void> deleteMoment(String momentId, String tripId) async {}

  @override
  Future<void> clear() async {}

  @override
  Moment? getMoment(String momentId) => null;

  @override
  List<Moment> getMomentsByTrip(String tripId) => [];

  @override
  Future<void> deleteFolder(String folderId) async {}

  @override
  List<TripFolder> getAllFolders() => [];

  @override
  Future<void> saveFolder(TripFolder folder) async {}

  @override
  Future<void> deleteHeartPlace(String id) async {}

  @override
  List<HeartPlace> getAllHeartPlaces() => [];

  @override
  Future<void> saveHeartPlace(HeartPlace place) async {}
}

class MockGeofenceService implements GeofencingManager {
  final List<Geofence> _geofences = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> addGeofence({
    required String id,
    required double latitude,
    required double longitude,
    required double radiusInMeter,
  }) async {
    _geofences.add(
      Geofence(
        id: id,
        latitude: latitude,
        longitude: longitude,
        radius: [GeofenceRadius(id: id, length: radiusInMeter)],
      ),
    );
  }

  @override
  Future<void> removeGeofence(String id) async {
    _geofences.removeWhere((g) => g.id == id);
  }

  @override
  Future<void> startMonitoring() async {}

  @override
  Future<void> stopMonitoring() async {}

  @override
  List<Geofence> getGeofences() => _geofences;

  @override
  Future<void> clearGeofences() async {
    _geofences.clear();
  }

  @override
  GeofenceService get geofenceService => throw UnimplementedError();
}

void main() {
  testWidgets('App starts and shows welcome message', (
    WidgetTester tester,
  ) async {
    // Provide mock services.
    final mockDatabaseService = MockDatabaseService();
    final mockGeofenceService = MockGeofenceService();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MyApp(
        databaseService: mockDatabaseService,
        geofenceService: mockGeofenceService,
      ),
    );

    // Verify that the app shows the initial message.
    expect(find.text('La tua avventura inizia ora'), findsOneWidget);
  });
}

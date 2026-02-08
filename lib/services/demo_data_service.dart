import 'package:uuid/uuid.dart';
import 'dart:math';
import '../models/trip.dart';
import '../models/moment.dart';
import '../services/database_service.dart';
import '../services/geofencing_manager.dart';

/// Servizio di testing per generare dati prova.
class DemoDataService {
  static final _db = DatabaseService.instance;
  static const _uuid = Uuid();
  static final _random = Random();

  static Future<void> injectDemoData() async {
    final now = DateTime.now();

    // 1. Viaggio di Gennaio - Settimana sulla neve (Cortina)
    await _createTrip(
      title: 'Settimana Bianca a Cortina',
      description: 'Splendida vacanza tra piste da sci e rifugi.',
      startDate: DateTime(now.year, 1, 10),
      endDate: DateTime(now.year, 1, 17),
      distance: 156.4,
      type: TripType.multiDayTrip,
      coverImg: 'assets/test_data/piste_innevate.png',
      moments: [
        _createMoment(
          'Arrivo in hotel',
          MomentType.note,
          'Che vista incredibile sulle Tofane!',
        ),
        _createMoment(
          'Piste perfettamente innevate',
          MomentType.photo,
          'assets/test_data/piste_innevate.png',
        ),
        _createMoment(
          'Video emozionante della discesa',
          MomentType.video,
          'assets/test_data/video_pista.mp4',
        ),
        _createMoment(
          'Nota vocale: rumore della neve',
          MomentType.audio,
          'assets/test_data/rumore_neve.mp3',
        ),
      ],
      baseLat: 46.5376,
      baseLng: 12.1337,
    );

    // 2. Viaggio di Febbraio - Weekend a Roma
    await _createTrip(
      title: 'Fine settimana a Roma',
      description: 'Passeggiata tra i monumenti della capitale.',
      startDate: DateTime(now.year, 2, 1),
      endDate: DateTime(now.year, 2, 3),
      distance: 42.8,
      type: TripType.dayTrip,
      coverImg: 'assets/test_data/colosseo_mattino.png',
      moments: [
        _createMoment(
          'Colosseo al mattino',
          MomentType.photo,
          'assets/test_data/colosseo_mattino.png',
        ),
        _createMoment(
          'Video panoramico fori imperiali',
          MomentType.video,
          'assets/test_data/video_fori.mp4',
        ),
        _createMoment(
          'Nota vocale: rumori del centro',
          MomentType.audio,
          'assets/test_data/rumori_roma.mp3',
        ),
        _createMoment(
          'Carbonara da record',
          MomentType.note,
          'Miglior pasta di sempre.',
        ),
      ],
      baseLat: 41.8902,
      baseLng: 12.4922,
    );

    // 3. Viaggio di Febbraio - Trekking Appennino (Cimone)
    await _createTrip(
      title: 'Escursione sul Monte Cimone',
      description: 'Una giornata di aria pura in quota.',
      startDate: DateTime(now.year, 2, 5),
      endDate: DateTime(now.year, 2, 5),
      distance: 12.5,
      type: TripType.localTrip,
      coverImg: 'assets/test_data/monte_cimone_cima.png',
      moments: [
        _createMoment(
          'Panorama dalla vetta',
          MomentType.photo,
          'assets/test_data/monte_cimone_cima.png',
        ),
        _createMoment(
          'Video della salita',
          MomentType.video,
          'assets/test_data/salita_cimone.mp4',
        ),
        _createMoment(
          'Nota vocale: sibilo del vento',
          MomentType.audio,
          'assets/test_data/rumore_vento.mp3',
        ),
        _createMoment(
          'Altra vetta raggiunta!',
          MomentType.note,
          'Vento forte ma panorama pazzesco.',
        ),
      ],
      baseLat: 44.1935,
      baseLng: 10.7011,
    );

    // 4. Viaggio di Gennaio - Road trip Toscana
    await _createTrip(
      title: 'Tour delle colline Toscane',
      description: 'Tra Siena e la Val d\'Orcia.',
      startDate: DateTime(now.year, 1, 5),
      endDate: DateTime(now.year, 1, 10),
      distance: 312.0,
      type: TripType.multiDayTrip,
      coverImg: 'assets/test_data/cipressi_senesi.png',
      moments: [
        _createMoment(
          'Siena e Piazza del Campo',
          MomentType.photo,
          'assets/test_data/piazza_campo.png',
        ),
        _createMoment(
          'Cipressi al tramonto',
          MomentType.photo,
          'assets/test_data/cipressi_senesi.png',
        ),
        _createMoment(
          'Nota vocale: quiete della campagna',
          MomentType.audio,
          'assets/test_data/rumore_campagna.mp3',
        ),
      ],
      baseLat: 43.3182,
      baseLng: 11.3306,
    );

    // 5. Luoghi del Cuore (Geofence)
    await _injectHeartPlaces();
  }

  static Future<void> _injectHeartPlaces() async {
    final manager = GeofencingManager.instance;
    // Pulisce quelli esistenti per evitare duplicati nei test
    await manager.clearGeofences();

    final places = [
      {'id': 'Colosseo', 'lat': 41.8902, 'lng': 12.4922, 'radius': 200.0},
      {
        'id': 'Piazza del Campo',
        'lat': 43.3184,
        'lng': 11.3314,
        'radius': 150.0,
      },
      {
        'id': 'Vetta Monte Cimone',
        'lat': 44.1935,
        'lng': 10.7011,
        'radius': 300.0,
      },
      {
        'id': 'Corso Italia, Cortina',
        'lat': 46.5376,
        'lng': 12.1337,
        'radius': 250.0,
      },
    ];

    for (var p in places) {
      await manager.addGeofence(
        id: p['id'] as String,
        latitude: p['lat'] as double,
        longitude: p['lng'] as double,
        radiusInMeter: p['radius'] as double,
      );
    }
  }

  /// Crea un viaggio con una traccia GPS densa (~50 punti) generata casualmente attorno a una base.
  static Future<void> _createTrip({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required double distance,
    required TripType type,
    required String coverImg,
    required List<Moment> moments,
    required double baseLat,
    required double baseLng,
  }) async {
    final tripId = _uuid.v4();

    // Genera 100 punti GPS con una direzione predominante (scenic route)
    final List<List<double>> denseTrack = [];
    double curLat = baseLat;
    double curLng = baseLng;

    // Scegliamo una direzione casuale ma costante per questo viaggio
    final double driftLat = (_random.nextDouble() - 0.5) * 0.002;
    final double driftLng = (_random.nextDouble() - 0.5) * 0.002;

    for (int i = 0; i < 100; i++) {
      denseTrack.add([curLat, curLng]);
      // Movimento: drift costante + piccola variazione casuale
      curLat += driftLat + (_random.nextDouble() - 0.5) * 0.001;
      curLng += driftLng + (_random.nextDouble() - 0.5) * 0.001;
    }

    final trip = Trip(
      id: tripId,
      title: title,
      description: description,
      startDate: startDate,
      endDate: endDate,
      totalDistance: distance,
      tripType: type,
      isActive: false,
      isPaused: false,
      coverPath: coverImg,
      moments: [], // Inizialmente vuoti per essere salvati via DBService
      gpsTrack: denseTrack,
    );

    await _db.saveTrip(trip);

    // Salva i momenti associandoli al viaggio
    // Per un realismo maggiore, piazziamo i momenti in ordine sequenziale lungo la traccia
    // e con intervalli temporali variabili
    int step = denseTrack.length ~/ (moments.length + 1);
    for (int i = 0; i < moments.length; i++) {
      final m = moments[i];
      final trackIdx = (i + 1) * step;

      // Calcolo tempo variabile: partiamo dalle 8:00 e distribuiamo fino alle 20:00 (~720 min)
      final baseTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        8,
        0,
      );
      final interval = 720 ~/ (moments.length + 1);
      final momentTime = baseTime.add(
        Duration(minutes: (i + 1) * interval + _random.nextInt(interval ~/ 2)),
      );

      final momentWithTrip = Moment(
        id: m.id,
        tripId: tripId,
        type: m.type,
        content: m.content,
        timestamp: momentTime,
        latitude: denseTrack[trackIdx][0],
        longitude: denseTrack[trackIdx][1],
        title: m.title,
        description: m.description,
      );
      await _db.saveMoment(momentWithTrip);
    }
  }

  static Moment _createMoment(String title, MomentType type, String content) {
    return Moment(
      id: _uuid.v4(),
      tripId: null, // Verrà impostato in _createTrip
      type: type,
      content: content,
      timestamp: DateTime.now(),
      latitude: 0,
      longitude: 0,
      title: title,
      description: type == MomentType.photo || type == MomentType.video
          ? title
          : null,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/moment.dart';
import 'models/trip.dart';
import 'services/database_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/geofencing_manager.dart';
import 'services/missing_memory_service.dart';
import 'screens/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza Hive
  await Hive.initFlutter();
  Hive.registerAdapter(MomentAdapter());
  Hive.registerAdapter(TripAdapter());

  // Inizializza i servizi
  await DatabaseService.instance.init();
  await NotificationService.instance.init();
  await GeofencingManager.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  final DatabaseService? databaseService;
  final GeofencingManager? geofenceService;

  const MyApp({
    super.key,
    this.databaseService,
    this.geofenceService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Avvia il controllo periodico dei Missing Memory ogni 15 minuti
    Future.delayed(const Duration(seconds: 2), () {
      _startMissingMemoryChecker();
    });
  }

  void _startMissingMemoryChecker() {
    // Effettua il primo controllo
    MissingMemoryService.instance.checkMissingMemories();
    MissingMemoryService.instance.checkForMovement();

    // Poi ripeti ogni 15 minuti
    Future.delayed(const Duration(minutes: 15), () {
      if (mounted) {
        _startMissingMemoryChecker();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseService>(create: (_) => widget.databaseService ?? DatabaseService.instance),
        Provider<LocationService>(create: (_) => LocationService.instance),
        Provider<NotificationService>(create: (_) => NotificationService.instance),
        Provider<GeofencingManager>(create: (_) => widget.geofenceService ?? GeofencingManager.instance),
        Provider<MissingMemoryService>(create: (_) => MissingMemoryService.instance),
      ],
      child: MaterialApp(
        title: 'The Memory Lane Journalist',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}

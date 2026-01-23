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

import 'models/trip_folder.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Forza Hybrid Composition per risolvere il crash: java.lang.IllegalStateException: Image is already closed
    // su dispositivi con GPU Mali (come Samsung Galaxy J6)
    final GoogleMapsFlutterPlatform mapsImplementation =
        GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      mapsImplementation.useAndroidViewSurface = true;
    }

    // Inizializza Hive in modo sicuro
    await Hive.initFlutter();
    Hive.registerAdapter(MomentAdapter());
    Hive.registerAdapter(TripAdapter());
    Hive.registerAdapter(MomentTypeAdapter());
    Hive.registerAdapter(TripTypeAdapter());
    Hive.registerAdapter(TripFolderAdapter());

    // Inizializza i servizi separatamente per evitare che il crash di uno blocchi l'app
    try {
      await DatabaseService.instance.init();
    } catch (e) {
      debugPrint('Database initialization error: $e');
    }

    try {
      await NotificationService.instance.init();
    } catch (e) {
      debugPrint('Notification initialization error: $e');
    }

    try {
      await GeofencingManager.instance.init();
    } catch (e) {
      debugPrint('Geofencing initialization error: $e');
    }
  } catch (e) {
    debugPrint('Critical initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  final DatabaseService? databaseService;
  final GeofencingManager? geofenceService;

  const MyApp({super.key, this.databaseService, this.geofenceService});

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
        Provider<DatabaseService>(
          create: (_) => widget.databaseService ?? DatabaseService.instance,
        ),
        Provider<LocationService>(create: (_) => LocationService.instance),
        Provider<NotificationService>(
          create: (_) => NotificationService.instance,
        ),
        Provider<GeofencingManager>(
          create: (_) => widget.geofenceService ?? GeofencingManager.instance,
        ),
        Provider<MissingMemoryService>(
          create: (_) => MissingMemoryService.instance,
        ),
      ],
      child: MaterialApp(
        title: 'The Memory Lane',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF16697A), // Deep Teal dal logo
            primary: const Color(0xFF16697A),
            secondary: const Color(0xFFFFA62B), // Gold dal logo
            tertiary: const Color(0xFF82C0CC), // Light Blue dal logo
            surface: const Color(0xFFF8FAFC),
          ),
          useMaterial3: true,
          fontFamily: 'Inter',
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B262C), // Dark Navy dal logo
              letterSpacing: -1,
            ),
            headlineMedium: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B262C),
              letterSpacing: -0.5,
            ),
            titleLarge: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B262C),
            ),
            bodyLarge: TextStyle(color: Color(0xFF455A64)),
            bodyMedium: TextStyle(color: Color(0xFF546E7A)),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            color: Colors.white,
            surfaceTintColor: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            backgroundColor: Color(0xFFF8FAFC),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            titleTextStyle: TextStyle(
              color: Color(0xFF1B262C),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          splashColor: const Color(0xFF16697A).withOpacity(0.1),
          highlightColor: const Color(0xFF16697A).withOpacity(0.05),
        ),
        home: const HomePage(),
      ),
    );
  }
}

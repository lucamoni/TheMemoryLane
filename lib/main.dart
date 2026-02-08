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
import 'models/heart_place.dart';
import 'screens/splash_screen.dart';

import 'models/trip_folder.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Forza Hybrid Composition per Google Maps su Android
    final GoogleMapsFlutterPlatform mapsImplementation =
        GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      mapsImplementation.useAndroidViewSurface = true;
    }

    // Inizializza la localizzazione italiana per le date
    Intl.defaultLocale = 'it_IT';
    await initializeDateFormatting('it_IT', null);

    // Inizializza l'archiviazione locale Hive
    await Hive.initFlutter();

    // Registrazione dei TypeAdapter per i modelli personalizzati
    Hive.registerAdapter(MomentAdapter());
    Hive.registerAdapter(TripAdapter());
    Hive.registerAdapter(MomentTypeAdapter());
    Hive.registerAdapter(TripTypeAdapter());
    Hive.registerAdapter(TripFolderAdapter());
    Hive.registerAdapter(HeartPlaceAdapter());

    // Inizializzazione dei servizi singleton
    try {
      await DatabaseService.instance.init();
    } catch (e) {
      debugPrint('Errore inizializzazione database: $e');
    }

    try {
      await NotificationService.instance.init();
    } catch (e) {
      debugPrint('Errore inizializzazione notifiche: $e');
    }

    // L'inizializzazione del GeofencingManager è stata rimossa dal main() per evitare crash all'avvio.
    // Ora viene inizializzato nello SplashScreen.
  } catch (e) {
    debugPrint('Errore critico durante l\'avvio: $e');
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
    // La logica di controllo missing memory è stata spostata in HomePage dopo i check dei permessi
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseService>(
          create: (_) => widget.databaseService ?? DatabaseService.instance,
        ),
        Provider<LocationService>(
          // Inizializzazione pigra: accede a .instance solo quando necessario
          create: (_) => LocationService.instance,
          lazy: true,
        ),
        Provider<NotificationService>(
          create: (_) => NotificationService.instance,
        ),
        Provider<GeofencingManager>(
          create: (_) => widget.geofenceService ?? GeofencingManager.instance,
          lazy: true,
        ),
        Provider<MissingMemoryService>(
          create: (_) => MissingMemoryService.instance,
          lazy: true,
        ),
      ],
      child: MaterialApp(
        title: 'The Memory Lane',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF16697A), // Deep Teal
            primary: const Color(0xFF16697A),
            secondary: const Color(0xFFFFA62B), // Gold
            tertiary: const Color(0xFF82C0CC), // Light Blue
            surface: const Color(0xFFF8FAFC),
          ),
          useMaterial3: true,
          fontFamily: 'Inter',
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B262C), // Dark Navy
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
          splashColor: const Color(0xFF16697A).withValues(alpha: 0.1),
          highlightColor: const Color(0xFF16697A).withValues(alpha: 0.05),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

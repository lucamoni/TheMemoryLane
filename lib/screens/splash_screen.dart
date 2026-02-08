import 'package:flutter/material.dart';
import 'home_page.dart';
import '../services/location_service.dart';
import '../services/geofencing_manager.dart';

/// Schermata di pre-caricamento animata (Splash Screen).
/// Fornisce un ingresso dinamico all'app con animazioni di scala e opacità del logo.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Inizializza il controller per una durata più breve (1.5 secondi invece di 2)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Animazione di scala: partiamo dalla dimensione normale (1.0) per evitare salti
    // rispetto allo splash nativo, facciamo solo un leggero respiro (pulse)
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Animazione di dissolvenza: partiamo già visibili (opacity 1.0)
    _fadeAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(_controller);

    // Avvia l'animazione
    _controller.repeat(reverse: true); // Pulsazione continua mentre carica
    _initApp();
  }

  /// Esegue i controlli di inizializzazione (permessi, servizi) mentre l'animazione scorre.
  Future<void> _initApp() async {
    // 1. Attendi almeno la durata dell'animazione per l'effetto visivo
    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    // 2. Richiedi i permessi di localizzazione in modo sicuro
    bool permissionGranted = false;
    try {
      permissionGranted = await LocationService.instance
          .requestLocationPermission();
    } catch (e) {
      debugPrint('Errore richiesta permessi splash: $e');
    }

    // 3. Inizializza il gestore dei geofence (carica i dati dal DB)
    try {
      await GeofencingManager.instance.init();
    } catch (e) {
      debugPrint('Errore inizializzazione geofencing splash: $e');
    }

    // 4. Se i permessi sono concessi, avvia il monitoraggio geofence
    if (permissionGranted) {
      try {
        await GeofencingManager.instance.startMonitoring();
      } catch (e) {
        debugPrint('Errore avvio geofencing splash: $e');
      }
    }

    if (!mounted) return;

    // 4. Naviga alla Home Page
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF16697A,
      ), // Stesso colore della native splash
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Utilizzo del logo ad alta risoluzione
                    Container(
                      width: 200, // Aumentato come richiesto
                      height: 200,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo/logo_512.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'THE MEMORY LANE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'I tuoi ricordi, la tua strada.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

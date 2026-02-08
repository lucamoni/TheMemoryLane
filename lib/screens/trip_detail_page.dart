import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../models/trip.dart';
import '../models/moment.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';
import '../widgets/photo_heat_map_widget.dart';
import '../widgets/timeline_widget.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:record/record.dart' as record;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:async';

/// Pagina dei dettagli di un viaggio.
/// Visualizza la timeline dei ricordi e la mappa di calore.
/// Permette anche di registrare nuovi momenti se il viaggio è attivo.
class TripDetailPage extends StatefulWidget {
  final Trip trip;
  const TripDetailPage({required this.trip, super.key});

  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage>
    with SingleTickerProviderStateMixin {
  late Trip _currentTrip;
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ScrollController _timelineScrollController = ScrollController();
  Timer? _trackingTimer;

  @override
  void initState() {
    super.initState();
    _currentTrip = widget.trip;
    _tabController = TabController(length: 2, vsync: this);

    if (_currentTrip.isActive) {
      _resumeTracking();
    }
  }

  /// Riprende il tracciamento GPS se il viaggio è ancora attivo all'apertura della pagina.
  void _resumeTracking() async {
    final loc = Provider.of<LocationService>(context, listen: false);
    try {
      if (!loc.isTracking) {
        loc.setInitialTrack(_currentTrip.gpsTrack);
        await loc.startTracking();
      }
      _syncTracking(); // Forza il primo aggiornamento immediato
      _startTrackingTimer();
    } catch (e) {
      debugPrint('Errore nel riprendere il tracciamento: $e');
    }
  }

  /// Avvia un timer per sincronizzare periodicamente il percorso GPS con il database.
  void _startTrackingTimer() {
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_currentTrip.isActive) {
        timer.cancel();
        return;
      }
      _syncTracking();
    });
  }

  /// Sincronizza i dati di tracciamento correnti nel modello e nel database.
  void _syncTracking() {
    final loc = Provider.of<LocationService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);

    setState(() {
      _currentTrip = _currentTrip.copyWith(
        gpsTrack: loc.getTrack(),
        totalDistance: loc.getTotalDistance(),
      );
    });
    db.saveTrip(_currentTrip);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timelineScrollController.dispose();
    _trackingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(context),
        ],
        body: Column(
          children: [
            _buildTabBar(context),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _KeepAliveWrapper(child: _buildTimelineTab()),
                  _KeepAliveWrapper(child: _buildHeatMapTab()),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _currentTrip.isActive
          ? _buildActiveTripDock()
          : null,
    );
  }

  /// AppBar con immagine di copertina e informazioni principali del viaggio.
  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 240,
      backgroundColor: Theme.of(context).primaryColor,
      title: _currentTrip.isPaused
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.pause_circle_filled_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'VIAGGIO IN PAUSA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : null,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _currentTrip.coverPath != null
                ? _buildCoverImage(_currentTrip.coverPath!)
                : _currentTrip.moments.any((m) => m.type == MomentType.photo)
                ? _buildCoverImage(
                    _currentTrip.moments
                        .firstWhere((m) => m.type == MomentType.photo)
                        .content!,
                  )
                : _buildDefaultGradientBackground(context),
            // Overlay per rendere il titolo leggibile in ogni stato
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _getTripTypeBadge(_currentTrip.tripType),
                  const SizedBox(height: 8),
                  Text(
                    _currentTrip.title ?? 'Senza Titolo',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat(
                      'dd MMMM yyyy',
                      'it_IT',
                    ).format(_currentTrip.startDate ?? DateTime.now()),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(
                  Icons.edit_location_alt_rounded,
                  color: Colors.white70,
                ),
                onPressed: _changeCoverImage,
                tooltip: 'Cambia Copertina',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Costruisce l'immagine di copertina gestendo sia file locali che asset demo.
  Widget _buildCoverImage(String path) {
    final bool isAsset = path.startsWith('assets/');
    return isAsset
        ? Image.asset(
            path,
            fit: BoxFit.cover,
            cacheHeight: 400,
            errorBuilder: (context, error, stackTrace) =>
                _buildDefaultGradientBackground(context),
          )
        : Image.file(
            File(path),
            fit: BoxFit.cover,
            cacheHeight: 400,
            errorBuilder: (context, error, stackTrace) =>
                _buildDefaultGradientBackground(context),
          );
  }

  Widget _buildDefaultGradientBackground(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, const Color(0xFF1B262C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  /// Permette all'utente di selezionare una nuova immagine di copertina dalla galleria.
  Future<void> _changeCoverImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (!mounted) return;
      final db = Provider.of<DatabaseService>(context, listen: false);
      setState(() {
        _currentTrip = _currentTrip.copyWith(coverPath: image.path);
      });
      await db.saveTrip(_currentTrip);
    }
  }

  /// TabBar per navigare tra Timeline e Heat Map.
  Widget _buildTabBar(BuildContext context) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Theme.of(context).primaryColor,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'Timeline Narrativa'),
          Tab(text: 'Mappa di Calore'),
        ],
      ),
    );
  }

  /// Barra inferiore visibile solo durante la registrazione di un viaggio attivo.
  Widget _buildActiveTripDock() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _currentTrip.isPaused ? _resumeTrip : _pauseTrip,
              icon: Icon(
                _currentTrip.isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
              ),
              label: Text(
                _currentTrip.isPaused ? 'Riprendi Viaggio' : 'Pausa / Opzioni',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentTrip.isPaused
                    ? const Color(0xFF16697A)
                    : Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              onPressed: _endTrip,
              icon: Icon(Icons.stop_rounded, color: Colors.red.shade700),
              tooltip: 'Termina definitivamente',
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            onPressed: _currentTrip.isPaused ? null : _showMomentSelector,
            backgroundColor: _currentTrip.isPaused
                ? Colors.grey.shade300
                : const Color(0xFF16697A),
            elevation: 0,
            mini: true,
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// Costruisce il widget Timeline per il primo tab.
  Widget _buildTimelineTab() {
    return TimelineWidget(
      trip: _currentTrip,
      scrollController: _timelineScrollController,
      onMomentDeleted: () async {
        final db = Provider.of<DatabaseService>(context, listen: false);
        final updatedTrip = await db.getTrip(_currentTrip.id!);
        if (updatedTrip != null && mounted) {
          setState(() {
            _currentTrip = updatedTrip;
          });
        }
      },
    );
  }

  /// Costruisce il widget Heat Map per il secondo tab.
  Widget _buildHeatMapTab() {
    return PhotoHeatMapWidget(
      trip: _currentTrip,
      onMomentSelected: (moment) {
        _tabController.animateTo(0);
        Future.delayed(const Duration(milliseconds: 300), () {
          _jumpToMoment(moment);
        });
      },
    );
  }

  /// Effettua lo scroll automatico fino a un momento specifico nella timeline.
  void _jumpToMoment(Moment moment) {
    if (!_timelineScrollController.hasClients) return;

    final sortedMoments = List<Moment>.from(_currentTrip.moments)
      ..sort(
        (a, b) => (a.timestamp ?? DateTime.now()).compareTo(
          b.timestamp ?? DateTime.now(),
        ),
      );

    final momentIndex = sortedMoments.indexWhere((m) => m.id == moment.id);
    if (momentIndex == -1) return;

    // Stima dinamica dell'offset: Header (~120) + Moments (media ~350px per card)
    // Usiamo un valore più preciso basato sulla struttura della card
    double offset = 120.0;
    for (int i = 0; i < momentIndex; i++) {
      final m = sortedMoments[i];
      // Altezza stimata: Header card (60) + Preview (200 se presente) + Desc (30 se presente) + Footer (40)
      double cardHeight = 120.0;
      if (m.type == MomentType.photo || m.type == MomentType.video) {
        cardHeight += 212;
      } else if (m.type == MomentType.audio) {
        cardHeight += 80;
      }
      if (m.description != null && m.description!.isNotEmpty) {
        cardHeight += 30;
      }
      offset += cardHeight + 16; // Add margin/padding
    }

    _timelineScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  /// Dialog modale per scegliere il tipo di momento da aggiungere.
  void _showMomentSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Cosa vuoi ricordare?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMomentAction(
                  Icons.edit_note_rounded,
                  'Nota',
                  const Color(0xFF16697A),
                  () => _addNote(),
                ),
                _buildMomentAction(
                  Icons.camera_alt_rounded,
                  'Foto',
                  const Color(0xFFFFA62B),
                  () => _takePhoto(),
                ),
                _buildMomentAction(
                  Icons.videocam_rounded,
                  'Video',
                  Colors.redAccent,
                  () => _takeVideo(),
                ),
                _buildMomentAction(
                  Icons.mic_rounded,
                  'Audio',
                  const Color(0xFF82C0CC),
                  () => _showAudioRecorder(),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Registra un nuovo video e lo salva come momento.
  Future<void> _takeVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
    if (video != null) {
      if (!mounted) return;
      final loc = await Provider.of<LocationService>(
        context,
        listen: false,
      ).getCurrentLocation();
      if (!mounted) return;

      if (!mounted) return;

      final titleController = TextEditingController(text: 'Nuovo Video');
      final descController = TextEditingController();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dettagli Video'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Titolo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Descrizione (opzionale)',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                _saveMoment(
                  MomentType.video,
                  video.path,
                  lat: loc?.latitude,
                  lng: loc?.longitude,
                  title: titleController.text,
                  description: descController.text,
                );
                Navigator.pop(context);
              },
              child: const Text('Salva Ricordo'),
            ),
          ],
        ),
      );
    }
  }

  /// Mostra il dialog per la registrazione audio.
  void _showAudioRecorder() {
    showDialog(
      context: context,
      builder: (context) => _AudioRecorderDialog(
        onSaved: (path) async {
          final loc = await Provider.of<LocationService>(
            context,
            listen: false,
          ).getCurrentLocation();
          if (!mounted) return;
          _saveMoment(
            MomentType.audio,
            path,
            lat: loc?.latitude,
            lng: loc?.longitude,
            title: 'Audio',
            description: 'Registrazione vocale',
          );
        },
      ),
    );
  }

  /// Permette di aggiungere una nota testuale o dettata.
  void _addNote() {
    final controller = TextEditingController();
    bool isListening = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text('Nuova Nota'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Scrivi o detta un pensiero...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isListening ? Icons.stop_circle : Icons.mic_rounded,
                        ),
                        color: isListening
                            ? Colors.red
                            : Theme.of(context).primaryColor,
                        onPressed: () async {
                          if (!isListening) {
                            bool available = await _speech.initialize();
                            if (available) {
                              setDialogState(() => isListening = true);
                              _speech.listen(
                                onResult: (result) {
                                  setDialogState(() {
                                    controller.text = result.recognizedWords;
                                    if (result.finalResult) isListening = false;
                                  });
                                },
                              );
                            }
                          } else {
                            _speech.stop();
                            setDialogState(() => isListening = false);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _speech.stop();
                  Navigator.pop(context);
                },
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (controller.text.isNotEmpty) {
                    if (!mounted) return;
                    final loc = await Provider.of<LocationService>(
                      context,
                      listen: false,
                    ).getCurrentLocation();
                    if (!mounted) return;
                    if (!mounted) return;
                    _saveMoment(
                      MomentType.note,
                      controller.text,
                      lat: loc?.latitude,
                      lng: loc?.longitude,
                      title: 'Nota',
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  }
                },
                child: const Text('Salva'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Widget per visualizzare un'azione rapida nel selettore di momenti.
  Widget _buildMomentAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Scatta una foto e la salva come momento.
  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      if (!mounted) return;
      final loc = await Provider.of<LocationService>(
        context,
        listen: false,
      ).getCurrentLocation();
      if (!mounted) return;

      if (!mounted) return;

      final titleController = TextEditingController(text: 'Nuova Foto');
      final descController = TextEditingController();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dettagli Foto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Titolo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Descrizione (opzionale)',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                _saveMoment(
                  MomentType.photo,
                  photo.path,
                  lat: loc?.latitude,
                  lng: loc?.longitude,
                  title: titleController.text,
                  description: descController.text,
                );
                Navigator.pop(context);
              },
              child: const Text('Salva Ricordo'),
            ),
          ],
        ),
      );
    }
  }

  /// Salva il momento nel database e aggiorna lo stato locale.
  void _saveMoment(
    MomentType type,
    String content, {
    double? lat,
    double? lng,
    String? title,
    String? description,
    String? id,
  }) async {
    if (!mounted) return;
    final db = Provider.of<DatabaseService>(context, listen: false);
    final moment = Moment(
      id: id ?? const Uuid().v4(),
      tripId: _currentTrip.id,
      type: type,
      content: content,
      timestamp: DateTime.now(),
      latitude: lat ?? 0.0,
      longitude: lng ?? 0.0,
      title: title,
      description: description,
    );
    await db.saveMoment(moment);
    setState(() {
      final index = _currentTrip.moments.indexWhere((m) => m.id == moment.id);
      if (index >= 0) {
        _currentTrip.moments[index] = moment;
      } else {
        _currentTrip.moments.add(moment);
      }
      _currentTrip = _currentTrip.copyWith(
        moments: List.from(_currentTrip.moments),
      );
    });
  }

  /// Mostra un dialogo per scegliere il tipo di pausa (semplice vs fine giornata).
  Future<void> _pauseTrip() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opzioni Pausa'),
        content: const Text(
          'Come vuoi sospendere il viaggio?\n\n'
          '• Pausa Semplice: ferma solo il GPS.\n'
          '• Fine Giornata: aggiunge un marcatore nella timeline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'simple'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Pausa Semplice'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'dayEnd'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16697A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Fine Giornata'),
          ),
        ],
      ),
    );

    if (choice != null) {
      await _executePause(isDayEnd: choice == 'dayEnd');
    }
  }

  /// Esegue la logica di pausa effettiva.
  Future<void> _executePause({required bool isDayEnd}) async {
    if (!mounted) return;
    final loc = Provider.of<LocationService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);

    // Recupera l'ultima posizione disponibile
    final currentPos = await loc.getCurrentLocation().timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    );

    await loc.stopTracking();
    _trackingTimer?.cancel();

    Moment? dayEndMoment;
    if (isDayEnd) {
      final dayNumber =
          _currentTrip.moments
              .where((m) => m.type == MomentType.dayEnd)
              .length +
          1;

      dayEndMoment = Moment(
        id: const Uuid().v4(),
        tripId: _currentTrip.id,
        type: MomentType.dayEnd,
        content: 'Fine Giorno $dayNumber',
        timestamp: DateTime.now(),
        latitude: currentPos?.latitude ?? 0.0,
        longitude: currentPos?.longitude ?? 0.0,
        title: 'Giorno $dayNumber Concluso',
      );
    }

    setState(() {
      final updatedMoments = List<Moment>.from(_currentTrip.moments);
      if (dayEndMoment != null) {
        updatedMoments.add(dayEndMoment);
      }

      _currentTrip = _currentTrip.copyWith(
        isPaused: true,
        moments: updatedMoments,
        gpsTrack: loc.getTrack(),
        totalDistance: loc.getTotalDistance(),
      );
    });

    await db.saveTrip(_currentTrip);
    if (dayEndMoment != null) {
      await db.saveMoment(dayEndMoment);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDayEnd
                ? 'Giorno concluso salvato. Viaggio in pausa.'
                : 'Pausa semplice attivata. GPS sospeso.',
          ),
          backgroundColor: const Color(0xFF16697A),
        ),
      );
    }
  }

  /// Riprende un viaggio in pausa, riavviando il tracking GPS.
  Future<void> _resumeTrip() async {
    final loc = Provider.of<LocationService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);

    // Re-idrata il path nel service se necessario (anche se dovrebbe essere già lì se l'app è aperta)
    loc.setInitialTrack(_currentTrip.gpsTrack);

    await loc.startTracking();
    _startTrackingTimer();

    setState(() {
      _currentTrip = _currentTrip.copyWith(isPaused: false);
    });

    await db.saveTrip(_currentTrip);
  }

  /// Termina definitivamente il viaggio.
  Future<void> _endTrip() async {
    final loc = Provider.of<LocationService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);

    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Termina Viaggio'),
            content: const Text(
              'Vuoi concludere definitivamente questa avventura? Non potrai più aggiungere momenti o tracce GPS.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Termina'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      if (!_currentTrip.isPaused) {
        await loc.stopTracking();
        _trackingTimer?.cancel();
      }

      setState(() {
        _currentTrip = _currentTrip.copyWith(
          isActive: false,
          isPaused: false,
          endDate: DateTime.now(),
          gpsTrack: loc.getTrack(),
          totalDistance: loc.getTotalDistance(),
        );
      });
      await db.saveTrip(_currentTrip);
    }
  }

  /// Badge grafico rappresentante il tipo di viaggio.
  Widget _getTripTypeBadge(TripType type) {
    IconData icon;
    String label;
    Color color;

    switch (type) {
      case TripType.localTrip:
        icon = Icons.directions_walk_rounded;
        label = 'Passeggiata';
        color = Colors.green;
        break;
      case TripType.dayTrip:
        icon = Icons.explore_rounded;
        label = 'Gita';
        color = Colors.orange;
        break;
      case TripType.multiDayTrip:
        icon = Icons.flight_takeoff_rounded;
        label = 'Viaggio';
        color = Colors.blue;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog per la registrazione audio integrato nella pagina dei dettagli.
class _AudioRecorderDialog extends StatefulWidget {
  final Function(String) onSaved;
  const _AudioRecorderDialog({required this.onSaved});

  @override
  State<_AudioRecorderDialog> createState() => _AudioRecorderDialogState();
}

class _AudioRecorderDialogState extends State<_AudioRecorderDialog> {
  final _audioRecorder = record.AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registra Audio'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic_rounded, size: 48, color: Color(0xFF82C0CC)),
          const SizedBox(height: 16),
          Text(
            _isRecording ? 'Registrazione in corso...' : 'Pronto a registrare',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (!_isRecording) {
              if (await _audioRecorder.hasPermission()) {
                if (!mounted) return;
                final directory = await getApplicationDocumentsDirectory();
                if (!mounted) return;
                _audioPath = p.join(
                  directory.path,
                  'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
                );
                await _audioRecorder.start(
                  const record.RecordConfig(),
                  path: _audioPath!,
                );
                setState(() => _isRecording = true);
              }
            } else {
              final path = await _audioRecorder.stop();
              if (!mounted) return;
              if (path != null) {
                widget.onSaved(path);
              }
              if (!context.mounted) return;
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRecording
                ? Colors.red
                : const Color(0xFF16697A),
          ),
          child: Text(_isRecording ? 'Ferma' : 'Inizia'),
        ),
      ],
    );
  }
}

/// Wrapper per mantenere vivo lo stato dei tab ed evitare ricostruzioni costose (es. Google Map).
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

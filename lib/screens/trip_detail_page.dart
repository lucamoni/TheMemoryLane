import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../models/trip.dart';
import '../models/moment.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';
import '../services/geofencing_manager.dart';
import '../widgets/photo_heat_map_widget.dart';
import '../widgets/timeline_widget.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:record/record.dart' as record;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:async';

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

  void _resumeTracking() async {
    final loc = Provider.of<LocationService>(context, listen: false);
    try {
      if (!loc.isTracking) {
        loc.setInitialTrack(_currentTrip.gpsTrack);
        await loc.startTracking();
      }
      _startTrackingTimer();
    } catch (e) {
      debugPrint('Error resuming tracking: $e');
    }
  }

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
                children: [_buildTimelineTab(), _buildHeatMapTab()],
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

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      stretch: true,
      backgroundColor: Theme.of(context).primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _currentTrip.coverPath != null
                ? Image.file(
                    File(_currentTrip.coverPath!),
                    fit: BoxFit.cover,
                    cacheHeight: 400,
                  )
                : _currentTrip.moments.any((m) => m.type == MomentType.photo)
                ? Image.file(
                    File(
                      _currentTrip.moments
                          .firstWhere((m) => m.type == MomentType.photo)
                          .content!,
                    ),
                    fit: BoxFit.cover,
                    cacheHeight: 400,
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor,
                          const Color(0xFF1B262C),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
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
                    ).format(_currentTrip.startDate ?? DateTime.now()),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
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

  Future<void> _changeCoverImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final db = Provider.of<DatabaseService>(context, listen: false);
      setState(() {
        _currentTrip = _currentTrip.copyWith(coverPath: image.path);
      });
      await db.saveTrip(_currentTrip);
    }
  }

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

  Widget _buildActiveTripDock() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Termina a sinistra
          TextButton.icon(
            onPressed: () => _stopRecording(context),
            icon: const Icon(
              Icons.stop_circle_outlined,
              color: Colors.red,
              size: 20,
            ),
            label: const Text(
              'Termina',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),

          // Stato al centro
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gps_fixed, color: Colors.red, size: 14),
              SizedBox(width: 4),
              Text(
                'LIVE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: Colors.red,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          // Momento a destra
          ElevatedButton.icon(
            onPressed: () => _showMomentSelector(),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Momento'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16697A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTab() {
    return TimelineWidget(
      moments: _currentTrip.moments,
      totalDistance: _currentTrip.totalDistance,
      startDate: _currentTrip.startDate,
      endDate: _currentTrip.endDate,
      onEdit: (moment) => _editMoment(moment),
      onDelete: (moment) => _deleteMoment(moment),
      controller: _timelineScrollController,
    );
  }

  Widget _buildHeatMapTab() {
    return PhotoHeatMapWidget(
      trip: _currentTrip,
      onMomentSelected: (moment) {
        _tabController.animateTo(0);
        // Ritardo per permettere al TabView di cambiare pagina prima di scorrere
        Future.delayed(const Duration(milliseconds: 300), () {
          _jumpToMoment(moment);
        });
      },
    );
  }

  void _jumpToMoment(Moment moment) {
    if (!_timelineScrollController.hasClients) return;

    // Ordiniamo i momenti come nella Timeline
    final sortedMoments = List<Moment>.from(_currentTrip.moments)
      ..sort(
        (a, b) => (a.timestamp ?? DateTime.now()).compareTo(
          b.timestamp ?? DateTime.now(),
        ),
      );

    final momentIndex = sortedMoments.indexWhere((m) => m.id == moment.id);
    if (momentIndex == -1) return;

    // Calcoliamo l'indice nel ListView (Header + Titolo + Milestones)
    final milestonesBefore = (momentIndex / 3).floor();
    final listIndex =
        momentIndex + milestonesBefore + 2; // +2 per header e titolo

    // Stima dell'offset (approssimativa perché le card variano in altezza)
    // Usiamo jumpTo prima e poi animateTo per precisione se possibile, o solo animateTo
    double offset = 0;
    for (int i = 0; i < listIndex; i++) {
      if (i == 0)
        offset += 300; // Header circa 300
      else if (i == 1)
        offset += 60; // Titolo circa 60
      else {
        final actualIdx = i - 2;
        if ((actualIdx + 1) % 4 == 0) {
          offset += 60; // Milestone circa 60
        } else {
          // Moment card: stima media
          offset += 250;
        }
      }
    }

    _timelineScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

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

  Future<void> _takeVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
    if (video != null) {
      final loc = await Provider.of<LocationService>(
        context,
        listen: false,
      ).getCurrentLocation();

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

  void _showAudioRecorder() {
    showDialog(
      context: context,
      builder: (context) => _AudioRecorderDialog(
        onSaved: (path) async {
          final loc = await Provider.of<LocationService>(
            context,
            listen: false,
          ).getCurrentLocation();
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
                    final loc = await Provider.of<LocationService>(
                      context,
                      listen: false,
                    ).getCurrentLocation();
                    _saveMoment(
                      MomentType.note,
                      controller.text,
                      lat: loc?.latitude,
                      lng: loc?.longitude,
                      title: 'Nota',
                    );
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
              color: color.withOpacity(0.1),
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

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      final loc = await Provider.of<LocationService>(
        context,
        listen: false,
      ).getCurrentLocation();

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

  void _saveMoment(
    MomentType type,
    String content, {
    double? lat,
    double? lng,
    String? title,
    String? description,
    String? id,
  }) async {
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
      _currentTrip = _currentTrip.copyWith(moments: _currentTrip.moments);
    });
  }

  void _editMoment(Moment moment) {
    if (moment.type == MomentType.note) {
      final controller = TextEditingController(text: moment.content);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Modifica Nota'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                _saveMoment(
                  moment.type!,
                  controller.text,
                  lat: moment.latitude,
                  lng: moment.longitude,
                  title: moment.title,
                  id: moment.id,
                );
                Navigator.pop(context);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      );
    } else {
      // Per foto/video/audio permettiamo solo di modificare il titolo per ora
      final controller = TextEditingController(text: moment.title);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rinomina Momento'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Titolo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                _saveMoment(
                  moment.type!,
                  moment.content!,
                  lat: moment.latitude,
                  lng: moment.longitude,
                  title: controller.text,
                  description: moment.description,
                  id: moment.id,
                );
                Navigator.pop(context);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      );
    }
  }

  void _deleteMoment(Moment moment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Momento'),
        content: const Text('Sei sicuro di voler eliminare questo ricordo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = Provider.of<DatabaseService>(context, listen: false);
              await db.deleteMoment(moment.id!);
              setState(() {
                _currentTrip.moments.removeWhere((m) => m.id == moment.id);
                _currentTrip = _currentTrip.copyWith(
                  moments: _currentTrip.moments,
                );
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopRecording(BuildContext context) async {
    final loc = Provider.of<LocationService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);
    await loc.stopTracking();

    setState(() {
      _currentTrip = _currentTrip.copyWith(
        isActive: false,
        endDate: DateTime.now(),
        gpsTrack: loc.getTrack(),
        totalDistance: loc.getTotalDistance(),
      );
    });
    await db.saveTrip(_currentTrip);

    if (mounted) {
      _showGeofencePrompt(
        loc.getLastLocation()?.latitude,
        loc.getLastLocation()?.longitude,
      );
    }
  }

  void _showGeofencePrompt(double? lat, double? lng) {
    if (lat == null || lng == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Luogo del Cuore?'),
        content: const Text(
          'Vuoi salvare questo punto per ricevere notifiche quando ci tornerai in futuro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addGeofence(lat, lng);
            },
            child: const Text('Sì, salva'),
          ),
        ],
      ),
    );
  }

  void _addGeofence(double lat, double lng) async {
    final gm = Provider.of<GeofencingManager>(context, listen: false);
    await gm.addGeofence(
      id: 'Geofence_${DateTime.now()}',
      latitude: lat,
      longitude: lng,
      radiusInMeter: 200,
    );
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Luogo del Cuore aggiunto!')),
      );
  }

  Widget _getTripTypeBadge(TripType type) {
    String label;
    Color color;
    switch (type) {
      case TripType.localTrip:
        label = 'LOCAL';
        color = const Color(0xFF10B981);
        break;
      case TripType.dayTrip:
        label = 'DAY TRIP';
        color = const Color(0xFFF59E0B);
        break;
      case TripType.multiDayTrip:
        label = 'VACATION';
        color = const Color(0xFF3B82F6);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _AudioRecorderDialog extends StatefulWidget {
  final Function(String) onSaved;
  const _AudioRecorderDialog({required this.onSaved});
  @override
  State<_AudioRecorderDialog> createState() => _AudioRecorderDialogState();
}

class _AudioRecorderDialogState extends State<_AudioRecorderDialog> {
  final _audioRecorder = record.AudioRecorder();
  bool _isRecording = false;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = p.join(
          dir.path,
          'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
        );
        await _audioRecorder.start(const record.RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _stop() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (path != null) {
      widget.onSaved(path);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Registra Audio'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _isRecording ? _stop : _start,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: _isRecording
                      ? Colors.red.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isRecording ? Colors.red : Colors.blue,
                    width: 3,
                  ),
                ),
                child: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 48,
                  color: _isRecording ? Colors.red : Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(_isRecording ? 'Registrazione...' : 'Tocca per registrare'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
      ],
    );
  }
}

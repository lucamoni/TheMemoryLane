import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/trip.dart';
import '../models/moment.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';
import '../services/geofencing_manager.dart';
import '../widgets/photo_heat_map_widget.dart';
import '../widgets/timeline_widget.dart';

class TripDetailPage extends StatefulWidget {
  final Trip trip;

  const TripDetailPage({required this.trip, super.key});

  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage> with SingleTickerProviderStateMixin {
  late Trip _currentTrip;
  bool _isRecording = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _currentTrip = widget.trip;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationService = Provider.of<LocationService>(context);
    final dbService = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTrip.title ?? 'Viaggio'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Dettagli'),
            Tab(icon: Icon(Icons.timeline), text: 'Timeline'),
            Tab(icon: Icon(Icons.map), text: 'Heat Map'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(locationService, dbService),
          _buildTimelineTab(),
          _buildHeatMapTab(),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(LocationService locationService, DatabaseService dbService) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Sezione di controllo registrazione
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Registrazione GPS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isRecording
                                  ? null
                                  : () => _startRecording(locationService),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Avvia'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isRecording
                                  ? () => _stopRecording(locationService, dbService)
                                  : null,
                              icon: const Icon(Icons.stop),
                              label: const Text('Ferma'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRecording
                            ? 'Registrazione in corso...'
                            : 'Registrazione ferma',
                        style: TextStyle(
                          color: _isRecording ? Colors.red : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Sezione momenti
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Momenti',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showAddMomentDialog(dbService),
                      ),
                    ],
                  ),
                  _currentTrip.moments.isEmpty
                      ? const Text('Nessun momento salvato')
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _currentTrip.moments.length,
                          itemBuilder: (context, index) {
                            final moment = _currentTrip.moments[index];
                            return ListTile(
                              title: Text(moment.title ?? 'Momento'),
                              subtitle: Text(moment.content ?? ''),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  if (moment.id != null) {
                                    dbService.deleteMoment(moment.id!);
                                  }
                                  final updatedMoments =
                                      List<Moment>.from(_currentTrip.moments);
                                  updatedMoments.removeAt(index);
                                  setState(() {
                                    _currentTrip = _currentTrip.copyWith(
                                        moments: updatedMoments);
                                  });
                                },
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildTimelineTab() {
    return SingleChildScrollView(
      child: TimelineWidget(
        moments: _currentTrip.moments,
        totalDistance: _currentTrip.totalDistance,
        startDate: _currentTrip.startDate,
        endDate: _currentTrip.endDate,
      ),
    );
  }

  Widget _buildHeatMapTab() {
    return SingleChildScrollView(
      child: PhotoHeatMapWidget(trip: _currentTrip),
    );
  }

  Future<void> _startRecording(LocationService locationService) async {
    try {
      await locationService.startTracking();
      setState(() {
        _isRecording = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registrazione GPS avviata')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _stopRecording(
      LocationService locationService, DatabaseService dbService) async {
    await locationService.stopTracking();
    final track = locationService.getTrack();
    final distance = locationService.getTotalDistance();
    final lastLocation = locationService.getLastLocation();

    setState(() {
      _isRecording = false;
      _currentTrip = _currentTrip.copyWith(
        gpsTrack: track,
        totalDistance: distance,
      );
    });

    await dbService.saveTrip(_currentTrip);
    locationService.clearTrack();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Registrazione fermata. Distanza: ${distance.toStringAsFixed(2)} km')),
      );

      // Offri all'utente di creare un geofence
      if (lastLocation != null && lastLocation.latitude != null && lastLocation.longitude != null) {
        _showCreateGeofenceDialog(lastLocation.latitude!, lastLocation.longitude!);
      }
    }
  }

  void _showCreateGeofenceDialog(double lat, double lng) {
    final nameController = TextEditingController();
    final radiusController = TextEditingController(text: '200');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salva questo luogo?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Vuoi salvare la fine del viaggio come "Luogo del Cuore"?'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nome del luogo',
                border: OutlineInputBorder(),
                hintText: 'Es: Casa, Ufficio',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: radiusController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Raggio (metri)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, grazie'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final geofencingManager = Provider.of<GeofencingManager>(context, listen: false);
                final radius = double.tryParse(radiusController.text) ?? 200;

                await geofencingManager.addGeofence(
                  id: nameController.text,
                  latitude: lat,
                  longitude: lng,
                  radiusInMeter: radius,
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Luogo del Cuore salvato!')),
                  );
                }
              }
            },
            child: const Text('Salva Luogo'),
          ),
        ],
      ),
    );
  }

  void _showAddMomentDialog(DatabaseService dbService) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aggiungi un Momento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Titolo'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(labelText: 'Nota'),
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
            onPressed: () async {
              final moment = Moment(
                id: const Uuid().v4(),
                tripId: _currentTrip.id,
                type: MomentType.note,
                content: contentController.text,
                timestamp: DateTime.now(),
                latitude: 0,
                longitude: 0,
                title: titleController.text.isEmpty
                    ? null
                    : titleController.text,
              );

              await dbService.saveMoment(moment);
              setState(() {
                _currentTrip = _currentTrip.copyWith(
                  moments: [..._currentTrip.moments, moment],
                );
              });

              if (mounted) Navigator.pop(context);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }
}


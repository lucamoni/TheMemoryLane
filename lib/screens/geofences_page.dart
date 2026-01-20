import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geofence_service/geofence_service.dart';
import '../services/geofencing_manager.dart';
import '../services/notification_service.dart';

class GeofencesPage extends StatefulWidget {
  const GeofencesPage({super.key});

  @override
  State<GeofencesPage> createState() => _GeofencesPageState();
}

class _GeofencesPageState extends State<GeofencesPage> {
  final _nameController = TextEditingController();
  final _radiusController = TextEditingController(text: '200');
  double? _currentLat;
  double? _currentLng;

  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final geofencingManager = Provider.of<GeofencingManager>(context);
    final geofences = geofencingManager.getGeofences();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luoghi del Cuore'),
      ),
      body: Column(
        children: [
          // Sezione per aggiungere geofence
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aggiungi un Luogo del Cuore',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome del luogo',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _radiusController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Raggio (metri)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.zoom_out_map),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_currentLat != null && _currentLng != null)
                      Text(
                        'Posizione attuale: $_currentLat, $_currentLng',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      )
                    else
                      const Text(
                        'Posizione non disponibile',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _addGeofence(geofencingManager),
                        icon: const Icon(Icons.add),
                        label: const Text('Salva Luogo'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Lista dei geofence
          Expanded(
            child: geofences.isEmpty
                ? const Center(
                    child: Text('Nessun luogo del cuore ancora'),
                  )
                : ListView.builder(
                    itemCount: geofences.length,
                    itemBuilder: (context, index) {
                      final geofence = geofences[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(geofence.id),
                          subtitle: Text(
                            'Lat: ${geofence.latitude.toStringAsFixed(4)}, '
                            'Lng: ${geofence.longitude.toStringAsFixed(4)}\n'
                            'Raggio: ${geofence.radius.first.length.toStringAsFixed(0)}m',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteGeofence(
                              context,
                              geofence.id,
                              geofencingManager,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addGeofence(GeofencingManager manager) async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il nome del luogo')),
      );
      return;
    }

    if (_currentLat == null || _currentLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Posizione non disponibile')),
      );
      return;
    }

    final radius = double.tryParse(_radiusController.text) ?? 200;

    await manager.addGeofence(
      id: _nameController.text,
      latitude: _currentLat!,
      longitude: _currentLng!,
      radiusInMeter: radius,
    );

    _nameController.clear();
    _radiusController.text = '200';

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Luogo aggiunto con successo')),
      );
    }
  }

  Future<void> _deleteGeofence(
    BuildContext context,
    String id,
    GeofencingManager manager,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Luogo'),
        content: const Text('Sei sicuro di voler eliminare questo luogo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await manager.removeGeofence(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Luogo eliminato')),
        );
      }
    }
  }
}


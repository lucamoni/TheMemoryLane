import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/geofencing_manager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import '../widgets/add_geofence_sheet.dart';

/// Pagina per la gestione dei "Luoghi del Cuore" (Geofence).
/// Permette di visualizzare la lista dei luoghi salvati e la loro posizione su mappa.
class GeofencesPage extends StatefulWidget {
  const GeofencesPage({super.key});

  @override
  State<GeofencesPage> createState() => _GeofencesPageState();
}

class _GeofencesPageState extends State<GeofencesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Il GeofencingManager fornisce lo stato dei luoghi salvati (geofences)
    final geofencingManager = Provider.of<GeofencingManager>(context);
    final geofences = geofencingManager.getGeofences();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Luoghi del Cuore'),
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Lista'),
            Tab(icon: Icon(Icons.map_outlined), text: 'Mappa'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Visualizzazione a lista
          geofences.isEmpty
              ? _buildEmptyState()
              : _buildGeofencesList(geofences, geofencingManager),
          // Visualizzazione su mappa
          _buildGeofencesMap(geofences),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGeofenceSheet(geofencingManager),
        icon: const Icon(Icons.add_location_rounded),
        label: const Text('Aggiungi Luogo'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// Stato vuoto mostrato quando non ci sono luoghi salvati.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 64,
            color: Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ancora nessun luogo preferito',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Salva i posti che ami per ricevere una notifica quando ci passi vicino durante i tuoi viaggi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Costruisce la lista scrollabile dei Luoghi del Cuore.
  Widget _buildGeofencesList(
    List<dynamic> geofences,
    GeofencingManager manager,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: geofences.length,
      itemBuilder: (context, index) {
        final gf = geofences[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(20),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA62B).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFFFA62B),
                size: 24,
              ),
            ),
            title: Text(
              gf.id,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Raggio: ${gf.radius.first.length.toStringAsFixed(0)}m\n${gf.latitude.toStringAsFixed(4)}, ${gf.longitude.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.grey,
              ),
              onPressed: () => _deleteGeofence(context, gf.id, manager),
            ),
          ),
        );
      },
    );
  }

  /// Costruisce la mappa con i marker e i cerchi dei raggio d'azione per ogni geofence.
  Widget _buildGeofencesMap(List<dynamic> geofences) {
    final markers = geofences.map((gf) {
      return Marker(
        markerId: MarkerId(gf.id),
        position: LatLng(gf.latitude, gf.longitude),
        infoWindow: InfoWindow(title: gf.id),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      );
    }).toSet();

    final circles = geofences.map((gf) {
      return Circle(
        circleId: CircleId(gf.id),
        center: LatLng(gf.latitude, gf.longitude),
        radius: gf.radius.first.length.toDouble(),
        fillColor: const Color(0xFFFFA62B).withOpacity(0.2),
        strokeWidth: 1,
        strokeColor: const Color(0xFFFFA62B),
      );
    }).toSet();

    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(41.9028, 12.4964), // Default su Roma se non ci sono dati
        zoom: 5,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      markers: markers,
      circles: circles,
      onMapCreated: (controller) {
        _mapController = controller;
        if (geofences.isNotEmpty) {
          _fitBounds(geofences);
        }
      },
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
    );
  }

  /// Adatta la visuale della mappa per includere tutti i geofence.
  void _fitBounds(List<dynamic> geofences) {
    if (geofences.isEmpty) return;
    double minLat = geofences.first.latitude;
    double maxLat = geofences.first.latitude;
    double minLng = geofences.first.longitude;
    double maxLng = geofences.first.longitude;

    for (var gf in geofences) {
      if (gf.latitude < minLat) minLat = gf.latitude;
      if (gf.latitude > maxLat) maxLat = gf.latitude;
      if (gf.longitude < minLng) minLng = gf.longitude;
      if (gf.longitude > maxLng) maxLng = gf.longitude;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50,
      ),
    );
  }

  /// Mostra il foglio modale per aggiungere un nuovo Luogo del Cuore.
  void _showAddGeofenceSheet(GeofencingManager manager) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddGeofenceSheet(manager: manager),
    );
  }

  /// Dialog di conferma per l'eliminazione di un geofence.
  void _deleteGeofence(
    BuildContext context,
    String id,
    GeofencingManager manager,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Luogo'),
        content: const Text('Rimuovere questo luogo dai tuoi preferiti?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await manager.removeGeofence(id);
    }
  }
}

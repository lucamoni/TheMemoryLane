import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../services/geofencing_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// Foglio modale per l'aggiunta di un nuovo "Luogo del Cuore" (Geofence).
/// Offre tre modalità: GPS attuale, selezione su Mappa, ricerca per Indirizzo.
class AddGeofenceSheet extends StatefulWidget {
  final GeofencingManager manager;
  const AddGeofenceSheet({required this.manager, super.key});

  @override
  State<AddGeofenceSheet> createState() => _AddGeofenceSheetState();
}

class _AddGeofenceSheetState extends State<AddGeofenceSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController(
    text: '200',
  );

  // Stato della mappa
  GoogleMapController? _mapController;
  LatLng? _selectedPosition;
  Set<Marker> _markers = {};

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initCurrentLocation();
  }

  /// Inizializza la posizione selezionata con le coordinate GPS attuali.
  Future<void> _initCurrentLocation() async {
    final loc = Provider.of<LocationService>(context, listen: false);
    final pos = await loc.getCurrentLocation();
    if (pos != null && pos.latitude != null) {
      setState(() {
        _selectedPosition = LatLng(pos.latitude!, pos.longitude!);
        _updateMarkers();
      });
    }
  }

  /// Aggiorna il marker sulla mappa in base alla posizione selezionata.
  void _updateMarkers() {
    if (_selectedPosition == null) return;
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected'),
          position: _selectedPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      };
    });
  }

  /// Esegue la ricerca geografica (geocoding) partendo da un indirizzo testuale.
  Future<void> _searchAddress() async {
    if (_addressController.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final locations = await locationFromAddress(_addressController.text);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final target = LatLng(loc.latitude, loc.longitude);
        setState(() {
          _selectedPosition = target;
          _updateMarkers();
        });

        // Passa automaticamente al tab mappa per confermare visivamente la posizione
        _tabController.animateTo(1);

        // Muove la telecamera sul punto trovato
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Indirizzo non trovato')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nella ricerca dell\'indirizzo')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Salva il nuovo geofence tramite il manager.
  Future<void> _save() async {
    if (_nameController.text.isEmpty || _selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci un nome e seleziona una posizione'),
        ),
      );
      return;
    }

    try {
      await widget.manager.addGeofence(
        id: _nameController.text,
        latitude: _selectedPosition!.latitude,
        longitude: _selectedPosition!.longitude,
        radiusInMeter: double.tryParse(_radiusController.text) ?? 200,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Gestione errore salvataggio geofence
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nuovo Luogo del Cuore',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.gps_fixed), text: 'GPS'),
              Tab(icon: Icon(Icons.map), text: 'Mappa'),
              Tab(icon: Icon(Icons.search), text: 'Cerca'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildGpsTab(), _buildMapTab(), _buildSearchTab()],
            ),
          ),
          _buildForm(),
        ],
      ),
    );
  }

  /// Tab per l'acquisizione della posizione GPS attuale.
  Widget _buildGpsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.my_location, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          const Text('Usa la tua posizione attuale'),
          if (_selectedPosition != null)
            Text(
              '${_selectedPosition!.latitude.toStringAsFixed(4)}, ${_selectedPosition!.longitude.toStringAsFixed(4)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              setState(() => _isLoading = true);
              await _initCurrentLocation();
              setState(() => _isLoading = false);
            },
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Aggiorna Posizione'),
          ),
        ],
      ),
    );
  }

  /// Tab per la selezione manuale del punto sulla mappa.
  Widget _buildMapTab() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(41.9028, 12.4964),
            zoom: 5,
          ),
          onMapCreated: (c) {
            _mapController = c;
            if (_selectedPosition != null) {
              c.animateCamera(
                CameraUpdate.newLatLngZoom(_selectedPosition!, 15),
              );
            }
          },
          markers: _markers,
          onTap: (pos) {
            setState(() {
              _selectedPosition = pos;
              _updateMarkers();
            });
          },
          onCameraIdle: () async {
            if (_mapController != null) {
              final bounds = await _mapController!.getVisibleRegion();
              final center = LatLng(
                (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
                (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
              );
              // Aggiorna la posizione selezionata al centro della mappa quando l'utente smette di muoverla
              setState(() {
                _selectedPosition = center;
                _updateMarkers();
              });
            }
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        ),
        const Center(
          child: Icon(Icons.add_location_alt, size: 40, color: Colors.blue),
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Sposta la mappa per centrare il luogo',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  /// Tab per la ricerca di un luogo tramite indirizzo.
  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              hintText: 'Cerca indirizzo (es. Piazza Maggiore, Bologna)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _searchAddress,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => _searchAddress(),
          ),
          const SizedBox(height: 20),
          if (_isLoading) const CircularProgressIndicator(),
          if (_selectedPosition != null && !_isLoading)
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Posizione trovata'),
              subtitle: Text(
                '${_selectedPosition!.latitude.toStringAsFixed(4)}, ${_selectedPosition!.longitude.toStringAsFixed(4)}',
              ),
            ),
        ],
      ),
    );
  }

  /// Form inferiore per definire nome e raggio della zona di notifica.
  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nome del Luogo',
              prefixIcon: Icon(Icons.favorite_border),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _radiusController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Raggio notifica (metri)',
              prefixIcon: Icon(Icons.radar),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Salva Luogo del Cuore'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _radiusController.dispose();
    super.dispose();
  }
}

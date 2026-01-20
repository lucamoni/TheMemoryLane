import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/moment.dart';
import '../models/trip.dart';

class PhotoHeatMapWidget extends StatefulWidget {
  final Trip trip;

  const PhotoHeatMapWidget({required this.trip, super.key});

  @override
  State<PhotoHeatMapWidget> createState() => _PhotoHeatMapWidgetState();
}

class _PhotoHeatMapWidgetState extends State<PhotoHeatMapWidget> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Circle> _heatCircles = {};

  @override
  void initState() {
    super.initState();
    _initializeMapData();
  }

  void _initializeMapData() {
    // Crea markers per le foto
    final photoMoments = widget.trip.moments
        .where((m) => m.type == MomentType.photo && m.latitude != null && m.longitude != null)
        .toList();

    // Calcola la densità di foto per ogni punto
    final densityMap = _calculatePhotoDensity(photoMoments);

    // Crea cerchi per la heatmap
    _heatCircles = densityMap.entries.map((entry) {
      final location = entry.key;
      final density = entry.value;

      // Colore basato sulla densità (da giallo a rosso)
      final color = _getHeatColor(density, densityMap.values.reduce((a, b) => a > b ? a : b));

      return Circle(
        circleId: CircleId('heat_${location.latitude}_${location.longitude}'),
        center: location,
        radius: 100 + (density * 50), // Raggio proporzionale alla densità
        fillColor: color.withOpacity(0.3),
        strokeColor: color,
        strokeWidth: 2,
      );
    }).toSet();

    // Crea markers per i momenti foto
    _markers = photoMoments.asMap().entries.map((entry) {
      final index = entry.key;
      final moment = entry.value;

      return Marker(
        markerId: MarkerId('photo_$index'),
        position: LatLng(moment.latitude!, moment.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(
          title: moment.title ?? 'Foto',
          snippet: moment.description ?? 'Momento fotografico',
        ),
      );
    }).toSet();

    // Crea polyline per il tracciato GPS
    if (widget.trip.gpsTrack.isNotEmpty) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('trip_track'),
          points: widget.trip.gpsTrack
              .map((coord) => LatLng(coord[0], coord[1]))
              .toList(),
          color: Colors.blue,
          width: 3,
        ),
      };
    }

    setState(() {});
  }

  Map<LatLng, int> _calculatePhotoDensity(List<Moment> photoMoments) {
    final Map<LatLng, int> densityMap = {};

    for (var moment in photoMoments) {
      if (moment.latitude == null || moment.longitude == null) continue;

      final location = LatLng(moment.latitude!, moment.longitude!);

      // Raggruppa foto vicine (entro ~100m)
      bool foundNearby = false;
      for (var key in densityMap.keys) {
        if (_isNearby(key, location, 0.001)) { // ~100m
          densityMap[key] = (densityMap[key] ?? 0) + 1;
          foundNearby = true;
          break;
        }
      }

      if (!foundNearby) {
        densityMap[location] = 1;
      }
    }

    return densityMap;
  }

  bool _isNearby(LatLng point1, LatLng point2, double threshold) {
    final latDiff = (point1.latitude - point2.latitude).abs();
    final lngDiff = (point1.longitude - point2.longitude).abs();
    return latDiff < threshold && lngDiff < threshold;
  }

  Color _getHeatColor(int density, int maxDensity) {
    if (maxDensity == 0) return Colors.yellow;

    final ratio = density / maxDensity;

    if (ratio < 0.3) {
      return Colors.yellow;
    } else if (ratio < 0.6) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  LatLng _getInitialPosition() {
    if (widget.trip.gpsTrack.isNotEmpty) {
      final firstPoint = widget.trip.gpsTrack.first;
      return LatLng(firstPoint[0], firstPoint[1]);
    }

    final photoMoments = widget.trip.moments
        .where((m) => m.type == MomentType.photo && m.latitude != null)
        .toList();

    if (photoMoments.isNotEmpty) {
      return LatLng(photoMoments.first.latitude!, photoMoments.first.longitude!);
    }

    // Default: Roma
    return const LatLng(41.9028, 12.4964);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Photo Heat Map',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Le aree più "calde" indicano dove hai scattato più foto',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              _buildLegend(),
            ],
          ),
        ),
        SizedBox(
          height: 400,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _getInitialPosition(),
              zoom: 13,
            ),
            markers: _markers,
            polylines: _polylines,
            circles: _heatCircles,
            onMapCreated: (controller) {
              _mapController = controller;
              _fitMapToBounds();
            },
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            mapType: MapType.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _buildLegendItem(Colors.yellow, 'Bassa densità'),
        const SizedBox(width: 16),
        _buildLegendItem(Colors.orange, 'Media densità'),
        const SizedBox(width: 16),
        _buildLegendItem(Colors.red, 'Alta densità'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            border: Border.all(color: color, width: 2),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  void _fitMapToBounds() {
    if (_mapController == null) return;

    final allPoints = <LatLng>[];

    // Aggiungi punti GPS
    for (var coord in widget.trip.gpsTrack) {
      allPoints.add(LatLng(coord[0], coord[1]));
    }

    // Aggiungi punti foto
    for (var moment in widget.trip.moments) {
      if (moment.latitude != null && moment.longitude != null) {
        allPoints.add(LatLng(moment.latitude!, moment.longitude!));
      }
    }

    if (allPoints.isEmpty) return;

    // Calcola bounds
    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (var point in allPoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

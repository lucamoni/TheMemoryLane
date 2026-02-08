import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import '../models/moment.dart';
import '../models/trip.dart';
import '../services/location_service.dart';

/// Widget che visualizza una mappa di calore (Heat Map) basata sui momenti del viaggio.
/// Mostra anche il percorso GPS e i marker per ogni singolo momento.
class PhotoHeatMapWidget extends StatefulWidget {
  final Trip trip;
  final Function(Moment)? onMomentSelected;
  const PhotoHeatMapWidget({
    required this.trip,
    this.onMomentSelected,
    super.key,
  });

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

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PhotoHeatMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Aggiorna solo se i dati sostanziali sono cambiati
    if (oldWidget.trip.gpsTrack.length != widget.trip.gpsTrack.length ||
        oldWidget.trip.moments.length != widget.trip.moments.length ||
        oldWidget.trip.isPaused != widget.trip.isPaused) {
      _initializeMapData();
    }
  }

  /// Inizializza i dati della mappa: Marker, Polyline (percorso) e Cerchi (Heat Map).
  void _initializeMapData() {
    final contentMoments = widget.trip.moments
        .where((m) => m.latitude != null && m.latitude != 0.0)
        .toList();

    // Calcoliamo la densità su tutti i momenti disponibili
    final densityMap = _calculateDensity(contentMoments);
    final maxDensity = densityMap.isEmpty
        ? 1
        : densityMap.values.reduce((a, b) => a > b ? a : b);

    // Crea i cerchi della mappa di calore basati sulla densità dei punti
    _heatCircles = densityMap.entries.map((entry) {
      final color = _getHeatColor(entry.value, maxDensity);
      return Circle(
        circleId: CircleId('heat_${entry.key.latitude}_${entry.key.longitude}'),
        center: entry.key,
        radius: 300 + (entry.value * 60.0),
        fillColor: color.withValues(alpha: 0.4),
        strokeWidth: 0,
      );
    }).toSet();

    // Crea i marker per ogni singolo momento (Foto, Video, Audio, Nota)
    _markers = contentMoments.asMap().entries.map((entry) {
      final moment = entry.value;
      double hue;
      String typeLabel;

      switch (moment.type) {
        case MomentType.photo:
          hue = BitmapDescriptor.hueAzure;
          typeLabel = 'Foto';
          break;
        case MomentType.video:
          hue = BitmapDescriptor.hueRed;
          typeLabel = 'Video';
          break;
        case MomentType.audio:
          hue = BitmapDescriptor.hueCyan;
          typeLabel = 'Audio';
          break;
        case MomentType.note:
          hue = BitmapDescriptor.hueOrange;
          typeLabel = 'Nota';
          break;
        default:
          hue = BitmapDescriptor.hueViolet;
          typeLabel = 'Momento';
      }

      return Marker(
        markerId: MarkerId('moment_${moment.id ?? entry.key}'),
        position: LatLng(moment.latitude!, moment.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        onTap: () {
          if (widget.onMomentSelected != null) {
            widget.onMomentSelected!(moment);
          }
        },
        infoWindow: InfoWindow(
          title: typeLabel,
          snippet:
              moment.title ??
              (moment.type == MomentType.note ? moment.content : ''),
          onTap: () {
            if (widget.onMomentSelected != null) {
              widget.onMomentSelected!(moment);
            }
          },
        ),
      );
    }).toSet();

    // Crea la linea continua del percorso GPS (se presente)
    if (widget.trip.gpsTrack.isNotEmpty) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('trip_track'),
          points: widget.trip.gpsTrack.map((c) => LatLng(c[0], c[1])).toList(),
          color: const Color(0xFF16697A),
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
    }
  }

  /// Raggruppa i momenti vicini geograficamente per calcolare l'indice di densità.
  Map<LatLng, int> _calculateDensity(List<Moment> moments) {
    final density = <LatLng, int>{};
    for (var m in moments) {
      final loc = LatLng(m.latitude!, m.longitude!);
      bool found = false;
      for (var k in density.keys) {
        // Soglia di raggruppamento (circa 500-600 metri) per cluster visibili a zoom medio
        if ((k.latitude - loc.latitude).abs() < 0.005 &&
            (k.longitude - loc.longitude).abs() < 0.005) {
          density[k] = (density[k] ?? 0) + 1;
          found = true;
          break;
        }
      }
      if (!found) density[loc] = 1;
    }
    return density;
  }

  /// Ritorna un colore in base alla densità relativa (Giallo -> Arancio -> Rosso).
  Color _getHeatColor(int d, int max) {
    final r = d / max;
    if (r < 0.3) return const Color(0xFFFCD34D); // Giallo
    if (r < 0.7) return const Color(0xFFF59E0B); // Arancio
    return const Color(0xFFEF4444); // Rosso
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopOverlay(),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _getInitialPos(),
                  zoom: 12,
                ),
                markers: _markers,
                polylines: _polylines,
                circles: _heatCircles,
                onMapCreated: (c) {
                  _mapController = c;
                  _fit();
                },
                myLocationEnabled: true,
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                tiltGesturesEnabled: true,
                rotateGesturesEnabled: true,
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
                gestureRecognizers: {
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Crea l'overlay superiore con titoli e legenda dei colori.
  Widget _buildTopOverlay() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, color: Color(0xFF16697A)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Punti di Interesse',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  const Text(
                    'Aree con maggiore intensità di ricordi',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _legend(const Color(0xFFEF4444), 'Alta'),
              const SizedBox(width: 12),
              _legend(const Color(0xFFF59E0B), 'Media'),
              const SizedBox(width: 12),
              _legend(const Color(0xFFFCD34D), 'Bassa'),
              const Spacer(),
              TextButton.icon(
                onPressed: _fit,
                icon: const Icon(Icons.center_focus_strong, size: 16),
                label: const Text('Ricentra', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Elemento singolo della legenda colori.
  Widget _legend(Color c, String l) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          l,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  /// Calcola la posizione iniziale della telecamera (partenza del viaggio o coordinata di default).
  LatLng _getInitialPos() {
    if (widget.trip.gpsTrack.isNotEmpty) {
      return LatLng(
        widget.trip.gpsTrack.first[0],
        widget.trip.gpsTrack.first[1],
      );
    }
    // Se non ci sono punti ancora, proviamo a usare la posizione dei momenti
    final momentsWithLocation = widget.trip.moments.where(
      (m) => m.latitude != 0.0,
    );
    if (momentsWithLocation.isNotEmpty) {
      final first = momentsWithLocation.first;
      return LatLng(first.latitude!, first.longitude!);
    }

    // Se il viaggio è attivo, proviamo a usare l'ultima posizione nota dal service
    if (widget.trip.isActive) {
      final lastLoc = LocationService.instance.getTrack();
      if (lastLoc.isNotEmpty) {
        return LatLng(lastLoc.last[0], lastLoc.last[1]);
      }
    }

    return const LatLng(41.9028, 12.4964); // Coordinate di Roma come fallback
  }

  /// Adatta la visuale della mappa per mostrare tutto il viaggio e i momenti.
  void _fit() {
    if (_mapController == null) return;
    final points = <LatLng>[];
    for (var c in widget.trip.gpsTrack) {
      points.add(LatLng(c[0], c[1]));
    }
    for (var m in widget.trip.moments) {
      if (m.latitude != null && m.latitude != 0.0) {
        points.add(LatLng(m.latitude!, m.longitude!));
      }
    }
    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 15),
      );
      return;
    }

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50,
      ),
    );
  }
}

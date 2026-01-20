import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/trip.dart';
import '../models/no_travel_period.dart';
import '../services/database_service.dart';
import '../widgets/add_trip_dialog.dart';
import 'trip_detail_page.dart';
import 'geofences_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('The Memory Lane Journalist'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            tooltip: 'Luoghi del Cuore',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GeofencesPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Trip>('trips').listenable(),
        builder: (context, Box<Trip> box, _) {
          final trips = box.values.toList();

          if (trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nessun viaggio registrato',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _showAddTripDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Inizia un Nuovo Viaggio'),
                  ),
                ],
              ),
            );
          }

          // Ordina i viaggi per data
          final sortedTrips = List<Trip>.from(trips)
            ..sort((a, b) => (a.startDate ?? DateTime.now())
                .compareTo(b.startDate ?? DateTime.now()));

          // Calcola i periodi di inattività
          final noTravelPeriods = _calculateNoTravelPeriods(sortedTrips);

          // Combina viaggi e periodi inattivi
          final timelineItems = _buildTimelineItems(sortedTrips, noTravelPeriods);

          return ListView.builder(
            itemCount: timelineItems.length,
            itemBuilder: (context, index) {
              final item = timelineItems[index];

              if (item is NoTravelPeriod) {
                return _buildNoTravelPeriodCard(item);
              } else if (item is Trip) {
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: _getTripTypeIcon(item.tripType),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(item.title ?? 'Senza titolo'),
                        ),
                        _getTripTypeBadge(item.tripType),
                      ],
                    ),
                    subtitle: Text(
                      'Inizio: ${item.startDate.toString().split('.')[0]}',
                    ),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TripDetailPage(trip: item),
                        ),
                      );
                    },
                    onLongPress: () {
                      if (item.id != null) {
                        _showDeleteConfirmation(context, item.id!, dbService);
                      }
                    },
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTripDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTripDialog() {
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AddTripDialog(
        onTripAdded: (trip) {
          dbService.saveTrip(trip);
        },
      ),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, String tripId, DatabaseService dbService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Viaggio'),
        content: const Text('Sei sicuro di voler eliminare questo viaggio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              dbService.deleteTrip(tripId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  List<NoTravelPeriod> _calculateNoTravelPeriods(List<Trip> sortedTrips) {
    final List<NoTravelPeriod> periods = [];

    for (int i = 0; i < sortedTrips.length - 1; i++) {
      final currentTrip = sortedTrips[i];
      final nextTrip = sortedTrips[i + 1];

      final currentEnd = currentTrip.endDate ?? currentTrip.startDate ?? DateTime.now();
      final nextStart = nextTrip.startDate ?? DateTime.now();

      // Se c'è un gap di almeno 2 giorni tra i viaggi
      final daysDifference = nextStart.difference(currentEnd).inDays;
      if (daysDifference >= 2) {
        periods.add(NoTravelPeriod(
          id: 'no_travel_${currentTrip.id}_${nextTrip.id}',
          startDate: currentEnd,
          endDate: nextStart,
          label: daysDifference > 30
              ? 'Lungo periodo di pausa'
              : 'Momenti di riflessione',
        ));
      }
    }

    return periods;
  }

  List<dynamic> _buildTimelineItems(List<Trip> trips, List<NoTravelPeriod> periods) {
    final List<dynamic> items = [];

    for (int i = 0; i < trips.length; i++) {
      items.add(trips[i]);

      // Aggiungi periodo inattivo se esiste
      final matchingPeriod = periods.where((p) =>
        p.id.contains(trips[i].id ?? '')
      ).firstOrNull;

      if (matchingPeriod != null) {
        items.add(matchingPeriod);
      }
    }

    return items;
  }

  Widget _buildNoTravelPeriodCard(NoTravelPeriod period) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[400]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.pause_circle_outline, color: Colors.grey[600], size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${period.durationInDays} giorni senza viaggi',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${_formatDate(period.startDate)} - ${_formatDate(period.endDate)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _getTripTypeIcon(TripType tripType) {
    IconData iconData;
    Color color;

    switch (tripType) {
      case TripType.localTrip:
        iconData = Icons.directions_walk;
        color = Colors.green;
        break;
      case TripType.dayTrip:
        iconData = Icons.wb_sunny;
        color = Colors.orange;
        break;
      case TripType.multiDayTrip:
        iconData = Icons.luggage;
        color = Colors.blue;
        break;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.2),
      child: Icon(iconData, color: color, size: 20),
    );
  }

  Widget _getTripTypeBadge(TripType tripType) {
    String label;
    Color color;

    switch (tripType) {
      case TripType.localTrip:
        label = 'Local';
        color = Colors.green;
        break;
      case TripType.dayTrip:
        label = 'Day';
        color = Colors.orange;
        break;
      case TripType.multiDayTrip:
        label = 'Multi-Day';
        color = Colors.blue;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}


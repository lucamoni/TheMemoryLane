import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/trip.dart';
import '../models/moment.dart';
import '../models/no_travel_period.dart';
import '../services/database_service.dart';
import '../widgets/add_trip_dialog.dart';
import 'trip_detail_page.dart';
import 'geofences_page.dart';
import 'package:intl/intl.dart';

import '../models/trip_folder.dart';
import '../services/location_service.dart';
import 'package:uuid/uuid.dart';

/// Pagina principale dell'applicazione che mostra la lista dei viaggi e delle cartelle.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _selectedFolderId;
  TripType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(context),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Trip>('trips').listenable(),
        builder: (context, Box<Trip> tripBox, _) {
          return ValueListenableBuilder(
            valueListenable: Hive.box<TripFolder>('folders').listenable(),
            builder: (context, Box<TripFolder> folderBox, _) {
              final allTrips = tripBox.values.toList();
              final folders = folderBox.values.toList();

              // Stato vuoto se non ci sono viaggi né cartelle
              if (allTrips.isEmpty && folders.isEmpty) {
                return _buildEmptyState();
              }

              // Filtra i viaggi in base alla cartella selezionata
              // Filtra i viaggi in base alla cartella e al tipo selezionato
              final filteredTrips = allTrips.where((t) {
                final folderMatch =
                    _selectedFolderId == null ||
                    t.folderId == _selectedFolderId;
                final typeMatch =
                    _selectedType == null || t.tripType == _selectedType;
                return folderMatch && typeMatch;
              }).toList();

              // Ordina per data decrescente (i più recenti in alto)
              filteredTrips.sort(
                (a, b) => (b.startDate ?? DateTime.now()).compareTo(
                  a.startDate ?? DateTime.now(),
                ),
              );

              final activeTrip = filteredTrips
                  .where((t) => t.isActive)
                  .firstOrNull;
              final noTravelPeriods = _calculateNoTravelPeriods(filteredTrips);
              final timelineItems = _buildTimelineItems(
                filteredTrips,
                noTravelPeriods,
              );

              return CustomScrollView(
                cacheExtent: 1000, // Migliora la fluidità dello scrolling
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildFilterBar(folders, dbService),
                  ),
                  if (activeTrip != null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: _buildActiveTripCard(activeTrip),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        _selectedFolderId == null
                            ? 'Esplorazioni Recenti'
                            : 'In questa cartella',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = timelineItems[index];
                      if (item is NoTravelPeriod) {
                        return _buildNoTravelPeriodTile(item);
                      }
                      if (item is Trip) {
                        if (item.isActive &&
                            index == 0 &&
                            _selectedFolderId == null) {
                          return const SizedBox.shrink();
                        }
                        return _buildTripCard(
                          context,
                          item,
                          dbService,
                          folders,
                        );
                      }
                      return const SizedBox.shrink();
                    }, childCount: timelineItems.length),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTripDialog,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Nuovo Viaggio'),
        elevation: 4,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildFilterBar(List<TripFolder> folders, DatabaseService dbService) {
    return Column(
      children: [_buildFolderBar(folders, dbService), _buildTypeFilterBar()],
    );
  }

  Widget _buildFolderBar(List<TripFolder> folders, DatabaseService dbService) {
    return Container(
      height: 60,
      margin: const EdgeInsets.only(top: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: folders.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildFolderChip(null, 'Tutti', Icons.all_inclusive_rounded);
          }
          if (index == folders.length + 1) {
            return GestureDetector(
              onTap: () => _showAddFolderDialog(dbService),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.grey),
              ),
            );
          }
          final folder = folders[index - 1];
          return _buildFolderChip(
            folder.id,
            folder.name,
            Icons.folder_rounded,
            color: Color(folder.color),
          );
        },
      ),
    );
  }

  Widget _buildTypeFilterBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildTypeChip(null, 'Ogni Tipo', Icons.filter_list_rounded),
          const SizedBox(width: 8),
          _buildTypeChip(
            TripType.localTrip,
            'Passeggiate',
            Icons.directions_walk_rounded,
          ),
          const SizedBox(width: 8),
          _buildTypeChip(TripType.dayTrip, 'Gite', Icons.explore_rounded),
          const SizedBox(width: 8),
          _buildTypeChip(
            TripType.multiDayTrip,
            'Vacanze',
            Icons.flight_takeoff_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(TripType? type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : Colors.grey,
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedType = selected ? type : null;
        });
      },
      selectedColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.grey.shade200,
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildFolderChip(
    String? id,
    String label,
    IconData icon, {
    Color? color,
  }) {
    final isSelected = _selectedFolderId == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedFolderId = id),
      onLongPress: id != null ? () => _showFolderOptions(id) : null,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? Theme.of(context).primaryColor)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFolderDialog(DatabaseService dbService) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuova Cartella'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Nome della cartella',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                dbService.saveFolder(
                  TripFolder(id: const Uuid().v4(), name: controller.text),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Crea'),
          ),
        ],
      ),
    );
  }

  void _showFolderOptions(String folderId) {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text('Elimina Cartella'),
              onTap: () {
                dbService.deleteFolder(folderId);
                if (_selectedFolderId == folderId) {
                  setState(() => _selectedFolderId = null);
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/logo/logo_192.png', height: 32, width: 32),
          const SizedBox(width: 10),
          const Text('The Memory Lane'),
        ],
      ),
      centerTitle: false,
      backgroundColor: Colors.transparent,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.favorite_rounded, color: Color(0xFFFFA62B)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GeofencesPage()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16697A).withValues(alpha: 0.05),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Inizia la tua avventura',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Registra i tuoi viaggi e cattura i momenti migliori della tua giornata.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.4, fontSize: 13),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _showAddTripDialog,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Crea Primo Viaggio'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTripCard(Trip trip) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        image:
            (trip.coverPath != null ||
                trip.moments.any((m) => m.type == MomentType.photo))
            ? DecorationImage(
                image: FileImage(
                  File(
                    trip.coverPath ??
                        trip.moments
                            .firstWhere((m) => m.type == MomentType.photo)
                            .content!,
                  ),
                ),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.6),
                  BlendMode.darken,
                ),
              )
            : null,
        gradient:
            (trip.coverPath == null &&
                !trip.moments.any((m) => m.type == MomentType.photo))
            ? LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  const Color(0xFF1B262C),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: trip.isPaused
                      ? Colors.orange.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: trip.isPaused
                      ? Border.all(color: Colors.orange.shade300)
                      : null,
                ),
                child: Row(
                  children: [
                    if (!trip.isPaused)
                      const SizedBox(
                        width: 8,
                        height: 8,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                          value: null,
                        ),
                      )
                    else
                      const Icon(
                        Icons.pause_circle_filled_rounded,
                        color: Colors.orange,
                        size: 14,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      trip.isPaused ? 'TRACKING IN PAUSA' : 'TRACKING ATTIVO',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _getTripTypeIcon(trip.tripType, invert: true),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            trip.title ?? 'Senza Titolo',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Iniziato ${DateFormat('dd MMM, HH:mm').format(trip.startDate ?? DateTime.now())}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCompactStat(
                Icons.route,
                '${trip.totalDistance.toStringAsFixed(1)} km',
              ),
              _buildCompactStat(
                Icons.camera_alt,
                '${trip.moments.length} momenti',
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TripDetailPage(trip: trip)),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Gestisci'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(
    BuildContext context,
    Trip trip,
    DatabaseService dbService,
    List<TripFolder> folders,
  ) {
    final folder = trip.folderId != null
        ? folders.where((f) => f.id == trip.folderId).firstOrNull
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading:
            (trip.coverPath != null ||
                trip.moments.any((m) => m.type == MomentType.photo))
            ? Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: FileImage(
                      File(
                        trip.coverPath ??
                            trip.moments
                                .firstWhere((m) => m.type == MomentType.photo)
                                .content!,
                      ),
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            : _getTripTypeIcon(trip.tripType),
        title: Row(
          children: [
            Expanded(
              child: Text(
                trip.title ?? 'Viaggio',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (folder != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(folder.color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  folder.name,
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(folder.color),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              DateFormat(
                'dd MMMM yyyy',
              ).format(trip.startDate ?? DateTime.now()),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.route_outlined,
                  size: 12,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  '${trip.totalDistance.toStringAsFixed(1)} km',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.photo_library_outlined,
                  size: 12,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  '${trip.moments.length}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
          onSelected: (val) {
            if (val == 'delete') {
              _showDeleteConfirmation(context, trip.id!, dbService);
            } else {
              dbService.saveTrip(
                trip.copyWith(folderId: val == 'none' ? null : val),
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'none', child: Text('Nessuna cartella')),
            ...folders.map(
              (f) => PopupMenuItem(
                value: f.id,
                child: Text('Sposta in ${f.name}'),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Elimina', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TripDetailPage(trip: trip)),
        ),
      ),
    );
  }

  Widget _buildNoTravelPeriodTile(NoTravelPeriod period) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 12,
            child: VerticalDivider(thickness: 1, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${period.durationInDays} giorni di pausa - ${period.label}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getTripTypeIcon(TripType type, {bool invert = false}) {
    IconData icon;
    Color color;
    switch (type) {
      case TripType.localTrip:
        icon = Icons.directions_walk;
        color = const Color(0xFF10B981);
        break;
      case TripType.dayTrip:
        icon = Icons.wb_sunny;
        color = const Color(0xFFF59E0B);
        break;
      case TripType.multiDayTrip:
        icon = Icons.luggage;
        color = const Color(0xFF3B82F6);
        break;
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: invert
            ? Colors.white.withValues(alpha: 0.2)
            : color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: invert ? Colors.white : color, size: 24),
    );
  }

  void _showAddTripDialog() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final locService = Provider.of<LocationService>(context, listen: false);

    showDialog(
      context: context,
      builder: (_) => AddTripDialog(
        onTripAdded: (t) async {
          final tripToSave = t.copyWith(folderId: _selectedFolderId);
          await dbService.saveTrip(tripToSave);

          // Fai partire il tracking immediatamente
          locService.clearTrack();
          await locService.startTracking();

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TripDetailPage(trip: tripToSave),
              ),
            );
          }
        },
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    String tripId,
    DatabaseService dbService,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina'),
        content: const Text('Vuoi davvero cancellare questo viaggio?'),
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
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  List<NoTravelPeriod> _calculateNoTravelPeriods(List<Trip> sortedTrips) {
    final periods = <NoTravelPeriod>[];
    for (var i = 0; i < sortedTrips.length - 1; i++) {
      final end =
          sortedTrips[i + 1].endDate ??
          sortedTrips[i + 1].startDate ??
          DateTime.now();
      final start = sortedTrips[i].startDate ?? DateTime.now();
      final diff = start.difference(end).inDays;
      if (diff >= 2) {
        periods.add(
          NoTravelPeriod(
            id: 'gap_$i',
            startDate: end,
            endDate: start,
            label: diff > 7 ? 'Momento di riflessione' : 'Pausa',
          ),
        );
      }
    }
    return periods;
  }

  List<dynamic> _buildTimelineItems(
    List<Trip> trips,
    List<NoTravelPeriod> periods,
  ) {
    final items = <dynamic>[];
    int tripIdx = 0;
    int periodIdx = 0;

    while (tripIdx < trips.length || periodIdx < periods.length) {
      if (tripIdx < trips.length && periodIdx < periods.length) {
        final tripDate = trips[tripIdx].startDate ?? DateTime.now();
        final periodDate = periods[periodIdx].endDate;

        if (tripDate.isAfter(periodDate)) {
          items.add(trips[tripIdx]);
          tripIdx++;
        } else {
          items.add(periods[periodIdx]);
          periodIdx++;
        }
      } else if (tripIdx < trips.length) {
        items.add(trips[tripIdx]);
        tripIdx++;
      } else {
        items.add(periods[periodIdx]);
        periodIdx++;
      }
    }
    return items;
  }
}

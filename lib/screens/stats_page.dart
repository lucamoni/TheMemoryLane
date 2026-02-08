import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/trip.dart';
import '../widgets/stats_overview_widget.dart';

/// Pagina dedicata alle statistiche globali dei viaggi.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Statistiche Globali',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1B262C),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Trip>('trips').listenable(),
        builder: (context, Box<Trip> tripBox, _) {
          final allTrips = tripBox.values.toList();

          if (allTrips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nessun dato disponibile',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 20),
                StatsOverviewWidget(trips: allTrips),
                const SizedBox(height: 20),
                _buildStatsSummary(allTrips),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsSummary(List<Trip> trips) {
    final totalKm = trips.fold(0.0, (sum, trip) => sum + trip.totalDistance);
    final totalTrips = trips.length;
    final avgKm = totalTrips > 0 ? totalKm / totalTrips : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildSummaryCard(
            'Chilometri Totali',
            '${totalKm.toStringAsFixed(1)} KM',
            Icons.speed_rounded,
            const Color(0xFF16697A),
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            'Viaggi Registrati',
            '$totalTrips',
            Icons.map_rounded,
            Colors.orange.shade700,
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            'Media per Viaggio',
            '${avgKm.toStringAsFixed(1)} KM',
            Icons.auto_graph_rounded,
            Colors.blue.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B262C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';

/// Widget che mostra un grafico a barre delle statistiche aggregate (KM per mese).
class StatsOverviewWidget extends StatelessWidget {
  final List<Trip> trips;

  const StatsOverviewWidget({super.key, required this.trips});

  @override
  Widget build(BuildContext context) {
    final monthlyStats = _calculateMonthlyStats();

    if (monthlyStats.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Chilometri per Mese',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B262C),
                ),
              ),
              Icon(
                Icons.bar_chart_rounded,
                color: Colors.blue.shade700,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 1.7,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _calculateMaxY(monthlyStats),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF16697A),
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toStringAsFixed(1)} KM',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < monthlyStats.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              monthlyStats[index].month,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(monthlyStats.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: monthlyStats[i].distance,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF16697A),
                            const Color(0xFF16697A).withValues(alpha: 0.7),
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: _calculateMaxY(monthlyStats),
                          color: Colors.grey.shade100,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_MonthlyData> _calculateMonthlyStats() {
    final Map<String, double> stats = {};
    final now = DateTime.now();

    // Inizializza gli ultimi 6 mesi con 0
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthName = DateFormat('MMM', 'it_IT').format(date).toUpperCase();
      stats[monthName] = 0.0;
    }

    // Calcola la data di inizio del periodo (primo giorno di 5 mesi fa)
    final startOfPeriod = DateTime(now.year, now.month - 5, 1);

    // Aggrega i KM dei viaggi
    for (final trip in trips) {
      if (trip.startDate == null) continue;

      // Ignora viaggi fuori dal periodo di analisi (ultimi 6 mesi)
      if (trip.startDate!.isBefore(startOfPeriod)) continue;

      final monthName = DateFormat(
        'MMM',
        'it_IT',
      ).format(trip.startDate!).toUpperCase();

      if (stats.containsKey(monthName)) {
        stats[monthName] = (stats[monthName] ?? 0.0) + trip.totalDistance;
      }
    }

    // Converte in lista ordinata cronologicamente
    final sortedMonths = stats.keys.toList();
    return sortedMonths.map((m) => _MonthlyData(m, stats[m]!)).toList();
  }

  double _calculateMaxY(List<_MonthlyData> data) {
    double max = 0;
    for (final d in data) {
      if (d.distance > max) max = d.distance;
    }
    return max == 0 ? 10 : max * 1.2;
  }
}

class _MonthlyData {
  final String month;
  final double distance;

  _MonthlyData(this.month, this.distance);
}

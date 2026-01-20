import 'dart:io';
import 'package:flutter/material.dart';
import '../models/moment.dart';

class TimelineWidget extends StatelessWidget {
  final List<Moment> moments;
  final double totalDistance;
  final DateTime? startDate;
  final DateTime? endDate;

  const TimelineWidget({
    required this.moments,
    required this.totalDistance,
    required this.startDate,
    required this.endDate,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (moments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                const Text('Nessun momento registrato'),
              ],
            ),
          ),
        ),
      );
    }

    // Ordina i momenti per timestamp
    final sortedMoments = List<Moment>.from(moments)
      ..sort((a, b) => (a.timestamp ?? DateTime.now())
          .compareTo(b.timestamp ?? DateTime.now()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sezione statistiche
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Statistiche del Viaggio',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatisticItem(
                        icon: Icons.directions_run,
                        value: '${totalDistance.toStringAsFixed(2)} km',
                        label: 'Distanza',
                      ),
                      _StatisticItem(
                        icon: Icons.image,
                        value: '${moments.length}',
                        label: 'Momenti',
                      ),
                      if (startDate != null && endDate != null)
                        _StatisticItem(
                          icon: Icons.calendar_today,
                          value: _getDaysDifference(),
                          label: 'Giorni',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Timeline dei momenti con milestone di distanza
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Timeline Narrativa',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _getTimelineItemCount(sortedMoments),
          itemBuilder: (context, index) {
            // Alterna tra milestone di distanza e momenti
            if (_isDistanceMilestone(index, sortedMoments)) {
              return _buildDistanceMilestone(index, sortedMoments);
            }

            final momentIndex = _getMomentIndex(index, sortedMoments);
            final moment = sortedMoments[momentIndex];
            final isLastItem = momentIndex == sortedMoments.length - 1;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline line
                  SizedBox(
                    width: 30,
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getMomentColor(moment.type),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                        if (!isLastItem)
                          Container(
                            width: 2,
                            height: 100,
                            color: Colors.grey[300],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Moment card
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getMomentIcon(moment.type),
                                      size: 20,
                                      color: _getMomentColor(moment.type),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        moment.title ?? 'Momento',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Anteprima foto se è un momento foto
                                if (moment.type == MomentType.photo && moment.content != null)
                                  _buildPhotoPreview(moment.content!),
                                if (moment.content != null && moment.type != MomentType.photo)
                                  Text(
                                    moment.content!,
                                    style: const TextStyle(fontSize: 13),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatTime(moment.timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (moment.latitude != null &&
                                    moment.longitude != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Lat: ${moment.latitude!.toStringAsFixed(4)}, '
                                      'Lng: ${moment.longitude!.toStringAsFixed(4)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'Data sconosciuta';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getDaysDifference() {
    if (startDate == null || endDate == null) return '0';
    final difference = endDate!.difference(startDate!).inDays + 1;
    return difference.toString();
  }

  Color _getMomentColor(MomentType? type) {
    switch (type) {
      case MomentType.note:
        return Colors.blue;
      case MomentType.photo:
        return Colors.orange;
      case MomentType.audio:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getMomentIcon(MomentType? type) {
    switch (type) {
      case MomentType.note:
        return Icons.note;
      case MomentType.photo:
        return Icons.photo;
      case MomentType.audio:
        return Icons.mic;
      default:
        return Icons.help;
    }
  }

  int _getTimelineItemCount(List<Moment> moments) {
    // Ogni 3 momenti, aggiungi una milestone di distanza
    if (moments.isEmpty) return 0;
    final milestones = (moments.length / 3).floor();
    return moments.length + milestones;
  }

  bool _isDistanceMilestone(int index, List<Moment> moments) {
    // Ogni 4° elemento è una milestone (dopo ogni 3 momenti)
    return (index + 1) % 4 == 0;
  }

  int _getMomentIndex(int timelineIndex, List<Moment> moments) {
    // Calcola l'indice del momento considerando le milestone
    final milestonesBeforeThis = (timelineIndex / 4).floor();
    return timelineIndex - milestonesBeforeThis;
  }

  Widget _buildDistanceMilestone(int index, List<Moment> moments) {
    // Calcola la distanza parziale fino a questo punto
    final momentIndex = _getMomentIndex(index, moments);
    final progress = momentIndex / moments.length;
    final partialDistance = totalDistance * progress;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 30,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.flag,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_run, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${partialDistance.toStringAsFixed(2)} km percorsi',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview(String photoPath) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(photoPath),
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 150,
                width: double.infinity,
                color: Colors.grey[300],
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Immagine non disponibile',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _StatisticItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatisticItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}


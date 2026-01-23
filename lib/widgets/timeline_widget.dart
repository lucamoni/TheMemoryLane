import 'dart:io';
import 'package:flutter/material.dart';
import '../models/moment.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/location_service.dart';

class TimelineWidget extends StatelessWidget {
  final List<Moment> moments;
  final double totalDistance;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(Moment)? onEdit;
  final Function(Moment)? onDelete;
  final ScrollController? controller;

  const TimelineWidget({
    required this.moments,
    required this.totalDistance,
    required this.startDate,
    required this.endDate,
    this.onEdit,
    this.onDelete,
    this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (moments.isEmpty) {
      return _buildEmptyState();
    }

    final sortedMoments = List<Moment>.from(moments)
      ..sort(
        (a, b) => (a.timestamp ?? DateTime.now()).compareTo(
          b.timestamp ?? DateTime.now(),
        ),
      );

    return ListView.builder(
      controller: controller,
      cacheExtent: 1500, // Pre-carica gli elementi per uno scrolling fluido
      physics: const BouncingScrollPhysics(),
      itemCount:
          _getTimelineItemCount(sortedMoments) + 2, // +2 per header e titolo
      itemBuilder: (context, index) {
        if (index == 0) return RepaintBoundary(child: _buildHeader(context));
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Text(
              'Timeline Narrativa',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          );
        }

        final actualIndex = index - 2;
        if (_isDistanceMilestone(actualIndex, sortedMoments)) {
          return RepaintBoundary(
            child: _buildDistanceMilestone(context, actualIndex, sortedMoments),
          );
        }

        final momentIndex = _getMomentIndex(actualIndex, sortedMoments);
        final moment = sortedMoments[momentIndex];
        final isLast = actualIndex == _getTimelineItemCount(sortedMoments) - 1;

        double? distanceSinceLast;
        if (momentIndex > 0) {
          final prev = sortedMoments[momentIndex - 1];
          if (moment.latitude != null &&
              moment.longitude != null &&
              prev.latitude != null &&
              prev.longitude != null &&
              moment.latitude != 0.0 &&
              prev.latitude != 0.0) {
            distanceSinceLast = LocationService.instance.calculateDistance(
              prev.latitude!,
              prev.longitude!,
              moment.latitude!,
              moment.longitude!,
            );
          }
        }

        return RepaintBoundary(
          child: _buildTimelineItem(context, moment, isLast, distanceSinceLast),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 64,
              color: Colors.indigo.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'La tua storia inizia qui...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Aggiungi note o foto per popolare la timeline.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, const Color(0xFF1B262C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatChip(
                context,
                Icons.route,
                '${totalDistance.toStringAsFixed(1)} KM',
                'Percorsi',
              ),
              _buildStatChip(
                context,
                Icons.auto_awesome,
                '${moments.length}',
                'Ricordi',
              ),
              _buildStatChip(
                context,
                Icons.timer_outlined,
                _getDuration(),
                'Tempo',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    Moment moment,
    bool isLast,
    double? distanceFromPrev,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimelinePath(context, moment, isLast, distanceFromPrev),
          const SizedBox(width: 16),
          Expanded(child: _buildMomentCard(context, moment)),
        ],
      ),
    );
  }

  Widget _buildTimelinePath(
    BuildContext context,
    Moment moment,
    bool isLast,
    double? distanceFromPrev,
  ) {
    return SizedBox(
      width: 40,
      child: Column(
        children: [
          if (distanceFromPrev != null && distanceFromPrev > 0.1)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              child: Text(
                '+${distanceFromPrev.toStringAsFixed(1)}km',
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _getMomentColor(moment.type), width: 2),
            ),
            child: Icon(
              _getMomentIcon(moment.type),
              size: 16,
              color: _getMomentColor(moment.type),
            ),
          ),
          if (!isLast)
            Container(
              width: 2,
              height: moment.type == MomentType.photo ? 180 : 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_getMomentColor(moment.type), Colors.grey.shade200],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMomentCard(BuildContext context, Moment moment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (moment.type == MomentType.photo && moment.content != null)
              _buildPhotoContent(moment.content!),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatTime(moment.timestamp),
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      if (moment.latitude != null)
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey,
                        ),
                      if (onEdit != null || onDelete != null)
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            size: 20,
                            color: Colors.grey,
                          ),
                          padding: EdgeInsets.zero,
                          onSelected: (value) {
                            if (value == 'edit' && onEdit != null)
                              onEdit!(moment);
                            if (value == 'delete' && onDelete != null)
                              onDelete!(moment);
                          },
                          itemBuilder: (context) => [
                            if (onEdit != null)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('Modifica'),
                                  ],
                                ),
                              ),
                            if (onDelete != null)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Elimina',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    moment.title!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (moment.type == MomentType.video)
                    _buildVideoPreview(context, moment.content!)
                  else if (moment.type == MomentType.audio)
                    _buildAudioPlayer(moment.content!)
                  else if (moment.content != null &&
                      moment.type != MomentType.photo)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _truncateContent(moment.content!),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoContent(String path) {
    return Image.file(
      File(path),
      height: 200,
      width: double.infinity,
      fit: BoxFit.cover,
      cacheWidth:
          300, // IMPORTANTE: Forza il caricamento di una miniatura per risparmiare RAM
      errorBuilder: (_, __, ___) => Container(
        height: 120,
        color: Colors.grey.shade100,
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      ),
    );
  }

  Widget _buildDistanceMilestone(
    BuildContext context,
    int index,
    List<Moment> moments,
  ) {
    final momentIndex = _getMomentIndex(index, moments);
    final progress = momentIndex / moments.length;
    final partialDistance = totalDistance * progress;

    return Padding(
      padding: const EdgeInsets.only(left: 30, right: 20, bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.flag_rounded,
                  size: 14,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                Text(
                  '${partialDistance.toStringAsFixed(1)} KM PERCORSI',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Divider(indent: 8, color: Colors.blueGrey, thickness: 0.5),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--:--';
    return DateFormat('HH:mm - dd MMM').format(dateTime);
  }

  String _getDuration() {
    if (startDate == null || endDate == null) return '0h';
    final diff = endDate!.difference(startDate!);
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }

  String _truncateContent(String content) {
    if (content.length <= 50) return content;
    return '${content.substring(0, 50)}...';
  }

  Color _getMomentColor(MomentType? type) {
    switch (type) {
      case MomentType.note:
        return const Color(0xFF16697A); // Deep Teal
      case MomentType.photo:
        return const Color(0xFFFFA62B); // Gold
      case MomentType.audio:
        return const Color(0xFF82C0CC); // Light Blue
      case MomentType.video:
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  IconData _getMomentIcon(MomentType? type) {
    switch (type) {
      case MomentType.note:
        return Icons.edit_note;
      case MomentType.photo:
        return Icons.camera_alt;
      case MomentType.audio:
        return Icons.audiotrack_rounded;
      case MomentType.video:
        return Icons.videocam_rounded;
      default:
        return Icons.more_horiz;
    }
  }

  Widget _buildVideoPreview(BuildContext context, String path) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => _VideoPlayerDialog(videoPath: path),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        height: 160,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                'Tocca per guardare il video',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPlayer(String path) {
    return _AudioPlayerWidget(path: path);
  }

  int _getTimelineItemCount(List<Moment> moments) {
    if (moments.isEmpty) return 0;
    final milestones = (moments.length / 3).floor();
    return moments.length + milestones;
  }

  bool _isDistanceMilestone(int index, List<Moment> moments) {
    return (index + 1) % 4 == 0;
  }

  int _getMomentIndex(int timelineIndex, List<Moment> moments) {
    final milestonesBefore = (timelineIndex / 4).floor();
    return timelineIndex - milestonesBefore;
  }
}

class _AudioPlayerWidget extends StatefulWidget {
  final String path;
  const _AudioPlayerWidget({required this.path});
  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final player = AudioPlayer();
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  @override
  void initState() {
    super.initState();
    player.onPositionChanged.listen((p) => setState(() => position = p));
    player.onDurationChanged.listen((d) => setState(() => duration = d));
    player.onPlayerComplete.listen((_) => setState(() => isPlaying = false));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
            ),
            color: const Color(0xFF82C0CC),
            iconSize: 32,
            onPressed: () async {
              if (isPlaying) {
                await player.pause();
                setState(() => isPlaying = false);
              } else {
                await player.play(DeviceFileSource(widget.path));
                setState(() => isPlaying = true);
              }
            },
          ),
          Expanded(
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                  ),
                  child: Slider(
                    value: position.inSeconds.toDouble(),
                    max: duration.inSeconds.toDouble() > 0
                        ? duration.inSeconds.toDouble()
                        : 1.0,
                    onChanged: (value) async {
                      await player.seek(Duration(seconds: value.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }
}

class _VideoPlayerDialog extends StatefulWidget {
  final String videoPath;
  const _VideoPlayerDialog({required this.videoPath});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() => _initialized = true);
        _controller.play();
        _controller.setLooping(true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_initialized)
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            )
          else
            const CircularProgressIndicator(color: Colors.white),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            bottom: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _controller.value.isPlaying
                          ? _controller.pause()
                          : _controller.play();
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

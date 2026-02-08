import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/moment.dart';
import '../models/trip.dart';
import '../services/database_service.dart';
import 'package:provider/provider.dart';

/// Widget che visualizza la timeline cronologica dei momenti di un viaggio.
class TimelineWidget extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onMomentDeleted;

  const TimelineWidget({super.key, required this.trip, this.onMomentDeleted});

  @override
  Widget build(BuildContext context) {
    // Ordina i momenti per timestamp (dal più vecchio al più recente per la timeline)
    final sortedMoments = List<Moment>.from(trip.moments)
      ..sort(
        (a, b) => (a.timestamp ?? DateTime.now()).compareTo(
          b.timestamp ?? DateTime.now(),
        ),
      );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: sortedMoments.length + 1, // Sempre +1 per l'header
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildStatsHeader(trip);
        }

        final momentIdx = index - 1;
        final moment = sortedMoments[momentIdx];
        final isLast = momentIdx == sortedMoments.length - 1;

        return _buildTimelineItem(context, moment, isLast);
      },
    );
  }

  /// Header con le statistiche principali del viaggio.
  Widget _buildStatsHeader(Trip trip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32, top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16697A).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.route_rounded,
            trip.totalDistance.toStringAsFixed(1),
            'km totali',
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade100),
          _buildStatItem(
            Icons.auto_awesome_rounded,
            trip.moments.length.toString(),
            'momenti',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF82C0CC), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF1B262C),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Widget per visualizzare il separatore di fine giornata.
  Widget _buildDayEndMarker(Moment moment) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Divider(color: Colors.grey.shade200, thickness: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.nightlight_round,
                  size: 14,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                Text(
                  moment.title ?? 'Fine Giornata',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, Moment moment, bool isLast) {
    if (moment.type == MomentType.dayEnd) {
      return _buildDayEndMarker(moment);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicatore della linea temporale
          _buildTimelineIndicator(moment, isLast),
          const SizedBox(width: 20),
          // Card del momento
          Expanded(child: _buildMomentCard(context, moment)),
        ],
      ),
    );
  }

  Widget _buildTimelineIndicator(Moment moment, bool isLast) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _getMomentColor(moment.type!).withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: _getMomentColor(moment.type!).withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Icon(
            _getMomentIcon(moment.type!),
            color: _getMomentColor(moment.type!),
            size: 18,
          ),
        ),
        if (!isLast)
          Expanded(
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _getMomentColor(moment.type!).withValues(alpha: 0.5),
                    Colors.grey.shade200,
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMomentCard(BuildContext context, Moment moment) {
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Intestazione della card (Ora e Titolo)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Text(
                  DateFormat(
                    'HH:mm',
                  ).format(moment.timestamp ?? DateTime.now()),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getMomentColor(moment.type!),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    moment.title ?? _getDefaultTitle(moment.type!),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onSelected: (val) {
                    if (val == 'delete') {
                      _showDeleteDialog(context, moment, dbService);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text('Elimina', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Contenuto specifico in base al tipo
          if (moment.type == MomentType.photo && moment.content != null)
            _buildPhotoPreview(moment.content!)
          else if (moment.type == MomentType.video)
            _buildVideoPreview(context, moment.content!)
          else if (moment.type == MomentType.audio)
            _buildAudioPlayer(moment.content!)
          else if (moment.content != null && moment.type != MomentType.photo)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                _truncateContent(moment.content!),
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
            ),

          // Descrizione aggiuntiva (se presente)
          if (moment.description != null && moment.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                moment.description!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          // Footer con posizione (aggiornato per usare moment.latitude/longitude se moment.location non esiste)
          // Se la classe Moment ha location, usiamolo, altrimenti proviamo latitude/longitude.
          // In base ai log precedenti, sembrava avere latitude/longitude.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 12,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Momento registrato in questa posizione',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview(String path) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildVideoPreview(BuildContext context, String path) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => _VideoPlayerDialog(path: path),
      ),
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
                  color: Colors.white.withValues(alpha: 0.7),
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

  String _truncateContent(String content) {
    if (content.length > 150) return '${content.substring(0, 147)}...';
    return content;
  }

  IconData _getMomentIcon(MomentType type) {
    switch (type) {
      case MomentType.note:
        return Icons.notes_rounded;
      case MomentType.photo:
        return Icons.camera_alt_rounded;
      case MomentType.video:
        return Icons.videocam_rounded;
      case MomentType.dayEnd:
        return Icons.nightlight_round;
      case MomentType.audio:
        return Icons.mic_rounded;
    }
  }

  Color _getMomentColor(MomentType type) {
    switch (type) {
      case MomentType.note:
        return const Color(0xFF16697A);
      case MomentType.photo:
        return const Color(0xFFFFA62B);
      case MomentType.video:
        return Colors.redAccent;
      case MomentType.dayEnd:
        return Colors.blueGrey;
      case MomentType.audio:
        return const Color(0xFF82C0CC);
    }
  }

  String _getDefaultTitle(MomentType type) {
    switch (type) {
      case MomentType.note:
        return 'Nota';
      case MomentType.photo:
        return 'Foto';
      case MomentType.video:
        return 'Video';
      case MomentType.dayEnd:
        return 'Fine Giornata';
      case MomentType.audio:
        return 'Audio';
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    Moment moment,
    DatabaseService dbService,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina momento'),
        content: const Text('Sei sicuro di voler eliminare questo ricordo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              dbService.deleteMoment(moment.id!, trip.id!);
              Navigator.pop(context);
              if (onMomentDeleted != null) onMomentDeleted!();
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
}

/// Widget interno per la riproduzione dei file audio registrati.
class _AudioPlayerWidget extends StatefulWidget {
  final String path;
  const _AudioPlayerWidget({required this.path});

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  late AudioPlayer player;
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  @override
  void initState() {
    super.initState();
    player = AudioPlayer();
    player.onDurationChanged.listen((d) => setState(() => duration = d));
    player.onPositionChanged.listen((p) => setState(() => position = p));
    player.onPlayerComplete.listen((_) => setState(() => isPlaying = false));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
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
}

/// Dialog per la riproduzione dei file video a schermo intero o quasi.
class _VideoPlayerDialog extends StatefulWidget {
  final String path;
  const _VideoPlayerDialog({required this.path});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path))
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

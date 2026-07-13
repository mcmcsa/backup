import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class VoicePlayerWidget extends StatefulWidget {
  final String audioUrl;
  final bool isLocal;

  const VoicePlayerWidget({
    super.key,
    required this.audioUrl,
    this.isLocal = false,
  });

  @override
  State<VoicePlayerWidget> createState() => _VoicePlayerWidgetState();
}

class _VoicePlayerWidgetState extends State<VoicePlayerWidget> {
  late final AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = true;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (widget.isLocal) {
        await _audioPlayer.setSourceDeviceFile(widget.audioUrl);
      } else {
        await _audioPlayer.setSourceUrl(widget.audioUrl);
      }

      _audioPlayer.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });

      _audioPlayer.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });

      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
            _isLoading = false;
          });
        }
      });

      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      });

      final duration = await _audioPlayer.getDuration();
      if (duration != null && mounted) {
        setState(() {
          _duration = duration;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                  color: Colors.blue.shade700,
                  iconSize: 32,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _togglePlayPause,
                ),
          const SizedBox(width: 12),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.blue.shade600,
                inactiveTrackColor: Colors.blue.shade200,
                thumbColor: Colors.blue.shade700,
              ),
              child: Slider(
                value: _position.inSeconds.toDouble(),
                min: 0,
                max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1,
                onChanged: (val) {
                  _audioPlayer.seek(Duration(seconds: val.toInt()));
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

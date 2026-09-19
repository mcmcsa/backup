import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:universal_html/html.dart' as html;
import '../providers/theme_provider.dart';

class VoiceRecorderWidget extends StatefulWidget {
  /// Callback triggered when user listens to the preview and taps Send.
  /// On Web, [filePath] will be empty — use [bytes] instead.
  /// On native, [bytes] may be empty — read [filePath] from disk.
  final Function(Uint8List bytes, String filePath) onRecordingComplete;
  final VoidCallback? onRecordingDeleted;
  final bool autoStart;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    this.onRecordingDeleted,
    this.autoStart = true,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with SingleTickerProviderStateMixin {
  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;

  bool _isRecording = false;
  bool _isRecorded = false; // true when recording stopped and preview is ready
  bool _isPlaying = false;
  bool _isPlayerReady = false;

  int _recordDuration = 0;
  Timer? _recordTimer;

  Duration _previewPosition = Duration.zero;
  Duration _previewDuration = Duration.zero;

  String? _recordedFilePath;
  Uint8List? _recordedBytes;

  late final AnimationController _animController;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _playerCompleteSub;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _initPlayerListeners();

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startRecording();
      });
    }
  }

  void _initPlayerListeners() {
    _durationSub = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _previewDuration = d);
    });

    _positionSub = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _previewPosition = p);
    });

    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _previewPosition = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _playerCompleteSub?.cancel();
    _animController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String? path;
        if (!kIsWeb) {
          final dir = await getTemporaryDirectory();
          path = '${dir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path ?? '',
        );

        setState(() {
          _isRecording = true;
          _isRecorded = false;
          _recordDuration = 0;
          _recordedFilePath = null;
          _recordedBytes = null;
          _previewPosition = Duration.zero;
          _previewDuration = Duration.zero;
        });

        _startRecordTimer();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
          widget.onRecordingDeleted?.call();
        }
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
      if (mounted) widget.onRecordingDeleted?.call();
    }
  }

  void _startRecordTimer() {
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) {
        setState(() => _recordDuration++);
      }
    });
  }

  /// Stops recording and prepares the preview player so the user can listen before sending!
  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      Uint8List bytes = Uint8List(0);

      if (path != null && path.isNotEmpty) {
        if (kIsWeb) {
          final xhr = await html.HttpRequest.request(
            path,
            responseType: 'arraybuffer',
          );
          bytes = (xhr.response as ByteBuffer).asUint8List();
        } else {
          final file = File(path);
          if (file.existsSync()) {
            bytes = await file.readAsBytes();
          }
        }
      }

      setState(() {
        _isRecording = false;
        _isRecorded = true;
        _recordedFilePath = path;
        _recordedBytes = bytes;
        _previewDuration = Duration(seconds: _recordDuration);
        _previewPosition = Duration.zero;
      });

      // Prepare AudioPlayer for preview playback
      await _setupPreviewPlayer();
    } catch (e) {
      debugPrint('Error stopping record: $e');
      _deleteRecording();
    }
  }

  Future<void> _setupPreviewPlayer() async {
    try {
      if (kIsWeb && _recordedBytes != null && _recordedBytes!.isNotEmpty) {
        await _audioPlayer.setSourceBytes(_recordedBytes!);
      } else if (_recordedFilePath != null && _recordedFilePath!.isNotEmpty) {
        await _audioPlayer.setSourceDeviceFile(_recordedFilePath!);
      } else if (_recordedBytes != null && _recordedBytes!.isNotEmpty) {
        await _audioPlayer.setSourceBytes(_recordedBytes!);
      }

      final d = await _audioPlayer.getDuration();
      if (d != null && mounted) {
        setState(() {
          _previewDuration = d;
          _isPlayerReady = true;
        });
      } else if (mounted) {
        setState(() => _isPlayerReady = true);
      }
    } catch (e) {
      debugPrint('Error setting up preview player: $e');
      if (mounted) setState(() => _isPlayerReady = true);
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_previewPosition >= _previewDuration && _previewDuration > Duration.zero) {
        await _audioPlayer.seek(Duration.zero);
      }
      await _audioPlayer.resume();
    }
  }

  void _seekTo(double value) {
    final target = Duration(seconds: value.toInt());
    _audioPlayer.seek(target);
  }

  void _sendRecording() {
    if (_recordedBytes != null && _recordedBytes!.isNotEmpty) {
      _audioPlayer.stop();
      widget.onRecordingComplete(_recordedBytes!, _recordedFilePath ?? '');
    } else if (_recordedFilePath != null && _recordedFilePath!.isNotEmpty) {
      _audioPlayer.stop();
      final bytes = File(_recordedFilePath!).readAsBytesSync();
      widget.onRecordingComplete(bytes, _recordedFilePath!);
    }
  }

  void _deleteRecording() {
    _recordTimer?.cancel();
    _audioPlayer.stop();
    if (_recordedFilePath != null && !kIsWeb) {
      try {
        final file = File(_recordedFilePath!);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
    setState(() {
      _isRecording = false;
      _isRecorded = false;
      _isPlaying = false;
      _recordedFilePath = null;
      _recordedBytes = null;
      _recordDuration = 0;
      _previewPosition = Duration.zero;
      _previewDuration = Duration.zero;
    });
    widget.onRecordingDeleted?.call();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatDurationObj(Duration d) {
    final minutes = d.inMinutes;
    final remainingSeconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDarkMode;

    if (_isRecorded) {
      return _buildPreviewBar(isDark);
    }

    if (_isRecording) {
      return _buildRecordingBar(isDark);
    }

    return _buildIdleBar(isDark);
  }

  /// Messenger-style Audio Preview & Confirmation Bar
  Widget _buildPreviewBar(bool isDark) {
    final bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final maxSeconds = _previewDuration.inSeconds > 0
        ? _previewDuration.inSeconds.toDouble()
        : (_recordDuration > 0 ? _recordDuration.toDouble() : 1.0);
    final currentSeconds = _previewPosition.inSeconds.toDouble().clamp(0.0, maxSeconds);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // 1. Discard (Trash) Button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
            onPressed: _deleteRecording,
            tooltip: 'Discard voice note',
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),

          // 2. Play / Pause Button
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFF0F766E),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 3. Audio Progress Scrubber & Duration
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: const Color(0xFF0F766E),
                    inactiveTrackColor: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    thumbColor: const Color(0xFF0F766E),
                    overlayColor: const Color(0xFF0F766E).withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    min: 0.0,
                    max: maxSeconds,
                    value: currentSeconds,
                    onChanged: _isPlayerReady ? _seekTo : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDurationObj(_previewPosition),
                        style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatDurationObj(_previewDuration.inSeconds > 0
                            ? _previewDuration
                            : Duration(seconds: _recordDuration)),
                        style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // 4. Send Button
          GestureDetector(
            onTap: _sendRecording,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFF0F766E),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Messenger-style Live Recording Bar
  Widget _buildRecordingBar(bool isDark) {
    final bg = isDark ? const Color(0xFF2D1616) : const Color(0xFFFEF2F2);
    final borderColor = isDark ? Colors.red.shade900.withValues(alpha: 0.5) : Colors.red.shade200;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Discard Button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
            onPressed: _deleteRecording,
            tooltip: 'Cancel recording',
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),

          // Pulsing Red Recording Dot
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.4 + (_animController.value * 0.6)),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4 * _animController.value),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Duration Timer
          Text(
            _formatDuration(_recordDuration),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.red,
              fontSize: 14,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),

          // Animated Audio Waveform Bars (Messenger style)
          Expanded(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(16, (index) {
                    final factor = (index % 4 == 0)
                        ? 0.9
                        : (index % 3 == 0)
                            ? 0.65
                            : (index % 2 == 0)
                                ? 0.4
                                : 0.8;
                    final animVal = (_animController.value * factor + 0.2).clamp(0.15, 1.0);
                    return Container(
                      width: 2.5,
                      height: 24 * animVal,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.5 + (animVal * 0.5)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(width: 10),

          // Stop Button (Stops recording and transitions to preview mode, does NOT auto-send!)
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.stop_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fallback Idle Bar
  Widget _buildIdleBar(bool isDark) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => widget.onRecordingDeleted?.call(),
          ),
          const Expanded(
            child: Text(
              'Tap microphone to record',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.mic_rounded, color: Color(0xFF0F766E)),
            onPressed: _startRecording,
          ),
        ],
      ),
    );
  }
}

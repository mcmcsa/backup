import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

class VoiceRecorderWidget extends StatefulWidget {
  /// On Web, [filePath] will be empty — use [bytes] instead.
  /// On native, [bytes] may be empty — read [filePath] from disk.
  final Function(Uint8List bytes, String filePath) onRecordingComplete;
  final VoidCallback? onRecordingDeleted;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    this.onRecordingDeleted,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isPaused = false;
  int _recordDuration = 0;
  Timer? _timer;
  String? _recordedFilePath;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
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
          _isPaused = false;
          _recordDuration = 0;
          _recordedFilePath = null;
        });

        _startTimer();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
  }

  Future<void> _pauseRecording() async {
    await _audioRecorder.pause();
    _timer?.cancel();
    setState(() => _isPaused = true);
  }

  Future<void> _resumeRecording() async {
    await _audioRecorder.resume();
    _startTimer();
    setState(() => _isPaused = false);
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });

    if (path != null) {
      setState(() => _recordedFilePath = path);
      Uint8List bytes;
      if (kIsWeb) {
        final xhr = await html.HttpRequest.request(
          path,
          responseType: 'arraybuffer',
        );
        bytes = (xhr.response as ByteBuffer).asUint8List();
      } else {
        bytes = await File(path).readAsBytes();
      }
      widget.onRecordingComplete(bytes, path);
    }
  }

  void _deleteRecording() {
    if (_recordedFilePath != null && !kIsWeb) {
      final file = File(_recordedFilePath!);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    setState(() {
      _recordedFilePath = null;
      _recordDuration = 0;
    });
    widget.onRecordingDeleted?.call();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_recordedFilePath != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Voice Note Ready', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
                  Text('Duration: ${_formatDuration(_recordDuration)}', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: _deleteRecording,
              tooltip: 'Delete Recording',
            ),
          ],
        ),
      );
    }

    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _isPaused ? Colors.red.shade200 : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatDuration(_recordDuration),
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.red, fontSize: 16),
            ),
            const SizedBox(width: 16),
            if (_isPaused)
              IconButton(
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.red),
                onPressed: _resumeRecording,
              )
            else
              IconButton(
                icon: const Icon(Icons.pause_rounded, color: Colors.red),
                onPressed: _pauseRecording,
              ),
            IconButton(
              icon: const Icon(Icons.stop_rounded, color: Colors.red),
              onPressed: _stopRecording,
            ),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _startRecording,
      icon: const Icon(Icons.mic_rounded),
      label: const Text('Record Voice Note'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.blue.shade700,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}

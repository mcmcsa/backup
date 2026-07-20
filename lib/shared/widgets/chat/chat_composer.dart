import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/chat_model.dart';
import '../voice_recorder_widget.dart';

class ChatComposer extends StatefulWidget {
  final ChatMessage? replyTo;
  final void Function(String text) onSendText;
  final void Function(String filePath, MessageType type) onSendAttachment;
  final void Function()? onCancelReply;
  final void Function(bool isTyping)? onTypingChanged;

  const ChatComposer({
    super.key,
    this.replyTo,
    required this.onSendText,
    required this.onSendAttachment,
    this.onCancelReply,
    this.onTypingChanged,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showVoiceRecorder = false;
  bool _isTyping = false;
  Timer? _typingTimer;

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _handleTextChange(String text) {
    final typing = text.trim().isNotEmpty;
    if (typing != _isTyping) {
      _isTyping = typing;
      widget.onTypingChanged?.call(typing);
    }
    // Auto-stop typing after 3 seconds of inactivity
    _typingTimer?.cancel();
    if (typing) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isTyping) {
          _isTyping = false;
          widget.onTypingChanged?.call(false);
        }
      });
    }
  }

  void _sendText() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    _isTyping = false;
    widget.onTypingChanged?.call(false);
    widget.onSendText(text);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      widget.onSendAttachment(picked.path, MessageType.image);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      widget.onSendAttachment(result.files.single.path!, MessageType.file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyTo != null) _buildReplyBar(),
            if (_showVoiceRecorder) _buildVoiceRecorder() else _buildInputRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyBar() {
    final msg = widget.replyTo!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E).withValues(alpha: 0.06),
        border: const Border(
          left: BorderSide(color: Color(0xFF0F766E), width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${msg.senderName}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  msg.previewText,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: Colors.grey,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceRecorder() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: VoiceRecorderWidget(
        onRecordingComplete: (path) {
          widget.onSendAttachment(path, MessageType.voice);
          setState(() => _showVoiceRecorder = false);
        },
        onRecordingDeleted: () {
          setState(() => _showVoiceRecorder = false);
        },
      ),
    );
  }

  Widget _buildInputRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment button
          _AttachButton(
            onImage: _pickImage,
            onFile: _pickFile,
            onVoice: () => setState(() => _showVoiceRecorder = true),
          ),
          const SizedBox(width: 6),
          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 42, maxHeight: 120),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _textCtrl,
                focusNode: _focusNode,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                onChanged: _handleTextChange,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Send button
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textCtrl,
            builder: (_, value, __) {
              final hasText = value.text.trim().isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                child: Material(
                  color: hasText ? const Color(0xFF0F766E) : Colors.grey.shade300,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: hasText ? _sendText : null,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: hasText ? Colors.white : Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────
// Attachment picker popup button
// ─────────────────────────────────
class _AttachButton extends StatelessWidget {
  final VoidCallback onImage;
  final VoidCallback onFile;
  final VoidCallback onVoice;

  const _AttachButton({
    required this.onImage,
    required this.onFile,
    required this.onVoice,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.add_circle_rounded, color: Colors.grey.shade600, size: 28),
      tooltip: 'Attach',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        _popupItem('image', Icons.photo_library_rounded, 'Photo'),
        _popupItem('file', Icons.attach_file_rounded, 'File'),
        _popupItem('voice', Icons.mic_rounded, 'Voice'),
      ],
      onSelected: (value) {
        switch (value) {
          case 'image':
            onImage();
            break;
          case 'file':
            onFile();
            break;
          case 'voice':
            onVoice();
            break;
        }
      },
    );
  }

  PopupMenuItem<String> _popupItem(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0F766E)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

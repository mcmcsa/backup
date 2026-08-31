import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/chat_model.dart';
import '../voice_recorder_widget.dart';

class ChatComposer extends StatefulWidget {
  final ChatMessage? replyTo;
  final ChatMessage? editingMessage;
  final void Function(String text, List<AttachmentItem> attachments) onSend;
  final void Function()? onCancelReply;
  final void Function()? onCancelEdit;
  final void Function(bool isTyping)? onTypingChanged;

  const ChatComposer({
    super.key,
    this.replyTo,
    this.editingMessage,
    required this.onSend,
    this.onCancelReply,
    this.onCancelEdit,
    this.onTypingChanged,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final TextEditingController _textCtrl = TextEditingController();
  late final FocusNode _focusNode;
  bool _showVoiceRecorder = false;
  bool _isTyping = false;
  Timer? _typingTimer;
  final List<AttachmentItem> _selectedAttachments = [];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
          final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
          if (!isShiftPressed) {
            _handleSend();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingMessage != oldWidget.editingMessage) {
      if (widget.editingMessage != null) {
        _textCtrl.text = widget.editingMessage!.content ?? '';
        _focusNode.requestFocus();
      } else {
        _textCtrl.clear();
      }
    }
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

  void _handleSend() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _selectedAttachments.isEmpty) return;
    _textCtrl.clear();
    _isTyping = false;
    widget.onTypingChanged?.call(false);

    final attachmentsToSend = List<AttachmentItem>.from(_selectedAttachments);
    setState(() {
      _selectedAttachments.clear();
    });

    widget.onSend(text, attachmentsToSend);
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final List<XFile> picked = await picker.pickMultiImage(imageQuality: 80);
      if (picked.isNotEmpty) {
        final List<AttachmentItem> newItems = [];
        for (final file in picked) {
          final bytes = await file.readAsBytes();
          newItems.add(AttachmentItem(
            name: file.name,
            bytes: bytes,
            path: file.path,
            type: MessageType.image,
          ));
        }
        setState(() {
          _selectedAttachments.addAll(newItems);
        });
      }
    } catch (_) {}
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
          'txt', 'csv', 'zip', 'rar', '7z',
          'mp3', 'wav', 'mp4', 'mov', 'avi',
        ],
        allowMultiple: true,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final List<AttachmentItem> newItems = [];
        for (final file in result.files) {
          final bytes = file.bytes;
          if (bytes != null && bytes.isNotEmpty) {
            newItems.add(AttachmentItem(
              name: file.name,
              bytes: bytes,
              path: kIsWeb ? null : file.path,
              type: MessageType.file,
            ));
          }
        }
        setState(() {
          _selectedAttachments.addAll(newItems);
        });
      }
    } catch (e) {
      debugPrint('File pick error: $e');
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
            if (widget.editingMessage != null) _buildEditBar(),
            if (_selectedAttachments.isNotEmpty) _buildAttachmentPreviewBar(),
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

  Widget _buildEditBar() {
    final msg = widget.editingMessage!;
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
                const Text(
                  'Editing Message',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  msg.content ?? '',
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
            onPressed: widget.onCancelEdit,
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceRecorder() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: VoiceRecorderWidget(
        onRecordingComplete: (bytes, path) {
          if (bytes.isNotEmpty) {
            // Determine filename: on Web, use .webm (opus), on native use .m4a
            final ext = kIsWeb ? 'webm' : 'm4a';
            final name = 'voice_note_${DateTime.now().millisecondsSinceEpoch}.$ext';
            widget.onSend('', [
              AttachmentItem(
                name: name,
                bytes: bytes,
                path: path.isNotEmpty ? path : null,
                type: MessageType.voice,
              )
            ]);
          }
          setState(() => _showVoiceRecorder = false);
        },
        onRecordingDeleted: () {
          setState(() => _showVoiceRecorder = false);
        },
      ),
    );
  }

  Widget _buildAttachmentPreviewBar() {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedAttachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _selectedAttachments[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: item.type == MessageType.image
                      ? Image.memory(
                          item.bytes,
                          fit: BoxFit.cover,
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.insert_drive_file_rounded,
                              color: Color(0xFF0F766E),
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                item.name,
                                style: const TextStyle(fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedAttachments.removeAt(index);
                      });
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(3),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputRow() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    final hasImages = _selectedAttachments.any((a) => a.type == MessageType.image);
    final hasFiles = _selectedAttachments.any((a) => a.type == MessageType.file);
    final disablePhoto = hasFiles;
    final disableFile = hasImages;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMobile)
            _AttachButton(
              onImage: _pickImage,
              onFile: _pickFile,
              onVoice: () => setState(() => _showVoiceRecorder = true),
              disablePhoto: disablePhoto,
              disableFile: disableFile,
            )
          else ...[
            IconButton(
              icon: Icon(
                Icons.photo_library_rounded,
                color: disablePhoto ? Colors.grey.shade300 : const Color(0xFF0F766E),
                size: 24,
              ),
              tooltip: 'Photo',
              onPressed: disablePhoto ? null : _pickImage,
            ),
            IconButton(
              icon: Icon(
                Icons.attach_file_rounded,
                color: disableFile ? Colors.grey.shade300 : const Color(0xFF0F766E),
                size: 24,
              ),
              tooltip: 'File',
              onPressed: disableFile ? null : _pickFile,
            ),
            IconButton(
              icon: const Icon(
                Icons.mic_rounded,
                color: Color(0xFF0F766E),
                size: 24,
              ),
              tooltip: 'Voice',
              onPressed: () => setState(() => _showVoiceRecorder = true),
            ),
          ],
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
            builder: (_, value, _c) {
              final hasText = value.text.trim().isNotEmpty;
              final hasAttachments = _selectedAttachments.isNotEmpty;
              final canSend = hasText || hasAttachments;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                child: Material(
                  color: canSend ? const Color(0xFF0F766E) : Colors.grey.shade300,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: canSend ? _handleSend : null,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: canSend ? Colors.white : Colors.grey.shade500,
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
  final VoidCallback? onImage;
  final VoidCallback? onFile;
  final VoidCallback onVoice;
  final bool disablePhoto;
  final bool disableFile;

  const _AttachButton({
    required this.onImage,
    required this.onFile,
    required this.onVoice,
    required this.disablePhoto,
    required this.disableFile,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.add_circle_rounded, color: Colors.grey.shade600, size: 28),
      tooltip: 'Attach',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'image',
          enabled: !disablePhoto,
          child: Row(
            children: [
              Icon(
                Icons.photo_library_rounded,
                size: 20,
                color: disablePhoto ? Colors.grey.shade300 : const Color(0xFF0F766E),
              ),
              const SizedBox(width: 12),
              Text(
                'Photo',
                style: TextStyle(
                  fontSize: 14,
                  color: disablePhoto ? Colors.grey.shade400 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'file',
          enabled: !disableFile,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.attach_file_rounded,
                  size: 20,
                  color: disableFile ? Colors.grey.shade300 : const Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'File',
                style: TextStyle(
                  fontSize: 14,
                  color: disableFile ? Colors.grey.shade400 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'voice',
          child: Row(
            children: [
              const Icon(Icons.mic_rounded, size: 20, color: Color(0xFF0F766E)),
              const SizedBox(width: 12),
              const Text('Voice', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'image':
            if (onImage != null) onImage!();
            break;
          case 'file':
            if (onFile != null) onFile!();
            break;
          case 'voice':
            onVoice();
            break;
        }
      },
    );
  }
}

// ─────────────────────────────────
// Helper Classes
// ─────────────────────────────────
class AttachmentItem {
  final String name;
  final Uint8List bytes;
  final String? path;
  final MessageType type;

  AttachmentItem({
    required this.name,
    required this.bytes,
    this.path,
    required this.type,
  });
}

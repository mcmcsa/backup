import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import '../../models/chat_model.dart';
import '../voice_player_widget.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final bool showSenderName;
  final void Function(ChatMessage)? onReply;
  final void Function(ChatMessage)? onForward;
  final void Function(ChatMessage)? onPin;
  final void Function(ChatMessage)? onDelete;
  final void Function(ChatMessage)? onEdit;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showSenderName = true,
    this.onReply,
    this.onForward,
    this.onPin,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return _buildDeletedBubble(context);
    }

    final mainBubbleWithMenu = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isMine) _buildPopupMenu(context),
        Flexible(child: _buildMainBubble(context)),
        if (!isMine) _buildPopupMenu(context),
      ],
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showContextMenu(context),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (showSenderName && !isMine) _buildSenderName(),
              if (message.isForwarded) _buildForwardedLabel(),
              if (message.replyToId != null) _buildReplyPreview(),
              mainBubbleWithMenu,
              const SizedBox(height: 2),
              _buildTimestamp(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeletedBubble(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Text(
          '🗑 Message deleted',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildSenderName() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        message.senderName,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F766E),
        ),
      ),
    );
  }

  Widget _buildForwardedLabel() {
    return Padding(
      padding: EdgeInsets.only(
        left: isMine ? 0 : 4,
        right: isMine ? 4 : 0,
        bottom: 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forward_rounded, size: 12, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(
            'Forwarded',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.2)
            : const Color(0xFF0F766E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isMine ? Colors.white : const Color(0xFF0F766E),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.replyToSenderName != null)
            Text(
              message.replyToSenderName!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isMine ? Colors.white : const Color(0xFF0F766E),
              ),
            ),
          Text(
            message.replyToContent ?? '…',
            style: TextStyle(
              fontSize: 12,
              color: isMine
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.grey.shade700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMainBubble(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: _bubblePadding,
      decoration: BoxDecoration(
        color: isMine ? const Color(0xFF0F766E) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMine ? 18 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _buildContent(context),
    );
  }

  EdgeInsets get _bubblePadding {
    switch (message.messageType) {
      case MessageType.image:
        return EdgeInsets.zero;
      case MessageType.voice:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      default:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    }
  }

  Widget _buildContent(BuildContext context) {
    switch (message.messageType) {
      case MessageType.image:
        return _buildImageContent(context);
      case MessageType.voice:
        return _buildVoiceContent();
      case MessageType.file:
        return _buildFileContent(context);
      default:
        return _buildTextContent();
    }
  }

  Widget _buildTextContent() {
    final text = message.content ?? '';
    if (text.isEmpty && message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty) {
      return Text(
        '📎 ${message.attachmentName ?? 'Attachment'}',
        style: TextStyle(
          fontSize: 14,
          color: isMine ? Colors.white : const Color(0xFF1A1A1A),
          height: 1.4,
        ),
      );
    }
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: isMine ? Colors.white : const Color(0xFF1A1A1A),
        height: 1.4,
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    if (message.attachmentUrl == null || message.attachmentUrl!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: Text(
          '📷 Image unavailable',
          style: TextStyle(
            fontSize: 13,
            color: isMine ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: Radius.circular(isMine ? 18 : 4),
        bottomRight: Radius.circular(isMine ? 4 : 18),
      ),
      child: GestureDetector(
        onTap: () => _openImageFullscreen(context),
        child: Image.network(
          message.attachmentUrl!,
          width: 240,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              width: 240,
              height: 160,
              color: Colors.grey.shade200,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            width: 240,
            height: 100,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceContent() {
    if (message.attachmentUrl == null || message.attachmentUrl!.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '🎤 Voice message unavailable',
          style: TextStyle(
            fontSize: 13,
            color: isMine ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
      );
    }
    return SizedBox(
      width: 240,
      child: VoicePlayerWidget(audioUrl: message.attachmentUrl!),
    );
  }

  Widget _buildFileContent(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty) {
          html.window.open(message.attachmentUrl!, '_blank');
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isMine
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFF0F766E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.insert_drive_file_rounded,
                size: 24,
                color: isMine ? Colors.white : const Color(0xFF0F766E),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.attachmentName ?? 'File',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isMine ? Colors.white : const Color(0xFF134E4A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Tap to download',
                    style: TextStyle(
                      fontSize: 11,
                      color: isMine
                          ? Colors.white70
                          : Colors.grey.shade600,
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

  Widget _buildTimestamp() {
    return Padding(
      padding: EdgeInsets.only(
        left: isMine ? 0 : 4,
        right: isMine ? 4 : 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.isPinned) ...[
            Icon(Icons.push_pin_rounded, size: 12, color: Colors.amber.shade700),
            const SizedBox(width: 3),
          ],
          Text(
            DateFormat('HH:mm').format(message.createdAt.toLocal()) +
                (message.messageType == MessageType.text &&
                        !message.isDeleted &&
                        message.updatedAt.difference(message.createdAt).inSeconds > 2
                    ? ' (edited)'
                    : ''),
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _openImageFullscreen(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(message.attachmentUrl!),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (message.content != null)
                _contextItem(
                  context,
                  Icons.copy_rounded,
                  'Copy',
                  () {
                    Clipboard.setData(ClipboardData(text: message.content!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                ),
              if (onReply != null)
                _contextItem(
                  context,
                  Icons.reply_rounded,
                  'Reply',
                  () => onReply!(message),
                ),
              if (onForward != null)
                _contextItem(
                  context,
                  Icons.forward_rounded,
                  'Forward',
                  () => onForward!(message),
                ),
              if (onPin != null)
                _contextItem(
                  context,
                  message.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  message.isPinned ? 'Unpin' : 'Pin',
                  () => onPin!(message),
                ),
              if (isMine && message.messageType == MessageType.text && onEdit != null)
                _contextItem(
                  context,
                  Icons.edit_rounded,
                  'Edit',
                  () => onEdit!(message),
                ),
              if (isMine && onDelete != null)
                _contextItem(
                  context,
                  Icons.delete_outline_rounded,
                  'Delete',
                  () => onDelete!(message),
                  color: Colors.red,
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _contextItem(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback action, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF0F766E), size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color ?? const Color(0xFF134E4A),
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        action();
      },
    );
  }

  Widget _buildPopupMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
      tooltip: 'Options',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onSelected: (value) {
        switch (value) {
          case 'reply':
            onReply?.call(message);
            break;
          case 'edit':
            onEdit?.call(message);
            break;
          case 'delete':
            onDelete?.call(message);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'reply',
          child: Row(
            children: [
              Icon(Icons.reply_rounded, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              const Text('Reply'),
            ],
          ),
        ),
        if (isMine && message.messageType == MessageType.text)
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_rounded, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                const Text('Edit'),
              ],
            ),
          ),
        if (isMine)
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade600),
                const SizedBox(width: 8),
                const Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
    );
  }
}

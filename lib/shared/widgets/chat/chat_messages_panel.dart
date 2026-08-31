import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';
import '../../services/app_notification_service.dart';
import 'chat_bubble.dart';
import 'chat_composer.dart';

class ChatMessagesPanel extends StatefulWidget {
  final ChatRoom room;
  final String currentUserId;
  final String currentUserName;
  final String currentUserRole;
  final VoidCallback? onBack;  // for mobile full-screen back

  const ChatMessagesPanel({
    super.key,
    required this.room,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserRole,
    this.onBack,
  });

  @override
  State<ChatMessagesPanel> createState() => _ChatMessagesPanelState();
}

class _ChatMessagesPanelState extends State<ChatMessagesPanel> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<ChatMessage> _messages = [];
  List<ChatMessage> _pinnedMessages = [];
  List<TypingIndicator> _typingUsers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _showSearch = false;
  String _searchQuery = '';
  List<ChatMessage> _searchResults = [];

  ChatMessage? _replyTo;
  ChatMessage? _editingMessage;
  RealtimeChannel? _msgChannel;
  RealtimeChannel? _updateChannel;
  RealtimeChannel? _typingChannel;
  Timer? _typingClearTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
    ChatService.markRead(widget.room.id, widget.currentUserId);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ChatMessagesPanel old) {
    super.didUpdateWidget(old);
    if (old.room.id != widget.room.id) {
      _msgChannel?.unsubscribe();
      _updateChannel?.unsubscribe();
      _typingChannel?.unsubscribe();
      setState(() {
        _messages = [];
        _pinnedMessages = [];
        _typingUsers = [];
        _isLoading = true;
        _replyTo = null;
        _editingMessage = null;
      });
      _load();
      _subscribeRealtime();
      ChatService.markRead(widget.room.id, widget.currentUserId);
    }
  }

  @override
  void dispose() {
    _msgChannel?.unsubscribe();
    _updateChannel?.unsubscribe();
    _typingChannel?.unsubscribe();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _typingClearTimer?.cancel();
    super.dispose();
  }

  void _subscribeRealtime() {
    _msgChannel = ChatService.subscribeToMessages(widget.room.id, (msg) {
      if (mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
        if (msg.senderId != widget.currentUserId) {
          ChatService.markRead(widget.room.id, widget.currentUserId);
        }
      }
    });

    _updateChannel = ChatService.subscribeToMessageUpdates(widget.room.id, (msg) {
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == msg.id);
          if (idx != -1) _messages[idx] = msg;
          // Update pin list
          if (msg.isPinned) {
            if (!_pinnedMessages.any((m) => m.id == msg.id)) {
              _pinnedMessages.insert(0, msg);
            }
          } else {
            _pinnedMessages.removeWhere((m) => m.id == msg.id);
          }
        });
      }
    });

    _typingChannel = ChatService.subscribeToTyping(widget.room.id, (t) {
      if (!mounted || t.userId == widget.currentUserId) return;
      setState(() {
        _typingUsers.removeWhere((u) => u.userId == t.userId);
        if (t.isTyping) _typingUsers.add(t);
      });
      // Auto-clear stale typing after 5 seconds
      _typingClearTimer?.cancel();
      _typingClearTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _typingUsers.clear());
      });
    });
  }

  Future<void> _load() async {
    try {
      final msgs = await ChatService.fetchMessages(widget.room.id);
      final pinned = await ChatService.fetchPinnedMessages(widget.room.id);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _pinnedMessages = pinned;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels < 100 && !_isLoadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_messages.isEmpty) return;
    setState(() => _isLoadingMore = true);
    try {
      final older = await ChatService.fetchMessages(
        widget.room.id,
        before: _messages.first.createdAt.toIso8601String(),
      );
      if (mounted && older.isNotEmpty) {
        final prevExtent = _scrollCtrl.position.maxScrollExtent;
        setState(() => _messages.insertAll(0, older));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.jumpTo(
              _scrollCtrl.position.maxScrollExtent - prevExtent,
            );
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend(String text, List<AttachmentItem> attachments) async {
    if (text.isEmpty && attachments.isEmpty) return;

    if (_editingMessage != null) {
      try {
        await ChatService.editMessage(_editingMessage!.id, text);
        setState(() => _editingMessage = null);
      } catch (e) {
        _showError('Failed to edit: $e');
      }
      return;
    }

    if (attachments.isNotEmpty && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
          ),
        ),
      );
    }

    try {
      // 1. Send all attachments first
      for (final attach in attachments) {
        await ChatService.sendAttachmentMessageBytes(
          roomId: widget.room.id,
          senderId: widget.currentUserId,
          senderName: widget.currentUserName,
          senderRole: widget.currentUserRole,
          bytes: attach.bytes,
          fileName: attach.name,
          messageType: attach.type,
          replyToId: _replyTo?.id,
        );
      }

      // 2. Send the text message if present
      if (text.isNotEmpty) {
        await ChatService.sendTextMessage(
          roomId: widget.room.id,
          senderId: widget.currentUserId,
          senderName: widget.currentUserName,
          senderRole: widget.currentUserRole,
          content: text,
          replyToId: _replyTo?.id,
          replyToContent: _replyTo?.previewText,
          replyToSenderName: _replyTo?.senderName,
        );
        _notifyOtherParticipants(text);
      } else if (attachments.isNotEmpty) {
        final preview = attachments.length == 1
            ? (attachments.first.type == MessageType.image ? '📷 Image' : '📎 ${attachments.first.name}')
            : '📷 Sent ${attachments.length} attachments';
        _notifyOtherParticipants(preview);
      }

      setState(() => _replyTo = null);
    } catch (e) {
      _showError('Failed to send: $e');
    } finally {
      if (attachments.isNotEmpty && mounted) {
        Navigator.of(context).pop(); // dismiss loading indicator
      }
    }
  }

  void _notifyOtherParticipants(String preview) {
    final others = widget.room.participants
        .where((p) => p.userId != widget.currentUserId);
    for (final p in others) {
      AppNotificationService.createForUser(
        targetUserId: p.userId,
        title: '💬 ${widget.currentUserName}',
        message: preview.length > 80 ? '${preview.substring(0, 80)}…' : preview,
        type: 'chat_message',
        targetPage: 'chat_room_id:${widget.room.id}',
      );
    }
  }

  Future<void> _handlePin(ChatMessage msg) async {
    await ChatService.pinMessage(msg.id, isPinned: !msg.isPinned);
  }

  Future<void> _handleDelete(ChatMessage msg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) await ChatService.deleteMessage(msg.id);
  }

  void _handleEdit(ChatMessage msg) {
    setState(() {
      _editingMessage = msg;
      _replyTo = null;
    });
  }

  Future<void> _searchMessages(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _searchQuery = ''; _searchResults = []; });
      return;
    }
    setState(() => _searchQuery = query);
    final results = await ChatService.searchMessages(widget.room.id, query);
    if (mounted) setState(() => _searchResults = results);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomName = widget.room.displayName(widget.currentUserId);

    return Column(
      children: [
        _buildTopBar(roomName),
        if (_pinnedMessages.isNotEmpty) _buildPinBar(),
        if (_showSearch) _buildSearchBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _showSearch && _searchQuery.isNotEmpty
                  ? _buildSearchResults()
                  : _buildMessageList(),
        ),
        if (_typingUsers.isNotEmpty) _buildTypingIndicator(),
        ChatComposer(
          replyTo: _replyTo,
          editingMessage: _editingMessage,
          onSend: _handleSend,
          onCancelReply: () => setState(() => _replyTo = null),
          onCancelEdit: () => setState(() => _editingMessage = null),
          onTypingChanged: (isTyping) {
            ChatService.setTyping(
              widget.room.id,
              widget.currentUserId,
              widget.currentUserName,
              isTyping: isTyping,
            );
          },
        ),
      ],
    );
  }

  Widget _buildTopBar(String roomName) {
    final other = widget.room.participants
        .where((p) => p.userId != widget.currentUserId)
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: const Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: widget.onBack,
              color: const Color(0xFF0F766E),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ],
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.12),
            child: Text(
              roomName.isNotEmpty ? roomName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Color(0xFF0F766E),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roomName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF134E4A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (other != null)
                  Text(
                    _roleLabel(other.role),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),
          if (widget.room.workRequestId != null)
            Tooltip(
              message: 'Linked to maintenance request',
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0369A1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.build_rounded, size: 12, color: Color(0xFF0369A1)),
                    SizedBox(width: 4),
                    Text('Request', style: TextStyle(fontSize: 11, color: Color(0xFF0369A1), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          IconButton(
            icon: Icon(_showSearch ? Icons.search_off_rounded : Icons.search_rounded, size: 20),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) { _searchQuery = ''; _searchResults = []; }
            }),
            color: const Color(0xFF0F766E),
            tooltip: 'Search messages',
          ),
        ],
      ),
    );
  }

  Widget _buildPinBar() {
    final pin = _pinnedMessages.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border(bottom: BorderSide(color: Colors.amber.shade200)),
      ),
      child: Row(
        children: [
          Icon(Icons.push_pin_rounded, size: 14, color: Colors.amber.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pin.previewText,
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_pinnedMessages.length > 1)
            Text(
              '+${_pinnedMessages.length - 1} more',
              style: TextStyle(fontSize: 11, color: Colors.amber.shade700),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFFF8FAFC),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        onChanged: _searchMessages,
        decoration: InputDecoration(
          hintText: 'Search messages…',
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () { _searchCtrl.clear(); _searchMessages(''); },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0F766E)),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No messages found for "$_searchQuery"',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _searchResults.length,
      itemBuilder: (_, i) {
        final msg = _searchResults[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.1),
              child: Text(msg.senderName[0], style: const TextStyle(fontSize: 12, color: Color(0xFF0F766E))),
            ),
            title: Text(msg.senderName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            subtitle: Text(msg.content ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Text(DateFormat('MMM d, HH:mm').format(msg.createdAt.toLocal()), style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ),
        );
      },
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.waving_hand_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Say hello! Start the conversation.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (_isLoadingMore && i == 0) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        final idx = _isLoadingMore ? i - 1 : i;
        final msg = _messages[idx];
        final isMine = msg.senderId == widget.currentUserId;
        final showName = !isMine && (idx == 0 ||
            _messages[idx - 1].senderId != msg.senderId);
        final showDate = idx == 0 ||
            !_isSameDay(_messages[idx - 1].createdAt, msg.createdAt);

        return Column(
          children: [
            if (showDate) _buildDateDivider(msg.createdAt),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: ChatBubble(
                message: msg,
                isMine: isMine,
                showSenderName: showName,
                onReply: (m) => setState(() => _replyTo = m),
                onForward: _handleForward,
                onPin: _handlePin,
                onDelete: _handleDelete,
                onEdit: _handleEdit,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(date, now)) {
      label = 'Today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMMM d, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final names = _typingUsers.map((u) => u.userName).join(', ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _TypingDots(),
          const SizedBox(width: 8),
          Text(
            '$names ${_typingUsers.length == 1 ? 'is' : 'are'} typing…',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _roleLabel(String role) {
    const labels = {
      'admin': 'Administrator',
      'campadmin': 'Campus Admin',
      'teacher': 'Faculty',
      'maintenance': 'Maintenance',
    };
    return labels[role] ?? role;
  }

  void _handleForward(ChatMessage msg) {
    // Simple forward: show room picker then forward
    showDialog(
      context: context,
      builder: (_) => _ForwardDialog(
        currentUserId: widget.currentUserId,
        onForward: (room) async {
          await ChatService.forwardMessage(
            original: msg,
            targetRoomId: room.id,
            forwarderName: widget.currentUserName,
            forwarderRole: widget.currentUserRole,
            forwarderId: widget.currentUserId,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Message forwarded')),
            );
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
// Animated typing dots
// ─────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
    _anim = Tween(begin: 0.0, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final t = ((_anim.value + delay) % 1.0);
            final opacity = t < 0.5 ? t * 2 : (1 - t) * 2;
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.withValues(alpha: opacity.clamp(0.2, 1.0)),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
// Forward dialog
// ─────────────────────────────────────────
class _ForwardDialog extends StatefulWidget {
  final String currentUserId;
  final void Function(ChatRoom) onForward;

  const _ForwardDialog({
    required this.currentUserId,
    required this.onForward,
  });

  @override
  State<_ForwardDialog> createState() => _ForwardDialogState();
}

class _ForwardDialogState extends State<_ForwardDialog> {
  List<ChatRoom> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ChatService.fetchRooms(widget.currentUserId).then((rooms) {
      if (mounted) setState(() { _rooms = rooms; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 400),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Forward to…', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (_loading) const Expanded(child: Center(child: CircularProgressIndicator()))
            else Expanded(
              child: ListView.builder(
                itemCount: _rooms.length,
                itemBuilder: (_, i) {
                  final r = _rooms[i];
                  return ListTile(
                    title: Text(r.displayName(widget.currentUserId)),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onForward(r);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

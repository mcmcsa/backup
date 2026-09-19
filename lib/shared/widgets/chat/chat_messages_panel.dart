import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chat_model.dart';
import '../../providers/theme_provider.dart';
import '../../services/chat_service.dart';
import 'chat_bubble.dart';
import 'chat_composer.dart';

class ChatMessagesPanel extends StatefulWidget {
  final ChatRoom room;
  final String currentUserId;
  final String currentUserName;
  final String currentUserRole;
  final VoidCallback? onBack;  // for mobile full-screen back
  final VoidCallback? onRoomDeleted;

  const ChatMessagesPanel({
    super.key,
    required this.room,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserRole,
    this.onBack,
    this.onRoomDeleted,
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
  DateTime? _clearedAt;

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
        if (_clearedAt != null && !msg.createdAt.isAfter(_clearedAt!)) {
          return;
        }
        setState(() {
          if (!_messages.any((m) => m.id == msg.id)) {
            _messages.add(msg);
          }
        });
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
      _clearedAt = await ChatService.getClearedAt(widget.currentUserId, widget.room.id);
      final msgs = await ChatService.fetchMessages(
        widget.room.id,
        currentUserId: widget.currentUserId,
      );
      final pinned = await ChatService.fetchPinnedMessages(
        widget.room.id,
        currentUserId: widget.currentUserId,
      );
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
        currentUserId: widget.currentUserId,
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
      for (int i = 0; i < attachments.length; i++) {
        final attach = attachments[i];
        // Only trigger notification on the last attachment if there is NO text message following
        final shouldNotify = text.isEmpty && (i == attachments.length - 1);
        await ChatService.sendAttachmentMessageBytes(
          roomId: widget.room.id,
          senderId: widget.currentUserId,
          senderName: widget.currentUserName,
          senderRole: widget.currentUserRole,
          bytes: attach.bytes,
          fileName: attach.name,
          messageType: attach.type,
          replyToId: _replyTo?.id,
          notify: shouldNotify,
        );
      }

      // 2. Send the text message if present (with notification)
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
          notify: true,
        );
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
    final results = await ChatService.searchMessages(
      widget.room.id,
      query,
      currentUserId: widget.currentUserId,
    );
    if (mounted) setState(() => _searchResults = results);
  }

  Future<void> _handleDeleteConversation() async {
    final roomName = widget.room.displayName(widget.currentUserId);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Delete Conversation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete your conversation with $roomName? All messages will be deleted for you. (The other participant will still keep their chat history.)',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await ChatService.deleteConversation(widget.currentUserId, widget.room.id);
    _clearedAt = DateTime.now();

    if (mounted) {
      setState(() {
        _messages.clear();
        _pinnedMessages.clear();
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted conversation with $roomName'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }

    widget.onRoomDeleted?.call();
    widget.onBack?.call();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final roomName = widget.room.displayName(widget.currentUserId);

    return Container(
      color: themeProvider.backgroundColor,
      child: Column(
        children: [
          _buildTopBar(roomName, themeProvider),
          if (_pinnedMessages.isNotEmpty) _buildPinBar(themeProvider),
          if (_showSearch) _buildSearchBar(themeProvider),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: themeProvider.primaryColor,
                    ),
                  )
                : _showSearch && _searchQuery.isNotEmpty
                    ? _buildSearchResults(themeProvider)
                    : _buildMessageList(themeProvider),
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
      ),
    );
  }

  Widget _buildTopBar(String roomName, ThemeProvider themeProvider) {
    final other = widget.room.participants
        .where((p) => p.userId != widget.currentUserId)
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        border: Border(bottom: BorderSide(color: themeProvider.borderColor)),
        boxShadow: [
          BoxShadow(
            color: themeProvider.shadowColor,
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 24),
            onPressed: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            color: themeProvider.textColor,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 18,
            backgroundColor: themeProvider.isDarkMode
                ? themeProvider.primaryColor.withValues(alpha: 0.25)
                : const Color(0xFF0F766E).withValues(alpha: 0.12),
            backgroundImage: (other?.profileImage != null && other!.profileImage!.trim().isNotEmpty)
                ? NetworkImage(other.profileImage!.trim())
                : null,
            child: (other?.profileImage == null || other!.profileImage!.trim().isEmpty)
                ? Text(
                    roomName.isNotEmpty ? roomName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: themeProvider.isDarkMode
                          ? Colors.tealAccent.shade200
                          : const Color(0xFF0F766E),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  roomName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: themeProvider.textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (other != null && other.role.toLowerCase() != 'teacher')
                  Text(
                    _roleLabel(other.role),
                    style: TextStyle(fontSize: 11, color: themeProvider.subtitleColor),
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
                  color: const Color(0xFF0369A1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.build_rounded, size: 12, color: Color(0xFF0EA5E9)),
                    SizedBox(width: 4),
                    Text('Request', style: TextStyle(fontSize: 11, color: Color(0xFF0EA5E9), fontWeight: FontWeight.w600)),
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
            color: themeProvider.isDarkMode ? Colors.white70 : const Color(0xFF0F766E),
            tooltip: 'Search messages',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 20, color: themeProvider.isDarkMode ? Colors.white70 : const Color(0xFF0F766E)),
            tooltip: 'Options',
            padding: EdgeInsets.zero,
            color: themeProvider.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'delete_conversation') {
                _handleDeleteConversation();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete_conversation',
                height: 38,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                    SizedBox(width: 10),
                    Text(
                      'Delete Conversation',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPinBar(ThemeProvider themeProvider) {
    final pin = _pinnedMessages.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Colors.amber.shade900.withValues(alpha: 0.25)
            : Colors.amber.shade50,
        border: Border(
          bottom: BorderSide(
            color: themeProvider.isDarkMode
                ? Colors.amber.shade800.withValues(alpha: 0.5)
                : Colors.amber.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.push_pin_rounded,
            size: 14,
            color: themeProvider.isDarkMode ? Colors.amber.shade300 : Colors.amber.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pin.previewText,
              style: TextStyle(
                fontSize: 12,
                color: themeProvider.isDarkMode ? Colors.amber.shade200 : Colors.amber.shade900,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_pinnedMessages.length > 1)
            Text(
              '+${_pinnedMessages.length - 1} more',
              style: TextStyle(
                fontSize: 11,
                color: themeProvider.isDarkMode ? Colors.amber.shade300 : Colors.amber.shade700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: themeProvider.cardColor,
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        onChanged: _searchMessages,
        style: TextStyle(fontSize: 13, color: themeProvider.textColor),
        decoration: InputDecoration(
          hintText: 'Search messages…',
          hintStyle: TextStyle(fontSize: 13, color: themeProvider.subtitleColor),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: themeProvider.subtitleColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, size: 18, color: themeProvider.subtitleColor),
                  onPressed: () { _searchCtrl.clear(); _searchMessages(''); },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: themeProvider.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: themeProvider.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: themeProvider.primaryColor),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
          filled: true,
          fillColor: themeProvider.inputFillColor,
        ),
      ),
    );
  }

  Widget _buildSearchResults(ThemeProvider themeProvider) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No messages found for "$_searchQuery"',
          style: TextStyle(color: themeProvider.subtitleColor),
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
          color: themeProvider.cardColor,
          child: ListTile(
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: themeProvider.isDarkMode
                  ? themeProvider.primaryColor.withValues(alpha: 0.25)
                  : const Color(0xFF0F766E).withValues(alpha: 0.1),
              child: Text(
                msg.senderName[0],
                style: TextStyle(
                  fontSize: 12,
                  color: themeProvider.isDarkMode
                      ? Colors.tealAccent.shade200
                      : const Color(0xFF0F766E),
                ),
              ),
            ),
            title: Text(
              msg.senderName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: themeProvider.textColor,
              ),
            ),
            subtitle: Text(
              msg.content ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: themeProvider.subtitleColor),
            ),
            trailing: Text(
              DateFormat('MMM d, HH:mm').format(msg.createdAt.toLocal()),
              style: TextStyle(fontSize: 10, color: themeProvider.subtitleColor),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageList(ThemeProvider themeProvider) {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.waving_hand_rounded,
              size: 48,
              color: themeProvider.subtitleColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Say hello! Start the conversation.',
              style: TextStyle(color: themeProvider.subtitleColor, fontSize: 14),
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
      builder: (context, child) {
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

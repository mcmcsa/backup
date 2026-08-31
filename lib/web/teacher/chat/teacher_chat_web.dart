import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/services/chat_service.dart';
import '../../admin/shared/admin_styles.dart';
import 'package:intl/intl.dart';

class TeacherChatWeb extends StatefulWidget {
  final ChatRoom? initialRoom;
  const TeacherChatWeb({super.key, this.initialRoom});

  @override
  State<TeacherChatWeb> createState() => _TeacherChatWebState();
}

class _TeacherChatWebState extends State<TeacherChatWeb> {
  List<ChatRoom> _rooms = [];
  List<Map<String, dynamic>> _eligibleUsers = [];
  bool _isLoading = true;
  ChatRoom? _selectedRoom;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserRole;
  RealtimeChannel? _roomsChannel;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant TeacherChatWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRoom != null && widget.initialRoom != oldWidget.initialRoom) {
      setState(() {
        _selectedRoom = widget.initialRoom;
      });
    }
  }

  @override
  void dispose() {
    _roomsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _init() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    _currentUserId = user.id;
    _currentUserName = user.name;
    _currentUserRole = user.role.name;
    await _loadRooms();
    await _loadEligibleUsers();
    _subscribeToRooms();
    if (widget.initialRoom != null) {
      setState(() {
        _selectedRoom = widget.initialRoom;
      });
    }
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await ChatService.fetchRooms(_currentUserId!);
      if (mounted) setState(() { _rooms = rooms; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEligibleUsers() async {
    try {
      final users = await ChatService.fetchEligibleUsers(
        currentUserId: _currentUserId!,
        currentUserRole: _currentUserRole!,
      );
      if (mounted) setState(() => _eligibleUsers = users);
    } catch (_) {}
  }

  void _subscribeToRooms() {
    _roomsChannel = ChatService.subscribeToRooms(_currentUserId!, () {
      _loadRooms();
    });
  }

  Future<void> _startChat(Map<String, dynamic> user) async {
    try {
      final room = await ChatService.findOrCreateDirectRoom(
        currentUserId: _currentUserId!,
        currentUserName: _currentUserName!,
        currentUserRole: _currentUserRole!,
        otherUserId: user['id'] as String,
        otherUserName: user['name'] as String,
        otherUserRole: user['role'] as String,
      );
      await _loadRooms();
      if (mounted) setState(() => _selectedRoom = room);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: $e'), backgroundColor: AdminStyles.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 750;

    if (isMobile) {
      return Container(
        color: const Color(0xFFF8FAFC),
        child: _selectedRoom != null
            ? _ChatConversationPanel(
                key: ValueKey(_selectedRoom!.id),
                room: _selectedRoom!,
                currentUserId: _currentUserId!,
                currentUserName: _currentUserName!,
                currentUserRole: _currentUserRole!,
                onBack: () => setState(() => _selectedRoom = null),
              )
            : _buildSidePanel(isMobile: true),
      );
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          // Left panel: conversations list
          _buildSidePanel(isMobile: false),
          // Right panel: active chat or placeholder
          Expanded(
            child: _selectedRoom != null
                ? _ChatConversationPanel(
                    key: ValueKey(_selectedRoom!.id),
                    room: _selectedRoom!,
                    currentUserId: _currentUserId!,
                    currentUserName: _currentUserName!,
                    currentUserRole: _currentUserRole!,
                    onBack: () => setState(() => _selectedRoom = null),
                  )
                : _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel({bool isMobile = false}) {
    return Container(
      width: isMobile ? double.infinity : 320,
      decoration: BoxDecoration(
        color: Colors.white,
        border: isMobile ? null : const Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AdminStyles.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Text('Messages', style: AdminStyles.headingStyle(fontSize: 20)),
                const Spacer(),
                _buildNewChatButton(),
              ],
            ),
          ),
          // Rooms list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary, strokeWidth: 2))
                : _rooms.isEmpty
                    ? _buildNoConversations()
                    : ListView.builder(
                        itemCount: _rooms.length,
                        itemBuilder: (context, index) => _buildRoomTile(_rooms[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewChatButton() {
    return InkWell(
      onTap: _showNewChatDialog,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AdminStyles.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.edit_rounded, color: AdminStyles.primary, size: 18),
      ),
    );
  }

  Widget _buildRoomTile(ChatRoom room) {
    final isSelected = _selectedRoom?.id == room.id;
    final otherName = room.displayName(_currentUserId!);
    final lastMsg = room.lastMessage ?? 'No messages yet';
    final lastTime = room.lastMessageAt;

    return InkWell(
      onTap: () => setState(() => _selectedRoom = room),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isSelected ? AdminStyles.primary.withValues(alpha: 0.06) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            _buildAvatar(otherName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          style: AdminStyles.headingStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AdminStyles.primary : AdminStyles.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lastTime != null)
                        Text(
                          _formatTime(lastTime),
                          style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMsg,
                    style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 4,
                height: 40,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: AdminStyles.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: AdminStyles.primaryGradient,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildNoConversations() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 56, color: AdminStyles.textMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No conversations yet', style: AdminStyles.headingStyle(fontSize: 16, color: AdminStyles.textSecondary)),
          const SizedBox(height: 8),
          Text('Tap the edit icon to start a new chat.',
              style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AdminStyles.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forum_rounded, size: 48, color: AdminStyles.primary),
          ),
          const SizedBox(height: 24),
          Text('Select a conversation', style: AdminStyles.headingStyle(fontSize: 22)),
          const SizedBox(height: 10),
          Text(
            'Choose a chat from the left panel or start\na new conversation.',
            style: AdminStyles.bodyStyle(fontSize: 14, color: AdminStyles.textSecondary, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _showNewChatDialog,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('New Conversation', style: AdminStyles.headingStyle(fontSize: 20)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded, color: AdminStyles.textMuted),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Select a contact to start messaging.',
                  style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
              const SizedBox(height: 20),
              if (_eligibleUsers.isEmpty)
                const Center(child: CircularProgressIndicator(color: AdminStyles.primary, strokeWidth: 2))
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _eligibleUsers.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final u = _eligibleUsers[i];
                      final name = u['name'] as String? ?? 'Unknown';
                      final role = (u['role'] as String? ?? '').toUpperCase();
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: AdminStyles.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        title: Text(name, style: AdminStyles.headingStyle(fontSize: 14)),
                        subtitle: Text(role, style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted)),
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          await _startChat(u);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return DateFormat('hh:mm a').format(dt);
    }
    return DateFormat('MMM d').format(dt);
  }
}

// ─── Conversation Panel ──────────────────────────────────────────────────────
class _ChatConversationPanel extends StatefulWidget {
  final ChatRoom room;
  final String currentUserId;
  final String currentUserName;
  final String currentUserRole;
  final VoidCallback onBack;

  const _ChatConversationPanel({
    super.key,
    required this.room,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserRole,
    required this.onBack,
  });

  @override
  State<_ChatConversationPanel> createState() => _ChatConversationPanelState();
}

class _ChatConversationPanelState extends State<_ChatConversationPanel> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isLoading = true;
  bool _isSending = false;
  RealtimeChannel? _msgChannel;

  String get _otherName => widget.room.displayName(widget.currentUserId);

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
    ChatService.markRead(widget.room.id, widget.currentUserId);
  }

  @override
  void dispose() {
    _msgChannel?.unsubscribe();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await ChatService.fetchMessages(widget.room.id);
      if (mounted) {
        setState(() { _messages.clear(); _messages.addAll(msgs); _isLoading = false; });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToMessages() {
    _msgChannel = ChatService.subscribeToMessages(widget.room.id, (msg) {
      if (mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
        ChatService.markRead(widget.room.id, widget.currentUserId);
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _inputCtrl.clear();

    try {
      await ChatService.sendTextMessage(
        roomId: widget.room.id,
        senderId: widget.currentUserId,
        senderName: widget.currentUserName,
        senderRole: widget.currentUserRole,
        content: text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: AdminStyles.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildChatHeader(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary, strokeWidth: 2))
              : _messages.isEmpty
                  ? _buildNoMessages()
                  : _buildMessageList(),
        ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildChatHeader() {
    final initials = _otherName.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(gradient: AdminStyles.primaryGradient, shape: BoxShape.circle),
            child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_otherName, style: AdminStyles.headingStyle(fontSize: 16)),
              Row(
                children: [
                  Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(color: AdminStyles.success, shape: BoxShape.circle)),
                  Text('Active', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.success)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoMessages() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.waving_hand_rounded, size: 48, color: AdminStyles.textMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Say hello to $_otherName!', style: AdminStyles.headingStyle(fontSize: 18, color: AdminStyles.textSecondary)),
          const SizedBox(height: 6),
          Text('Be the first to send a message.', style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final msg = _messages[i];
        final isMe = msg.senderId == widget.currentUserId;
        final showSender = i == 0 || _messages[i - 1].senderId != msg.senderId;

        return _buildMessageBubble(msg, isMe: isMe, showSender: showSender);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, {required bool isMe, required bool showSender}) {
    final color = isMe ? AdminStyles.primary : const Color(0xFFF1F5F9);
    final textColor = isMe ? Colors.white : AdminStyles.textPrimary;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final msgAlign = isMe ? MainAxisAlignment.end : MainAxisAlignment.start;

    return Padding(
      padding: EdgeInsets.only(bottom: 4, top: showSender ? 12 : 2),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (showSender && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(msg.senderName,
                  style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted, fontWeight: FontWeight.w600)),
            ),
          Row(
            mainAxisAlignment: msgAlign,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isMe) ...[
                Text(
                  DateFormat('hh:mm a').format(msg.createdAt),
                  style: AdminStyles.bodyStyle(fontSize: 10, color: AdminStyles.textMuted),
                ),
                const SizedBox(width: 8),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isMe ? AdminStyles.primary : Colors.black).withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: msg.isDeleted
                      ? Text('🗑 Message deleted',
                          style: TextStyle(color: textColor.withValues(alpha: 0.5), fontStyle: FontStyle.italic, fontSize: 13))
                      : Text(msg.content ?? '', style: TextStyle(color: textColor, fontSize: 14, height: 1.4)),
                ),
              ),
              if (!isMe) ...[
                const SizedBox(width: 8),
                Text(
                  DateFormat('hh:mm a').format(msg.createdAt),
                  style: AdminStyles.bodyStyle(fontSize: 10, color: AdminStyles.textMuted),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _inputCtrl,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: AdminStyles.bodyStyle(color: AdminStyles.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AdminStyles.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AdminStyles.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isSending
                  ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

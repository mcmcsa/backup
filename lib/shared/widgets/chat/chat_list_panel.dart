import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';
import 'chat_room_tile.dart';
import 'new_chat_dialog.dart';

class ChatListPanel extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String currentUserRole;
  final String? selectedRoomId;
  final void Function(ChatRoom room) onRoomSelected;

  const ChatListPanel({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserRole,
    this.selectedRoomId,
    required this.onRoomSelected,
  });

  @override
  State<ChatListPanel> createState() => _ChatListPanelState();
}

class _ChatListPanelState extends State<ChatListPanel> {
  List<ChatRoom> _rooms = [];
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  RealtimeChannel? _roomsChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
    _roomsChannel = ChatService.subscribeToRooms(widget.currentUserId, _load);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _roomsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rooms = await ChatService.fetchRooms(widget.currentUserId);
      if (mounted) setState(() { _rooms = rooms; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ChatRoom> get _filteredRooms {
    if (_query.isEmpty) return _rooms;
    final q = _query.toLowerCase();
    return _rooms.where((r) =>
        r.displayName(widget.currentUserId).toLowerCase().contains(q) ||
        (r.lastMessage ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildSearchBar(),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Messages',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF134E4A),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _load,
            tooltip: 'Refresh',
            color: const Color(0xFF0F766E),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
            ),
            onPressed: _openNewChat,
            tooltip: 'New conversation',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Search conversations…',
            prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
            hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final rooms = _filteredRooms;

    if (rooms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                _query.isEmpty
                    ? 'No conversations yet.\nTap the pencil to start one.'
                    : 'No results for "$_query"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        itemCount: rooms.length,
        itemBuilder: (_, i) {
          final room = rooms[i];
          return ChatRoomTile(
            room: room,
            currentUserId: widget.currentUserId,
            isSelected: room.id == widget.selectedRoomId,
            onTap: () => widget.onRoomSelected(room),
          );
        },
      ),
    );
  }

  void _openNewChat() {
    showDialog(
      context: context,
      builder: (_) => NewChatDialog(
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
        currentUserRole: widget.currentUserRole,
        onStartChat: (otherId, otherName, otherRole, workRequestId) async {
          final room = await ChatService.findOrCreateDirectRoom(
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
            currentUserRole: widget.currentUserRole,
            otherUserId: otherId,
            otherUserName: otherName,
            otherUserRole: otherRole,
            workRequestId: workRequestId,
          );
          await _load();
          if (mounted) widget.onRoomSelected(room);
        },
      ),
    );
  }
}

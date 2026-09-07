import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';
import 'chat_room_tile.dart';
import 'new_chat_dialog.dart';

enum ChatFilterTab { all, archived }

class ChatListPanel extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String currentUserRole;
  final String? selectedRoomId;
  final void Function(ChatRoom room) onRoomSelected;
  final void Function(String roomId)? onRoomDeleted;

  const ChatListPanel({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserRole,
    this.selectedRoomId,
    required this.onRoomSelected,
    this.onRoomDeleted,
  });

  @override
  State<ChatListPanel> createState() => _ChatListPanelState();
}

class _ChatListPanelState extends State<ChatListPanel> {
  List<ChatRoom> _rooms = [];
  Set<String> _archivedRoomIds = {};
  ChatFilterTab _currentTab = ChatFilterTab.all;
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
      final archived = await ChatService.getArchivedRoomIds(widget.currentUserId);
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _archivedRoomIds = archived;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _activeCount => _rooms.where((r) => !_archivedRoomIds.contains(r.id)).length;
  int get _archivedCount => _rooms.where((r) => _archivedRoomIds.contains(r.id)).length;

  List<ChatRoom> get _filteredRooms {
    final tabRooms = _currentTab == ChatFilterTab.all
        ? _rooms.where((r) => !_archivedRoomIds.contains(r.id)).toList()
        : _rooms.where((r) => _archivedRoomIds.contains(r.id)).toList();

    if (_query.isEmpty) return tabRooms;
    final q = _query.toLowerCase();
    return tabRooms.where((r) =>
        r.displayName(widget.currentUserId).toLowerCase().contains(q) ||
        (r.lastMessage ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildSearchBar(),
        _buildTabBar(),
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

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTabItem(
                tab: ChatFilterTab.all,
                label: 'All Chats',
                count: _activeCount,
                icon: Icons.chat_bubble_outline_rounded,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildTabItem(
                tab: ChatFilterTab.archived,
                label: 'Archived',
                count: _archivedCount,
                icon: Icons.archive_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required ChatFilterTab tab,
    required String label,
    required int count,
    required IconData icon,
  }) {
    final isSelected = _currentTab == tab;
    return InkWell(
      onTap: () => setState(() => _currentTab = tab),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF64748B),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ],
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
      final isArchivedTab = _currentTab == ChatFilterTab.archived;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isArchivedTab ? Icons.archive_outlined : Icons.chat_bubble_outline_rounded,
                size: 56,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                _query.isNotEmpty
                    ? 'No results for "$_query"'
                    : isArchivedTab
                        ? 'No archived conversations.\nYou can archive conversations using the options menu.'
                        : 'No conversations yet.\nTap the pencil to start one.',
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
          final isArchived = _archivedRoomIds.contains(room.id);
          return ChatRoomTile(
            room: room,
            currentUserId: widget.currentUserId,
            isSelected: room.id == widget.selectedRoomId,
            isArchived: isArchived,
            onTap: () => widget.onRoomSelected(room),
            onArchive: () => _handleArchive(room),
            onUnarchive: () => _handleUnarchive(room),
            onDelete: () => _handleDelete(room),
          );
        },
      ),
    );
  }

  Future<void> _handleArchive(ChatRoom room) async {
    await ChatService.setRoomArchived(widget.currentUserId, room.id, true);
    setState(() {
      _archivedRoomIds.add(room.id);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Archived conversation with ${room.displayName(widget.currentUserId)}'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: const Color(0xFF2DD4BF),
          onPressed: () async {
            await ChatService.setRoomArchived(widget.currentUserId, room.id, false);
            if (mounted) {
              setState(() {
                _archivedRoomIds.remove(room.id);
              });
            }
          },
        ),
      ),
    );
  }

  Future<void> _handleUnarchive(ChatRoom room) async {
    await ChatService.setRoomArchived(widget.currentUserId, room.id, false);
    setState(() {
      _archivedRoomIds.remove(room.id);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unarchived conversation with ${room.displayName(widget.currentUserId)}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleDelete(ChatRoom room) async {
    final name = room.displayName(widget.currentUserId);
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
          'Are you sure you want to delete your conversation with $name? This conversation and its messages will be removed.',
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

    await ChatService.deleteConversation(widget.currentUserId, room.id);
    widget.onRoomDeleted?.call(room.id);

    setState(() {
      _rooms.removeWhere((r) => r.id == room.id);
      _archivedRoomIds.remove(room.id);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted conversation with $name'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFDC2626),
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

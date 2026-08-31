import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/widgets/chat/chat_list_panel.dart';
import '../../../shared/widgets/chat/chat_messages_panel.dart';

class MaintenanceChatPageWeb extends StatefulWidget {
  final ChatRoom? initialRoom;
  const MaintenanceChatPageWeb({super.key, this.initialRoom});

  @override
  State<MaintenanceChatPageWeb> createState() => _MaintenanceChatPageWebState();
}

class _MaintenanceChatPageWebState extends State<MaintenanceChatPageWeb> {
  ChatRoom? _selectedRoom;

  static const _primary = Color(0xFF0EA5E9);
  static const _bg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    if (widget.initialRoom != null) {
      _selectedRoom = widget.initialRoom;
    }
  }

  @override
  void didUpdateWidget(covariant MaintenanceChatPageWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRoom != null && widget.initialRoom != oldWidget.initialRoom) {
      setState(() {
        _selectedRoom = widget.initialRoom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const SizedBox.shrink();

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    Widget mainContent;
    if (isMobile) {
      if (_selectedRoom != null) {
        mainContent = ChatMessagesPanel(
          key: ValueKey(_selectedRoom!.id),
          room: _selectedRoom!,
          currentUserId: user.id,
          currentUserName: user.name,
          currentUserRole: user.role.name,
          onBack: () => setState(() => _selectedRoom = null),
        );
      } else {
        mainContent = ChatListPanel(
          currentUserId: user.id,
          currentUserName: user.name,
          currentUserRole: user.role.name,
          selectedRoomId: _selectedRoom?.id,
          onRoomSelected: (room) => setState(() => _selectedRoom = room),
        );
      }
    } else {
      mainContent = Row(
        children: [
          // Left: Room list
          Container(
            width: 300,
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: ChatListPanel(
              currentUserId: user.id,
              currentUserName: user.name,
              currentUserRole: user.role.name,
              selectedRoomId: _selectedRoom?.id,
              onRoomSelected: (room) => setState(() => _selectedRoom = room),
            ),
          ),
          // Right: Messages
          Expanded(
            child: _selectedRoom == null
                ? _buildEmptyState()
                : ChatMessagesPanel(
                    key: ValueKey(_selectedRoom!.id),
                    room: _selectedRoom!,
                    currentUserId: user.id,
                    currentUserName: user.name,
                    currentUserRole: user.role.name,
                  ),
          ),
        ],
      );
    }

    return Container(
      color: _bg,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 10 : 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: mainContent,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 56,
              color: _primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Select a conversation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a chat or start a new one.',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

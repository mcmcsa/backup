import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/widgets/chat/chat_list_panel.dart';
import '../../../shared/widgets/chat/chat_messages_panel.dart';
import '../shared/admin_styles.dart';

class AdminChatPageWeb extends StatefulWidget {
  final ChatRoom? initialRoom;
  const AdminChatPageWeb({super.key, this.initialRoom});

  @override
  State<AdminChatPageWeb> createState() => _AdminChatPageWebState();
}

class _AdminChatPageWebState extends State<AdminChatPageWeb> {
  ChatRoom? _selectedRoom;

  @override
  void initState() {
    super.initState();
    _selectedRoom = widget.initialRoom;
  }

  @override
  void didUpdateWidget(covariant AdminChatPageWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRoom != oldWidget.initialRoom && widget.initialRoom != null) {
      _selectedRoom = widget.initialRoom;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Container(
      color: AdminStyles.bg,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AdminStyles.border),
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
            child: Row(
              children: [
                // Left panel: Room list
                Container(
                  width: 300,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border(
                      right: BorderSide(color: AdminStyles.border),
                    ),
                  ),
                  child: ChatListPanel(
                    currentUserId: user.id,
                    currentUserName: user.name,
                    currentUserRole: user.role.name,
                    selectedRoomId: _selectedRoom?.id,
                    onRoomSelected: (room) => setState(() => _selectedRoom = room),
                  ),
                ),
                // Right panel: Messages
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
            ),
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
              color: AdminStyles.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 56,
              color: AdminStyles.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Select a conversation',
            style: AdminStyles.headingStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a chat from the list or start\na new conversation.',
            textAlign: TextAlign.center,
            style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textMuted),
          ),
        ],
      ),
    );
  }
}

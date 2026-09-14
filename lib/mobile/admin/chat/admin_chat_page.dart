import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/widgets/chat/chat_list_panel.dart';
import '../../../shared/widgets/chat/chat_messages_panel.dart';
import '../shared/admin_app_bar.dart';

class AdminChatPage extends StatefulWidget {
  final VoidCallback? openDrawer;
  final ChatRoom? initialRoom;

  const AdminChatPage({
    super.key,
    this.openDrawer,
    this.initialRoom,
  });

  @override
  State<AdminChatPage> createState() => _AdminChatPageState();
}

class _AdminChatPageState extends State<AdminChatPage> {
  ChatRoom? _selectedRoom;

  @override
  void initState() {
    super.initState();
    _selectedRoom = widget.initialRoom;
  }

  @override
  void didUpdateWidget(covariant AdminChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRoom != oldWidget.initialRoom && widget.initialRoom != null) {
      _selectedRoom = widget.initialRoom;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const SizedBox.shrink();

    if (_selectedRoom != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          setState(() => _selectedRoom = null);
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: ChatMessagesPanel(
            key: ValueKey(_selectedRoom!.id),
            room: _selectedRoom!,
            currentUserId: user.id,
            currentUserName: user.name,
            currentUserRole: user.role.name,
            onBack: () => setState(() => _selectedRoom = null),
            onRoomDeleted: () => setState(() => _selectedRoom = null),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.openDrawer != null
          ? AdminAppBar(
              openDrawer: widget.openDrawer!,
              subtitle: 'MESSAGES',
            )
          : AppBar(
              backgroundColor: const Color(0xFFF2F4F7),
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black12,
              elevation: 1,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: const Text(
                'Messages',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
      body: ChatListPanel(
        currentUserId: user.id,
        currentUserName: user.name,
        currentUserRole: user.role.name,
        selectedRoomId: null,
        onRoomSelected: (room) => setState(() => _selectedRoom = room),
        onRoomDeleted: (roomId) {
          if (_selectedRoom?.id == roomId) {
            setState(() => _selectedRoom = null);
          }
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/widgets/chat/chat_list_panel.dart';
import '../../../shared/widgets/chat/chat_messages_panel.dart';

class TeacherChatPage extends StatefulWidget {
  const TeacherChatPage({super.key});

  @override
  State<TeacherChatPage> createState() => _TeacherChatPageState();
}

class _TeacherChatPageState extends State<TeacherChatPage> {
  ChatRoom? _selectedRoom;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const SizedBox.shrink();

    // On mobile: show list or thread based on selection
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => _selectedRoom == null
            ? _buildListView(context, user)
            : _buildThreadView(context, user),
      ),
    );
  }

  Widget _buildListView(BuildContext context, dynamic user) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ChatListPanel(
        currentUserId: user.id,
        currentUserName: user.name,
        currentUserRole: user.role.name,
        selectedRoomId: null,
        onRoomSelected: (room) => setState(() => _selectedRoom = room),
      ),
    );
  }

  Widget _buildThreadView(BuildContext context, dynamic user) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ChatMessagesPanel(
        key: ValueKey(_selectedRoom!.id),
        room: _selectedRoom!,
        currentUserId: user.id,
        currentUserName: user.name,
        currentUserRole: user.role.name,
        onBack: () => setState(() => _selectedRoom = null),
      ),
    );
  }
}

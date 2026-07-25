import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/widgets/chat/chat_list_panel.dart';
import '../../../shared/widgets/chat/chat_messages_panel.dart';
import '../../../shared/widgets/common_app_bar.dart';

class MaintenanceChatPage extends StatefulWidget {
  const MaintenanceChatPage({super.key});

  @override
  State<MaintenanceChatPage> createState() => _MaintenanceChatPageState();
}

class _MaintenanceChatPageState extends State<MaintenanceChatPage> {
  ChatRoom? _selectedRoom;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const SizedBox.shrink();

    if (_selectedRoom == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: const CommonAppBar(
          roleText: 'Welcome Maintenance Staff',
          primaryColor: Color(0xFF4169E1),
          showMenu: true,
        ),
        body: ChatListPanel(
          currentUserId: user.id,
          currentUserName: user.name,
          currentUserRole: user.role.name,
          selectedRoomId: null,
          onRoomSelected: (room) => setState(() => _selectedRoom = room),
        ),
      );
    }

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

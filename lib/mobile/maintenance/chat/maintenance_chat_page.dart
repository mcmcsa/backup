import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/widgets/chat/chat_list_panel.dart';
import '../../../shared/widgets/chat/chat_messages_panel.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../shared/providers/theme_provider.dart';

class MaintenanceChatPage extends StatefulWidget {
  final VoidCallback? openDrawer;

  const MaintenanceChatPage({super.key, this.openDrawer});

  @override
  State<MaintenanceChatPage> createState() => _MaintenanceChatPageState();
}

class _MaintenanceChatPageState extends State<MaintenanceChatPage> {
  ChatRoom? _selectedRoom;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const SizedBox.shrink();

    if (_selectedRoom == null) {
      return Scaffold(
        backgroundColor: themeProvider.backgroundColor,
        appBar: CommonAppBar(
          roleText: '',
          primaryColor: const Color(0xFF4169E1),
          showMenu: true,
          onMenuPressed: widget.openDrawer,
        ),
        body: ChatListPanel(
          currentUserId: user.id,
          currentUserName: user.name,
          currentUserRole: user.role.name,
          selectedRoomId: null,
          onRoomSelected: (room) => setState(() => _selectedRoom = room),
          onRoomDeleted: (_) => setState(() => _selectedRoom = null),
        ),
      );
    }

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      body: ChatMessagesPanel(
        key: ValueKey(_selectedRoom!.id),
        room: _selectedRoom!,
        currentUserId: user.id,
        currentUserName: user.name,
        currentUserRole: user.role.name,
        onBack: () => setState(() => _selectedRoom = null),
        onRoomDeleted: () => setState(() => _selectedRoom = null),
      ),
    );
  }
}

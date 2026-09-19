import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/providers/theme_provider.dart';
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
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (_selectedRoom != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          setState(() => _selectedRoom = null);
        },
        child: Scaffold(
          backgroundColor: themeProvider.backgroundColor,
          body: SafeArea(
            child: ChatMessagesPanel(
              key: ValueKey(_selectedRoom!.id),
              room: _selectedRoom!,
              currentUserId: user.id,
              currentUserName: user.name,
              currentUserRole: user.role.name,
              onBack: () => setState(() => _selectedRoom = null),
              onRoomDeleted: () => setState(() => _selectedRoom = null),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: widget.openDrawer != null
          ? AdminAppBar(
              openDrawer: widget.openDrawer!,
              subtitle: 'MESSAGES',
            )
          : AppBar(
              backgroundColor: themeProvider.appBarColor,
              surfaceTintColor: Colors.transparent,
              shadowColor: themeProvider.shadowColor,
              elevation: 1,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: themeProvider.textColor),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: Text(
                'Messages',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
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

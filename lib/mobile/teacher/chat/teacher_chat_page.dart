import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/chat/chat_list_panel.dart';
import '../../../shared/widgets/chat/chat_messages_panel.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../admin/shared/notifications_page.dart';

class TeacherChatPage extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final ChatRoom? initialRoom;

  const TeacherChatPage({
    super.key,
    this.scaffoldKey,
    this.initialRoom,
  });

  @override
  State<TeacherChatPage> createState() => _TeacherChatPageState();
}

class _TeacherChatPageState extends State<TeacherChatPage> {
  ChatRoom? _selectedRoom;

  @override
  void initState() {
    super.initState();
    _selectedRoom = widget.initialRoom;
  }

  @override
  void didUpdateWidget(covariant TeacherChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRoom != null && widget.initialRoom != oldWidget.initialRoom) {
      _selectedRoom = widget.initialRoom;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = context.watch<AuthService>().currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: themeProvider.backgroundColor,
        appBar: CommonAppBar(
          roleText: '',
          primaryColor: themeProvider.primaryColor,
          onMenuPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
          onNotificationPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsPage(),
              ),
            );
          },
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_selectedRoom != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          setState(() => _selectedRoom = null);
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            top: true,
            bottom: true,
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
      appBar: CommonAppBar(
        roleText: '',
        primaryColor: themeProvider.primaryColor,
        onMenuPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
        onNotificationPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationsPage(),
            ),
          );
        },
      ),
      body: SafeArea(
        child: ChatListPanel(
          currentUserId: user.id,
          currentUserName: user.name,
          currentUserRole: user.role.name,
          selectedRoomId: null,
          onRoomSelected: (room) => setState(() => _selectedRoom = room),
          onRoomDeleted: (_) => setState(() => _selectedRoom = null),
        ),
      ),
    );
  }
}

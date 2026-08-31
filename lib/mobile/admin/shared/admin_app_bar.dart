import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/utils/workflow_guide_dialog.dart';
import 'notifications_page.dart';

class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback openDrawer;
  final String? subtitle;

  static const Color _headerColor = Color(0xFFF2F4F7);

  const AdminAppBar({
    super.key,
    required this.openDrawer,
    this.subtitle,
  });

  Future<int> _fetchUnreadCount(BuildContext context) async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user == null) return 0;

    return AppNotificationService.getUnreadCount(
      role: user.role.name,
      userId: user.id,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: _headerColor,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black12,
      elevation: 1,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 8),
        child: GestureDetector(
          onTap: openDrawer,
          child: const Icon(Icons.menu, color: Colors.black87, size: 28),
        ),
      ),
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(left: 0),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'PSU',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.2,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    subtitle?.toUpperCase() ?? 'CAMPUS ADMINISTRATOR',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                      height: 1.2,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.help_outline_rounded,
            color: Colors.black87,
          ),
          tooltip: 'Workflow Guide',
          onPressed: () {
            final user = context.read<AuthService>().currentUser;
            showWorkflowGuideDialog(context, role: user?.role.name);
          },
        ),
        FutureBuilder<int>(
          future: _fetchUnreadCount(context),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 10),
                  child: IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.black87,
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsPage(),
                        ),
                      );
                    },
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 14,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

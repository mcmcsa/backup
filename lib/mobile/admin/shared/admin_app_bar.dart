import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/providers/theme_provider.dart';
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final headerBg = isDark ? themeProvider.appBarColor : _headerColor;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);

    return AppBar(
      backgroundColor: headerBg,
      surfaceTintColor: Colors.transparent,
      shadowColor: themeProvider.shadowColor,
      elevation: isDark ? 0 : 1,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 8),
        child: GestureDetector(
          onTap: openDrawer,
          child: Icon(Icons.menu, color: iconColor, size: 28),
        ),
      ),
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: (subtitle != null &&
                subtitle!.trim().isNotEmpty &&
                subtitle!.toUpperCase() != 'CAMPUS ADMINISTRATOR')
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'PSU E-Ayos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                      height: 1.2,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    subtitle!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: subtitleColor,
                      height: 1.2,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              )
            : Text(
                'PSU E-Ayos',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                  letterSpacing: 0.5,
                ),
              ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.help_outline_rounded,
            color: iconColor,
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
                    icon: Icon(
                      Icons.notifications_outlined,
                      color: iconColor,
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

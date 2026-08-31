import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../authentication/services/auth_service.dart';
import '../services/app_notification_service.dart';
import '../providers/theme_provider.dart';
import '../utils/workflow_guide_dialog.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String roleText;
  final Color primaryColor;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onNotificationPressed;
  final bool showMenu;
  final bool showBack;
  final VoidCallback? onBackPressed;

  const CommonAppBar({
    super.key,
    required this.roleText,
    required this.primaryColor,
    this.onMenuPressed,
    this.onNotificationPressed,
    this.showMenu = true,
    this.showBack = false,
    this.onBackPressed,
  });

  Future<int> _fetchUnreadCount(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return 0;

    return AppNotificationService.getUnreadCount(
      role: user.role.name,
      userId: user.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return AppBar(
      leadingWidth: 48,
      backgroundColor: themeProvider.appBarColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: themeProvider.appBarIconColor),
              onPressed: onBackPressed ?? () {
                final router = GoRouter.maybeOf(context);
                if (router != null) {
                  router.pop();
                } else {
                  Navigator.pop(context);
                }
              },
            )
          : (showMenu
              ? IconButton(
                  icon: Icon(
                    Icons.menu,
                    color: themeProvider.appBarIconColor,
                    size: 24,
                  ),
                  onPressed: onMenuPressed ?? () {
                    Scaffold.of(context).openDrawer();
                  },
                )
              : null),
      title: Row(
        children: [
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PSU',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.appBarTextColor,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                roleText,
                style: TextStyle(
                  fontSize: 9,
                  color: themeProvider.subtitleColor,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.help_outline_rounded,
            color: themeProvider.appBarIconColor,
          ),
          tooltip: 'Workflow Guide',
          onPressed: () {
            final user = Provider.of<AuthService>(context, listen: false).currentUser;
            showWorkflowGuideDialog(context, role: user?.role.name);
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: FutureBuilder<int>(
            future: _fetchUnreadCount(context),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.notifications_outlined,
                      color: themeProvider.appBarIconColor,
                    ),
                    onPressed: onNotificationPressed ?? () {},
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        constraints: const BoxConstraints(minWidth: 18),
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
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

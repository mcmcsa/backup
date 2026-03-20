import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/services/app_notification_service.dart';
import 'notifications_page.dart';

class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback openDrawer;
  final String? subtitle;

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
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GestureDetector(
          onTap: openDrawer,
          child: const Icon(Icons.menu, color: Colors.black87, size: 28),
        ),
      ),
      title: Row(
        children: [
          SizedBox(
            height: 35,
            width: 35,
            child: Image.asset(
              'assets/images/PsuLogo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.school,
                color: Color(0xFF4169E1),
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PSU',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1,
                ),
              ),
              Text(
                subtitle?.toUpperCase() ?? 'CAMPUS ADMINISTRATOR',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        FutureBuilder<int>(
          future: _fetchUnreadCount(context),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;
            return Stack(
              children: [
                IconButton(
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
                if (unreadCount > 0)
                  Positioned(
                    right: 6,
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

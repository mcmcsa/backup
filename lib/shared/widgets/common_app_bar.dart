import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String roleText;
  final Color primaryColor;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onNotificationPressed;
  final bool showMenu;

  const CommonAppBar({
    super.key,
    required this.roleText,
    required this.primaryColor,
    this.onMenuPressed,
    this.onNotificationPressed,
    this.showMenu = true,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return AppBar(
      backgroundColor: themeProvider.appBarColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: showMenu
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
          : null,
      title: Row(
        children: [
          SizedBox(
            height: 35,
            width: 35,
            child: Image.asset(
              'assets/images/PsuLogo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.school,
                color: primaryColor,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 10),
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
        Stack(
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_outlined, 
                color: themeProvider.appBarIconColor,
              ),
              onPressed: onNotificationPressed ?? () {},
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

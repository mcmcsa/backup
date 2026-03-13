import 'package:flutter/material.dart';

class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback openDrawer;
  final String? subtitle;

  const AdminAppBar({
    super.key,
    required this.openDrawer,
    this.subtitle,
  });

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
              errorBuilder: (_, __, _) => const Icon(
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
    );
  }
}

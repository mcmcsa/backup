import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../authentication/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../../router/app_router.dart';

class StudentDrawer extends StatelessWidget {
  final Function(int)? onSelectTab;
  final int? currentTab;

  const StudentDrawer({
    super.key,
    this.onSelectTab,
    this.currentTab,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 280,
      child: Container(
        color: const Color(0xFF00BFA5),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  children: [
                    // Logo
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Image.asset(
                        'assets/images/app_logo_v2.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.school,
                          color: Color(0xFF00BFA5),
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'PSU E-Ayos',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white24, height: 1),

              // Menu Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  children: [
                    // Main Navigation items from Bottom Bar
                    _buildDrawerItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      isSelected: currentTab == 0,
                      onTap: () {
                        Navigator.pop(context);
                        if (onSelectTab != null) onSelectTab!(0);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.history_rounded,
                      label: 'Logs',
                      isSelected: currentTab == 1,
                      onTap: () {
                        Navigator.pop(context);
                        if (onSelectTab != null) onSelectTab!(1);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan',
                      isSelected: currentTab == 2,
                      onTap: () {
                        Navigator.pop(context);
                        if (onSelectTab != null) onSelectTab!(2);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.description_rounded,
                      label: 'Reports',
                      isSelected: currentTab == 3,
                      onTap: () {
                        Navigator.pop(context);
                        if (onSelectTab != null) onSelectTab!(3);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.chat_bubble_rounded,
                      label: 'Messages',
                      isSelected: currentTab == 5,
                      onTap: () {
                        Navigator.pop(context);
                        if (onSelectTab != null) onSelectTab!(5);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.person_rounded,
                      label: 'Profile',
                      isSelected: currentTab == 4,
                      onTap: () {
                        Navigator.pop(context);
                        if (onSelectTab != null) {
                          onSelectTab!(4);
                        } else {
                          context.push(teacherProfileRoute);
                        }
                      },
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Divider(color: Colors.white24, height: 1),
                    ),

                    // Additional Features
                    _buildDrawerItem(
                      icon: Icons.inventory_2_outlined,
                      label: 'History',
                      onTap: () {
                        Navigator.pop(context);
                        context.push(teacherArchivesRoute);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () {
                        Navigator.pop(context);
                        context.push(teacherSettingsRoute);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.account_tree_outlined,
                      label: 'System workflow',
                      onTap: () {
                        Navigator.pop(context);
                        context.push(teacherWorkflowRoute);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.info_outlined,
                      label: 'About Us',
                      onTap: () {
                        Navigator.pop(context);
                        context.push(teacherAboutRoute);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.phone_outlined,
                      label: 'Contact Us',
                      onTap: () {
                        Navigator.pop(context);
                        context.push(teacherContactRoute);
                      },
                    ),
                  ],
                ),
              ),

              // Logout Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showLogoutConfirmation(context),
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF00BFA5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '© PSU E-Ayos',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.logout,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'Do you want to logout?',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'No',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Yes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true && context.mounted) {
      Navigator.of(context).pop();
      final authService = context.read<AuthService>();
      await authService.handleLogoutButton(context);
    }
  }
}

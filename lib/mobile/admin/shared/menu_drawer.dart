import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import 'admin_activity_logs_page.dart';
import 'admin_logs_page.dart';
import 'maintenance_management_page.dart';
import '../users/users_page.dart';
import '../../teacher/menu_pages/settings_page.dart';

class MenuDrawer extends StatelessWidget {
  const MenuDrawer({super.key});

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth <= 430;
    final drawerWidth = isCompact
        ? (screenWidth * 0.9).clamp(300.0, 360.0)
        : 360.0;

    return Drawer(
      width: drawerWidth,
      backgroundColor: const Color(0xFF4169E1),
      child: SafeArea(
        child: Column(
          children: [
            // Header with close button
            Padding(
              padding: EdgeInsets.all(isCompact ? 12.0 : 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: isCompact ? 26 : 28,
                      ),
                      padding: EdgeInsets.all(isCompact ? 8 : 8),
                      constraints: BoxConstraints(
                        minWidth: isCompact ? 44 : 44,
                        minHeight: isCompact ? 44 : 44,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),

            // PSU Logo and Title
            Container(
              padding: EdgeInsets.symmetric(vertical: isCompact ? 16 : 24),
              child: Column(
                children: [
                  // PSU Logo
                  SizedBox(
                    width: isCompact ? 98 : 100,
                    height: isCompact ? 98 : 100,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/psu_logo_v3.png',
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                        errorBuilder: (_, error, stackTrace) => const Icon(
                          Icons.school,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isCompact ? 14 : 16),
                  Text(
                    'PANGASINAN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 16 : 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.3,
                    ),
                  ),
                  Text(
                    'STATE UNIVERSITY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 18 : 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: isCompact ? 1.1 : 1.2,
                    ),
                  ),
                  SizedBox(height: isCompact ? 4 : 4),
                  Text(
                    'CAMPUS ADMINISTRATOR',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isCompact ? 11.5 : 11,
                      letterSpacing: 0.9,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isCompact ? 22 : 20),

            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(isCompact ? 14 : 16, isCompact ? 6 : 0, isCompact ? 14 : 16, 0),
                children: [
                  _buildMenuItem(
                    icon: Icons.list_alt_rounded,
                    title: 'Logs',
                    isCompact: isCompact,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminLogsPage(),
                        ),
                      );
                    },
                  ),

                  _buildMenuItem(
                    icon: Icons.history_rounded,
                    title: 'History',
                    isCompact: isCompact,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminHistoryPage(),
                        ),
                      );
                    },
                  ),
                  
                  _buildMenuItem(
                    icon: Icons.group_outlined,
                    title: 'Users',
                    isCompact: isCompact,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UsersPage(openDrawer: _noop),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.engineering_outlined,
                    title: 'Maintenance',
                    isCompact: isCompact,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const MaintenanceManagementPage(),
                        ),
                      );
                    },
                  ),

                  _buildMenuItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    isCompact: isCompact,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Logout Button
            Padding(
              padding: EdgeInsets.all(isCompact ? 16 : 24),
              child: Column(
                children: [
                  FractionallySizedBox(
                    widthFactor: isCompact ? 0.95 : 1,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final authService = context.read<AuthService>();
                        // Show confirmation dialog using root navigator to ensure valid context
                        final confirm = await showDialog<bool>(
                          context: context,
                          useRootNavigator: true,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Logout'),
                            content: const Text('Do you want to logout?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                child: const Text('Logout'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          if (context.mounted) {
                            await authService.handleLogoutButton(context);
                          }
                        }
                      },
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 17 : 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: isCompact ? 14 : 14),
                        side: const BorderSide(color: Colors.white, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isCompact ? 10 : 16),
                  Text(
                    '© PSU Maintenance',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.1),
                      fontSize: isCompact ? 12 : 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required bool isCompact,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 2 : 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 16 : 16,
              vertical: isCompact ? 13 : 14,
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: isCompact ? 27 : 24),
                SizedBox(width: isCompact ? 16 : 16),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 17.5 : 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

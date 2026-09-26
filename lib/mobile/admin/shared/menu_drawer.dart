import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../authentication/services/auth_service.dart';
import 'admin_activity_logs_page.dart';
import 'admin_logs_page.dart';
import 'maintenance_management_page.dart';
import '../users/users_page.dart';
import '../../teacher/menu_pages/settings_page.dart';
import '../ticket/approval_queue_page.dart';
import '../rooms/qr_code_history_page.dart';
import '../main_navigation.dart';

class MenuDrawer extends StatelessWidget {
  final void Function(int index)? onSelectTab;
  final int? currentTab;

  const MenuDrawer({
    super.key,
    this.onSelectTab,
    this.currentTab,
  });

  static void _noop() {}

  void _navigateToTab(BuildContext context, int tabIndex) {
    Navigator.pop(context);
    if (onSelectTab != null) {
      onSelectTab!(tabIndex);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => MainNavigation(initialIndex: tabIndex)),
        (route) => route.isFirst,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isCompact = screenWidth <= 430;
    const drawerWidth = 280.0;

    return Drawer(
      width: drawerWidth,
      backgroundColor: isDark ? const Color(0xFF141724) : const Color(0xFF4169E1),
      child: SafeArea(
        child: Column(
          children: [
            // Header with close button
            Padding(
              padding: EdgeInsets.fromLTRB(16, isCompact ? 8 : 12, 12, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: isCompact ? 22 : 24,
                    ),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),

            // PSU Logo and Title
            Container(
              padding: EdgeInsets.symmetric(vertical: isCompact ? 10 : 16),
              child: Column(
                children: [
                  SizedBox(
                    width: isCompact ? 86 : 96,
                    height: isCompact ? 86 : 96,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/app_logo_v2.png',
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                        errorBuilder: (_, error, stackTrace) => const Icon(
                          Icons.school,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'PANGASINAN STATE UNIVERSITY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 13 : 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'CAMPUS ADMINISTRATOR',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white24, height: 1),

            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 10 : 12,
                  vertical: 8,
                ),
                children: [
                  _buildMenuItem(
                    icon: Icons.home_rounded,
                    title: 'Home',
                    isCompact: isCompact,
                    isSelected: currentTab == 0,
                    onTap: () => _navigateToTab(context, 0),
                  ),
                  _buildMenuItem(
                    icon: Icons.meeting_room_rounded,
                    title: 'Rooms',
                    isCompact: isCompact,
                    isSelected: currentTab == 1,
                    onTap: () => _navigateToTab(context, 1),
                  ),
                  _buildMenuItem(
                    icon: Icons.assignment_rounded,
                    title: 'Tickets',
                    isCompact: isCompact,
                    isSelected: currentTab == 2,
                    onTap: () => _navigateToTab(context, 2),
                  ),
                  _buildMenuItem(
                    icon: Icons.chat_bubble_rounded,
                    title: 'Messages',
                    isCompact: isCompact,
                    isSelected: currentTab == 3,
                    onTap: () => _navigateToTab(context, 3),
                  ),
                  _buildMenuItem(
                    icon: Icons.bar_chart_rounded,
                    title: 'Stats',
                    isCompact: isCompact,
                    isSelected: currentTab == 4,
                    onTap: () => _navigateToTab(context, 4),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Divider(color: Colors.white24, height: 1),
                  ),
                  _buildMenuItem(
                    icon: Icons.pending_actions_rounded,
                    title: 'Approvals',
                    isCompact: isCompact,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ApprovalQueuePage(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.qr_code_2_rounded,
                    title: 'QR Management',
                    isCompact: isCompact,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QRCodeHistoryPage(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.people_rounded,
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
                    icon: Icons.engineering_rounded,
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
                    icon: Icons.receipt_long_rounded,
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
                    icon: Icons.settings_rounded,
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
                  _buildMenuItem(
                    icon: Icons.person_rounded,
                    title: 'Profile',
                    isCompact: isCompact,
                    isSelected: currentTab == 5,
                    onTap: () => _navigateToTab(context, 5),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white24, height: 1),

            // Logout Button
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 16 : 20,
                vertical: isCompact ? 12 : 16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final authService = context.read<AuthService>();
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
                  icon: const Icon(Icons.logout, color: Colors.white, size: 18),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: Colors.white60, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
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
    bool isSelected = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 2 : 3),
      child: Material(
        color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 14 : 16,
              vertical: isCompact ? 10 : 11,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.88),
                  size: isCompact ? 22 : 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 14.5 : 15,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
}

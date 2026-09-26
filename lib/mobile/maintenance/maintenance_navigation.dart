import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../authentication/services/auth_service.dart';
import '../../shared/services/maintenance_status_service.dart';
import '../../shared/providers/theme_provider.dart';
import 'dashboard/maintenance_dashboard.dart';
import 'task/maintenance_reports_page.dart';
import 'history/maintenance_staff_history_page.dart';
import 'profile/maintenance_staff_profile_page.dart';
import 'chat/maintenance_chat_page.dart';
import '../../shared/widgets/announcements/global_announcement_listener.dart';
import '../teacher/menu_pages/settings_page.dart';
import '../teacher/menu_pages/about_us_page.dart';
import '../teacher/menu_pages/contact_us_page.dart';
import '../teacher/menu_pages/system_workflow_page.dart';
import 'logs/maintenance_logs_page.dart';

class MaintenanceNavigation extends StatefulWidget {
  final int initialIndex;

  const MaintenanceNavigation({super.key, this.initialIndex = 0});

  @override
  State<MaintenanceNavigation> createState() => _MaintenanceNavigationState();
}

class _MaintenanceNavigationState extends State<MaintenanceNavigation> {
  late int _selectedIndex;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    final currentUser = context.read<AuthService>().currentUser;
    if (currentUser != null && currentUser.role.name == 'maintenance') {
      MaintenanceStatusService.startHeartbeat(currentUser.id);
    }
  }

  @override
  void didUpdateWidget(covariant MaintenanceNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      setState(() {
        _selectedIndex = widget.initialIndex;
      });
    }
  }

  @override
  void dispose() {
    final currentUser = context.read<AuthService>().currentUser;
    if (currentUser != null) {
      MaintenanceStatusService.stopHeartbeat();
      MaintenanceStatusService.setOfflineOnLogout(currentUser.id);
    }
    super.dispose();
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final List<Widget> pages = [
      MaintenanceDashboardMobile(
        openDrawer: _openDrawer,
        onTabSelected: _onNavItemTapped,
      ),
      MaintenanceReportsPage(
        openDrawer: _openDrawer,
      ),
      MaintenanceChatPage(
        openDrawer: _openDrawer,
      ),
      MaintenanceStaffHistoryPage(
        openDrawer: _openDrawer,
      ),
      MaintenanceStaffProfilePage(
        openDrawer: _openDrawer,
      ),
    ];

    return GlobalAnnouncementListener(
      child: Scaffold(
      key: _scaffoldKey,
      backgroundColor: themeProvider.backgroundColor,
      drawer: Drawer(
        width: 280,
        backgroundColor: isDark ? const Color(0xFF141724) : const Color(0xFF4169E1),
        child: SafeArea(
          child: Column(
            children: [
              // Header with close button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 22,
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    SizedBox(
                      width: 86,
                      height: 86,
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
                    const Text(
                      'PANGASINAN STATE UNIVERSITY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'MAINTENANCE STAFF',
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  children: [
                    _buildDrawerMenuItem(
                      icon: Icons.home_rounded,
                      title: 'Home',
                      isSelected: _selectedIndex == 0,
                      onTap: () {
                        Navigator.pop(context);
                        _onNavItemTapped(0);
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerMenuItem(
                      icon: Icons.work_rounded,
                      title: 'Tasks',
                      isSelected: _selectedIndex == 1,
                      onTap: () {
                        Navigator.pop(context);
                        _onNavItemTapped(1);
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerMenuItem(
                      icon: Icons.chat_bubble_rounded,
                      title: 'Chat',
                      isSelected: _selectedIndex == 2,
                      onTap: () {
                        Navigator.pop(context);
                        _onNavItemTapped(2);
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerMenuItem(
                      icon: Icons.history_rounded,
                      title: 'History',
                      isSelected: _selectedIndex == 3,
                      onTap: () {
                        Navigator.pop(context);
                        _onNavItemTapped(3);
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerMenuItem(
                      icon: Icons.person_rounded,
                      title: 'Profile',
                      isSelected: _selectedIndex == 4,
                      onTap: () {
                        Navigator.pop(context);
                        _onNavItemTapped(4);
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Divider(color: Colors.white24, height: 1),
                    ),
                    _buildDrawerMenuItem(
                      icon: Icons.history_edu_outlined,
                      title: 'Activity Logs',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MaintenanceLogsPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerMenuItem(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerMenuItem(
                      icon: Icons.account_tree_outlined,
                      title: 'System Workflow',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SystemWorkflowPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerMenuItem(
                      icon: Icons.info_outlined,
                      title: 'About Us',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutUsPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerMenuItem(
                      icon: Icons.phone_outlined,
                      title: 'Contact Us',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ContactUsPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Logout Button at Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
                          _scaffoldKey.currentState?.closeDrawer();
                        }
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
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildBottomNavBar(themeProvider),
    ),
  );
  }

  Widget _buildBottomNavBar(ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: themeProvider.navBarColor,
        border: Border(top: BorderSide(color: themeProvider.borderColor, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: themeProvider.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                index: 0,
                themeProvider: themeProvider,
              ),
              _buildNavItem(
                icon: Icons.work_outline_rounded,
                activeIcon: Icons.work_rounded,
                label: 'Tasks',
                index: 1,
                themeProvider: themeProvider,
              ),
              _buildNavItem(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Chat',
                index: 2,
                themeProvider: themeProvider,
              ),
              _buildNavItem(
                icon: Icons.history_outlined,
                activeIcon: Icons.history_rounded,
                label: 'History',
                index: 3,
                themeProvider: themeProvider,
              ),
              _buildNavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                index: 4,
                themeProvider: themeProvider,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required ThemeProvider themeProvider,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onNavItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF4169E1).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected),
                color: isSelected 
                    ? const Color(0xFF4169E1) 
                    : themeProvider.navBarTextColor,
                size: isSelected ? 26 : 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected 
                    ? const Color(0xFF4169E1) 
                    : themeProvider.navBarTextColor,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Material(
      color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 11,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
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
    );
  }
}

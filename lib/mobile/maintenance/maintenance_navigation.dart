import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../authentication/services/auth_service.dart';
import 'dashboard/maintenance_dashboard.dart';
import 'task/maintenance_reports_page.dart';
import 'history/maintenance_staff_history_page.dart';
import 'profile/maintenance_staff_profile_page.dart';
import 'chat/maintenance_chat_page.dart';

class MaintenanceNavigation extends StatefulWidget {
  final int initialIndex;

  const MaintenanceNavigation({super.key, this.initialIndex = 0});

  @override
  State<MaintenanceNavigation> createState() => _MaintenanceNavigationState();
}

class _MaintenanceNavigationState extends State<MaintenanceNavigation> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final userName = user?.name ?? 'Maintenance';
    final userEmail = user?.email ?? '';

    final List<Widget> pages = [
      const MaintenanceDashboardMobile(),
      const MaintenanceReportsPage(),
      const MaintenanceChatPage(),
      const MaintenanceStaffHistoryPage(),
      const MaintenanceStaffProfilePage(),
    ];

    return Scaffold(
      drawer: Drawer(
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: Color(0xFF4169E1),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'M',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4169E1),
                    ),
                  ),
                ),
                accountName: Text(
                  userName,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                accountEmail: Text(
                  userEmail,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home_rounded, color: Color(0xFF4169E1)),
                title: const Text('Home', style: TextStyle(fontWeight: FontWeight.w600)),
                selected: _selectedIndex == 0,
                selectedTileColor: const Color(0xFF4169E1).withValues(alpha: 0.08),
                onTap: () {
                  Navigator.pop(context);
                  _onNavItemTapped(0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.work_rounded, color: Color(0xFF4169E1)),
                title: const Text('Tasks', style: TextStyle(fontWeight: FontWeight.w600)),
                selected: _selectedIndex == 1,
                selectedTileColor: const Color(0xFF4169E1).withValues(alpha: 0.08),
                onTap: () {
                  Navigator.pop(context);
                  _onNavItemTapped(1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF4169E1)),
                title: const Text('Chat', style: TextStyle(fontWeight: FontWeight.w600)),
                selected: _selectedIndex == 2,
                selectedTileColor: const Color(0xFF4169E1).withValues(alpha: 0.08),
                onTap: () {
                  Navigator.pop(context);
                  _onNavItemTapped(2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history_rounded, color: Color(0xFF4169E1)),
                title: const Text('History', style: TextStyle(fontWeight: FontWeight.w600)),
                selected: _selectedIndex == 3,
                selectedTileColor: const Color(0xFF4169E1).withValues(alpha: 0.08),
                onTap: () {
                  Navigator.pop(context);
                  _onNavItemTapped(3);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_rounded, color: Color(0xFF4169E1)),
                title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w600)),
                selected: _selectedIndex == 4,
                selectedTileColor: const Color(0xFF4169E1).withValues(alpha: 0.08),
                onTap: () {
                  Navigator.pop(context);
                  _onNavItemTapped(4);
                },
              ),
              const Divider(),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(context);
                  final authService = context.read<AuthService>();
                  await authService.handleLogoutButton(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
              ),
              _buildNavItem(
                icon: Icons.work_outline_rounded,
                activeIcon: Icons.work_rounded,
                label: 'Tasks',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Chat',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.history_outlined,
                activeIcon: Icons.history_rounded,
                label: 'History',
                index: 3,
              ),
              _buildNavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                index: 4,
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
                    : Colors.grey.shade500,
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
                    : Colors.grey.shade600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

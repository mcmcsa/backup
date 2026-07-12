import 'package:flutter/material.dart';
import '../../shared/screens/unified_dashboard_page.dart';
import 'rooms/room_management_page.dart';
import 'ticket/work_requests_page.dart';
import '../../shared/screens/unified_analytics_page.dart';
import 'profile/profile_page.dart';
import 'shared/menu_drawer.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;

  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _selectedIndex;
  bool _isDrawerOpen = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactMobile = screenWidth <= 430;

    final List<Widget> pages = [
      UnifiedDashboardPage(openDrawer: _openDrawer),
      RoomManagementPage(openDrawer: _openDrawer),
      WorkRequestsPage(openDrawer: _openDrawer),
      UnifiedAnalyticsPage(openDrawer: _openDrawer),
      ProfilePage(openDrawer: _openDrawer),
    ];

    Widget content = Scaffold(
      key: _scaffoldKey,
      drawer: const MenuDrawer(),
      onDrawerChanged: (isOpen) {
        setState(() {
          _isDrawerOpen = isOpen;
        });
      },
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: _isDrawerOpen ? null : _buildBottomNavBar(),
    );

    if (isCompactMobile) {
      final baseTheme = Theme.of(context);

      final compactTheme = baseTheme.copyWith(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
        ),
        chipTheme: baseTheme.chipTheme.copyWith(
          labelStyle: (baseTheme.chipTheme.labelStyle ?? const TextStyle())
              .copyWith(fontSize: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      );

      content = MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(0.95),
        ),
        child: Theme(data: compactTheme, child: content),
      );
    }

    return content;
  }

  Widget _buildBottomNavBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth <= 430;

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
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 2 : 4,
            vertical: isCompact ? 6 : 10,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                index: 0,
                isCompact: isCompact,
              ),
              _buildNavItem(
                icon: Icons.meeting_room_outlined,
                activeIcon: Icons.meeting_room_rounded,
                label: 'Rooms',
                index: 1,
                isCompact: isCompact,
              ),
              _buildNavItem(
                icon: Icons.assignment_outlined,
                activeIcon: Icons.assignment_rounded,
                label: 'Tickets',
                index: 2,
                isCompact: isCompact,
              ),
              _buildNavItem(
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart_rounded,
                label: 'Stats',
                index: 3,
                isCompact: isCompact,
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                index: 4,
                isCompact: isCompact,
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
    required bool isCompact,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onNavItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8 : 12,
          vertical: isCompact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF4169E1).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
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
                size: isCompact
                    ? (isSelected ? 23 : 21)
                    : (isSelected ? 26 : 24),
              ),
            ),
            SizedBox(height: isCompact ? 2 : 4),
            Text(
              label,
              style: TextStyle(
                fontSize: isCompact ? 10 : 11,
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






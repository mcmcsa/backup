import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/providers/theme_provider.dart';
import 'dashboard/student_dashboard_page.dart';
import 'dashboard/logs_page.dart';
import 'scanner/scanner_page.dart';
import 'reports/student_reports_page.dart';
import 'profile/student_profile_page.dart';
import 'widgets/student_drawer.dart';

class StudentTeacherNavigation extends StatefulWidget {
  final int initialIndex;

  const StudentTeacherNavigation({super.key, this.initialIndex = 0});

  @override
  State<StudentTeacherNavigation> createState() => _StudentTeacherNavigationState();
}

class _StudentTeacherNavigationState extends State<StudentTeacherNavigation> {
  late int _selectedIndex;
  late GlobalKey<ScaffoldState> _scaffoldKey;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _scaffoldKey = GlobalKey<ScaffoldState>();
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final List<Widget> pages = [
      StudentTeacherDashboard(scaffoldKey: _scaffoldKey),
      LogsPage(scaffoldKey: _scaffoldKey),
      ScannerPage(scaffoldKey: _scaffoldKey),
      StudentReportsPage(scaffoldKey: _scaffoldKey),
      StudentProfilePage(scaffoldKey: _scaffoldKey),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: themeProvider.backgroundColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      drawer: const StudentDrawer(),
      bottomNavigationBar: _buildBottomNavBar(themeProvider),
    );
  }

  Widget _buildBottomNavBar(ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: themeProvider.navBarColor,
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
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
                icon: Icons.history_outlined,
                activeIcon: Icons.history_rounded,
                label: 'Logs',
                index: 1,
                themeProvider: themeProvider,
              ),
              _buildCenterNavItem(themeProvider),
              _buildNavItem(
                icon: Icons.description_outlined,
                activeIcon: Icons.description_rounded,
                label: 'Reports',
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    ? themeProvider.primaryColor 
                    : themeProvider.navBarTextColor,
                size: isSelected ? 26 : 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected 
                    ? themeProvider.primaryColor 
                    : themeProvider.navBarTextColor,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterNavItem(ThemeProvider themeProvider) {
    final isSelected = _selectedIndex == 2;
    return GestureDetector(
      onTap: () => _onNavItemTapped(2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: themeProvider.primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: themeProvider.primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scanner',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected 
                  ? themeProvider.primaryColor 
                  : themeProvider.navBarTextColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../authentication/services/auth_service.dart';
import 'dashboard/teacher_dashboard_web.dart';
import 'profile/teacher_profile_web.dart';
import 'reports/teacher_reports_web.dart';
import 'logs/teacher_logs_web.dart';
import 'scanner/teacher_scanner_web.dart';
import 'menu/teacher_settings_web.dart';
import 'menu/teacher_about_web.dart';
import 'menu/teacher_contact_web.dart';
import 'menu/teacher_workflow_web.dart';
import 'menu/teacher_archives_web.dart';
import '../../router/app_router.dart';
import '../admin/shared/admin_styles.dart';
import 'reports/teacher_create_request_web.dart';

class TeacherNavigationWeb extends StatefulWidget {
  final int initialIndex;

  const TeacherNavigationWeb({super.key, this.initialIndex = 0});

  @override
  State<TeacherNavigationWeb> createState() => _TeacherNavigationWebState();
}

class _TeacherNavigationWebState extends State<TeacherNavigationWeb> {
  late int _selectedIndex;
  String _userName = 'Teacher';
  final String _userRole = 'Faculty';
  int _hoveredIndex = -1;
  bool _isUserMenuHovered = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Professional color palette
  static const _sidebarBg = Color(0xFF0F172A);
  static const _sidebarSelected = Color(0xFF00BFA5);
  static const _sidebarHover = Color(0xFF1E293B);
  static const _textWhite = Colors.white;
  static const _textMuted = Color(0xFF94A3B8);
  static const _headerBg = Colors.white;
  static const _contentBg = Color(0xFFF8FAFC);
  static const _badgeRed = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user != null && mounted) {
      setState(() {
        _userName = user.name;
      });
    }
  }

  @override
  void didUpdateWidget(covariant TeacherNavigationWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _selectedIndex = widget.initialIndex;
    }
  }

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          margin: const EdgeInsets.all(24),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _badgeRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.logout_rounded, color: _badgeRed, size: 28),
                        ),
                        const SizedBox(height: 16),
                        Text('Sign Out', style: AdminStyles.headingStyle(fontSize: 18)),
                        const SizedBox(height: 8),
                        Text('Are you sure you want to sign out?', style: AdminStyles.bodyStyle()),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: _badgeRed, foregroundColor: Colors.white),
                            onPressed: () => Navigator.of(dialogContext).pop(true),
                            child: const Text('Sign Out'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (confirm == true && mounted) {
      final authService = context.read<AuthService>();
      await authService.handleLogoutButton(context);
    }
  }

  Widget _getCurrentPage() {
    switch (_selectedIndex) {
      case 0: return const TeacherDashboardWeb();
      case 1: return const TeacherReportsWeb();
      case 2: return const TeacherLogsWeb();
      case 3: return const TeacherScannerWeb();
      case 4: return const TeacherProfileWeb();
      case 5: return const TeacherArchivesWeb();
      case 6: return const TeacherSettingsWeb();
      case 7: return const TeacherAboutWeb();
      case 8: return const TeacherContactWeb();
      case 9: return const TeacherSystemWorkflowWeb();
      case 10: return const TeacherCreateRequestWeb();
      default: return const TeacherDashboardWeb();
    }
  }

  String _routeForIndex(int index) {
    switch (index) {
      case 0: return teacherDashboardRoute;
      case 1: return teacherReportsRoute;
      case 2: return teacherLogsRoute;
      case 3: return teacherScannerRoute;
      case 4: return teacherProfileRoute;
      case 5: return teacherArchivesRoute;
      case 6: return teacherSettingsRoute;
      case 7: return teacherAboutRoute;
      case 8: return teacherContactRoute;
      case 9: return teacherWorkflowRoute;
      case 10: return teacherCreateRequestRoute;
      default: return teacherDashboardRoute;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1100;

        if (isCompact) {
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: _contentBg,
            drawer: Drawer(
              width: 280,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              child: _buildSidebar(width: 280, closeDrawerOnTap: true),
            ),
            body: Column(
              children: [
                _buildHeader(
                  isCompact: true,
                  onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(color: _contentBg),
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: _getCurrentPage(),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: _contentBg,
          body: Row(
            children: [
              _buildSidebar(),
              Expanded(
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: Container(
                        color: _contentBg,
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1400),
                          child: _getCurrentPage(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar({double width = 260, bool closeDrawerOnTap = false}) {
    return Container(
      width: width,
      decoration: const BoxDecoration(color: _sidebarBg),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: _sidebarSelected, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PSU Teacher', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textWhite)),
                    Text('Faculty Portal', style: TextStyle(fontSize: 12, color: _textMuted)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                children: [
                  _buildNavItem(index: 0, icon: Icons.dashboard_rounded, title: 'Dashboard', closeDrawerOnTap: closeDrawerOnTap),
                  _buildNavItem(index: 1, icon: Icons.assessment_rounded, title: 'Reports', closeDrawerOnTap: closeDrawerOnTap),
                  _buildNavItem(index: 2, icon: Icons.history_rounded, title: 'Logs', closeDrawerOnTap: closeDrawerOnTap),
                  _buildNavItem(index: 3, icon: Icons.qr_code_2_rounded, title: 'Scanner', closeDrawerOnTap: closeDrawerOnTap),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Account'),
                  _buildNavItem(index: 4, icon: Icons.person_rounded, title: 'Profile', closeDrawerOnTap: closeDrawerOnTap),
                  _buildNavItem(index: 5, icon: Icons.archive_rounded, title: 'Archives', closeDrawerOnTap: closeDrawerOnTap),
                  _buildNavItem(index: 6, icon: Icons.settings_rounded, title: 'Settings', closeDrawerOnTap: closeDrawerOnTap),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Information'),
                  _buildNavItem(index: 7, icon: Icons.info_rounded, title: 'About', closeDrawerOnTap: closeDrawerOnTap),
                  _buildNavItem(index: 8, icon: Icons.mail_rounded, title: 'Contact', closeDrawerOnTap: closeDrawerOnTap),
                  _buildNavItem(index: 9, icon: Icons.schema_rounded, title: 'Workflow', closeDrawerOnTap: closeDrawerOnTap),
                  const SizedBox(height: 32),
                  _buildCreateRequestButton(),
                ],
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: _buildLogoutButton()),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textMuted.withOpacity(0.5), letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildCreateRequestButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(teacherCreateRequestRoute),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: AdminStyles.primaryGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: AdminStyles.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('New Request', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required int index, required IconData icon, required String title, int badge = 0, bool closeDrawerOnTap = false}) {
    final isSelected = _selectedIndex == index;
    final isHovered = _hoveredIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredIndex = index),
        onExit: (_) => setState(() => _hoveredIndex = -1),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            context.go(_routeForIndex(index));
            if (closeDrawerOnTap && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? _sidebarSelected.withOpacity(0.15) : (isHovered ? _sidebarHover : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: isSelected ? Border.all(color: _sidebarSelected.withOpacity(0.3)) : null,
            ),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? _sidebarSelected : _textMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? _sidebarSelected : _textMuted))),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _badgeRed, borderRadius: BorderRadius.circular(10)),
                    child: Text('$badge', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _handleLogout,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _badgeRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _badgeRed.withOpacity(0.2)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFFCA5A5), size: 18),
              SizedBox(width: 10),
              Text('Log out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFFCA5A5))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({bool isCompact = false, VoidCallback? onMenuTap}) {
    return Container(
      height: 70,
      decoration: BoxDecoration(color: _headerBg, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 24),
      child: Row(
        children: [
          if (isCompact) ...[
            IconButton(
              onPressed: onMenuTap,
              icon: const Icon(Icons.menu_rounded, color: AdminStyles.textPrimary),
              tooltip: 'Open menu',
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                height: 42,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.grey.shade300)),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (!isCompact) ...[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('TEACHER PORTAL', style: AdminStyles.headingStyle(fontSize: 13, letterSpacing: 0.5)),
                Text(_userRole, style: AdminStyles.bodyStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(width: 20),
          ],
          _HeaderIconButton(icon: Icons.notifications_outlined, badge: 0, onTap: () {}),
          const SizedBox(width: 12),
          _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildUserAvatar() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isUserMenuHovered = true),
      onExit: (_) => setState(() => _isUserMenuHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(teacherProfileRoute),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _isUserMenuHovered ? _sidebarSelected : Colors.transparent, width: 2),
          ),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: _sidebarSelected, borderRadius: BorderRadius.circular(10)),
            child: Center(
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'T',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final int badge;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, this.badge = 0, required this.onTap});
  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: _isHovered ? Colors.grey.shade100 : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(widget.icon, color: Colors.grey.shade600, size: 22),
              if (widget.badge > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                    child: Center(child: Text('${widget.badge}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

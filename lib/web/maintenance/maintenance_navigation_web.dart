import 'package:flutter/material.dart';
import '../../shared/models/work_request_model.dart';
import '../../shared/widgets/lazy_indexed_stack.dart';
import 'package:provider/provider.dart';
import '../../authentication/services/auth_service.dart';
import 'dashboard/maintenance_dashboard_web.dart';
import 'profile/maintenance_profile_web.dart';
import 'reports/maintenance_reports_web.dart';
import 'history/maintenance_history_web.dart';
import 'chat/maintenance_chat_page_web.dart';
import 'settings/maintenance_settings_web.dart';
import 'workflow/maintenance_workflow_web.dart';
import 'maintenance_nav_controller.dart';
import 'task/maintenance_task_details_web.dart';

class MaintenanceNavigationWeb extends StatefulWidget {
  final int initialIndex;

  const MaintenanceNavigationWeb({super.key, this.initialIndex = 0});

  @override
  State<MaintenanceNavigationWeb> createState() => _MaintenanceNavigationWebState();
}

class _MaintenanceNavigationWebState extends State<MaintenanceNavigationWeb> {
  late int _selectedIndex;
  WorkRequest? _selectedRequestForDetails;
  String _userName = 'Maintenance';
  final String _userRole = 'Staff';
  int _hoveredIndex = -1;
  bool _isUserMenuHovered = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Professional color palette - Slate theme for maintenance
  static const _sidebarBg = Color(0xFF1E293B); // Dark slate sidebar
  static const _sidebarSelected = Color(0xFF0EA5E9); // Sky blue accent
  static const _sidebarHover = Color(0xFF334155);
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
                    color: Colors.black.withValues(alpha: 0.15),
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
                            color: _badgeRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: _badgeRed,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Are you sure you want to sign out?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _badgeRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop(true),
                            child: const Text(
                              'Sign Out',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
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

  Widget _buildIndexedStack() {
    if (_selectedRequestForDetails != null) {
      return MaintenanceTaskDetailsWeb(
        key: ValueKey('task-details-${_selectedRequestForDetails!.id}'),
        task: _selectedRequestForDetails!,
        onBack: () {
          setState(() {
            _selectedRequestForDetails = null;
          });
        },
      );
    }

    return LazyIndexedStack(
      index: _selectedIndex,
      children: const [
        MaintenanceDashboardWeb(),
        MaintenanceReportsWeb(),
        MaintenanceChatPageWeb(), // Message
        MaintenanceHistoryWeb(), // History
        MaintenanceProfileWeb(), // Profile
        MaintenanceSettingsWeb(), // Settings
        MaintenanceWorkflowWeb(), // System Work Flow
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaintenanceNavController(
      navigateTo: (index, {request}) {
        setState(() {
          _selectedIndex = index;
          _selectedRequestForDetails = request;
        });
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1100;

        if (isCompact) {
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: _contentBg,
            drawer: Drawer(
              width: 260,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              child: _buildSidebar(width: 260, closeDrawerOnTap: true),
            ),
            body: Column(
              children: [
                _buildHeader(
                  isCompact: true,
                  onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                Expanded(
                  child: Container(
                    color: _contentBg,
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: _buildIndexedStack(),
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
              // Dark Sidebar
              _buildSidebar(),

              // Main Content Area
              Expanded(
                child: Column(
                  children: [
                    // Header Bar
                    _buildHeader(),

                    // Page Content
                    Expanded(
                      child: Container(
                        color: _contentBg,
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1400),
                          child: _buildIndexedStack(),
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
    ),
  );
}

  Widget _buildSidebar({double width = 240, bool closeDrawerOnTap = false}) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: _sidebarBg,
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                // Logo icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _sidebarSelected,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.engineering_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PSU Maintenance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textWhite,
                      ),
                    ),
                    Text(
                      'Work Portal',
                      style: TextStyle(
                        fontSize: 12,
                        color: _textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Navigation Items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_rounded,
                  title: 'Home',
                  closeDrawerOnTap: closeDrawerOnTap,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.work_rounded,
                  title: 'Task',
                  closeDrawerOnTap: closeDrawerOnTap,
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.chat_bubble_rounded,
                  title: 'Message',
                  closeDrawerOnTap: closeDrawerOnTap,
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.history_rounded,
                  title: 'History',
                  closeDrawerOnTap: closeDrawerOnTap,
                ),
                _buildNavItem(
                  index: 4,
                  icon: Icons.person_rounded,
                  title: 'Profile',
                  closeDrawerOnTap: closeDrawerOnTap,
                ),
                _buildNavItem(
                  index: 5,
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  closeDrawerOnTap: closeDrawerOnTap,
                ),
                _buildNavItem(
                  index: 6,
                  icon: Icons.account_tree_rounded,
                  title: 'System Work Flow',
                  closeDrawerOnTap: closeDrawerOnTap,
                ),
              ],
            ),
          ),

          const Spacer(),

          // Log Out button
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildLogoutButton(),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String title,
    int badge = 0,
    bool closeDrawerOnTap = false,
  }) {
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
            setState(() {
              _selectedIndex = index;
              _selectedRequestForDetails = null;
            });
            if (closeDrawerOnTap && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? _sidebarSelected.withValues(alpha: 0.2)
                  : isHovered
                      ? _sidebarHover
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: _sidebarSelected.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? _sidebarSelected : _textMuted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? _sidebarSelected : _textMuted,
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _badgeRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
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
            color: _badgeRed.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _badgeRed.withValues(alpha: 0.3),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout_rounded,
                color: Color(0xFFFCA5A5),
                size: 18,
              ),
              SizedBox(width: 10),
              Text(
                'Log out',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFCA5A5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({bool isCompact = false, VoidCallback? onMenuTap}) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: _headerBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 24),
      child: Row(
        children: [
          if (isCompact) ...[
            IconButton(
              onPressed: onMenuTap,
              icon: const Icon(Icons.menu_rounded, color: Color(0xFF1E293B)),
              tooltip: 'Open menu',
            ),
            const SizedBox(width: 4),
          ],
          // Search Bar
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search requests...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(
                        Icons.search_rounded,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          if (!isCompact) ...[
            // USER ROLE section
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'MAINTENANCE STAFF',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _userRole,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
          ],

          // Notification Bell
          _HeaderIconButton(
            icon: Icons.notifications_outlined,
            badge: 0,
            onTap: () {},
          ),

          const SizedBox(width: 12),

          // User Avatar
          MouseRegion(
            onEnter: (_) => setState(() => _isUserMenuHovered = true),
            onExit: (_) => setState(() => _isUserMenuHovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isUserMenuHovered
                        ? _sidebarSelected
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _sidebarSelected,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'M',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Header icon button with optional badge
class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final int badge;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    this.badge = 0,
    required this.onTap,
  });

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
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.grey.shade100
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                widget.icon,
                color: Colors.grey.shade600,
                size: 22,
              ),
              if (widget.badge > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.badge}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

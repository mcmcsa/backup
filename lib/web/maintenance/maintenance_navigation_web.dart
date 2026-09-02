import 'package:flutter/material.dart';
import '../../shared/models/work_request_model.dart';
import '../../shared/models/chat_model.dart';
import '../../shared/widgets/lazy_indexed_stack.dart';
import 'package:provider/provider.dart';
import '../../authentication/services/auth_service.dart';
import '../admin/shared/admin_styles.dart';
import '../../shared/services/app_notification_service.dart';
import '../../shared/utils/workflow_guide_dialog.dart';
import 'dashboard/maintenance_dashboard_web.dart';
import 'profile/maintenance_profile_web.dart';
import 'reports/maintenance_reports_web.dart';
import 'history/maintenance_history_web.dart';
import 'chat/maintenance_chat_page_web.dart';
import 'settings/maintenance_settings_web.dart';
import 'workflow/maintenance_workflow_web.dart';
import 'notifications/maintenance_notifications_web.dart';
import 'maintenance_nav_controller.dart';
import 'task/maintenance_task_details_web.dart';

class MaintenanceNavigationWeb extends StatefulWidget {
  final int initialIndex;

  const MaintenanceNavigationWeb({super.key, this.initialIndex = 0});

  @override
  State<MaintenanceNavigationWeb> createState() =>
      _MaintenanceNavigationWebState();
}

class _MaintenanceNavigationWebState extends State<MaintenanceNavigationWeb> {
  late int _selectedIndex;
  WorkRequest? _selectedRequestForDetails;
  ChatRoom? _selectedChatRoom;
  int _hoveredIndex = -1;
  bool _isUserMenuHovered = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const int _notificationsIndex = 7;
  int _unreadNotificationCount = 0;

  // ─── Design Tokens ────────────────────────────────────────────────────────
  static const _sidebarBg = Color(0xFF0F172A);       // Slate-900 (deeper)
  static const _sidebarBorder = Color(0xFF1E293B);   // Subtle internal divider
  static const _accent = Color(0xFF0EA5E9);           // Sky-500
  static const _sidebarHover = Color(0xFF1E293B);    // Slate-800
  static const _textWhite = Colors.white;
  static const _textMuted = Color(0xFF94A3B8);        // Slate-400
  static const _contentBg = Color(0xFFF1F5F9);        // Slate-100
  static const _badgeRed = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadUserInfo();
    _loadUnreadNotificationCount();
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final user = context.read<AuthService>().currentUser;
      if (user == null) return;
      final count = await AppNotificationService.getUnreadCount(
        userId: user.id,
        role: user.role.name,
      );
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUserInfo() async {
    // Info is now dynamically loaded in build()
  }

  Future<void> _handleLogout() async {
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
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: _badgeRed.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.logout_rounded, color: _badgeRed, size: 30),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Logout',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Are you sure you want to logout of the maintenance portal?',
                          style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _badgeRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop(true),
                            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
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
      children: [
        const MaintenanceDashboardWeb(),
        const MaintenanceReportsWeb(),
        MaintenanceChatPageWeb(
          key: ValueKey('chat-page-${_selectedChatRoom?.id}'),
          initialRoom: _selectedChatRoom,
        ),
        const MaintenanceHistoryWeb(),
        const MaintenanceProfileWeb(),
        const MaintenanceSettingsWeb(),
        const MaintenanceWorkflowWeb(),
        const MaintenanceNotificationsWeb(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaintenanceNavController(
      navigateTo: (index, {request, chatRoom}) {
        setState(() {
          _selectedIndex = index;
          _selectedRequestForDetails = request;
          if (chatRoom != null) {
            _selectedChatRoom = chatRoom;
          }
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
                width: 270,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                child: _buildSidebar(width: 270, closeDrawerOnTap: true),
              ),
              body: Column(
                children: [
                  _buildHeader(isCompact: true, onMenuTap: () => _scaffoldKey.currentState?.openDrawer()),
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

  Widget _buildSidebar({double width = 250, bool closeDrawerOnTap = false}) {
    final user = context.watch<AuthService>().currentUser;
    final userName = user?.name ?? 'Maintenance';
    final userSpecialization = user?.position ?? 'Maintenance Staff';
    final userAvatarUrl = user?.profileImage;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: _sidebarBg,
        border: Border(right: BorderSide(color: _sidebarBorder)),
      ),
      child: Column(
        children: [
          // ── Logo / Brand Header ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _sidebarBorder.withValues(alpha: 0.8))),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/app_logo_v2.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PSU MMS',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textWhite, letterSpacing: -0.3),
                      ),
                      Text(
                        'MAINTENANCE PORTAL',
                        style: TextStyle(fontSize: 10, color: _textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable Navigation Items ────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  // ── NAVIGATION Section ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'NAVIGATION',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _textMuted.withValues(alpha: 0.5), letterSpacing: 1.2),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        _buildNavItem(index: 0, icon: Icons.dashboard_rounded, title: 'Dashboard', closeDrawerOnTap: closeDrawerOnTap),
                        _buildNavItem(index: 1, icon: Icons.assignment_rounded, title: 'Work Tasks', closeDrawerOnTap: closeDrawerOnTap),
                        _buildNavItem(index: 2, icon: Icons.chat_bubble_outline_rounded, title: 'Messages', closeDrawerOnTap: closeDrawerOnTap),
                        _buildNavItem(index: 3, icon: Icons.history_rounded, title: 'History', closeDrawerOnTap: closeDrawerOnTap),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── ACCOUNT Section ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ACCOUNT',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _textMuted.withValues(alpha: 0.5), letterSpacing: 1.2),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        _buildNavItem(index: 4, icon: Icons.person_outline_rounded, title: 'Profile', closeDrawerOnTap: closeDrawerOnTap),
                        _buildNavItem(index: 5, icon: Icons.settings_outlined, title: 'Settings', closeDrawerOnTap: closeDrawerOnTap),
                        _buildNavItem(index: 6, icon: Icons.account_tree_outlined, title: 'Work Flow', closeDrawerOnTap: closeDrawerOnTap),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom Anchored User Profile & Logout ───────────────────────
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _sidebarBorder)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _sidebarHover,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _sidebarBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          image: userAvatarUrl != null && userAvatarUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(userAvatarUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: (userAvatarUrl == null || userAvatarUrl.isEmpty)
                            ? Center(
                                child: Text(
                                  userName.isNotEmpty ? userName[0].toUpperCase() : 'M',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textWhite), overflow: TextOverflow.ellipsis),
                            Text(userSpecialization, style: const TextStyle(fontSize: 11, color: _textMuted), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  child: _buildLogoutButton(),
                ),
              ],
            ),
          ),
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
      padding: const EdgeInsets.only(bottom: 2),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected
                  ? _accent.withValues(alpha: 0.15)
                  : isHovered
                      ? _sidebarHover
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border(left: BorderSide(color: _accent, width: 3))
                  : null,
            ),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? _accent : _textMuted, size: 19),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? _textWhite : _textMuted,
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _badgeRed, borderRadius: BorderRadius.circular(10)),
                    child: Text('$badge', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _badgeRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _badgeRed.withValues(alpha: 0.2)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFFCA5A5), size: 17),
              SizedBox(width: 8),
              Text('Logout', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFFCA5A5))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({bool isCompact = false, VoidCallback? onMenuTap}) {
    final user = context.watch<AuthService>().currentUser;
    final userName = user?.name ?? 'Maintenance';
    final userAvatarUrl = user?.profileImage;

    return Container(
      height: 70,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isCompact) ...[
            IconButton(
              onPressed: onMenuTap,
              icon: Icon(Icons.menu_rounded, color: AdminStyles.textPrimary),
              tooltip: 'Open menu',
            ),
            const SizedBox(width: 4),
          ],
          
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pangasinan State University',
              style: AdminStyles.headingStyle(
                fontSize: isCompact ? 15 : 18,
                fontWeight: FontWeight.bold,
                color: AdminStyles.primary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          
          // Guide Button
          IconButton(
            onPressed: () {
              final user = context.read<AuthService>().currentUser;
              showWorkflowGuideDialog(context, role: user?.role.name);
            },
            icon: const Icon(Icons.help_outline_rounded, color: AdminStyles.textSecondary),
            tooltip: 'Workflow Guide',
          ),
          const SizedBox(width: 8),
          
          // Notification button — shows label on wide, icon-only on compact
          _NotificationButton(
            showLabel: !isCompact,
            onTap: () => setState(() => _selectedIndex = _notificationsIndex),
            badge: _unreadNotificationCount,
          ),
          const SizedBox(width: 12),
          
          // User Avatar
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isUserMenuHovered = true),
            onExit: (_) => setState(() => _isUserMenuHovered = false),
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = 4), // 4 is MaintenanceProfileWeb
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  image: userAvatarUrl != null && userAvatarUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(userAvatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (userAvatarUrl == null || userAvatarUrl.isEmpty)
                    ? Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'M',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationButton extends StatefulWidget {
  final bool showLabel;
  final VoidCallback onTap;
  final int badge;
  const _NotificationButton({required this.showLabel, required this.onTap, required this.badge});

  @override
  State<_NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<_NotificationButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.showLabel ? 14 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFF0EA5E9).withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered ? const Color(0xFF0EA5E9).withValues(alpha: 0.15) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: widget.badge > 0,
                label: Text('${widget.badge}'),
                child: Icon(
                  Icons.notifications_outlined,
                  color: _isHovered ? const Color(0xFF0EA5E9) : const Color(0xFF94A3B8),
                  size: 22,
                ),
              ),
              if (widget.showLabel) ...[
                const SizedBox(width: 8),
                Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isHovered ? const Color(0xFF0EA5E9) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

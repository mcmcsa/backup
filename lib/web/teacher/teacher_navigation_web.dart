import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../authentication/services/auth_service.dart';
import '../../../shared/utils/workflow_guide_dialog.dart';
import 'dashboard/teacher_dashboard_web.dart';
import 'profile/teacher_profile_web.dart';
import 'reports/teacher_reports_web.dart';
import 'reports/teacher_work_process_web.dart';
import 'logs/teacher_logs_web.dart';
import 'scanner/teacher_scanner_web.dart';
import 'menu/teacher_settings_web.dart';
import 'menu/teacher_about_web.dart';
import 'menu/teacher_contact_web.dart';
import 'menu/teacher_workflow_web.dart';
import 'menu/teacher_archives_web.dart';
import '../admin/shared/admin_styles.dart';
import 'reports/teacher_create_request_web.dart';
import 'chat/teacher_chat_web.dart';
import 'notifications/teacher_notifications_web.dart';
import '../../shared/widgets/lazy_indexed_stack.dart';
import '../../shared/widgets/announcements/global_announcement_listener.dart';
import '../../shared/models/work_request_model.dart';
import '../../shared/models/chat_model.dart';
import 'teacher_nav_controller.dart';

class TeacherNavigationWeb extends StatefulWidget {
  final int initialIndex;

  const TeacherNavigationWeb({super.key, this.initialIndex = 0});

  @override
  State<TeacherNavigationWeb> createState() => _TeacherNavigationWebState();
}

class _TeacherNavigationWebState extends State<TeacherNavigationWeb> {
  late int _selectedIndex;
  int _hoveredIndex = -1;
  bool _isLogoutHovered = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String? _createRoomId;
  String? _createRoomName;
  String? _createBuildingName;
  String? _createFloor;
  String? _createDepartmentName;
  WorkRequest? _selectedRequestForDetails;
  ChatRoom? _selectedChatRoom;

  int _unreadNotificationCount = 0;
  RealtimeChannel? _notificationsChannel;

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;
      if (currentUser == null) return;

      final count = await AppNotificationService.getUnreadCount(
        role: currentUser.role.name,
        userId: currentUser.id,
      );
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    } catch (_) {}
  }

  void _subscribeNotifications() {
    final authService = context.read<AuthService>();
    final currentUser = authService.currentUser;
    if (currentUser == null) return;

    _notificationsChannel = Supabase.instance.client
        .channel('teacher_notifications_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_notifications',
          callback: (payload) {
            _loadUnreadNotificationCount();
          },
        )
        .subscribe();
  }

  // Professional color palette
  static const _sidebarBg = Color(0xFF0F172A);
  static const _sidebarSelected = Color(0xFF00BFA5);
  static const _sidebarHover = Color(0xFF1E293B);
  static const _textWhite = Colors.white;
  static const _textMuted = Color(0xFF94A3B8);
  static const _contentBg = Color(0xFFF8FAFC);
  static const _badgeRed = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadUnreadNotificationCount();
    _subscribeNotifications();
  }

  @override
  void dispose() {
    if (_notificationsChannel != null) {
      Supabase.instance.client.removeChannel(_notificationsChannel!);
    }
    super.dispose();
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
                          child: const Icon(Icons.logout_rounded, color: _badgeRed, size: 28),
                        ),
                        const SizedBox(height: 16),
                        Text('Logout', style: AdminStyles.headingStyle(fontSize: 18)),
                        const SizedBox(height: 8),
                        Text('Are you sure you want to logout?', style: AdminStyles.bodyStyle()),
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
                            child: const Text('Logout'),
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
    return LazyIndexedStack(
      index: _selectedIndex,
      children: [
        const TeacherDashboardWeb(),
        const TeacherLogsWeb(),
        const TeacherScannerWeb(),
        _selectedRequestForDetails != null
            ? TeacherWorkProcessWeb(
                key: ValueKey('work-process-${_selectedRequestForDetails!.id}'),
                request: _selectedRequestForDetails!,
                onBack: () {
                  setState(() {
                    _selectedRequestForDetails = null;
                  });
                },
              )
            : const TeacherReportsWeb(),
        TeacherChatWeb(
          key: ValueKey('chat-page-${_selectedChatRoom?.id}'),
          initialRoom: _selectedChatRoom,
        ),
        const TeacherArchivesWeb(),
        const TeacherProfileWeb(),
        const TeacherAboutWeb(),
        const TeacherSystemWorkflowWeb(),
        const TeacherSettingsWeb(),
        const TeacherContactWeb(),
        TeacherCreateRequestWeb(
          key: ValueKey('$_createRoomId-$_createRoomName-$_createBuildingName-$_createFloor'),
          roomId: _createRoomId,
          roomName: _createRoomName,
          buildingName: _createBuildingName,
          floor: _createFloor,
          departmentName: _createDepartmentName,
        ),
        const TeacherNotificationsWeb(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlobalAnnouncementListener(
      child: LayoutBuilder(
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
                  child: TeacherNavController(
                    navigateTo: (i, {roomId, roomName, buildingName, floor, departmentName, request, chatRoom}) {
                      setState(() {
                        _selectedIndex = i;
                        _selectedRequestForDetails = request;
                        if (chatRoom != null) {
                          _selectedChatRoom = chatRoom;
                        }
                        if (i == 11) {
                          _createRoomId = roomId;
                          _createRoomName = roomName;
                          _createBuildingName = buildingName;
                          _createFloor = floor;
                          _createDepartmentName = departmentName;
                        }
                      });
                    },
                    child: Container(
                      decoration: const BoxDecoration(color: _contentBg),
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: _buildIndexedStack(),
                      ),
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
                      child: TeacherNavController(
                        navigateTo: (i, {roomId, roomName, buildingName, floor, departmentName, request, chatRoom}) {
                          setState(() {
                            _selectedIndex = i;
                            _selectedRequestForDetails = request;
                            if (chatRoom != null) {
                              _selectedChatRoom = chatRoom;
                            }
                            if (i == 11) {
                              _createRoomId = roomId;
                              _createRoomName = roomName;
                              _createBuildingName = buildingName;
                              _createFloor = floor;
                              _createDepartmentName = departmentName;
                            }
                          });
                        },
                        child: Container(
                          color: _contentBg,
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1400),
                            child: _buildIndexedStack(),
                          ),
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

  Widget _buildSidebar({double width = 260, bool closeDrawerOnTap = false}) {
    return Container(
      width: width,
      decoration: const BoxDecoration(color: _sidebarBg),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _textWhite,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'FACULTY',
                        style: TextStyle(
                          fontSize: 10,
                          color: _textMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                children: [
                  _buildNavItem(index: 0, icon: Icons.dashboard_rounded, title: 'Home', closeDrawerOnTap: closeDrawerOnTap),
                  _buildNavItem(index: 1, icon: Icons.history_rounded, title: 'Logs', closeDrawerOnTap: closeDrawerOnTap),
                  _buildNavItem(index: 2, icon: Icons.qr_code_2_rounded, title: 'Scanner', closeDrawerOnTap: closeDrawerOnTap),
                  _buildNavItem(index: 3, icon: Icons.assessment_rounded, title: 'Reports', closeDrawerOnTap: closeDrawerOnTap),
                  _buildNavItem(index: 4, icon: Icons.message_rounded, title: 'Messages', closeDrawerOnTap: closeDrawerOnTap),
                  _buildNavItem(index: 5, icon: Icons.archive_rounded, title: 'Archives', closeDrawerOnTap: closeDrawerOnTap),
                  _buildNavItem(index: 6, icon: Icons.person_rounded, title: 'Profile', closeDrawerOnTap: closeDrawerOnTap),
                  _buildNavItem(index: 9, icon: Icons.settings_rounded, title: 'Settings', closeDrawerOnTap: closeDrawerOnTap),
                  _buildNavItem(index: 7, icon: Icons.info_rounded, title: 'About us', closeDrawerOnTap: closeDrawerOnTap),
                  _buildNavItem(index: 8, icon: Icons.schema_rounded, title: 'System Work Flow', closeDrawerOnTap: closeDrawerOnTap),
                ],
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: _buildLogoutButton()),
        ],
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
            setState(() {
              _selectedIndex = index;
              _selectedRequestForDetails = null;
            });
            if (closeDrawerOnTap && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
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
      onEnter: (_) => setState(() => _isLogoutHovered = true),
      onExit: (_) => setState(() => _isLogoutHovered = false),
      child: GestureDetector(
        onTap: _handleLogout,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: _isLogoutHovered
                ? const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: _isLogoutHovered ? null : const Color(0xFFEF4444).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isLogoutHovered ? Colors.transparent : const Color(0xFFEF4444).withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: _isLogoutHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout_rounded,
                color: _isLogoutHovered ? Colors.white : const Color(0xFFFCA5A5),
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _isLogoutHovered ? Colors.white : const Color(0xFFFCA5A5),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({bool isCompact = false, VoidCallback? onMenuTap}) {
    final user = context.watch<AuthService>().currentUser;
    final userName = user?.name ?? 'Faculty';
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
              icon: const Icon(Icons.menu_rounded, color: AdminStyles.textPrimary),
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
            onTap: () => setState(() => _selectedIndex = 12),
            badge: _unreadNotificationCount,
          ),
          const SizedBox(width: 12),
          
          // User Avatar
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = 6), // 6 is TeacherProfileWeb
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00BFA5), Color(0xFF0F766E)],
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
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'T',
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
            color: _isHovered ? const Color(0xFFF1F5F9) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered ? const Color(0xFFE2E8F0) : Colors.transparent,
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
                  color: _isHovered ? const Color(0xFF0F766E) : Colors.grey.shade600,
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
                    color: _isHovered ? const Color(0xFF0F766E) : Colors.grey.shade700,
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


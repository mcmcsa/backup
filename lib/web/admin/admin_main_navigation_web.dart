import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../shared/widgets/announcements/global_announcement_listener.dart';
import '../../authentication/services/auth_service.dart';
import '../../../shared/utils/workflow_guide_dialog.dart';
import '../../shared/models/room_model.dart';
import '../../shared/models/chat_model.dart';
import 'shared/admin_styles.dart';
import '../../shared/screens/unified_dashboard_page.dart';
import 'users/admin_users_web.dart';
import 'profile/admin_profile_web.dart';
import '../../../shared/screens/unified_analytics_page.dart';
import 'analytics/admin_cost_tracking_dashboard_web.dart';
import 'work_requests/admin_work_requests_web.dart';
import 'tickets/maintenance/maintenance_management_page_web.dart';
import 'facilities/rooms/add_room_page.dart';
import 'facilities/rooms/admin_rooms_web.dart';
import 'facilities/rooms/admin_edit_room_page_web.dart';
import 'facilities/rooms/admin_qr_history_page_web.dart';
import 'facilities/rooms/admin_room_details_page_web.dart';
import 'tickets/tickets_page_web.dart';
import 'tickets/maintenance_history_page_web.dart';
import 'facilities/admin_buildings_web.dart';
import 'facilities/admin_departments_web.dart';
import 'facilities/admin_room_types_web.dart';
import 'facilities/admin_floors_web.dart';
import 'facilities/admin_request_types_web.dart';
import 'facilities/facility_quick_actions_row.dart';
import 'shared/admin_logs_web.dart';
import 'shared/admin_notifications_web.dart';
import 'shared/about_system_page.dart';
import 'shared/settings_page_web.dart';
import 'chat/admin_chat_page_web.dart';
import '../../shared/models/work_request_model.dart';
import 'tickets/admin_work_process_web.dart';
import 'admin_nav_controller.dart';

class AdminMainNavigationWeb extends StatefulWidget {
  static const int aboutIndex = 17;
  static const int chatIndex = 20;
  final int initialIndex;

  const AdminMainNavigationWeb({super.key, this.initialIndex = 0});

  @override
  State<AdminMainNavigationWeb> createState() => _AdminMainNavigationWebState();
}

class _AdminMainNavigationWebState extends State<AdminMainNavigationWeb> {
  static const int _dashboardIndex = 0;
  static const int _analyticsIndex = 1;
  static const int _workRequestsIndex = 2;
  static const int _ticketsIndex = 3;
  static const int _departmentsIndex = 4;
  static const int _buildingsIndex = 5;
  static const int _floorsIndex = 6;
  static const int _roomTypesIndex = 7;
  static const int _roomsIndex = 8;
  static const int _usersIndex = 9;
  static const int _logsIndex = 10;
  static const int _notificationsIndex = 11;
  static const int _profileIndex = 12;
  static const int _historyIndex = 13;
  static const int _maintenanceIndex = 14;
  static const int _requestTypesIndex = 15;
  static const int _settingsIndex = 16;
  static const int _qrHistoryIndex = 18;
  static const int _costTrackingIndex = 19;
  static const int _chatIndex = 20;
  static const int _roomsSubviewList = 0;
  static const int _roomsSubviewAdd = 1;
  static const int _roomsSubviewEdit = 2;
  static const int _roomsSubviewDetails = 3;
  static const int _ticketsSubviewList = 0;
  static const int _ticketsSubviewProcess = 1;
  static const FacilityQuickActionsConfig _facilityQuickActionsConfig =
      FacilityQuickActionsConfig(
        departmentsIndex: _departmentsIndex,
        buildingsIndex: _buildingsIndex,
        floorsIndex: _floorsIndex,
        roomTypesIndex: _roomTypesIndex,
        requestTypesIndex: _requestTypesIndex,
      );

  // State and style helpers
  late int _selectedIndex;
  String _userName = 'Administrator';
  int _hoveredIndex = -1;
  bool _isUserMenuHovered = false;
  bool _isMenuExpanded = true;
  int _roomsSubview = _roomsSubviewList;
  Room? _selectedRoom;
  int _ticketsSubview = _ticketsSubviewList;
  WorkRequest? _selectedTicket;
  ChatRoom? _selectedChatRoom;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _sidebarScrollController = ScrollController();

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
        .channel('admin_notifications_realtime')
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

  // Design Tokens (Mapping AdminStyles for internal use)
  static const _sidebarBg = Color(0xFF0B1F33);
  static const _sidebarBorder = Color(0xFF17324A);
  static const _sidebarSelected = AdminStyles.primaryLight;
  static const _textMuted = AdminStyles.textMuted;
  static const _headerBg = AdminStyles.surface;
  static const _contentBg = AdminStyles.bg;
  static const _errorRed = AdminStyles.error;
  // static const _primaryTeal = AdminStyles.primary;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadUserInfo();
    _loadUnreadNotificationCount();
    _subscribeNotifications();
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
                            color: _errorRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: _errorRed,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AdminStyles.textPrimary,
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
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.vertical(
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
                              backgroundColor: _errorRed,
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

  Widget _getCurrentPage() {
    switch (_selectedIndex) {
      case _dashboardIndex:
        return UnifiedDashboardPage(
          onViewAllWorkRequests: () {
            setState(() {
              _selectedIndex = _ticketsIndex; // Switch to Tickets tab
            });
          },
        );
      case _analyticsIndex:
        return const UnifiedAnalyticsPage();
      case _costTrackingIndex:
        return const AdminCostTrackingDashboardWeb();
      case _workRequestsIndex:
        return const AdminWorkRequestsWeb();
      case _ticketsIndex:
        if (_ticketsSubview == _ticketsSubviewProcess && _selectedTicket != null) {
          return AdminWorkProcessWeb(
            request: _selectedTicket!,
            onBack: () => setState(() => _ticketsSubview = _ticketsSubviewList),
          );
        }
        return TicketsPageWeb(
          onViewDetails: (request) {
            setState(() {
              _selectedTicket = request;
              _ticketsSubview = _ticketsSubviewProcess;
            });
          },
        );
      case _maintenanceIndex:
        return const MaintenanceManagementPageWeb();
      case _departmentsIndex:
        return AdminDepartmentsWeb(
          activeIndex: _selectedIndex,
          onNavigate: _handleFacilityQuickNavigate,
          quickActionsConfig: _facilityQuickActionsConfig,
        );
      case _buildingsIndex:
        return AdminBuildingsWeb(
          activeIndex: _selectedIndex,
          onNavigate: _handleFacilityQuickNavigate,
          quickActionsConfig: _facilityQuickActionsConfig,
        );
      case _floorsIndex:
        return AdminFloorsWeb(
          activeIndex: _selectedIndex,
          onNavigate: _handleFacilityQuickNavigate,
          quickActionsConfig: _facilityQuickActionsConfig,
        );
      case _roomTypesIndex:
        return AdminRoomTypesWeb(
          activeIndex: _selectedIndex,
          onNavigate: _handleFacilityQuickNavigate,
          quickActionsConfig: _facilityQuickActionsConfig,
        );
      case _requestTypesIndex:
        return AdminRequestTypesWeb(
          activeIndex: _selectedIndex,
          onNavigate: _handleFacilityQuickNavigate,
          quickActionsConfig: _facilityQuickActionsConfig,
        );
      case _roomsIndex:
        if (_roomsSubview == _roomsSubviewAdd) {
          return AddRoomPage(onClose: _backToRoomsList);
        }
        if (_roomsSubview == _roomsSubviewEdit && _selectedRoom != null) {
          return AdminEditRoomPageWeb(
            room: _selectedRoom!,
            onClose: _backToRoomsList,
          );
        }
        if (_roomsSubview == _roomsSubviewDetails && _selectedRoom != null) {
          return AdminRoomDetailsPageWeb(
            room: _selectedRoom!,
            onEditRoom: _openEditRoomInShell,
            onBack: _backToRoomsList,
          );
        }

        return AdminRoomsWeb(
          onAddRoom: _openAddRoomInShell,
          onEditRoom: _openEditRoomInShell,
          onViewRoom: _openRoomDetailsInShell,
        );
      case _usersIndex:
        return const AdminUsersWeb();
      case _profileIndex:
        return const AdminProfileWeb();
      case _logsIndex:
        return const AdminLogsWeb();
      case _notificationsIndex:
        return const AdminNotificationsWeb();
      case _historyIndex:
        return const MaintenanceHistoryPageWeb();
      case _settingsIndex:
        return const SettingsPageWeb();
      case AdminMainNavigationWeb.aboutIndex:
        return const AboutSystemPage();
      case _qrHistoryIndex:
        return const AdminQrHistoryPageWeb();
      case _chatIndex:
        return AdminChatPageWeb(initialRoom: _selectedChatRoom);
      default:
        return Container(); // Fallback
    }
  }

  void _handleFacilityQuickNavigate(int index) {
    setState(() => _selectedIndex = index);
  }

  void _openAddRoomInShell() {
    setState(() {
      _selectedIndex = _roomsIndex;
      _roomsSubview = _roomsSubviewAdd;
    });
  }

  void _openEditRoomInShell(Room room) {
    setState(() {
      _selectedIndex = _roomsIndex;
      _selectedRoom = room;
      _roomsSubview = _roomsSubviewEdit;
    });
  }

  void _openRoomDetailsInShell(Room room) {
    setState(() {
      _selectedIndex = _roomsIndex;
      _selectedRoom = room;
      _roomsSubview = _roomsSubviewDetails;
    });
  }

  void _backToRoomsList() {
    setState(() {
      _selectedIndex = _roomsIndex;
      _roomsSubview = _roomsSubviewList;
      _selectedRoom = null;
    });
  }

  @override
  void dispose() {
    if (_notificationsChannel != null) {
      Supabase.instance.client.removeChannel(_notificationsChannel!);
    }
    _sidebarScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminNavController(
      navigateTo: (index, {request, chatRoom}) {
        setState(() {
          _selectedIndex = index;
          if (request != null) {
            _selectedTicket = request;
            _ticketsSubview = _ticketsSubviewProcess;
          }
          if (chatRoom != null) {
            _selectedChatRoom = chatRoom;
          }
        });
      },
      openWorkProcess: (request) {
        setState(() {
          _selectedIndex = _ticketsIndex;
          _selectedTicket = request;
          _ticketsSubview = _ticketsSubviewProcess;
        });
      },
      child: GlobalAnnouncementListener(
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
                ),
              ],
            ),
          );
        },
        ),
      ),
    );
  }

  Widget _buildSidebar({double width = 260, bool closeDrawerOnTap = false}) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: _sidebarBg,
        border: Border(right: BorderSide(color: _sidebarBorder, width: 1)),
      ),
      child: Column(
        children: [
          // Logo Section with updated branding
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _sidebarBorder, width: 1)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/app_logo_v2.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PSU MMS',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'CAMPUS ADMINISTRATOR',
                        style: TextStyle(
                          fontSize: 11,
                          color: _textMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Navigation Items
          Expanded(
            child: Scrollbar(
              controller: _sidebarScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _sidebarScrollController,
                primary: false,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    _buildNavItem(
                      index: _dashboardIndex,
                      icon: Icons.home_rounded,
                      title: 'Home',
                      closeDrawerOnTap: closeDrawerOnTap,
                    ),
                    _buildNavItem(
                      index: _roomsIndex,
                      icon: Icons.meeting_room_outlined,
                      title: 'Rooms',
                      closeDrawerOnTap: closeDrawerOnTap,
                    ),
                    _buildNavItem(
                      index: _ticketsIndex,
                      icon: Icons.confirmation_num_rounded,
                      title: 'Tickets',
                      closeDrawerOnTap: closeDrawerOnTap,
                    ),
                    _buildNavItem(
                      index: _analyticsIndex,
                      icon: Icons.query_stats_rounded,
                      title: 'Stats',
                      closeDrawerOnTap: closeDrawerOnTap,
                    ),
                    _buildNavItem(
                      index: _chatIndex,
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Messages',
                      closeDrawerOnTap: closeDrawerOnTap,
                    ),
                    _buildNavItem(
                      index: _qrHistoryIndex,
                      icon: Icons.qr_code_2_rounded,
                      title: 'QR Management',
                      closeDrawerOnTap: closeDrawerOnTap,
                    ),

                    _buildNavItem(
                      index: _usersIndex,
                      icon: Icons.people_rounded,
                      title: 'Users',
                      closeDrawerOnTap: closeDrawerOnTap,
                    ),
                    _buildNavItem(
                      index: _maintenanceIndex,
                      icon: Icons.engineering_rounded,
                      title: 'Maintenance',
                      closeDrawerOnTap: closeDrawerOnTap,
                    ),
                    _buildNavItem(
                      index: _logsIndex,
                      icon: Icons.receipt_long_rounded,
                      title: 'Logs',
                      closeDrawerOnTap: closeDrawerOnTap,
                    ),
                    _buildNavItem(
                      index: _historyIndex,
                      icon: Icons.history_rounded,
                      title: 'History',
                      closeDrawerOnTap: closeDrawerOnTap,
                    ),
                    _buildNavItem(
                      index: _settingsIndex,
                      icon: Icons.settings_rounded,
                      title: 'Settings',
                      closeDrawerOnTap: closeDrawerOnTap,
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),

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
    double inset = 0,
    bool closeDrawerOnTap = false,
  }) {
    final isSelected = _selectedIndex == index;
    final isHovered = _hoveredIndex == index;

    return Padding(
      padding: EdgeInsets.only(left: inset, bottom: 6, right: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredIndex = index),
        onExit: (_) => setState(() => _hoveredIndex = -1),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedIndex = index;
              _roomsSubview = _roomsSubviewList;
              _selectedRoom = null;
            });
            if (closeDrawerOnTap && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: AdminStyles.sidebarItemDecoration(isActive: isSelected).copyWith(
              color: isSelected
                  ? _sidebarSelected.withValues(alpha: 0.15)
                  : isHovered
                      ? _sidebarBorder.withValues(alpha: 0.3)
                      : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? _sidebarSelected : _textMuted,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: AdminStyles.bodyStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected ? Colors.white : _textMuted,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: _sidebarSelected,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (badge > 0 && !isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: AdminStyles.pillDecoration(color: _errorRed),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
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

  Widget _buildDropdownHeader({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    double inset = 0,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: inset, bottom: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: _sidebarBorder.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _sidebarBorder.withValues(alpha: 0.65)),
            ),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: _textMuted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: AdminStyles.bodyStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textMuted,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: AdminStyles.pillDecoration(color: _errorRed, isSecondary: true),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.power_settings_new_rounded,
                color: Color(0xFFFCA5A5),
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                'LOGOUT',
                style: AdminStyles.headingStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFCA5A5),
                  letterSpacing: 1,
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
      height: 72,
      decoration: BoxDecoration(
        color: _headerBg,
        border: Border(bottom: BorderSide(color: AdminStyles.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 32),
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
          Row(
            children: [
              SizedBox(
                width: isCompact ? 160 : null,
                child: Text(
                  'PANGASINAN STATE UNIVERSITY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminStyles.headingStyle(
                    fontSize: isCompact ? 11 : 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F766E),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // Guide Button
          IconButton(
            onPressed: () {
              final user = context.read<AuthService>().currentUser;
              showWorkflowGuideDialog(context, role: user?.role.name);
            },
            icon: const Icon(Icons.help_outline_rounded, color: AdminStyles.textSecondary),
            tooltip: 'Workflow Guide',
          ),

          SizedBox(width: isCompact ? 8 : 16),

          // Notification Bell with badge
          _NotificationButton(
            showLabel: !isCompact,
            badge: _unreadNotificationCount,
            onTap: () => setState(() => _selectedIndex = _notificationsIndex),
          ),

          SizedBox(width: isCompact ? 8 : 16),

          // User Avatar - Professional styling
          MouseRegion(
            onEnter: (_) => setState(() => _isUserMenuHovered = true),
            onExit: (_) => setState(() => _isUserMenuHovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = _profileIndex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isUserMenuHovered ? _sidebarSelected : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: _isUserMenuHovered
                      ? [
                          BoxShadow(
                            color: _sidebarSelected.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_sidebarSelected, _sidebarSelected.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
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

  // Widget _buildFacilityQuickActions() {
  //   final quickActions = <Map<String, dynamic>>[
  //     {
  //       'label': 'Department',
  //       'icon': Icons.account_tree_rounded,
  //       'index': _departmentsIndex,
  //     },
  //     {
  //       'label': 'Building',
  //       'icon': Icons.apartment_rounded,
  //       'index': _buildingsIndex,
  //     },
  //     {
  //       'label': 'Floor',
  //       'icon': Icons.layers_rounded,
  //       'index': _floorsIndex,
  //     },
  //     {
  //       'label': 'Room Type',
  //       'icon': Icons.category_rounded,
  //       'index': _roomTypesIndex,
  //     },
  //     {
  //       'label': 'Request Type',
  //       'icon': Icons.assignment_rounded,
  //       'index': _requestTypesIndex,
  //     },
  //   ];
  //
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
  //     decoration: const BoxDecoration(color: Colors.white),
  //     child: SingleChildScrollView(
  //       scrollDirection: Axis.horizontal,
  //       child: Row(
  //         children: quickActions.map((action) {
  //           final targetIndex = action['index'] as int;
  //           final isSelected = _selectedIndex == targetIndex;
  //
  //           return Padding(
  //             padding: const EdgeInsets.only(right: 10),
  //             child: OutlinedButton.icon(
  //               onPressed: () => setState(() => _selectedIndex = targetIndex),
  //               icon: Icon(action['icon'] as IconData, size: 18),
  //               label: Text(action['label'] as String),
  //               style: OutlinedButton.styleFrom(
  //                 foregroundColor: isSelected ? Colors.white : AdminStyles.textSecondary,
  //                 backgroundColor: isSelected ? AdminStyles.primary : Colors.white,
  //                 side: BorderSide(
  //                   color: isSelected ? AdminStyles.primary : AdminStyles.border,
  //                 ),
  //                 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  //                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  //                 textStyle: const TextStyle(
  //                   fontSize: 13,
  //                   fontWeight: FontWeight.w600,
  //                 ),
  //               ),
  //             ),
  //           );
  //         }).toList(),
  //       ),
  //     ),
  //   );
  // }
}

/// Header icon button with professional styling and badge support
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: _isHovered
              ? AdminStyles.glassDecoration(
                  color: const Color(0xFFF1F5F9),
                  opacity: 1.0,
                  borderRadius: 12,
                )
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.transparent),
                ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                widget.icon,
                color: _isHovered ? AdminStyles.primary : const Color(0xFF94A3B8),
                size: 22,
              ),
              if (widget.badge > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AdminStyles.error,
                      shape: BoxShape.circle,
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
            color: _isHovered ? AdminStyles.primary.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered ? AdminStyles.primary.withValues(alpha: 0.15) : Colors.transparent,
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
                  color: _isHovered ? AdminStyles.primary : const Color(0xFF94A3B8),
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
                    color: _isHovered ? AdminStyles.primary : const Color(0xFF64748B),
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

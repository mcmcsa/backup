import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../authentication/services/auth_service.dart';
import '../../shared/utils/workflow_guide_dialog.dart';


import 'screens/system_admin_dashboard_view.dart';
import 'screens/system_admin_users_view.dart';
import 'screens/system_admin_qr_management_view.dart';
import '../../shared/models/room_model.dart';
import 'screens/system_admin_reports_view.dart';
import '../admin/facilities/rooms/add_room_page.dart';
import '../admin/facilities/rooms/admin_rooms_web.dart';
import '../admin/facilities/rooms/admin_edit_room_page_web.dart';
import '../admin/facilities/rooms/admin_room_details_page_web.dart';

import '../admin/facilities/admin_departments_web.dart';
import '../admin/facilities/admin_buildings_web.dart';
import '../admin/facilities/admin_floors_web.dart';
import '../admin/facilities/admin_room_types_web.dart';
import '../admin/facilities/admin_request_types_web.dart';
import '../admin/facilities/facility_quick_actions_row.dart';
import 'screens/system_admin_feedback_view.dart';
import 'screens/system_admin_announcements_view.dart';
import 'screens/system_admin_audit_logs_view.dart';
import 'screens/system_admin_system_health_view.dart';
import 'screens/system_admin_backup_restore_view.dart';
import 'screens/system_admin_settings_view.dart';
import '../../shared/widgets/announcements/global_announcement_listener.dart';

class SystemAdminMainNavigationWeb extends StatefulWidget {
  const SystemAdminMainNavigationWeb({super.key});

  @override
  State<SystemAdminMainNavigationWeb> createState() =>
      _SystemAdminMainNavigationWebState();
}

class _SystemAdminMainNavigationWebState
    extends State<SystemAdminMainNavigationWeb> {
  // Navigation State
  int _selectedIndex = 0;
  bool _isMenuExpanded = true;
  String _userName = 'System Administrator';

  int _roomsSubview = _roomsSubviewList;
  Room? _selectedRoom;

  static const int _roomsSubviewList = 0;
  static const int _roomsSubviewAdd = 1;
  static const int _roomsSubviewEdit = 2;
  static const int _roomsSubviewDetails = 3;

  // Colors
  static const _sidebarBg = Color(0xFF0F172A);
  static const _sidebarBorder = Color(0xFF1E293B);
  static const _contentBg = Color(0xFFF8FAFC);
  static const _primaryBlue = Color(0xFF0F766E); // Consistent Teal accent

  static const int _buildingsIndex = 2; // Default Facility Management
  static const int _departmentsIndex = 12;
  static const int _floorsIndex = 13;
  static const int _roomTypesIndex = 14;
  static const int _requestTypesIndex = 15;

  static const FacilityQuickActionsConfig _facilityQuickActionsConfig =
      FacilityQuickActionsConfig(
        departmentsIndex: _departmentsIndex,
        buildingsIndex: _buildingsIndex,
        floorsIndex: _floorsIndex,
        roomTypesIndex: _roomTypesIndex,
        requestTypesIndex: _requestTypesIndex,
      );

  void _handleFacilityQuickNavigate(int index) {
    setState(() => _selectedIndex = index);
  }

  void _openAddRoomInShell() {
    setState(() {
      _selectedIndex = 3;
      _roomsSubview = _roomsSubviewAdd;
    });
  }

  void _openEditRoomInShell(Room room) {
    setState(() {
      _selectedIndex = 3;
      _selectedRoom = room;
      _roomsSubview = _roomsSubviewEdit;
    });
  }

  void _openRoomDetailsInShell(Room room) {
    setState(() {
      _selectedIndex = 3;
      _selectedRoom = room;
      _roomsSubview = _roomsSubviewDetails;
    });
  }

  void _backToRoomsList() {
    setState(() {
      _selectedIndex = 3;
      _roomsSubview = _roomsSubviewList;
      _selectedRoom = null;
    });
  }

  @override
  void initState() {
    super.initState();
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
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: Colors.redAccent,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Are you sure you want to logout from System Management Console?',
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
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop(true),
                            child: const Text(
                              'Logout',
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

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'}, // 0
    {'icon': Icons.people_outline, 'label': 'Users Management'}, // 1
    {'icon': Icons.apartment_outlined, 'label': 'Facility Management'}, // 2
    {'icon': Icons.meeting_room_outlined, 'label': 'Rooms Management'}, // 3
    {'icon': Icons.qr_code_scanner_outlined, 'label': 'QR Management'}, // 4
    {'icon': Icons.bar_chart_rounded, 'label': 'Reports'}, // 5
    {'icon': Icons.feedback_outlined, 'label': 'Feedback'}, // 6
    {'icon': Icons.campaign_outlined, 'label': 'Announcements'}, // 7
    {'icon': Icons.history_edu, 'label': 'Audit Logs'}, // 8
    {'icon': Icons.monitor_heart_outlined, 'label': 'System Health'}, // 9
    {'icon': Icons.backup_outlined, 'label': 'Backup & Restore'}, // 10
    {'icon': Icons.settings_outlined, 'label': 'Settings'}, // 11
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 850;

    return GlobalAnnouncementListener(
      child: Scaffold(
        backgroundColor: _contentBg,
        drawer: isMobile
            ? Drawer(
                backgroundColor: _sidebarBg,
                child: _buildSidebarContents(isMobile: true),
              )
            : null,
        body: Row(
          children: [
            if (!isMobile) _buildSidebar(),
            Expanded(
              child: Column(
                children: [
                  _buildHeader(isMobile: isMobile),
                  Expanded(
                    child: Container(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey<int>(_selectedIndex),
                            child: _buildBodyContent(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 0:
        return SystemAdminDashboardView(
          onCreateUser: () => setState(() => _selectedIndex = 1),
          onAddDepartment: () => setState(() => _selectedIndex = 2),
          onGenerateQR: () => setState(() => _selectedIndex = 4),
          onBackupData: () => setState(() => _selectedIndex = 10),
        );
      case 1:
        return const SystemAdminUsersView();
      case 2:
        return AdminBuildingsWeb(
          activeIndex: _selectedIndex,
          onNavigate: _handleFacilityQuickNavigate,
          quickActionsConfig: _facilityQuickActionsConfig,
        );
      case 3:
        return Builder(
          builder: (context) {
            if (_roomsSubview == _roomsSubviewAdd) return AddRoomPage(onClose: _backToRoomsList);
            if (_roomsSubview == _roomsSubviewEdit && _selectedRoom != null) {
              return AdminEditRoomPageWeb(room: _selectedRoom!, onClose: _backToRoomsList);
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
              showAddEdit: true,
            );
          }
        );
      case 4:
        return const SystemAdminQrManagementView();
      case 5:
        return const SystemAdminReportsView();
      case 6:
        return const SystemAdminFeedbackView();
      case 7:
        return const SystemAdminAnnouncementsView();
      case 8:
        return const SystemAdminAuditLogsView();
      case 9:
        return const SystemAdminSystemHealthView();
      case 10:
        return const SystemAdminBackupRestoreView();
      case 11:
        return const SystemAdminSettingsView();
      case _departmentsIndex:
        return AdminDepartmentsWeb(
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
      default:
        return const Center(child: Text('Page not found'));
    }
  }

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      width: _isMenuExpanded ? 260 : 70,
      decoration: const BoxDecoration(
        color: _sidebarBg,
        border: Border(right: BorderSide(color: _sidebarBorder, width: 1)),
      ),
      child: ClipRect(
        child: _buildSidebarContents(isMobile: false),
      ),
    );
  }

  Widget _buildSidebarContents({required bool isMobile}) {
    return Column(
      children: [
        // Logo Section
        Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _sidebarBorder)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.tealAccent, size: 28),
              if (isMobile) ...[
                const SizedBox(width: 12),
                const Text(
                  'SYSTEM ADMIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ] else ...[
                Expanded(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    opacity: _isMenuExpanded ? 1.0 : 0.0,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        children: const [
                          SizedBox(width: 12),
                          Text(
                            'SYSTEM ADMIN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Nav Items
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            itemCount: _menuItems.length,
            itemBuilder: (context, index) {
              final item = _menuItems[index];
              return _buildSidebarNavItem(
                index: index,
                icon: item['icon'] as IconData,
                label: item['label'] as String,
                isMobile: isMobile,
              );
            },
          ),
        ),
        // Logout Button in Navigation Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: InkWell(
            onTap: _handleLogout,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  if (isMobile) ...[
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        opacity: _isMenuExpanded ? 1.0 : 0.0,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Row(
                            children: const [
                              SizedBox(width: 12),
                              Text(
                                'Logout',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (!isMobile) ...[
          const SizedBox(height: 4),
          // Collapse Toggle aligned to the far right with smooth rotation
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            alignment: _isMenuExpanded ? Alignment.centerRight : Alignment.center,
            child: Padding(
              padding: EdgeInsets.only(right: _isMenuExpanded ? 8.0 : 0.0),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => setState(() => _isMenuExpanded = !_isMenuExpanded),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: AnimatedRotation(
                      turns: _isMenuExpanded ? 0.0 : 0.5,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOutCubic,
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildSidebarNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isMobile,
  }) {
    bool isSelected = _selectedIndex == index;
    // Highlight Facility Management if a sub-view is active
    if (index == _buildingsIndex &&
        (_selectedIndex == _departmentsIndex ||
         _selectedIndex == _buildingsIndex ||
         _selectedIndex == _floorsIndex ||
         _selectedIndex == _roomTypesIndex ||
         _selectedIndex == _requestTypesIndex)) {
      isSelected = true;
    }
    return InkWell(
      onTap: () {
        setState(() => _selectedIndex = index);
        if (isMobile) {
          Navigator.pop(context); // Close the drawer
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: 22,
            ),
            if (isMobile) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else ...[
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  opacity: _isMenuExpanded ? 1.0 : 0.0,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required bool isMobile}) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showFullTitle = constraints.maxWidth > 500;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMobile) ...[
                    Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu_rounded, color: Color(0xFF1E293B)),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    showFullTitle ? 'System Management Console' : 'Console',
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tutorial Guide Icon Button (Icon Only)
                  Tooltip(
                    message: 'Tutorial Guide',
                    child: InkWell(
                      onTap: () {
                        final user = context.read<AuthService>().currentUser;
                        showWorkflowGuideDialog(context, role: user?.role.name);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.help_outline_rounded,
                          color: Color(0xFF0F766E),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFF0F766E),
                        child: Icon(Icons.person_rounded, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _userName,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        }
      ),
    );
  }
}

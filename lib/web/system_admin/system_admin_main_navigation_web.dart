import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../authentication/services/auth_service.dart';
import '../admin/shared/admin_styles.dart';

import 'screens/system_admin_dashboard_view.dart';
import 'screens/system_admin_users_view.dart';
import 'screens/system_admin_departments_view.dart';
import 'screens/system_admin_buildings_view.dart';
import 'screens/system_admin_rooms_view.dart';
import 'screens/system_admin_qr_management_view.dart';
import 'screens/system_admin_request_types_view.dart';
import 'screens/system_admin_specializations_view.dart';
import 'screens/system_admin_reports_view.dart';
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

  // Colors
  static const _sidebarBg = Color(0xFF0F172A);
  static const _sidebarBorder = Color(0xFF1E293B);
  static const _headerBg = Colors.white;
  static const _contentBg = Color(0xFFF8FAFC);
  static const _primaryBlue = Color(0xFF0F766E); // Consistent Teal accent

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

  void _handleLogout() async {
    final authService = context.read<AuthService>();
    await authService.handleLogoutButton(context);
  }

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
    {'icon': Icons.people_outline, 'label': 'Users Management'},
    {'icon': Icons.account_tree_outlined, 'label': 'Departments'},
    {'icon': Icons.business_outlined, 'label': 'Buildings'},
    {'icon': Icons.meeting_room_outlined, 'label': 'Rooms'},
    {'icon': Icons.qr_code_scanner_outlined, 'label': 'QR Management'},
    {'icon': Icons.build_circle_outlined, 'label': 'Request Types'},
    {'icon': Icons.psychology_outlined, 'label': 'Specializations'},
    {'icon': Icons.bar_chart_rounded, 'label': 'Reports'},
    {'icon': Icons.feedback_outlined, 'label': 'Feedback'},
    {'icon': Icons.campaign_outlined, 'label': 'Announcements'},
    {'icon': Icons.history_edu, 'label': 'Audit Logs'},
    {'icon': Icons.monitor_heart_outlined, 'label': 'System Health'},
    {'icon': Icons.backup_outlined, 'label': 'Backup & Restore'},
    {'icon': Icons.settings_outlined, 'label': 'Settings'},
  ];

  @override
  Widget build(BuildContext context) {
    return GlobalAnnouncementListener(
      child: Scaffold(
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
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: _buildBodyContent(),
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
        );
      case 1:
        return const SystemAdminUsersView();
      case 2:
        return const SystemAdminDepartmentsView();
      case 3:
        return const SystemAdminBuildingsView();
      case 4:
        return const SystemAdminRoomsView();
      case 5:
        return const SystemAdminQrManagementView();
      case 6:
        return const SystemAdminRequestTypesView();
      case 7:
        return const SystemAdminSpecializationsView();
      case 8:
        return const SystemAdminReportsView();
      case 9:
        return const SystemAdminFeedbackView();
      case 10:
        return const SystemAdminAnnouncementsView();
      case 11:
        return const SystemAdminAuditLogsView();
      case 12:
        return const SystemAdminSystemHealthView();
      case 13:
        return const SystemAdminBackupRestoreView();
      case 14:
        return const SystemAdminSettingsView();
      default:
        return const Center(child: Text('Page not found'));
    }
  }

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isMenuExpanded ? 260 : 70,
      decoration: const BoxDecoration(
        color: _sidebarBg,
        border: Border(right: BorderSide(color: _sidebarBorder, width: 1)),
      ),
      child: Column(
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
                if (_isMenuExpanded) ...[
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
                );
              },
            ),
          ),
          // Collapse Toggle
          IconButton(
            onPressed: () => setState(() => _isMenuExpanded = !_isMenuExpanded),
            icon: Icon(
              _isMenuExpanded
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
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
            if (_isMenuExpanded) ...[
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 70,
      color: _headerBg,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Text(
            'System Management Console',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            _userName,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }
}

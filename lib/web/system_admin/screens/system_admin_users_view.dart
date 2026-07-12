import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../authentication/models/user_model.dart';
import '../../../shared/models/department_model.dart';
import '../../../shared/services/department_service.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../shared/services/system_admin_service.dart';
import '../../admin/shared/admin_styles.dart';
import 'system_admin_add_user_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Constants & helpers
// ─────────────────────────────────────────────────────────────────────────────

const int _kPageSize = 15;

class _RoleStyle {
  final Color bg;
  final Color fg;
  final IconData icon;
  final String label;
  const _RoleStyle(this.bg, this.fg, this.icon, this.label);
}

_RoleStyle _roleStyle(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return _RoleStyle(
        const Color(0xFFFEE2E2),
        const Color(0xFF991B1B),
        Icons.shield_rounded,
        'System Admin',
      );
    case UserRole.campadmin:
      return _RoleStyle(
        const Color(0xFFFEF9C3),
        const Color(0xFF854D0E),
        Icons.admin_panel_settings_rounded,
        'Campus Admin',
      );
    case UserRole.teacher:
      return _RoleStyle(
        const Color(0xFFE0F2FE),
        const Color(0xFF075985),
        Icons.school_rounded,
        'Teacher',
      );
    case UserRole.maintenance:
      return _RoleStyle(
        const Color(0xFFF3E8FF),
        const Color(0xFF6B21A8),
        Icons.handyman_rounded,
        'Maintenance',
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widget
// ─────────────────────────────────────────────────────────────────────────────

class SystemAdminUsersView extends StatefulWidget {
  const SystemAdminUsersView({super.key});

  @override
  State<SystemAdminUsersView> createState() => _SystemAdminUsersViewState();
}

class _SystemAdminUsersViewState extends State<SystemAdminUsersView> {
  // ── Data ──────────────────────────────────────────────────────────────────
  List<AppUser> _allUsers = [];
  List<Department> _departments = [];
  Map<String, DateTime?> _lastLoginMap = {}; // userId → last login
  bool _loading = true;
  String? _error;

  // ── Filters ───────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _roleFilter = 'all';
  String _deptFilter = 'all';
  String _statusFilter = 'all';

  // ── Selection & pagination ────────────────────────────────────────────────
  final Set<String> _selectedIds = {};
  int _currentPage = 0;

  // ── View state ────────────────────────────────────────────────────────────
  bool _isAddingUser = false;

  static const _db = Supabase;

  // ─────────────────────────────────────────────────────────────────────────
  //  Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _currentPage = 0));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Data loading
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedIds.clear();
    });
    try {
      final results = await Future.wait([
        SystemAdminService.fetchAllUsers(),
        DepartmentService.fetchAll(),
        LoginActivityService.fetchAdminLogs(),
      ]);

      final users = results[0] as List<AppUser>;
      final depts = results[1] as List<Department>;
      final logs = results[2] as List<LoginActivity>;

      // Build last-login lookup for all users
      final loginMap = <String, DateTime?>{};
      for (final u in users) {
        loginMap[u.id] = null;
      }
      for (final log in logs) {
        final existing = loginMap[log.userId];
        if (existing == null || log.loggedInAt.isAfter(existing)) {
          loginMap[log.userId] = log.loggedInAt;
        }
      }

      if (!mounted) return;
      setState(() {
        _allUsers = users;
        _departments = depts;
        _lastLoginMap = loginMap;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Computed
  // ─────────────────────────────────────────────────────────────────────────

  List<AppUser> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _allUsers.where((u) {
      if (q.isNotEmpty) {
        final matches = u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            (u.employeeId ?? '').toLowerCase().contains(q);
        if (!matches) return false;
      }
      if (_roleFilter != 'all' && u.role.name != _roleFilter) return false;
      if (_deptFilter != 'all' && (u.department ?? '') != _deptFilter) {
        return false;
      }
      if (_statusFilter == 'active' && !u.isActive) return false;
      if (_statusFilter == 'inactive' && u.isActive) return false;
      return true;
    }).toList();
  }

  List<AppUser> get _paginated {
    final f = _filtered;
    final start = _currentPage * _kPageSize;
    if (start >= f.length) return [];
    return f.sublist(start, (start + _kPageSize).clamp(0, f.length));
  }

  int get _totalPages => ((_filtered.length - 1) / _kPageSize).ceil();

  int get _totalUsers => _allUsers.length;
  int get _activeUsers => _allUsers.where((u) => u.isActive).length;
  int get _inactiveUsers => _allUsers.where((u) => !u.isActive).length;

  // ─────────────────────────────────────────────────────────────────────────
  //  Actions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _toggleActive(AppUser user, bool activate) async {
    final confirmed = await _confirm(
      title: activate ? 'Activate Account' : 'Deactivate Account',
      message: activate
          ? 'This will restore ${user.name}\'s access to the system.'
          : 'This will prevent ${user.name} from logging in.',
      confirmLabel: activate ? 'Activate' : 'Deactivate',
      danger: !activate,
    );
    if (!confirmed) return;

    final err = await SystemAdminService.updateUserAccount(
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role.name,
      isActive: activate,
    );
    if (err == null) {
      _toast('${user.name} has been ${activate ? 'activated' : 'deactivated'}.');
      _load();
    } else {
      _toast('Error: $err', isError: true);
    }
  }

  Future<void> _resetPassword(AppUser user) async {
    final confirmed = await _confirm(
      title: 'Reset Password',
      message:
          'Send a password reset email to ${user.email}? The user will receive a link to set a new password.',
      confirmLabel: 'Send Reset Email',
    );
    if (!confirmed) return;
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(user.email);
      _toast('Password reset email sent to ${user.email}.');
    } catch (e) {
      _toast('Error: $e', isError: true);
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    final confirmed = await _confirm(
      title: 'Delete Account',
      message:
          'This will permanently deactivate "${user.name}". This action cannot be undone easily.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!confirmed) return;

    final err = await SystemAdminService.updateUserAccount(
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role.name,
      isActive: false,
    );
    if (err == null) {
      _toast('${user.name} has been removed.');
      _load();
    } else {
      _toast('Error: $err', isError: true);
    }
  }

  Future<void> _bulkDeactivate() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await _confirm(
      title: 'Bulk Deactivate',
      message: 'Deactivate ${_selectedIds.length} selected account(s)?',
      confirmLabel: 'Deactivate All',
      danger: true,
    );
    if (!confirmed) return;
    for (final id in _selectedIds) {
      final user = _allUsers.firstWhere((u) => u.id == id,
          orElse: () => _allUsers.first);
      await SystemAdminService.updateUserAccount(
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role.name,
        isActive: false,
      );
    }
    _toast('${_selectedIds.length} accounts deactivated.');
    _load();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Dialogs
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              danger ? Icons.warning_rounded : Icons.info_outline_rounded,
              color: danger ? AdminStyles.error : AdminStyles.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(title, style: AdminStyles.headingStyle(fontSize: 18)),
          ],
        ),
        content: Text(message, style: AdminStyles.bodyStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? AdminStyles.error : AdminStyles.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showUserDetail(AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => _UserDetailDialog(
        user: user,
        lastLogin: _lastLoginMap[user.id],
        departments: _departments,
        onEdit: () {
          Navigator.pop(ctx);
          _showEditDialog(user);
        },
        onResetPassword: () {
          Navigator.pop(ctx);
          _resetPassword(user);
        },
      ),
    );
  }

  void _showEditDialog(AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => _EditUserDialog(
        user: user,
        departments: _departments,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Flexible(child: Text(msg)),
        ]),
        backgroundColor: isError ? AdminStyles.error : AdminStyles.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isAddingUser) {
      return SystemAdminAddUserView(
        departments: _departments,
        onCancel: () => setState(() => _isAddingUser = false),
        onSuccess: () {
          setState(() => _isAddingUser = false);
          _load();
        },
      );
    }

    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();

    return LayoutBuilder(builder: (ctx, constraints) {
      final isMobile = constraints.maxWidth < 800;
      return Container(
        color: AdminStyles.bg,
        child: Column(
          children: [
            // ── Header + summary cards ──────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  isMobile ? 16 : 32, isMobile ? 16 : 28, isMobile ? 16 : 32, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPageHeader(isMobile),
                  const SizedBox(height: 20),
                  _buildSummaryCards(isMobile),
                  const SizedBox(height: 20),
                  _buildToolbar(isMobile),
                  if (_selectedIds.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildBulkBar(),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ── Table / List ────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
                child: _filtered.isEmpty
                    ? _buildEmpty()
                    : isMobile
                        ? _buildMobileList()
                        : _buildDesktopTable(),
              ),
            ),

            // ── Pagination ──────────────────────────────────────────────────
            if (_filtered.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 32, vertical: 12),
                child: _buildPagination(),
              ),
          ],
        ),
      );
    });
  }

  // ── States ────────────────────────────────────────────────────────────────

  Widget _buildLoading() => Container(
        color: AdminStyles.bg,
        child: const Center(
          child: CircularProgressIndicator(
              color: AdminStyles.primary, strokeWidth: 3),
        ),
      );

  Widget _buildError() => Container(
        color: AdminStyles.bg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AdminStyles.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    size: 36, color: AdminStyles.error),
              ),
              const SizedBox(height: 20),
              Text('Failed to load users', style: AdminStyles.headingStyle(fontSize: 20)),
              const SizedBox(height: 8),
              Text(_error ?? '', style: AdminStyles.bodyStyle()),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminStyles.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 56, color: AdminStyles.textMuted),
            const SizedBox(height: 16),
            Text('No users match your filters',
                style: AdminStyles.headingStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Try adjusting your search or filters.',
                style: AdminStyles.bodyStyle()),
          ],
        ),
      );

  // ── Page Header ───────────────────────────────────────────────────────────

  Widget _buildPageHeader(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Users Management',
                  style: AdminStyles.headingStyle(fontSize: isMobile ? 22 : 28)),
              const SizedBox(height: 4),
              Text('Manage all system accounts, roles, and permissions.',
                  style: AdminStyles.bodyStyle(fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () => setState(() => _isAddingUser = true),
          icon: const Icon(Icons.person_add_rounded, size: 18),
          label: Text(isMobile ? 'Create' : 'Create User'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminStyles.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 20, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _load,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded, color: AdminStyles.textSecondary),
        ),
      ],
    );
  }

  // ── Summary Cards ─────────────────────────────────────────────────────────

  Widget _buildSummaryCards(bool isMobile) {
    final cards = [
      _SummaryCard('Total Users', _totalUsers, Icons.people_rounded,
          AdminStyles.primary),
      _SummaryCard('Active', _activeUsers, Icons.check_circle_rounded,
          AdminStyles.success),
      _SummaryCard('Inactive', _inactiveUsers, Icons.do_not_disturb_on_rounded,
          AdminStyles.error),
      _SummaryCard(
          'Departments',
          _departments.length,
          Icons.business_rounded,
          AdminStyles.warning),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: cards.map(_buildSummaryTile).toList(),
      );
    }

    return Row(
      children: cards
          .map((c) => Expanded(child: _buildSummaryTile(c)))
          .toList()
          .expand((w) => [w, const SizedBox(width: 12)])
          .toList()
        ..removeLast(),
    );
  }

  Widget _buildSummaryTile(_SummaryCard c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(c.icon, color: c.color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${c.value}',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: c.color,
                      letterSpacing: -0.5)),
              Text(c.label, style: AdminStyles.bodyStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────

  Widget _buildToolbar(bool isMobile) {
    final searchField = Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: AdminStyles.bodyStyle(
            color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Search name, email, or ID…',
          hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AdminStyles.textMuted, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AdminStyles.textMuted, size: 18),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        ),
      ),
    );

    final roleFilter = _buildDropdown(
      label: 'All Roles',
      value: _roleFilter,
      icon: Icons.badge_outlined,
      items: {
        'all': 'All Roles',
        'admin': 'System Admin',
        'campadmin': 'Campus Admin',
        'teacher': 'Teacher',
        'maintenance': 'Maintenance',
      },
      onChanged: (v) => setState(() {
        _roleFilter = v;
        _currentPage = 0;
      }),
    );

    final deptFilter = _buildDropdown(
      label: 'All Departments',
      value: _deptFilter,
      icon: Icons.business_outlined,
      items: {
        'all': 'All Departments',
        for (final d in _departments) d.name: d.name,
      },
      onChanged: (v) => setState(() {
        _deptFilter = v;
        _currentPage = 0;
      }),
    );

    final statusFilter = _buildDropdown(
      label: 'All Status',
      value: _statusFilter,
      icon: Icons.toggle_on_outlined,
      items: {
        'all': 'All Status',
        'active': 'Active Only',
        'inactive': 'Inactive Only',
      },
      onChanged: (v) => setState(() {
        _statusFilter = v;
        _currentPage = 0;
      }),
    );

    if (isMobile) {
      return Column(
        children: [
          searchField,
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: roleFilter),
              const SizedBox(width: 8),
              Expanded(child: statusFilter),
            ],
          ),
          const SizedBox(height: 8),
          deptFilter,
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 3, child: searchField),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: roleFilter),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: deptFilter),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: statusFilter),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required IconData icon,
    required Map<String, String> items,
    required void Function(String) onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AdminStyles.textMuted, size: 18),
          style: AdminStyles.bodyStyle(
              color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
          items: items.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value,
                        overflow: TextOverflow.ellipsis,
                        style: AdminStyles.bodyStyle(
                            color: AdminStyles.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  // ── Bulk Bar ──────────────────────────────────────────────────────────────

  Widget _buildBulkBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AdminStyles.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.checklist_rounded, color: AdminStyles.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            '${_selectedIds.length} selected',
            style: AdminStyles.bodyStyle(
                color: AdminStyles.primary, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _bulkDeactivate,
            icon: const Icon(Icons.block_rounded, size: 16),
            label: const Text('Deactivate'),
            style: TextButton.styleFrom(
              foregroundColor: AdminStyles.error,
              textStyle: AdminStyles.bodyStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _selectedIds.clear()),
            child: const Text('Clear'),
            style: TextButton.styleFrom(
                foregroundColor: AdminStyles.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Desktop Table ─────────────────────────────────────────────────────────

  Widget _buildDesktopTable() {
    final users = _paginated;
    final allPageSelected =
        users.isNotEmpty && users.every((u) => _selectedIds.contains(u.id));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 900),
            child: Column(
              children: [
                // Header row
                _buildTableHeader(allPageSelected, users),
                const Divider(height: 1, color: AdminStyles.border),
                // Data rows
                Expanded(
                  child: ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AdminStyles.border),
                    itemBuilder: (_, i) => _buildTableRow(users[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(bool allSelected, List<AppUser> pageUsers) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            tristate: true,
            onChanged: (v) {
              setState(() {
                if (allSelected) {
                  _selectedIds.removeAll(pageUsers.map((u) => u.id));
                } else {
                  _selectedIds.addAll(pageUsers.map((u) => u.id));
                }
              });
            },
            activeColor: AdminStyles.primary,
          ),
          _th('Name', flex: 3),
          _th('Email', flex: 3),
          _th('Role', flex: 2),
          _th('Department', flex: 2),
          _th('Status', flex: 1),
          _th('Last Login', flex: 2),
          _th('Actions', flex: 2, center: true),
        ],
      ),
    );
  }

  Widget _th(String label, {int flex = 1, bool center = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AdminStyles.textMuted,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTableRow(AppUser user) {
    final rs = _roleStyle(user.role);
    final lastLogin = _lastLoginMap[user.id];
    final isSelected = _selectedIds.contains(user.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      color: isSelected
          ? AdminStyles.primary.withValues(alpha: 0.04)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedIds.add(user.id);
                } else {
                  _selectedIds.remove(user.id);
                }
              });
            },
            activeColor: AdminStyles.primary,
          ),
          // Name + avatar
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _Avatar(name: user.name, role: user.role, size: 34),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: AdminStyles.bodyStyle(
                          fontWeight: FontWeight.w700,
                          color: AdminStyles.textPrimary,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user.employeeId != null)
                        Text(
                          'ID: ${user.employeeId}',
                          style: AdminStyles.bodyStyle(
                              fontSize: 10, color: AdminStyles.textMuted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Email
          Expanded(
            flex: 3,
            child: Text(
              user.email,
              style: AdminStyles.bodyStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Role
          Expanded(
            flex: 2,
            child: _RoleBadge(role: user.role),
          ),
          // Department
          Expanded(
            flex: 2,
            child: Text(
              user.department ?? '—',
              style: AdminStyles.bodyStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Status
          Expanded(
            flex: 1,
            child: _StatusBadge(isActive: user.isActive),
          ),
          // Last Login
          Expanded(
            flex: 2,
            child: Text(
              lastLogin != null ? _formatRelative(lastLogin) : 'Never',
              style: AdminStyles.bodyStyle(
                  fontSize: 11,
                  color: lastLogin != null
                      ? AdminStyles.textSecondary
                      : AdminStyles.textMuted),
            ),
          ),
          // Actions
          Expanded(
            flex: 2,
            child: _buildActionButtons(user),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppUser user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _IconBtn(
          icon: Icons.visibility_outlined,
          tooltip: 'View Details',
          color: AdminStyles.primary,
          onTap: () => _showUserDetail(user),
        ),
        _IconBtn(
          icon: Icons.edit_outlined,
          tooltip: 'Edit',
          color: AdminStyles.secondary,
          onTap: () => _showEditDialog(user),
        ),
        _ActionMenu(
          items: [
            _MenuItem(
              Icons.lock_reset_rounded,
              'Reset Password',
              AdminStyles.info,
              () => _resetPassword(user),
            ),
            if (user.isActive)
              _MenuItem(
                Icons.block_rounded,
                'Deactivate',
                AdminStyles.warning,
                () => _toggleActive(user, false),
              )
            else
              _MenuItem(
                Icons.check_circle_outline_rounded,
                'Activate',
                AdminStyles.success,
                () => _toggleActive(user, true),
              ),
            _MenuItem(
              Icons.delete_outline_rounded,
              'Delete',
              AdminStyles.error,
              () => _deleteUser(user),
            ),
          ],
        ),
      ],
    );
  }

  // ── Mobile List ───────────────────────────────────────────────────────────

  Widget _buildMobileList() {
    final users = _paginated;
    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildMobileCard(users[i]),
    );
  }

  Widget _buildMobileCard(AppUser user) {
    final rs = _roleStyle(user.role);
    final lastLogin = _lastLoginMap[user.id];
    final isSelected = _selectedIds.contains(user.id);

    return GestureDetector(
      onLongPress: () => setState(() {
        if (isSelected) {
          _selectedIds.remove(user.id);
        } else {
          _selectedIds.add(user.id);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AdminStyles.primary
                : AdminStyles.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(Icons.check_circle_rounded,
                    color: AdminStyles.primary, size: 20),
              ),
            _Avatar(name: user.name, role: user.role, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(user.name,
                            style: AdminStyles.bodyStyle(
                                fontWeight: FontWeight.w700,
                                color: AdminStyles.textPrimary),
                            overflow: TextOverflow.ellipsis),
                      ),
                      _StatusBadge(isActive: user.isActive, compact: true),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(user.email,
                      style: AdminStyles.bodyStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _RoleBadge(role: user.role, small: true),
                      const SizedBox(width: 8),
                      if (user.department != null)
                        Flexible(
                          child: Text(user.department!,
                              style: AdminStyles.bodyStyle(
                                  fontSize: 11, color: AdminStyles.textMuted),
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AdminStyles.textMuted, size: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              itemBuilder: (ctx) => [
                _popItem(Icons.visibility_outlined, 'View', 'view'),
                _popItem(Icons.edit_outlined, 'Edit', 'edit'),
                _popItem(Icons.lock_reset_rounded, 'Reset Password', 'reset'),
                if (user.isActive)
                  _popItem(Icons.block_rounded, 'Deactivate', 'deactivate',
                      color: AdminStyles.warning)
                else
                  _popItem(Icons.check_circle_outline_rounded, 'Activate',
                      'activate',
                      color: AdminStyles.success),
                _popItem(Icons.delete_outline_rounded, 'Delete', 'delete',
                    color: AdminStyles.error),
              ],
              onSelected: (v) {
                switch (v) {
                  case 'view':
                    _showUserDetail(user);
                    break;
                  case 'edit':
                    _showEditDialog(user);
                    break;
                  case 'reset':
                    _resetPassword(user);
                    break;
                  case 'deactivate':
                    _toggleActive(user, false);
                    break;
                  case 'activate':
                    _toggleActive(user, true);
                    break;
                  case 'delete':
                    _deleteUser(user);
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _popItem(IconData icon, String label, String value,
      {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? AdminStyles.textSecondary),
          const SizedBox(width: 10),
          Text(label,
              style: AdminStyles.bodyStyle(
                  color: color ?? AdminStyles.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }

  // ── Pagination ────────────────────────────────────────────────────────────

  Widget _buildPagination() {
    final total = _filtered.length;
    final start = _currentPage * _kPageSize + 1;
    final end = ((_currentPage + 1) * _kPageSize).clamp(0, total);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Showing $start–$end of $total users',
          style: AdminStyles.bodyStyle(fontSize: 12),
        ),
        Row(
          children: [
            _PaginationBtn(
              icon: Icons.first_page_rounded,
              onTap: _currentPage > 0
                  ? () => setState(() => _currentPage = 0)
                  : null,
            ),
            _PaginationBtn(
              icon: Icons.chevron_left_rounded,
              onTap: _currentPage > 0
                  ? () => setState(() => _currentPage--)
                  : null,
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AdminStyles.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_currentPage + 1} / ${_totalPages.clamp(1, 9999)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
            _PaginationBtn(
              icon: Icons.chevron_right_rounded,
              onTap: _currentPage < _totalPages - 1
                  ? () => setState(() => _currentPage++)
                  : null,
            ),
            _PaginationBtn(
              icon: Icons.last_page_rounded,
              onTap: _currentPage < _totalPages - 1
                  ? () => setState(() => _currentPage = _totalPages - 1)
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Re-usable small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final UserRole role;
  final double size;

  const _Avatar({required this.name, required this.role, required this.size});

  @override
  Widget build(BuildContext context) {
    final rs = _roleStyle(role);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: rs.bg,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: rs.fg,
            fontSize: size * 0.45,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  final bool small;

  const _RoleBadge({required this.role, this.small = false});

  @override
  Widget build(BuildContext context) {
    final rs = _roleStyle(role);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: rs.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(rs.icon, color: rs.fg, size: small ? 10 : 12),
          const SizedBox(width: 4),
          Text(
            rs.label,
            style: TextStyle(
              color: rs.fg,
              fontSize: small ? 9 : 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  final bool compact;

  const _StatusBadge({required this.isActive, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? AdminStyles.success : AdminStyles.error,
              shape: BoxShape.circle,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 5),
            Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: isActive
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem(this.icon, this.label, this.color, this.onTap);
}

class _ActionMenu extends StatelessWidget {
  final List<_MenuItem> items;

  const _ActionMenu({required this.items});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.more_vert_rounded,
          color: AdminStyles.textMuted, size: 18),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (i) => items[i].onTap(),
      itemBuilder: (ctx) => items.asMap().entries.map((e) {
        final item = e.value;
        return PopupMenuItem<int>(
          value: e.key,
          child: Row(
            children: [
              Icon(item.icon, size: 18, color: item.color),
              const SizedBox(width: 10),
              Text(item.label,
                  style: AdminStyles.bodyStyle(
                      color: item.color, fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PaginationBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _PaginationBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: onTap != null ? Colors.white : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: AdminStyles.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                size: 18,
                color: onTap != null
                    ? AdminStyles.textPrimary
                    : AdminStyles.textMuted),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Summary card data model
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _SummaryCard(this.label, this.value, this.icon, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
//  User Detail Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _UserDetailDialog extends StatelessWidget {
  final AppUser user;
  final DateTime? lastLogin;
  final List<Department> departments;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;

  const _UserDetailDialog({
    required this.user,
    required this.lastLogin,
    required this.departments,
    required this.onEdit,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    final rs = _roleStyle(user.role);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  _Avatar(name: user.name, role: user.role, size: 52),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name,
                            style: AdminStyles.headingStyle(fontSize: 18)),
                        const SizedBox(height: 4),
                        _RoleBadge(role: user.role),
                      ],
                    ),
                  ),
                  _StatusBadge(isActive: user.isActive),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: AdminStyles.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: AdminStyles.border),
              const SizedBox(height: 16),

              // Details
              _DetailRow(Icons.alternate_email_rounded, 'Email', user.email),
              if (user.department != null)
                _DetailRow(Icons.business_rounded, 'Department', user.department!),
              if (user.position != null)
                _DetailRow(Icons.work_outline_rounded, 'Position', user.position!),
              if (user.employeeId != null)
                _DetailRow(Icons.badge_outlined, 'Employee ID', user.employeeId!),
              if (user.phone != null)
                _DetailRow(Icons.phone_outlined, 'Phone', user.phone!),
              _DetailRow(
                Icons.calendar_today_outlined,
                'Account Created',
                user.createdAt != null
                    ? _formatDate(user.createdAt!)
                    : 'Unknown',
              ),
              _DetailRow(
                Icons.login_rounded,
                'Last Login',
                lastLogin != null ? _formatDate(lastLogin!) : 'Never',
              ),

              const SizedBox(height: 24),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onResetPassword,
                      icon: const Icon(Icons.lock_reset_rounded, size: 16),
                      label: const Text('Reset Password'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminStyles.primary,
                        side: const BorderSide(color: AdminStyles.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit Account'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminStyles.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AdminStyles.textMuted),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label,
                style: AdminStyles.bodyStyle(
                    fontSize: 12, color: AdminStyles.textMuted)),
          ),
          Expanded(
            child: Text(value,
                style: AdminStyles.bodyStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AdminStyles.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Edit User Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _EditUserDialog extends StatefulWidget {
  final AppUser user;
  final List<Department> departments;
  final VoidCallback onSaved;

  const _EditUserDialog({
    required this.user,
    required this.departments,
    required this.onSaved,
  });

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late final _nameCtrl = TextEditingController(text: widget.user.name);
  late final _emailCtrl = TextEditingController(text: widget.user.email);
  late final _empIdCtrl = TextEditingController(text: widget.user.employeeId ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.user.phone ?? '');
  late final _posCtrl = TextEditingController(text: widget.user.position ?? '');

  late String _role = widget.user.role.name;
  late bool _isActive = widget.user.isActive;
  String? _selectedDeptId;
  bool _saving = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Try to find dept id by matching name
    if (widget.user.department != null) {
      try {
        final match = widget.departments
            .firstWhere((d) => d.name == widget.user.department);
        _selectedDeptId = match.id;
      } catch (_) {}
    }
    if (_selectedDeptId == null && widget.departments.isNotEmpty) {
      _selectedDeptId = widget.departments.first.id;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _empIdCtrl.dispose();
    _phoneCtrl.dispose();
    _posCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final err = await SystemAdminService.updateUserAccount(
      id: widget.user.id,
      email: _emailCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      role: _role,
      isActive: _isActive,
      departmentId: _role == 'teacher' ? _selectedDeptId : null,
      position: _posCtrl.text.trim().isNotEmpty ? _posCtrl.text.trim() : null,
      employeeId:
          _empIdCtrl.text.trim().isNotEmpty ? _empIdCtrl.text.trim() : null,
      phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
      specialization:
          _role == 'maintenance' && _posCtrl.text.trim().isNotEmpty
              ? _posCtrl.text.trim()
              : null,
    );

    setState(() => _saving = false);

    if (!mounted) return;
    if (err == null) {
      widget.onSaved();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $err'),
        backgroundColor: AdminStyles.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_rounded,
                        color: AdminStyles.primary, size: 22),
                    const SizedBox(width: 10),
                    Text('Edit Account',
                        style: AdminStyles.headingStyle(fontSize: 20)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: AdminStyles.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _field('Full Name', _nameCtrl, Icons.person_outline_rounded,
                    validator: (v) =>
                        v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 14),
                _field('Email', _emailCtrl, Icons.alternate_email_rounded,
                    validator: (v) =>
                        v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 14),
                // Role selector
                _sectionLabel('Role'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: _inputDecor(Icons.shield_outlined),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('System Admin')),
                    DropdownMenuItem(
                        value: 'campadmin', child: Text('Campus Admin')),
                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                    DropdownMenuItem(
                        value: 'maintenance', child: Text('Maintenance')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? _role),
                ),
                const SizedBox(height: 14),
                if (_role == 'teacher') ...[
                  _sectionLabel('Department'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedDeptId,
                    decoration: _inputDecor(Icons.business_rounded),
                    items: widget.departments
                        .map((d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(d.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDeptId = v),
                  ),
                  const SizedBox(height: 14),
                  _field('Position', _posCtrl, Icons.work_outline_rounded),
                  const SizedBox(height: 14),
                ],
                if (_role == 'maintenance') ...[
                  _field('Specialization', _posCtrl,
                      Icons.build_circle_outlined,
                      hint: 'e.g. Electrical, Plumbing'),
                  const SizedBox(height: 14),
                ],
                _field('Employee ID', _empIdCtrl, Icons.badge_outlined,
                    hint: 'Optional'),
                const SizedBox(height: 14),
                _field('Phone', _phoneCtrl, Icons.phone_outlined,
                    hint: 'Optional'),
                const SizedBox(height: 14),
                // Active toggle
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AdminStyles.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminStyles.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.toggle_on_rounded,
                          color: AdminStyles.textSecondary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Account Active',
                            style: AdminStyles.bodyStyle(
                                fontWeight: FontWeight.w700,
                                color: AdminStyles.textPrimary)),
                      ),
                      Switch(
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        activeColor: AdminStyles.success,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminStyles.textSecondary,
                          side: const BorderSide(color: AdminStyles.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminStyles.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Save Changes',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: AdminStyles.bodyStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AdminStyles.textSecondary));
  }

  InputDecoration _inputDecor(IconData icon, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon:
          Icon(icon, size: 18, color: AdminStyles.textSecondary),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminStyles.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminStyles.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminStyles.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminStyles.error, width: 1.5),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          validator: validator,
          style: AdminStyles.bodyStyle(
              color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
          decoration: _inputDecor(icon, hint: hint),
        ),
      ],
    );
  }
}

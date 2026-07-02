import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../authentication/models/user_model.dart';
import '../../authentication/services/auth_service.dart';
import '../../shared/models/department_model.dart';
import '../../shared/services/department_service.dart';
import '../../shared/services/system_admin_service.dart';
import '../admin/shared/admin_styles.dart';

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

  // Users State
  List<AppUser> _allUsers = [];
  List<Department> _departments = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';
  String _selectedStatusFilter = 'all';

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
    _loadData();
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final users = await SystemAdminService.fetchAllUsers();
      final depts = await DepartmentService.fetchAll();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _departments = depts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AppUser> get _filteredUsers {
    return _allUsers.where((user) {
      // 1. Search Query filter
      final query = _searchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matchesName = user.name.toLowerCase().contains(query);
        final matchesEmail = user.email.toLowerCase().contains(query);
        final matchesId = (user.employeeId ?? '').toLowerCase().contains(query);
        if (!matchesName && !matchesEmail && !matchesId) return false;
      }

      // 2. Role filter
      if (_selectedRoleFilter != 'all') {
        if (user.role.name != _selectedRoleFilter) return false;
      }

      // 3. Status filter
      if (_selectedStatusFilter != 'all') {
        final checkActive = _selectedStatusFilter == 'active';
        if (user.isActive != checkActive) return false;
      }

      return true;
    }).toList();
  }

  void _handleLogout() async {
    final authService = context.read<AuthService>();
    await authService.handleLogoutButton(context);
  }

  @override
  Widget build(BuildContext context) {
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
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: _selectedIndex == 0
                          ? _buildUserManagementContent()
                          : _buildAuditLogsContent(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              children: [
                _buildSidebarNavItem(
                  index: 0,
                  icon: Icons.people_outline,
                  label: 'Users Management',
                ),
                _buildSidebarNavItem(
                  index: 1,
                  icon: Icons.history_edu,
                  label: 'Audit & Activity Logs',
                ),
              ],
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

  Widget _buildUserManagementContent() {
    final filtered = _filteredUsers;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Users Console',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configure credentials, roles, and status profiles.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddUserDialog(),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text(
                  'CREATE NEW USER',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Search & Filter Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search by name, email or employee ID...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedRoleFilter,
                  onChanged: (val) =>
                      setState(() => _selectedRoleFilter = val ?? 'all'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Roles')),
                    DropdownMenuItem(value: 'admin', child: Text('System Admin')),
                    DropdownMenuItem(
                        value: 'campadmin', child: Text('Campus Admin')),
                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                    DropdownMenuItem(
                        value: 'maintenance', child: Text('Maintenance')),
                  ],
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedStatusFilter,
                  onChanged: (val) =>
                      setState(() => _selectedStatusFilter = val ?? 'all'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'active', child: Text('Active Only')),
                    DropdownMenuItem(
                        value: 'inactive', child: Text('Inactive Only')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Users List
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(child: Text('No users found.'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final user = filtered[idx];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: _primaryBlue.withOpacity(0.1),
                                child: Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: _primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    user.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildRoleBadge(user.role),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(user.email),
                                  if (user.employeeId != null) ...[
                                    const SizedBox(height: 2),
                                    Text('Employee ID: ${user.employeeId}'),
                                  ],
                                  if (user.role == UserRole.teacher &&
                                      user.department != null) ...[
                                    const SizedBox(height: 2),
                                    Text('Department: ${user.department}'),
                                  ],
                                  if (user.role == UserRole.maintenance &&
                                      user.position != null) ...[
                                    const SizedBox(height: 2),
                                    Text('Specialization: ${user.position}'),
                                  ],
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Status Indicator
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: user.isActive
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      user.isActive ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: user.isActive
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    onPressed: () => _showEditUserDialog(user),
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Edit / Configure Account',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    Color bg;
    Color text;
    String label;

    switch (role) {
      case UserRole.admin:
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFF991B1B);
        label = 'System Admin';
        break;
      case UserRole.campadmin:
        bg = const Color(0xFFFEF9C3);
        text = const Color(0xFF854D0E);
        label = 'Campus Admin';
        break;
      case UserRole.teacher:
        bg = const Color(0xFFE0F2FE);
        text = const Color(0xFF075985);
        label = 'Teacher';
        break;
      case UserRole.maintenance:
        bg = const Color(0xFFF3E8FF);
        text = const Color(0xFF6B21A8);
        label = 'Maintenance';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }

  Widget _buildAuditLogsContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_edu, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Activity Logs Console',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('All admin actions and login tracking records are logged in DB.'),
        ],
      ),
    );
  }

  // DIALOGS & MUTATIONS

  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    final empIdController = TextEditingController();
    final phoneController = TextEditingController();
    final specController = TextEditingController();
    final posController = TextEditingController();
    String selectedRole = 'teacher';
    String? selectedDeptId =
        _departments.isNotEmpty ? _departments.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create New Account'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Container(
                    width: 480,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration:
                              const InputDecoration(labelText: 'Full Name'),
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          decoration:
                              const InputDecoration(labelText: 'Email Address'),
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password'),
                          validator: (v) => (v?.length ?? 0) < 6
                              ? 'Must be at least 6 characters'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          onChanged: (val) =>
                              setState(() => selectedRole = val ?? 'teacher'),
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: const [
                            DropdownMenuItem(
                                value: 'admin', child: Text('System Admin')),
                            DropdownMenuItem(
                                value: 'campadmin', child: Text('Campus Admin')),
                            DropdownMenuItem(
                                value: 'teacher', child: Text('Teacher')),
                            DropdownMenuItem(
                                value: 'maintenance',
                                child: Text('Maintenance')),
                          ],
                        ),
                        if (selectedRole == 'teacher') ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedDeptId,
                            onChanged: (val) =>
                                setState(() => selectedDeptId = val),
                            decoration:
                                const InputDecoration(labelText: 'Department'),
                            items: _departments
                                .map((d) => DropdownMenuItem(
                                      value: d.id,
                                      child: Text(d.name),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: posController,
                            decoration: const InputDecoration(
                                labelText: 'Position (e.g. Faculty)'),
                          ),
                        ],
                        if (selectedRole == 'maintenance') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: specController,
                            decoration: const InputDecoration(
                                labelText:
                                    'Specialization (e.g. Plumber, Electrician)'),
                          ),
                        ],
                        if (selectedRole == 'teacher' ||
                            selectedRole == 'maintenance') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: empIdController,
                            decoration:
                                const InputDecoration(labelText: 'Employee ID'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                                labelText: 'Contact Phone Number'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: _primaryBlue),
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final err = await SystemAdminService.createUserAccount(
                        email: emailController.text,
                        password: passwordController.text,
                        name: nameController.text,
                        role: selectedRole,
                        departmentId: selectedDeptId,
                        position: posController.text,
                        employeeId: empIdController.text,
                        phone: phoneController.text,
                        specialization: specController.text,
                      );
                      Navigator.pop(ctx);
                      if (err == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Account Created Successfully!')),
                        );
                        _loadData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(err), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Create', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditUserDialog(AppUser user) {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController(text: user.email);
    final nameController = TextEditingController(text: user.name);
    final empIdController = TextEditingController(text: user.employeeId);
    final phoneController = TextEditingController(text: user.phone);
    final specController =
        TextEditingController(text: user.role == UserRole.maintenance ? user.position : '');
    final posController =
        TextEditingController(text: user.role == UserRole.teacher ? user.position : '');
    String selectedRole = user.role.name;
    bool isActive = user.isActive;
    String? selectedDeptId = _departments.isNotEmpty ? _departments.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit Profile: ${user.name}'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Container(
                    width: 480,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration:
                              const InputDecoration(labelText: 'Full Name'),
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          decoration:
                              const InputDecoration(labelText: 'Email Address'),
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          onChanged: (val) =>
                              setState(() => selectedRole = val ?? 'teacher'),
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: const [
                            DropdownMenuItem(
                                value: 'admin', child: Text('System Admin')),
                            DropdownMenuItem(
                                value: 'campadmin', child: Text('Campus Admin')),
                            DropdownMenuItem(
                                value: 'teacher', child: Text('Teacher')),
                            DropdownMenuItem(
                                value: 'maintenance',
                                child: Text('Maintenance')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          title: const Text('Account Active'),
                          value: isActive,
                          onChanged: (val) => setState(() => isActive = val),
                        ),
                        if (selectedRole == 'teacher') ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedDeptId,
                            onChanged: (val) =>
                                setState(() => selectedDeptId = val),
                            decoration:
                                const InputDecoration(labelText: 'Department'),
                            items: _departments
                                .map((d) => DropdownMenuItem(
                                      value: d.id,
                                      child: Text(d.name),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: posController,
                            decoration: const InputDecoration(
                                labelText: 'Position (e.g. Faculty)'),
                          ),
                        ],
                        if (selectedRole == 'maintenance') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: specController,
                            decoration: const InputDecoration(
                                labelText:
                                    'Specialization (e.g. Plumber, Electrician)'),
                          ),
                        ],
                        if (selectedRole == 'teacher' ||
                            selectedRole == 'maintenance') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: empIdController,
                            decoration:
                                const InputDecoration(labelText: 'Employee ID'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                                labelText: 'Contact Phone Number'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: _primaryBlue),
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final err = await SystemAdminService.updateUserAccount(
                        id: user.id,
                        email: emailController.text,
                        name: nameController.text,
                        role: selectedRole,
                        isActive: isActive,
                        departmentId: selectedDeptId,
                        position: posController.text,
                        employeeId: empIdController.text,
                        phone: phoneController.text,
                        specialization: specController.text,
                      );
                      Navigator.pop(ctx);
                      if (err == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Account Configured Successfully!')),
                        );
                        _loadData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(err), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

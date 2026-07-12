import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../authentication/models/user_model.dart';
import '../../authentication/services/auth_service.dart';
import '../../shared/models/department_model.dart';
import '../../shared/services/department_service.dart';
import '../../shared/services/system_admin_service.dart';

class SystemAdminMainNavigation extends StatefulWidget {
  const SystemAdminMainNavigation({super.key});

  @override
  State<SystemAdminMainNavigation> createState() =>
      _SystemAdminMainNavigationState();
}

class _SystemAdminMainNavigationState extends State<SystemAdminMainNavigation> {
  // Users State
  List<AppUser> _allUsers = [];
  List<Department> _departments = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';
  String _selectedStatusFilter = 'all';

  // Styling Accent
  static const _primaryTeal = Color(0xFF0F766E);

  @override
  void initState() {
    super.initState();
    _loadData();
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
    final filtered = _filteredUsers;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        title: const Text(
          'SysAdmin Console',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Panel
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search name, email, ID...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedRoleFilter,
                        onChanged: (val) =>
                            setState(() => _selectedRoleFilter = val ?? 'all'),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                          border: InputBorder.none,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Roles', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'admin', child: Text('System Admin', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'campadmin', child: Text('Campus Admin', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'teacher', child: Text('Teacher', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'maintenance', child: Text('Maint.', style: TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatusFilter,
                        onChanged: (val) =>
                            setState(() => _selectedStatusFilter = val ?? 'all'),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                          border: InputBorder.none,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Status', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'active', child: Text('Active', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'inactive', child: Text('Inactive', style: TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // User Cards List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('No users found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final user = filtered[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: _primaryTeal.withValues(alpha: 0.1),
                                        child: Text(
                                          user.name.isNotEmpty
                                              ? user.name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: _primaryTeal,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              user.email,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildRoleBadge(user.role),
                                      _buildStatusBadge(user.isActive),
                                    ],
                                  ),
                                  if (user.employeeId != null ||
                                      user.department != null ||
                                      user.position != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (user.employeeId != null)
                                            Text(
                                              'ID: ${user.employeeId}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          if (user.role == UserRole.teacher &&
                                              user.department != null)
                                            Text(
                                              'Dept: ${user.department}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          if (user.role == UserRole.maintenance &&
                                              user.position != null)
                                            Text(
                                              'Spec: ${user.position}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _showEditUserDialog(user),
                                        icon: const Icon(Icons.edit_outlined, size: 16),
                                        label: const Text('Edit Account'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: _primaryTeal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        backgroundColor: _primaryTeal,
        child: const Icon(Icons.add, color: Colors.white),
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

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        ),
      ),
    );
  }

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
              title: const Text('Create User'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Full Name'),
                        validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email Address'),
                        validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password'),
                        validator: (v) => (v?.length ?? 0) < 6
                            ? 'Min 6 characters'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        onChanged: (val) =>
                            setState(() => selectedRole = val ?? 'teacher'),
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const [
                          DropdownMenuItem(value: 'admin', child: Text('System Admin')),
                          DropdownMenuItem(value: 'campadmin', child: Text('Campus Admin')),
                          DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                          DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                        ],
                      ),
                      if (selectedRole == 'teacher') ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedDeptId,
                          onChanged: (val) => setState(() => selectedDeptId = val),
                          decoration: const InputDecoration(labelText: 'Department'),
                          items: _departments
                              .map((d) => DropdownMenuItem(
                                    value: d.id,
                                    child: Text(d.name),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: posController,
                          decoration: const InputDecoration(labelText: 'Position'),
                        ),
                      ],
                      if (selectedRole == 'maintenance') ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: specController,
                          decoration: const InputDecoration(labelText: 'Specialization'),
                        ),
                      ],
                      if (selectedRole == 'teacher' ||
                          selectedRole == 'maintenance') ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: empIdController,
                          decoration: const InputDecoration(labelText: 'Employee ID'),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: phoneController,
                          decoration: const InputDecoration(labelText: 'Phone'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryTeal),
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
                          const SnackBar(content: Text('Account Created!')),
                        );
                        _loadData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(err), backgroundColor: Colors.red),
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
              title: Text('Edit: ${user.name}'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Full Name'),
                        validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email Address'),
                        validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        onChanged: (val) =>
                            setState(() => selectedRole = val ?? 'teacher'),
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const [
                          DropdownMenuItem(value: 'admin', child: Text('System Admin')),
                          DropdownMenuItem(value: 'campadmin', child: Text('Campus Admin')),
                          DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                          DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: (val) => setState(() => isActive = val),
                      ),
                      if (selectedRole == 'teacher') ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedDeptId,
                          onChanged: (val) => setState(() => selectedDeptId = val),
                          decoration: const InputDecoration(labelText: 'Department'),
                          items: _departments
                              .map((d) => DropdownMenuItem(
                                    value: d.id,
                                    child: Text(d.name),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: posController,
                          decoration: const InputDecoration(labelText: 'Position'),
                        ),
                      ],
                      if (selectedRole == 'maintenance') ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: specController,
                          decoration: const InputDecoration(labelText: 'Specialization'),
                        ),
                      ],
                      if (selectedRole == 'teacher' ||
                          selectedRole == 'maintenance') ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: empIdController,
                          decoration: const InputDecoration(labelText: 'Employee ID'),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: phoneController,
                          decoration: const InputDecoration(labelText: 'Phone'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryTeal),
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
                          const SnackBar(content: Text('Account Configured!')),
                        );
                        _loadData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(err), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

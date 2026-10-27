import 'package:flutter/material.dart';
import '../../../shared/models/department_model.dart';
import '../../../shared/services/system_admin_service.dart';
import '../../admin/shared/admin_styles.dart';

class SystemAdminAddUserView extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onSuccess;
  final List<Department> departments; // Pass in departments from parent

  const SystemAdminAddUserView({
    super.key,
    required this.onCancel,
    required this.onSuccess,
    required this.departments,
  });

  @override
  State<SystemAdminAddUserView> createState() => _SystemAdminAddUserViewState();
}

class _SystemAdminAddUserViewState extends State<SystemAdminAddUserView> {
  final _formKey = GlobalKey<FormState>();
  
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _empIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specController = TextEditingController();
  final _posController = TextEditingController();

  static const List<String> _teacherPositions = [
    'Faculty',
    'Department Head',
    'Non-Teaching',
  ];
  String _selectedPosition = 'Faculty';

  String _selectedRole = 'teacher';
  String? _selectedDeptId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDeptId = null;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _empIdController.dispose();
    _phoneController.dispose();
    _specController.dispose();
    _posController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final empId = _empIdController.text.trim();
    if (empId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee ID is required (it serves as the default password).'),
          backgroundColor: AdminStyles.error,
        ),
      );
      return;
    }

    final firstName = _firstNameController.text.trim();
    final middleName = _middleNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = [
      firstName,
      if (middleName.isNotEmpty) middleName,
      lastName,
    ].join(' ');

    setState(() => _isLoading = true);

    final String resolvedPosition = _selectedRole == 'teacher'
        ? _selectedPosition
        : _posController.text.trim();

    final rawPhone = _phoneController.text.trim();
    String? normalizedPhone;
    if (rawPhone.isNotEmpty) {
      String digits = rawPhone.replaceAll(RegExp(r'\D'), '');
      if (digits.startsWith('63') && digits.length >= 12) {
        normalizedPhone = '+$digits';
      } else if (digits.startsWith('0')) {
        normalizedPhone = '+63${digits.substring(1)}';
      } else {
        normalizedPhone = '+63$digits';
      }
    }

    final error = await SystemAdminService.createUserAccount(
      email: _emailController.text.trim(),
      password: empId,
      firstName: firstName,
      middleName: middleName.isNotEmpty ? middleName : null,
      lastName: lastName,
      name: fullName,
      role: _selectedRole,
      departmentId: _selectedDeptId?.isNotEmpty == true ? _selectedDeptId : null,
      position: resolvedPosition,
      employeeId: empId,
      phone: normalizedPhone ?? (rawPhone.isNotEmpty ? rawPhone : null),
      specialization: _specController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (error == null) {
      final targetEmail = _emailController.text.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('User Account "$fullName" Created! Login credentials sent to $targetEmail (check Inbox or Spam folder).'),
              ),
            ],
          ),
          backgroundColor: AdminStyles.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AdminStyles.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Container(
      color: AdminStyles.bg,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 40,
          vertical: isMobile ? 16 : 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AdminStyles.textPrimary),
                  onPressed: widget.onCancel,
                  tooltip: 'Back to Users',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New User',
                        style: AdminStyles.headingStyle(fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Configure credentials, roles, and profiles.',
                        style: AdminStyles.bodyStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 24 : 32),

            // Form Layout
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Basic Details Section
                      _buildSectionTitle('Basic Details'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: AdminStyles.cardDecoration(borderRadius: 16),
                        child: MediaQuery.of(context).size.width < 700
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildInputWrapper(
                                    label: 'First Name',
                                    child: _buildTextField(
                                      controller: _firstNameController,
                                      hint: 'e.g. Juan',
                                      icon: Icons.person_outline_rounded,
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'First name is required' : null,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildInputWrapper(
                                    label: 'Middle Name',
                                    child: _buildTextField(
                                      controller: _middleNameController,
                                      hint: 'e.g. Santos (Optional)',
                                      icon: Icons.person_outline_rounded,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildInputWrapper(
                                    label: 'Last Name',
                                    child: _buildTextField(
                                      controller: _lastNameController,
                                      hint: 'e.g. Dela Cruz',
                                      icon: Icons.person_outline_rounded,
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Last name is required' : null,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildInputWrapper(
                                    label: 'Email Address',
                                    child: _buildTextField(
                                      controller: _emailController,
                                      hint: 'e.g. juan@psu.edu.ph',
                                      icon: Icons.alternate_email_rounded,
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required' : null,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: _buildInputWrapper(
                                          label: 'First Name',
                                          child: _buildTextField(
                                            controller: _firstNameController,
                                            hint: 'e.g. Juan',
                                            icon: Icons.person_outline_rounded,
                                            validator: (v) => (v == null || v.trim().isEmpty) ? 'First name is required' : null,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 3,
                                        child: _buildInputWrapper(
                                          label: 'Middle Name',
                                          child: _buildTextField(
                                            controller: _middleNameController,
                                            hint: 'e.g. Santos (Optional)',
                                            icon: Icons.person_outline_rounded,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 4,
                                        child: _buildInputWrapper(
                                          label: 'Last Name',
                                          child: _buildTextField(
                                            controller: _lastNameController,
                                            hint: 'e.g. Dela Cruz',
                                            icon: Icons.person_outline_rounded,
                                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Last name is required' : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _buildInputWrapper(
                                          label: 'Email Address',
                                          child: _buildTextField(
                                            controller: _emailController,
                                            hint: 'e.g. juan@psu.edu.ph',
                                            icon: Icons.alternate_email_rounded,
                                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required' : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 32),

                      // 2. Profile Details Section (Credentials & Contact)
                      _buildSectionTitle('Profile Details'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: AdminStyles.cardDecoration(borderRadius: 16),
                        child: MediaQuery.of(context).size.width < 600
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildInputWrapper(
                                    label: 'Employee ID',
                                    child: _buildTextField(
                                      controller: _empIdController,
                                      hint: 'e.g. EMP-2024-001',
                                      helperText: 'Default password for initial login (min. 6 chars)',
                                      icon: Icons.badge_outlined,
                                      validator: (v) {
                                        final val = v?.trim() ?? '';
                                        if (val.isEmpty) return 'Employee ID is required';
                                        if (val.length < 6) return 'Must be at least 6 characters';
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildInputWrapper(
                                    label: 'Phone Number',
                                    child: _buildTextField(
                                      controller: _phoneController,
                                      hint: 'Optional',
                                      icon: Icons.phone_outlined,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildInputWrapper(
                                      label: 'Employee ID',
                                      child: _buildTextField(
                                        controller: _empIdController,
                                        hint: 'e.g. EMP-2024-001',
                                        helperText: 'Default password for initial login (min. 6 chars)',
                                        icon: Icons.badge_outlined,
                                        validator: (v) {
                                          final val = v?.trim() ?? '';
                                          if (val.isEmpty) return 'Employee ID is required';
                                          if (val.length < 6) return 'Must be at least 6 characters';
                                          return null;
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: _buildInputWrapper(
                                      label: 'Phone Number',
                                      child: _buildTextField(
                                        controller: _phoneController,
                                        hint: 'Optional',
                                        icon: Icons.phone_outlined,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 32),

                      // 3. Access Level Section (The 3 clickable role squares moved down here!)
                      _buildSectionTitle('Access Level'),
                      const SizedBox(height: 16),
                      _buildRoleSelector(),
                      const SizedBox(height: 24),

                      // 4. Role-Specific Details Section
                      if (_selectedRole == 'teacher' ||
                          _selectedRole == 'maintenance' ||
                          _selectedRole == 'campadmin' ||
                          _selectedRole == 'admin') ...[
                        _buildSectionTitle(
                          _selectedRole == 'teacher'
                              ? 'Employee Role Information'
                              : _selectedRole == 'maintenance'
                                  ? 'Maintenance Role Information'
                                  : 'Campus Admin Role Information',
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: AdminStyles.cardDecoration(borderRadius: 16),
                          child: MediaQuery.of(context).size.width < 600
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (_selectedRole == 'teacher') ...[
                                      _buildInputWrapper(
                                        label: 'Department',
                                        child: DropdownButtonFormField<String?>(
                                          isExpanded: true,
                                          initialValue: _selectedDeptId,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminStyles.textSecondary),
                                          decoration: _inputDecoration(icon: Icons.business_rounded),
                                          items: [
                                            const DropdownMenuItem<String?>(
                                              value: null,
                                              child: Text('None'),
                                            ),
                                            ...widget.departments.map<DropdownMenuItem<String?>>((d) {
                                              return DropdownMenuItem<String?>(
                                                value: d.id,
                                                child: Text(d.name, style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                              );
                                            }),
                                          ],
                                          onChanged: (v) => setState(() => _selectedDeptId = v),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      _buildInputWrapper(
                                        label: 'Position',
                                        child: DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          value: _selectedPosition,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminStyles.textSecondary),
                                          decoration: _inputDecoration(icon: Icons.work_outline_rounded),
                                          items: _teacherPositions.map<DropdownMenuItem<String>>((pos) {
                                            return DropdownMenuItem<String>(
                                              value: pos,
                                              child: Text(pos, style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600)),
                                            );
                                          }).toList(),
                                          onChanged: (v) {
                                            if (v != null) {
                                              setState(() => _selectedPosition = v);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                    if (_selectedRole == 'campadmin' || _selectedRole == 'admin') ...[
                                      _buildInputWrapper(
                                        label: 'Designation / Position',
                                        child: _buildTextField(
                                          controller: _posController,
                                          hint: 'e.g. Campus Administrator',
                                          icon: Icons.work_outline_rounded,
                                        ),
                                      ),
                                    ],
                                    if (_selectedRole == 'maintenance') ...[
                                      _buildInputWrapper(
                                        label: 'Specialization',
                                        child: _buildTextField(
                                          controller: _specController,
                                          hint: 'e.g. Electrical, Plumbing',
                                          icon: Icons.build_circle_outlined,
                                        ),
                                      ),
                                    ],
                                  ],
                                )
                              : Column(
                                  children: [
                                    if (_selectedRole == 'teacher') ...[
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _buildInputWrapper(
                                              label: 'Department',
                                              child: DropdownButtonFormField<String?>(
                                                isExpanded: true,
                                                initialValue: _selectedDeptId,
                                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminStyles.textSecondary),
                                                decoration: _inputDecoration(icon: Icons.business_rounded),
                                                items: [
                                                  const DropdownMenuItem<String?>(
                                                    value: null,
                                                    child: Text('None'),
                                                  ),
                                                  ...widget.departments.map<DropdownMenuItem<String?>>((d) {
                                                    return DropdownMenuItem<String?>(
                                                      value: d.id,
                                                      child: Text(d.name, style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                                    );
                                                  }),
                                                ],
                                                onChanged: (v) => setState(() => _selectedDeptId = v),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          Expanded(
                                            child: _buildInputWrapper(
                                              label: 'Position',
                                              child: DropdownButtonFormField<String>(
                                                isExpanded: true,
                                                value: _selectedPosition,
                                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminStyles.textSecondary),
                                                decoration: _inputDecoration(icon: Icons.work_outline_rounded),
                                                items: _teacherPositions.map<DropdownMenuItem<String>>((pos) {
                                                  return DropdownMenuItem<String>(
                                                    value: pos,
                                                    child: Text(pos, style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600)),
                                                  );
                                                }).toList(),
                                                onChanged: (v) {
                                                  if (v != null) {
                                                    setState(() => _selectedPosition = v);
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (_selectedRole == 'campadmin' || _selectedRole == 'admin') ...[
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _buildInputWrapper(
                                              label: 'Designation / Position',
                                              child: _buildTextField(
                                                controller: _posController,
                                                hint: 'e.g. Campus Administrator',
                                                icon: Icons.work_outline_rounded,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          const Expanded(child: SizedBox()),
                                        ],
                                      ),
                                    ],
                                    if (_selectedRole == 'maintenance') ...[
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _buildInputWrapper(
                                              label: 'Specialization',
                                              child: _buildTextField(
                                                controller: _specController,
                                                hint: 'e.g. Electrical, Plumbing',
                                                icon: Icons.build_circle_outlined,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          const Expanded(child: SizedBox()),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Actions
                      LayoutBuilder(
                        builder: (context, actionConstraints) {
                          final isNarrow = actionConstraints.maxWidth < 450;
                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AdminStyles.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 2,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('Create User Account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: widget.onCancel,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    foregroundColor: AdminStyles.textSecondary,
                                    side: const BorderSide(color: AdminStyles.border),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            );
                          }
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: widget.onCancel,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                  foregroundColor: AdminStyles.textSecondary,
                                ),
                                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AdminStyles.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Create User Account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AdminStyles.headingStyle(fontSize: 18, color: AdminStyles.textPrimary, fontWeight: FontWeight.w800),
    );
  }

  Widget _buildRoleSelector() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      return Column(
        children: [
          _RoleOptionCard(
            title: 'Campus Admin',
            desc: 'Manage requests for a campus.',
            icon: Icons.admin_panel_settings_rounded,
            color: AdminStyles.warning,
            isSelected: _selectedRole == 'campadmin',
            onTap: () => setState(() => _selectedRole = 'campadmin'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RoleOptionCard(
                  title: 'Employee',
                  desc: 'Submit and track work requests.',
                  icon: Icons.badge_rounded,
                  color: AdminStyles.primary,
                  isSelected: _selectedRole == 'teacher',
                  onTap: () => setState(() => _selectedRole = 'teacher'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RoleOptionCard(
                  title: 'Maintenance',
                  desc: 'Resolve and manage assigned work.',
                  icon: Icons.handyman_rounded,
                  color: Colors.purple,
                  isSelected: _selectedRole == 'maintenance',
                  onTap: () => setState(() => _selectedRole = 'maintenance'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _RoleOptionCard(
          title: 'Campus Admin',
          desc: 'Manage requests for a campus.',
          icon: Icons.admin_panel_settings_rounded,
          color: AdminStyles.warning,
          isSelected: _selectedRole == 'campadmin',
          onTap: () => setState(() => _selectedRole = 'campadmin'),
        ),
        _RoleOptionCard(
          title: 'Employee',
          desc: 'Submit and track work requests.',
          icon: Icons.badge_rounded,
          color: AdminStyles.primary,
          isSelected: _selectedRole == 'teacher',
          onTap: () => setState(() => _selectedRole = 'teacher'),
        ),
        _RoleOptionCard(
          title: 'Maintenance',
          desc: 'Resolve and manage assigned work.',
          icon: Icons.handyman_rounded,
          color: Colors.purple,
          isSelected: _selectedRole == 'maintenance',
          onTap: () => setState(() => _selectedRole = 'maintenance'),
        ),
      ],
    );
  }

  Widget _buildInputWrapper({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AdminStyles.textSecondary)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({
    required IconData icon,
    String? hint,
    String? helperText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      helperText: helperText,
      helperStyle: const TextStyle(color: AdminStyles.textSecondary, fontSize: 12),
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
      prefixIcon: Icon(icon, size: 20, color: AdminStyles.textSecondary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminStyles.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminStyles.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminStyles.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminStyles.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    String? helperText,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600, color: AdminStyles.textPrimary),
      decoration: _inputDecoration(
        icon: icon,
        hint: hint,
        helperText: helperText,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleOptionCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: MediaQuery.of(context).size.width < 600 ? null : 180,
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AdminStyles.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isSelected ? color : AdminStyles.textSecondary, size: 28),
            const Spacer(),
            Text(
              title,
              style: AdminStyles.headingStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isSelected ? color : AdminStyles.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

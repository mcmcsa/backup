import 'package:flutter/material.dart';
import '../../../shared/services/system_admin_service.dart';
import '../../admin/shared/admin_styles.dart';

class SystemAdminAddUserView extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onSuccess;
  final List<dynamic> departments; // Pass in departments from parent

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
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _empIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specController = TextEditingController();
  final _posController = TextEditingController();

  String _selectedRole = 'teacher';
  String? _selectedDeptId;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.departments.isNotEmpty) {
      _selectedDeptId = widget.departments.first.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _empIdController.dispose();
    _phoneController.dispose();
    _specController.dispose();
    _posController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final error = await SystemAdminService.createUserAccount(
      email: _emailController.text,
      password: _passwordController.text,
      name: _nameController.text,
      role: _selectedRole,
      departmentId: _selectedDeptId,
      position: _posController.text,
      employeeId: _empIdController.text,
      phone: _phoneController.text,
      specialization: _specController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Text('User Account "${_nameController.text}" Created Successfully!'),
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
                      // Role Selection Section
                      _buildSectionTitle('Access Level'),
                      const SizedBox(height: 16),
                      _buildRoleSelector(),
                      const SizedBox(height: 32),

                      // Basic Details Section
                      _buildSectionTitle('Basic Details'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: AdminStyles.cardDecoration(borderRadius: 16),
                        child: Wrap(
                          spacing: 24,
                          runSpacing: 20,
                          children: [
                            _buildInputWrapper(
                              label: 'Full Name',
                              child: _buildTextField(
                                controller: _nameController,
                                hint: 'e.g. Juan Dela Cruz',
                                icon: Icons.person_outline_rounded,
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                            _buildInputWrapper(
                              label: 'Email Address',
                              child: _buildTextField(
                                controller: _emailController,
                                hint: 'e.g. juan@psu.edu.ph',
                                icon: Icons.alternate_email_rounded,
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                            _buildInputWrapper(
                              label: 'Password',
                              child: _buildTextField(
                                controller: _passwordController,
                                hint: 'Min. 6 characters',
                                icon: Icons.lock_outline_rounded,
                                obscure: _obscurePassword,
                                validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: AdminStyles.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Role Specific Details
                      if (_selectedRole == 'teacher' || _selectedRole == 'maintenance') ...[
                        _buildSectionTitle('Profile Details'),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: AdminStyles.cardDecoration(borderRadius: 16),
                          child: Wrap(
                            spacing: 24,
                            runSpacing: 20,
                            children: [
                              _buildInputWrapper(
                                label: 'Employee ID',
                                child: _buildTextField(
                                  controller: _empIdController,
                                  hint: 'Optional',
                                  icon: Icons.badge_outlined,
                                ),
                              ),
                              _buildInputWrapper(
                                label: 'Phone Number',
                                child: _buildTextField(
                                  controller: _phoneController,
                                  hint: 'Optional',
                                  icon: Icons.phone_outlined,
                                ),
                              ),
                              if (_selectedRole == 'teacher') ...[
                                _buildInputWrapper(
                                  label: 'Department',
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedDeptId,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminStyles.textSecondary),
                                    decoration: _inputDecoration(icon: Icons.business_rounded),
                                    items: widget.departments.map<DropdownMenuItem<String>>((d) {
                                      return DropdownMenuItem<String>(
                                        value: d.id,
                                        child: Text(d.name, style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600)),
                                      );
                                    }).toList(),
                                    onChanged: (v) => setState(() => _selectedDeptId = v),
                                  ),
                                ),
                                _buildInputWrapper(
                                  label: 'Position',
                                  child: _buildTextField(
                                    controller: _posController,
                                    hint: 'e.g. Associate Professor',
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
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Actions
                      Row(
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
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _RoleOptionCard(
          title: 'System Admin',
          desc: 'Full access to all system features.',
          icon: Icons.shield_rounded,
          color: AdminStyles.error,
          isSelected: _selectedRole == 'admin',
          onTap: () => setState(() => _selectedRole = 'admin'),
        ),
        _RoleOptionCard(
          title: 'Campus Admin',
          desc: 'Manage requests for a campus.',
          icon: Icons.admin_panel_settings_rounded,
          color: AdminStyles.warning,
          isSelected: _selectedRole == 'campadmin',
          onTap: () => setState(() => _selectedRole = 'campadmin'),
        ),
        _RoleOptionCard(
          title: 'Teacher',
          desc: 'Submit and track work requests.',
          icon: Icons.school_rounded,
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
    return SizedBox(
      width: 340, 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AdminStyles.textSecondary)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required IconData icon, String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
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
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600, color: AdminStyles.textPrimary),
      decoration: _inputDecoration(icon: icon, hint: hint, suffixIcon: suffixIcon),
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
        width: 180,
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

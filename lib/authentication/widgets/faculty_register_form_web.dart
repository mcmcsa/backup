import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../shared/department_input_field_shared.dart';
import '../shared/department_select_shared.dart';

class FacultyRegisterFormWeb extends StatefulWidget {
  final VoidCallback onCancel;
  final ScrollController? scrollController;

  const FacultyRegisterFormWeb({
    super.key,
    required this.onCancel,
    this.scrollController,
  });

  @override
  State<FacultyRegisterFormWeb> createState() => _FacultyRegisterFormWebState();
}

class _FacultyRegisterFormWebState extends State<FacultyRegisterFormWeb> {
  static const Color _brandNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E40AF);
  static const Color _inputBorder = Color(0xFFBFDBFE);
  static const Color _textPrimary = Color(0xFF161E2E);
  static const Color _textMuted = Color(0xFF64748B);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _departmentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  
  final List<String> _departmentOptions = [];
  String? _selectedDepartment;
  bool _isLoadingDepartments = true;
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final departments = await DepartmentSelectShared.loadDepartmentNames();
      if (!mounted) return;

      setState(() {
        _departmentOptions
          ..clear()
          ..addAll(departments);
        _selectedDepartment = _departmentOptions.isNotEmpty ? _departmentOptions.first : null;
        _departmentController.text = _selectedDepartment ?? '';
        _isLoadingDepartments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingDepartments = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _employeeIdController.dispose();
    _departmentController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();
    final error = await authService.registerFaculty(
      fullName: _nameController.text,
      email: _emailController.text,
      department: _departmentController.text.trim(),
      employeeId: _employeeIdController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registration successful. Please verify your email.'),
        backgroundColor: Colors.green,
      ),
    );
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthService>().isLoading;

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.arrow_back_rounded, color: _brandNavy),
                  tooltip: 'Back to Login',
                ),
                const SizedBox(width: 8),
                const Text(
                  'Faculty Registration',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _brandNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFieldLabel('Full Name'),
            _buildTextField(
              controller: _nameController,
              hint: 'Enter your full name',
              prefixIcon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 12),
            _buildFieldLabel('Institutional Email'),
            _buildTextField(
              controller: _emailController,
              hint: 'user@psu.edu.ph',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final email = (v ?? '').trim();
                if (email.isEmpty) return 'Email is required';
                if (!email.contains('@')) return 'Enter a valid email';
                if (!context.read<AuthService>().isInstitutionalEmail(email)) {
                  return 'Please use your institutional email';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildFieldLabel('Department'),
            DepartmentInputFieldShared(
              controller: _departmentController,
              options: _departmentOptions,
              isLoading: _isLoadingDepartments,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.business_rounded, color: _brandNavy, size: 18),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _inputBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _inputBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _brandBlue, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _selectedDepartment = value.trim().isEmpty ? null : value;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildFieldLabel('Employee ID'),
            _buildTextField(
              controller: _employeeIdController,
              hint: 'Enter your Employee ID',
              prefixIcon: Icons.badge_outlined,
            ),
            const SizedBox(height: 12),
            _buildFieldLabel('Password'),
            _buildTextField(
              controller: _passwordController,
              hint: 'At least 8 characters',
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              isPswVisible: _isPasswordVisible,
              onTogglePsw: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              validator: (v) {
                final p = v ?? '';
                if (p.isEmpty) return 'Password is required';
                if (p.length < 8) return 'Min. 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildFieldLabel('Confirm Password'),
            _buildTextField(
              controller: _confirmController,
              hint: 'Re-enter your password',
              prefixIcon: Icons.lock_reset_rounded,
              isPassword: true,
              isPswVisible: _isConfirmVisible,
              onTogglePsw: () => setState(() => _isConfirmVisible = !_isConfirmVisible),
              validator: (v) {
                if (v != _passwordController.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Complete Registration', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: _brandNavy, letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    bool isPassword = false,
    bool isPswVisible = false,
    VoidCallback? onTogglePsw,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !isPswVisible,
      keyboardType: keyboardType,
      style: const TextStyle(fontWeight: FontWeight.w500, color: _textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
        prefixIcon: Icon(prefixIcon, color: _brandNavy, size: 18),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(isPswVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: _textMuted, size: 18),
              onPressed: onTogglePsw,
            )
          : null,
        filled: true,
        fillColor: Colors.transparent,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _inputBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _inputBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _brandBlue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: validator ?? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }

}

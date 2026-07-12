import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../authentication/models/user_model.dart';
import '../../../authentication/services/auth_service.dart';
import '../../admin/shared/admin_styles.dart';

class TeacherProfileWeb extends StatefulWidget {
  const TeacherProfileWeb({super.key});

  @override
  State<TeacherProfileWeb> createState() => _TeacherProfileWebState();
}

class _TeacherProfileWebState extends State<TeacherProfileWeb> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _departmentController;
  late final TextEditingController _positionController;
  late final TextEditingController _employeeIdController;

  bool _isEditing = false;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _initControllers(user);
    _lastUserId = user?.id;
  }

  void _initControllers(AppUser? user) {
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _departmentController = TextEditingController(text: user?.department ?? '');
    _positionController = TextEditingController(text: user?.position ?? 'Faculty');
    _employeeIdController = TextEditingController(text: user?.employeeId ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _departmentController.dispose();
    _positionController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }

  void _syncControllers(AppUser? user) {
    if (user == null || _isEditing || user.id == _lastUserId) return;
    
    // We only update controllers if the user object has fundamentally changed (e.g. ID mismatch)
    // or if the data changed while we weren't looking.
    _lastUserId = user.id;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isEditing) return;
      _nameController.text = user.name;
      _emailController.text = user.email;
      _departmentController.text = user.department ?? '';
      _positionController.text = user.position ?? 'Faculty';
      _employeeIdController.text = user.employeeId ?? '';
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) return;

    try {
      final updated = user.copyWith(
        name: _nameController.text.trim(),
        department: _departmentController.text.trim(),
        position: _positionController.text.trim(),
        employeeId: _employeeIdController.text.trim(),
      );

      final success = await auth.updateProfile(updated);
      
      if (!mounted) return;

      if (success) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: AdminStyles.success,
            behavior: SnackBarBehavior.floating,
            width: 400,
          ),
        );
      } else {
        throw Exception('Update returned false');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: ${e.toString()}'),
          backgroundColor: AdminStyles.error,
          behavior: SnackBarBehavior.floating,
          width: 400,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    _syncControllers(user);

    return Scaffold(
      backgroundColor: AdminStyles.bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildProfileHero(user, authService.isLoading),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildRegistrationDetails()),
                      const SizedBox(width: 32),
                      Expanded(flex: 2, child: _buildAccountSummary(user)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Faculty Profile', style: AdminStyles.headingStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text('Manage your institutional identity and personal information.', 
          style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontSize: 16)),
      ],
    );
  }

  Widget _buildProfileHero(AppUser? user, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: AdminStyles.cardDecoration(hasShadow: true),
      child: Row(
        children: [
          _buildAvatar(user),
          const SizedBox(width: 40),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.name ?? 'Teacher Account', style: AdminStyles.headingStyle(fontSize: 28)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildBadge('FACULTY', AdminStyles.primary),
                    const SizedBox(width: 12),
                    _buildBadge(user?.position?.toUpperCase() ?? 'STAFF', AdminStyles.secondary),
                  ],
                ),
              ],
            ),
          ),
          _buildActionButton(isLoading),
        ],
      ),
    );
  }

  Widget _buildAvatar(AppUser? user) {
    final initials = (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'T';
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: AdminStyles.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AdminStyles.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: AdminStyles.pillDecoration(color: color, isSecondary: true),
      child: Text(label, style: AdminStyles.headingStyle(fontSize: 10, color: color, letterSpacing: 0.5)),
    );
  }

  Widget _buildActionButton(bool isLoading) {
    if (_isEditing) {
      return Row(
        children: [
          TextButton(
            onPressed: () => setState(() => _isEditing = false),
            child: Text('Cancel', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: isLoading ? null : _saveProfile,
            icon: isLoading 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      );
    }
    return ElevatedButton.icon(
      onPressed: () => setState(() => _isEditing = true),
      icon: const Icon(Icons.edit_rounded, size: 18),
      label: const Text('Edit Profile'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminStyles.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildRegistrationDetails() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Information', style: AdminStyles.headingStyle(fontSize: 18)),
          const SizedBox(height: 32),
          _buildField(Icons.person_outline_rounded, 'Full Name', _nameController, _isEditing),
          const SizedBox(height: 24),
          _buildField(Icons.email_outlined, 'Institutional Email', _emailController, false),
          const SizedBox(height: 24),
          _buildField(Icons.badge_outlined, 'Employee ID', _employeeIdController, _isEditing),
          const SizedBox(height: 24),
          _buildField(Icons.school_outlined, 'Department', _departmentController, _isEditing),
          const SizedBox(height: 24),
          _buildField(Icons.work_outline_rounded, 'Designation', _positionController, _isEditing),
        ],
      ),
    );
  }

  Widget _buildField(IconData icon, String label, TextEditingController controller, bool enabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AdminStyles.textSecondary),
            const SizedBox(width: 8),
            Text(label, style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          enabled: enabled,
          style: AdminStyles.bodyStyle(color: enabled ? AdminStyles.textPrimary : AdminStyles.textMuted),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? Colors.white : AdminStyles.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AdminStyles.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AdminStyles.border)),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AdminStyles.border.withValues(alpha: 0.5))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSummary(AppUser? user) {
    final joined = user?.createdAt != null ? DateFormat('MMM dd, yyyy').format(user!.createdAt!) : 'N/A';
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account Summary', style: AdminStyles.headingStyle(fontSize: 18)),
          const SizedBox(height: 32),
          _buildSummaryRow(Icons.verified_user_rounded, 'Status', 'Active', AdminStyles.success),
          _buildSummaryRow(Icons.calendar_today_rounded, 'Joined Date', joined, AdminStyles.primary),
          _buildSummaryRow(Icons.language_rounded, 'Role', user?.roleLabel ?? 'Teacher', AdminStyles.info),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
              Text(value, style: AdminStyles.headingStyle(fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

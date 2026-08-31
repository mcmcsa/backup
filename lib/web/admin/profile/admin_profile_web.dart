import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../authentication/models/user_model.dart';
import '../../../authentication/services/auth_service.dart';
import '../shared/admin_styles.dart';

class AdminProfileWeb extends StatefulWidget {
  const AdminProfileWeb({super.key});

  @override
  State<AdminProfileWeb> createState() => _AdminProfileWebState();
}

class _AdminProfileWebState extends State<AdminProfileWeb> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for all fields set by System Admin during account creation
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _positionController;
  late final TextEditingController _employeeIdController;
  late final TextEditingController _phoneController;

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
    _positionController = TextEditingController(text: user?.position ?? '');
    _employeeIdController = TextEditingController(text: user?.employeeId ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _positionController.dispose();
    _employeeIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _syncControllers(AppUser? user) {
    if (user == null || _isEditing || user.id == _lastUserId) return;
    _lastUserId = user.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isEditing) return;
      _nameController.text = user.name;
      _emailController.text = user.email;
      _positionController.text = user.position ?? '';
      _employeeIdController.text = user.employeeId ?? '';
      _phoneController.text = user.phone ?? '';
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
        position: _positionController.text.trim(),
        employeeId: _employeeIdController.text.trim(),
        phone: _phoneController.text.trim(),
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

    final isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      color: AdminStyles.bg,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 20 : 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildProfileHero(user, authService.isLoading, isMobile),
              const SizedBox(height: 32),
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDetailsCard(),
                        const SizedBox(height: 24),
                        _buildSummaryCard(user),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildDetailsCard()),
                        const SizedBox(width: 24),
                        Expanded(flex: 2, child: _buildSummaryCard(user)),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Settings',
          style: AdminStyles.headingStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Your profile details as configured by the System Administrator.',
          style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildProfileHero(AppUser? user, bool isLoading, bool isMobile) {
    final avatar = Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AdminStyles.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          (_nameController.text.isNotEmpty)
              ? _nameController.text[0].toUpperCase()
              : 'A',
          style: AdminStyles.headingStyle(
              fontSize: 48, fontWeight: FontWeight.w700, color: AdminStyles.primary),
        ),
      ),
    );

    final userInfo = Column(
      crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          user?.name ?? 'Administrator',
          style: AdminStyles.headingStyle(fontSize: 22, fontWeight: FontWeight.w700),
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
        ),
        const SizedBox(height: 4),
        Text(
          user?.email ?? '',
          style: AdminStyles.bodyStyle(fontSize: 14, color: AdminStyles.textSecondary),
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
          children: [
            _buildBadge(user?.roleLabel ?? 'Campus Administrator', AdminStyles.primary),
            if ((user?.position ?? '').isNotEmpty)
              _buildBadge(user!.position!, AdminStyles.secondary),
          ],
        ),
      ],
    );

    final actions = _isEditing
        ? Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: isMobile ? WrapAlignment.center : WrapAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {
                  _syncControllers(user);
                  setState(() => _isEditing = false);
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AdminStyles.border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Cancel', style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600)),
              ),
              ElevatedButton.icon(
                onPressed: isLoading ? null : _saveProfile,
                icon: isLoading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminStyles.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          )
        : ElevatedButton.icon(
            onPressed: () => setState(() => _isEditing = true),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Edit Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        color: AdminStyles.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                avatar,
                const SizedBox(height: 20),
                userInfo,
                const SizedBox(height: 24),
                actions,
              ],
            )
          : Row(
              children: [
                avatar,
                const SizedBox(width: 24),
                Expanded(child: userInfo),
                const SizedBox(width: 24),
                actions,
              ],
            ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AdminStyles.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Information',
              style: AdminStyles.headingStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Set by System Admin at account creation. You may update your name, phone, and designation.',
            style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted),
          ),
          const SizedBox(height: 24),
          _buildField(
            label: 'Full Name',
            icon: Icons.person_outline_rounded,
            controller: _nameController,
            enabled: _isEditing,
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
          ),
          const SizedBox(height: 18),
          _buildField(
            label: 'Email Address',
            icon: Icons.alternate_email_rounded,
            controller: _emailController,
            enabled: false,
            helperText: 'Email is locked to the current login account.',
          ),
          const SizedBox(height: 18),
          _buildField(
            label: 'Employee ID',
            icon: Icons.badge_outlined,
            controller: _employeeIdController,
            enabled: _isEditing,
          ),
          const SizedBox(height: 18),
          _buildField(
            label: 'Designation / Position',
            icon: Icons.work_outline_rounded,
            controller: _positionController,
            enabled: _isEditing,
          ),
          const SizedBox(height: 18),
          _buildField(
            label: 'Contact Number',
            icon: Icons.phone_outlined,
            controller: _phoneController,
            enabled: _isEditing,
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool enabled,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: AdminStyles.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AdminStyles.bodyStyle(
                  fontSize: 13,
                  color: AdminStyles.textSecondary,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          style: AdminStyles.bodyStyle(
              color: enabled ? AdminStyles.textPrimary : AdminStyles.textMuted),
          decoration: InputDecoration(
            helperText: helperText,
            helperStyle: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted),
            filled: true,
            fillColor: enabled ? Colors.white : AdminStyles.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AdminStyles.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AdminStyles.border),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AdminStyles.border.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdminStyles.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(AppUser? user) {
    final joined = user?.createdAt != null
        ? DateFormat('MMMM dd, yyyy').format(user!.createdAt!)
        : 'N/A';

    return Container(
      decoration: BoxDecoration(
        color: AdminStyles.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account Summary',
              style: AdminStyles.headingStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          _buildSummaryRow('Account Status', 'Active', AdminStyles.success),
          _buildSummaryRow('Role', user?.roleLabel ?? 'Campus Administrator', AdminStyles.primary),
          _buildSummaryRow(
              'Employee ID',
              (user?.employeeId?.isNotEmpty == true) ? user!.employeeId! : 'Not set',
              AdminStyles.primary),
          _buildSummaryRow(
              'Contact',
              (user?.phone?.isNotEmpty == true) ? user!.phone! : 'Not set',
              AdminStyles.info),
          _buildSummaryRow('Joined', joined, AdminStyles.textSecondary),
          const Divider(height: 32),
          // Quick links
          Text('Quick Actions',
              style: AdminStyles.bodyStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AdminStyles.textMuted)),
          const SizedBox(height: 16),
          _buildSettingItem('Notifications', Icons.notifications_rounded, const Color(0xFF10B981)),
          const SizedBox(height: 10),
          _buildSettingItem('Preferences', Icons.tune_rounded, const Color(0xFF818CF8)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String title, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: AdminStyles.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminStyles.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: AdminStyles.bodyStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Icon(Icons.arrow_forward_rounded,
              color: AdminStyles.textMuted.withValues(alpha: 0.5), size: 16),
        ],
      ),
    );
  }
}

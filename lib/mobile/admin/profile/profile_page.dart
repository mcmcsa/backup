import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../authentication/models/user_model.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../shared/admin_app_bar.dart';
import '../../../web/admin/shared/admin_styles.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback openDrawer;

  const ProfilePage({super.key, required this.openDrawer});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers — matches Web fields
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _positionController;
  late final TextEditingController _employeeIdController;
  late final TextEditingController _phoneController;

  bool _isEditing = false;
  String? _lastUserId;
  bool _isUploadingImage = false;
  List<WorkRequest> _requests = [];
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _initControllers(user);
    _lastUserId = user?.id;
    _loadStats();
  }

  void _initControllers(AppUser? user) {
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _positionController = TextEditingController(text: user?.position ?? '');
    _employeeIdController = TextEditingController(text: user?.employeeId ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  Future<void> _loadStats() async {
    try {
      final data = await WorkRequestService.fetchAll();
      if (mounted) {
        setState(() {
          _requests = data;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
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

  Future<void> _pickAndUploadProfileImage(AppUser user) async {
    final auth = context.read<AuthService>();
    final picker = ImagePicker();
    try {
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (file == null) return;

      setState(() => _isUploadingImage = true);

      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last;
      final path = 'profiles/${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // Upload binary to Supabase storage
      await Supabase.instance.client.storage
          .from('profile-images')
          .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));

      // Get public URL
      final publicUrl = Supabase.instance.client.storage
          .from('profile-images')
          .getPublicUrl(path);

      // Save to database
      final success = await auth.updateProfileImage(
        role: user.role,
        userId: user.id,
        profileImage: publicUrl,
      );

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile picture updated successfully!'),
            backgroundColor: AdminStyles.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw Exception('Failed to update profile picture in database');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload profile picture: $e'),
          backgroundColor: AdminStyles.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
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
      appBar: AdminAppBar(
        openDrawer: widget.openDrawer,
        subtitle: 'Campus Administrator',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildProfileHero(user, authService.isLoading),
              const SizedBox(height: 20),
              _buildDetailsCard(),
              const SizedBox(height: 20),
              _buildSummaryCard(user),
              const SizedBox(height: 24),
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
          style: AdminStyles.headingStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Your profile details as configured by the System Administrator.',
          style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildProfileHero(AppUser? user, bool isLoading) {
    final avatar = _buildAvatar(user);

    final userInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          user?.name ?? 'Administrator',
          style: AdminStyles.headingStyle(fontSize: 20, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          user?.email ?? '',
          style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _buildBadge(user?.roleLabel ?? 'Campus Administrator', AdminStyles.primary),
            if ((user?.position ?? '').isNotEmpty)
              _buildBadge(user!.position!, AdminStyles.secondary),
          ],
        ),
      ],
    );

    final actions = _buildActionButton(isLoading);

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          avatar,
          const SizedBox(height: 16),
          userInfo,
          const SizedBox(height: 20),
          actions,
          const SizedBox(height: 20),
          const Divider(color: AdminStyles.border),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                _isLoadingStats ? '...' : '${_requests.length}',
                'Total Requests',
              ),
              Container(
                width: 1,
                height: 40,
                color: AdminStyles.border,
              ),
              _buildStatItem(
                _isLoadingStats
                    ? '...'
                    : _requests.isEmpty
                        ? '0%'
                        : '${(_requests.where((r) => r.status == 'completed').length * 100 / _requests.length).round()}%',
                'Resolved',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(AppUser? user) {
    if (user == null) return const SizedBox.shrink();
    final initials = (user.name.isNotEmpty == true) ? user.name[0].toUpperCase() : 'A';

    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AdminStyles.primary.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: AdminStyles.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: _isUploadingImage
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : (user.profileImage?.isNotEmpty == true)
                    ? ClipOval(
                        child: Image.network(
                          user.profileImage!,
                          width: 94,
                          height: 94,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              initials,
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initials,
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
          ),
        ),
        if (!_isUploadingImage)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _pickAndUploadProfileImage(user),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminStyles.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton(bool isLoading) {
    if (_isEditing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () {
              _syncControllers(context.read<AuthService>().currentUser);
              setState(() => _isEditing = false);
            },
            child: Text('Cancel', style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 16),
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
      );
    }
    return ElevatedButton.icon(
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

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AdminStyles.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AdminStyles.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
      ),
      padding: const EdgeInsets.all(20),
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
      padding: const EdgeInsets.all(20),
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

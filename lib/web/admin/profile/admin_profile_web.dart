import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
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
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _initControllers(user);
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
    if (user == null || _isEditing) return;
    if (_nameController.text != user.name ||
        _emailController.text != user.email ||
        _positionController.text != (user.position ?? '') ||
        _employeeIdController.text != (user.employeeId ?? '') ||
        _phoneController.text != (user.phone ?? '')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isEditing) return;
        _nameController.text = user.name;
        _emailController.text = user.email;
        _positionController.text = user.position ?? '';
        _employeeIdController.text = user.employeeId ?? '';
        _phoneController.text = user.phone ?? '';
      });
    }
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
      final rawExt = file.name.split('.').last.toLowerCase();
      // Normalize MIME types — Supabase only accepts standard image/* types
      final mimeType = _normalizeMimeType(rawExt);
      final ext = mimeType.split('/').last == 'jpeg' ? 'jpg' : rawExt;
      final path = 'profiles/${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Supabase.instance.client.storage
          .from('profile-images')
          .uploadBinary(path, bytes,
              fileOptions: FileOptions(upsert: true, contentType: mimeType));

      final publicUrl = Supabase.instance.client.storage
          .from('profile-images')
          .getPublicUrl(path);

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
            width: 400,
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
          width: 400,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
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

  /// Maps raw file extensions to Supabase-accepted image MIME types.
  String _normalizeMimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'jfif':
      case 'pjpeg':
      case 'pjp':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'image/jpeg';
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
              const SizedBox(height: 24),
              _buildDetailsCard(),
              const SizedBox(height: 32),
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

  Widget _buildAvatar(AppUser? user) {
    if (user == null) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AdminStyles.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text('A',
              style: AdminStyles.headingStyle(
                  fontSize: 40, fontWeight: FontWeight.w700, color: AdminStyles.primary)),
        ),
      );
    }

    final initials = user.name.isNotEmpty ? user.name[0].toUpperCase() : 'A';

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
                            child: Text(initials,
                                style: const TextStyle(
                                    fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(initials,
                            style: const TextStyle(
                                fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
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
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileHero(AppUser? user, bool isLoading, bool isMobile) {
    final avatar = _buildAvatar(user);

    // Role badge
    final roleBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: AdminStyles.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminStyles.primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        'CAMPUS ADMINISTRATOR',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AdminStyles.primary,
          letterSpacing: 1.2,
        ),
      ),
    );

    final userInfo = Column(
      crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        isMobile ? roleBadge : Align(alignment: Alignment.centerLeft, child: roleBadge),
        const SizedBox(height: 10),
        Text(
          user?.name ?? 'Administrator',
          style: AdminStyles.headingStyle(fontSize: 22, fontWeight: FontWeight.w800),
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
        ),
        const SizedBox(height: 4),
        Text(
          user?.email ?? '',
          style: AdminStyles.bodyStyle(fontSize: 14, color: AdminStyles.textSecondary),
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
        ),
        if ((user?.position ?? '').isNotEmpty) ...[  
          const SizedBox(height: 4),
          Text(
            user!.position!,
            style: AdminStyles.bodyStyle(
                fontSize: 13, color: AdminStyles.primary, fontWeight: FontWeight.w600),
            textAlign: isMobile ? TextAlign.center : TextAlign.left,
          ),
        ],
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
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 18),
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
                const SizedBox(height: 20),
                actions,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                avatar,
                const SizedBox(width: 28),
                Expanded(child: userInfo),
                const SizedBox(width: 24),
                actions,
              ],
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

}

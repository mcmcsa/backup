import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../authentication/models/user_model.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/providers/theme_provider.dart';
import '../shared/admin_app_bar.dart';
import '../../../web/admin/shared/admin_styles.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback openDrawer;

  const ProfilePage({super.key, required this.openDrawer});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _primary = AdminStyles.primary;

  final _formKey = GlobalKey<FormState>();

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
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() => _isUploadingImage = true);

      final bytes = await file.readAsBytes();
      final rawExt = file.name.split('.').last.toLowerCase();
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
      if (mounted) setState(() => _isUploadingImage = false);
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    _syncControllers(user);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AdminAppBar(
        openDrawer: widget.openDrawer,
        subtitle: 'Campus Administrator',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildProfileHero(user, authService.isLoading, themeProvider, isDark),
              const SizedBox(height: 20),
              _buildAccountDetails(themeProvider, isDark),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // -- Profile Hero ------------------------------------------------------------

  Widget _buildProfileHero(AppUser? user, bool isLoading, ThemeProvider themeProvider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeProvider.borderColor),
        boxShadow: [
          BoxShadow(
            color: themeProvider.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Center(child: _buildAvatar(user, themeProvider, isDark)),
          const SizedBox(height: 20),
          // Role label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F766E).withValues(alpha: 0.25)
                  : _primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2DD4BF).withValues(alpha: 0.3)
                    : _primary.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              'CAMPUS ADMINISTRATOR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFF2DD4BF) : _primary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user?.name ?? 'Administrator',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: themeProvider.textColor,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            user?.email ?? '',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: themeProvider.subtitleColor,
            ),
            textAlign: TextAlign.center,
          ),
          if ((user?.position ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              user!.position!,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF2DD4BF) : _primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          _buildActionButton(isLoading, user, themeProvider, isDark),
        ],
      ),
    );
  }

  Widget _buildAvatar(AppUser? user, ThemeProvider themeProvider, bool isDark) {
    if (user == null) return const SizedBox.shrink();
    final initials = user.name.isNotEmpty ? user.name[0].toUpperCase() : 'A';

    return Stack(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? themeProvider.borderColor : Colors.white,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.18),
                blurRadius: 18,
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
                          width: 104,
                          height: 104,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
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
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? themeProvider.cardColor : Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton(bool isLoading, AppUser? user, ThemeProvider themeProvider, bool isDark) {
    if (_isEditing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () {
              _syncControllers(user);
              setState(() => _isEditing = false);
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: themeProvider.subtitleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: isLoading ? null : _saveProfile,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => setState(() => _isEditing = true),
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // -- Account Details Card ----------------------------------------------------

  Widget _buildAccountDetails(ThemeProvider themeProvider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeProvider.borderColor),
        boxShadow: [
          BoxShadow(
            color: themeProvider.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: themeProvider.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'These details were set by the System Admin. You may update your name, phone, and designation.',
            style: TextStyle(
              fontSize: 12,
              color: themeProvider.subtitleColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          _buildField(
            Icons.person_outline_rounded,
            'Full Name',
            _nameController,
            _isEditing,
            themeProvider,
            isDark,
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
          ),
          const SizedBox(height: 20),
          _buildField(
            Icons.alternate_email_rounded,
            'Email Address',
            _emailController,
            false,
            themeProvider,
            isDark,
            helperText: 'Email is locked to the current login account.',
          ),
          const SizedBox(height: 20),
          _buildField(
            Icons.badge_outlined,
            'Employee ID',
            _employeeIdController,
            _isEditing,
            themeProvider,
            isDark,
          ),
          const SizedBox(height: 20),
          _buildField(
            Icons.work_outline_rounded,
            'Designation / Position',
            _positionController,
            _isEditing,
            themeProvider,
            isDark,
          ),
          const SizedBox(height: 20),
          _buildField(
            Icons.phone_outlined,
            'Contact Number',
            _phoneController,
            _isEditing,
            themeProvider,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    IconData icon,
    String label,
    TextEditingController controller,
    bool enabled,
    ThemeProvider themeProvider,
    bool isDark, {
    String? helperText,
    String? Function(String?)? validator,
  }) {
    final disabledBg = isDark
        ? const Color(0xFF222222)
        : AdminStyles.bg;
    final enabledBg = isDark
        ? themeProvider.inputFillColor
        : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: themeProvider.subtitleColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: themeProvider.subtitleColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: enabled ? themeProvider.textColor : themeProvider.subtitleColor,
          ),
          decoration: InputDecoration(
            helperText: helperText,
            helperStyle: TextStyle(fontSize: 11, color: themeProvider.subtitleColor),
            filled: true,
            fillColor: enabled ? enabledBg : disabledBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: themeProvider.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: themeProvider.borderColor),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? themeProvider.borderColor.withValues(alpha: 0.4)
                    : themeProvider.borderColor.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}



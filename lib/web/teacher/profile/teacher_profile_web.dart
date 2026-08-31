import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
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

  // Controllers — all fields the System Admin fills in during user creation
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _departmentController;
  late final TextEditingController _positionController;
  late final TextEditingController _employeeIdController;
  late final TextEditingController _phoneController;

  bool _isEditing = false;
  String? _lastUserId;
  bool _isUploadingImage = false;

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
    _positionController = TextEditingController(text: user?.position ?? '');
    _employeeIdController = TextEditingController(text: user?.employeeId ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _departmentController.dispose();
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
      _departmentController.text = user.department ?? '';
      _positionController.text = user.position ?? '';
      _employeeIdController.text = user.employeeId ?? '';
      _phoneController.text = user.phone ?? '';
    });
  }

  Future<void> _pickAndUploadProfileImage(AppUser user) async {
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

      // Save to teacher profile database
      final auth = context.read<AuthService>();
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
        department: _departmentController.text.trim(),
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

    return Scaffold(
      backgroundColor: AdminStyles.bg,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 20 : 40),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHero(user, authService.isLoading, isMobile),
                  const SizedBox(height: 32),
                  _buildRegistrationDetails(isMobile),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHero(AppUser? user, bool isLoading, bool isMobile) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        decoration: AdminStyles.cardDecoration(hasShadow: true),
        child: Column(
          children: [
            _buildAvatar(user),
            const SizedBox(height: 24),
            Text(
              'PROFILE',
              style: AdminStyles.headingStyle(
                fontSize: 11,
                color: AdminStyles.primary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user?.name ?? 'Teacher Account',
              style: AdminStyles.headingStyle(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              user?.email ?? '',
              style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Center(child: _buildActionButton(isLoading)),
            ),
          ],
        ),
      );
    }

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
                Text(
                  'PROFILE',
                  style: AdminStyles.headingStyle(
                    fontSize: 11,
                    color: AdminStyles.primary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(user?.name ?? 'Teacher Account',
                    style: AdminStyles.headingStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text(user?.email ?? '',
                    style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
              ],
            ),
          ),
          _buildActionButton(isLoading),
        ],
      ),
    );
  }

  Widget _buildAvatar(AppUser? user) {
    if (user == null) return const SizedBox.shrink();
    final initials = (user.name.isNotEmpty == true) ? user.name[0].toUpperCase() : 'T';
    
    return Stack(
      children: [
        Container(
          width: 110,
          height: 110,
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
                          width: 104,
                          height: 104,
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
                              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initials,
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
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
                  size: 16,
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
            onPressed: () => setState(() => _isEditing = false),
            child: Text('Cancel',
                style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: isLoading ? null : _saveProfile,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildRegistrationDetails(bool isMobile) {
    final fields = [
      _buildField(Icons.person_outline_rounded, 'Full Name', _nameController, _isEditing),
      _buildField(Icons.email_outlined, 'Institutional Email', _emailController, false, helperText: 'Email address cannot be changed here.'),
      _buildField(Icons.badge_outlined, 'Employee ID', _employeeIdController, _isEditing),
      _buildField(Icons.phone_outlined, 'Contact Number', _phoneController, _isEditing),
      _buildField(Icons.school_outlined, 'Department', _departmentController, _isEditing),
      _buildField(Icons.work_outline_rounded, 'Designation / Position', _positionController, _isEditing),
    ];

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Information', style: AdminStyles.headingStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            'These details were set by the System Admin when your account was created. You may update them here.',
            style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted),
          ),
          const SizedBox(height: 28),
          if (isMobile)
            Column(
              children: fields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: f,
              )).toList(),
            )
          else
            Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 24),
                    Expanded(child: fields[1]),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: fields[2]),
                    const SizedBox(width: 24),
                    Expanded(child: fields[3]),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: fields[4]),
                    const SizedBox(width: 24),
                    Expanded(child: fields[5]),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildField(
    IconData icon,
    String label,
    TextEditingController controller,
    bool enabled, {
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AdminStyles.textSecondary),
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
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          enabled: enabled,
          style: AdminStyles.bodyStyle(
              color: enabled
                  ? AdminStyles.textPrimary
                  : AdminStyles.textMuted),
          decoration: InputDecoration(
            helperText: helperText,
            helperStyle: AdminStyles.bodyStyle(
                fontSize: 11, color: AdminStyles.textMuted),
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
              borderSide: BorderSide(
                  color: AdminStyles.border.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AdminStyles.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}

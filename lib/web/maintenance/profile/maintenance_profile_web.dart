import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../authentication/models/user_model.dart';
import '../../../authentication/services/auth_service.dart';

class MaintenanceProfileWeb extends StatefulWidget {
  const MaintenanceProfileWeb({super.key});

  @override
  State<MaintenanceProfileWeb> createState() => _MaintenanceProfileWebState();
}

class _MaintenanceProfileWebState extends State<MaintenanceProfileWeb> {
  static const Color _primaryBlue = Color(0xFF0EA5E9);
  static const Color _subtleText = Color(0xFF64748B);
  static const Color _pageBg = Color(0xFFF1F5F9);
  static const Color _cardBg = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF0F172A);

  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _employeeIdController;
  late final TextEditingController _specializationController;
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
    _employeeIdController = TextEditingController(text: user?.employeeId ?? '');
    _specializationController = TextEditingController(text: user?.position ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _employeeIdController.dispose();
    _specializationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _syncControllers(AppUser? user) {
    if (user == null) return;
    if (user.id != _lastUserId) {
      _lastUserId = user.id;
      _initControllers(user);
    } else if (!_isEditing) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _employeeIdController.text = user.employeeId ?? '';
      _specializationController.text = user.position ?? '';
      _phoneController.text = user.phone ?? '';
    }
  }

  Future<void> _pickAndUploadProfileImage(AppUser user) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (file == null) return;

      setState(() => _isUploadingImage = true);

      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last;
      final path = 'profiles/${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Supabase.instance.client.storage
          .from('profile-images')
          .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));

      final publicUrl = Supabase.instance.client.storage
          .from('profile-images')
          .getPublicUrl(path);

      final auth = context.read<AuthService>();
      final success = await auth.updateProfileImage(
        role: user.role,
        userId: user.id,
        profileImage: publicUrl,
      );

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!')),
        );
      } else {
        throw Exception('Failed to update profile picture in database');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload profile picture: $e')),
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
        position: _specializationController.text.trim(),
        employeeId: _employeeIdController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      final success = await auth.updateProfile(updated);
      if (!mounted) return;

      if (success) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      } else {
        throw Exception('Update returned false');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: ${e.toString()}')),
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
      backgroundColor: _pageBg,
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
    final avatar = _buildAvatar(user);
    final details = Column(
      crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        const Text(
          'MAINTENANCE PROFILE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _primaryBlue,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          user?.name ?? 'Maintenance Account',
          style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.w800, color: _textPrimary, letterSpacing: -0.5),
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
        ),
        const SizedBox(height: 8),
        Text(
          user?.email ?? '',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _subtleText),
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
        ),
      ],
    );
    final actionBtn = _buildActionButton(isLoading);

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 40),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              children: [
                Center(child: avatar),
                const SizedBox(height: 24),
                details,
                const SizedBox(height: 24),
                actionBtn,
              ],
            )
          : Row(
              children: [
                avatar,
                const SizedBox(width: 40),
                Expanded(child: details),
                actionBtn,
              ],
            ),
    );
  }

  Widget _buildAvatar(AppUser? user) {
    if (user == null) return const SizedBox.shrink();
    final initials = (user.name.isNotEmpty == true) ? user.name[0].toUpperCase() : 'M';
    
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
                color: _primaryBlue.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryBlue, Color(0xFF0284C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
                  color: _primaryBlue,
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
            child: const Text('Cancel', style: TextStyle(color: _subtleText, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: isLoading ? null : _saveProfile,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
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
      label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildRegistrationDetails(bool isMobile) {
    final fields = [
      _buildField(Icons.person_outline_rounded, 'Full Name', _nameController, _isEditing),
      _buildField(Icons.email_outlined, 'Email Address', _emailController, false, helperText: 'Email address cannot be changed here.'),
      _buildField(Icons.badge_outlined, 'Employee ID', _employeeIdController, _isEditing),
      _buildField(Icons.phone_outlined, 'Contact Number', _phoneController, _isEditing),
      _buildField(Icons.engineering_outlined, 'Specialization', _specializationController, _isEditing),
    ];

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'These details were set by the System Admin when your account was created. You may update them here.',
            style: TextStyle(fontSize: 12, color: _subtleText, fontWeight: FontWeight.w500),
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
                    Expanded(child: const SizedBox()), // Empty space to balance
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
            Icon(icon, size: 16, color: _subtleText),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 13,
                  color: _subtleText,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: enabled ? _textPrimary : _subtleText),
          decoration: InputDecoration(
            helperText: helperText,
            helperStyle: const TextStyle(fontSize: 11, color: _subtleText),
            filled: true,
            fillColor: enabled ? Colors.white : _pageBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderColor),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _borderColor.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryBlue, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}

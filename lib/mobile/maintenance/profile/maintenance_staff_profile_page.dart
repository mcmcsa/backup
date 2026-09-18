import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../authentication/models/user_model.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../teacher/menu_pages/about_us_page.dart';
import '../../teacher/menu_pages/contact_us_page.dart';
import '../../teacher/menu_pages/settings_page.dart';

class MaintenanceStaffProfilePage extends StatefulWidget {
  const MaintenanceStaffProfilePage({super.key});

  @override
  State<MaintenanceStaffProfilePage> createState() => _MaintenanceStaffProfilePageState();
}

class _MaintenanceStaffProfilePageState extends State<MaintenanceStaffProfilePage> {
  static const Color _primaryBlue = Color(0xFF0EA5E9);
  static const Color _subtleText = Color(0xFF64748B);

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
  int _completedCount = 0;
  int _inProgressCount = 0;

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
    _employeeIdController = TextEditingController(text: user?.employeeId ?? '');
    _specializationController = TextEditingController(text: user?.position ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  Future<void> _loadStats() async {
    try {
      final user = context.read<AuthService>().currentUser;
      if (user != null) {
        final requests = await WorkRequestService.fetchAssignedTo(user.id);
        if (mounted) {
          setState(() {
            _completedCount = requests.where((r) => r.status.toLowerCase() == 'completed').length;
            _inProgressCount = requests.where((r) => ['in progress', 'in_progress', 'assigned', 'accepted by maintenance'].contains(r.status.toLowerCase())).length;
          });
        }
      }
    } catch (_) {}
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
    if (user == null || _isEditing || user.id == _lastUserId) return;
    _lastUserId = user.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isEditing) return;
      _nameController.text = user.name;
      _emailController.text = user.email;
      _employeeIdController.text = user.employeeId ?? '';
      _specializationController.text = user.position ?? '';
      _phoneController.text = user.phone ?? '';
    });
  }

  Future<void> _pickAndUploadProfileImage(AppUser user) async {
    final auth = context.read<AuthService>();
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    _syncControllers(user);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: CommonAppBar(
        roleText: 'Maintenance Staff',
        primaryColor: _primaryBlue,
        onMenuPressed: () => Scaffold.of(context).openDrawer(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildProfileHero(user, authService.isLoading, themeProvider),
              const SizedBox(height: 20),
              _buildRegistrationDetails(themeProvider),
              const SizedBox(height: 20),
              _buildSettingsMenu(themeProvider),
              const SizedBox(height: 20),
              _buildSupportMenu(themeProvider),
              const SizedBox(height: 20),
              _buildLogoutButton(themeProvider),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHero(AppUser? user, bool isLoading, ThemeProvider themeProvider) {
    final avatar = _buildAvatar(user);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
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
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: themeProvider.textColor, letterSpacing: -0.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          user?.email ?? '',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: themeProvider.subtitleColor),
          textAlign: TextAlign.center,
        ),
      ],
    );

    final actionBtn = _buildActionButton(isLoading);

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
          Center(child: avatar),
          const SizedBox(height: 24),
          details,
          const SizedBox(height: 24),
          actionBtn,
          const SizedBox(height: 20),
          Divider(color: themeProvider.borderColor),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('$_completedCount', 'Completed', Icons.check_circle_outline, themeProvider),
              Container(
                width: 1,
                height: 50,
                color: themeProvider.borderColor,
              ),
              _buildStatItem('$_inProgressCount', 'In Progress', Icons.pending_outlined, themeProvider),
            ],
          ),
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

  Widget _buildRegistrationDetails(ThemeProvider themeProvider) {
    final fields = [
      _buildField(Icons.person_outline_rounded, 'Full Name', _nameController, _isEditing, themeProvider),
      _buildField(Icons.email_outlined, 'Email Address', _emailController, false, themeProvider, helperText: 'Email address cannot be changed here.'),
      _buildField(Icons.badge_outlined, 'Employee ID', _employeeIdController, _isEditing, themeProvider),
      _buildField(Icons.phone_outlined, 'Contact Number', _phoneController, _isEditing, themeProvider),
      _buildField(Icons.engineering_outlined, 'Specialization', _specializationController, _isEditing, themeProvider),
    ];

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
          Text('Account Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: themeProvider.textColor)),
          const SizedBox(height: 8),
          Text(
            'These details were set by the System Admin when your account was created. You may update them here.',
            style: TextStyle(fontSize: 12, color: themeProvider.subtitleColor, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 28),
          Column(
            children: fields.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: f,
            )).toList(),
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
    ThemeProvider themeProvider, {
    String? helperText,
  }) {
    final isDark = themeProvider.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: themeProvider.subtitleColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                  fontSize: 13,
                  color: themeProvider.subtitleColor,
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
              color: enabled ? themeProvider.textColor : themeProvider.subtitleColor),
          decoration: InputDecoration(
            helperText: helperText,
            helperStyle: TextStyle(fontSize: 11, color: themeProvider.subtitleColor),
            filled: true,
            fillColor: enabled
                ? (isDark ? const Color(0xFF1E1E2E) : Colors.white)
                : (isDark ? const Color(0xFF181824) : const Color(0xFFF1F5F9)),
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
              borderSide: BorderSide(color: themeProvider.borderColor.withValues(alpha: 0.5)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: _primaryBlue, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, ThemeProvider themeProvider) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: _primaryBlue,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: themeProvider.subtitleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsMenu(ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeProvider.borderColor),
        boxShadow: [
          BoxShadow(
            color: themeProvider.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.notifications_outlined,
            iconColor: Colors.orange,
            title: 'Notifications',
            subtitle: 'Manage notification preferences',
            themeProvider: themeProvider,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification preferences coming soon')),
              );
            },
          ),
          _buildDivider(themeProvider),
          _buildMenuItem(
            icon: Icons.lock_outline,
            iconColor: Colors.green,
            title: 'Security',
            subtitle: 'Change password & security settings',
            themeProvider: themeProvider,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Security settings coming soon')),
              );
            },
          ),
          _buildDivider(themeProvider),
          _buildMenuItem(
            icon: Icons.settings_outlined,
            iconColor: Colors.grey,
            title: 'Settings',
            subtitle: 'App preferences and configurations',
            themeProvider: themeProvider,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSupportMenu(ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeProvider.borderColor),
        boxShadow: [
          BoxShadow(
            color: themeProvider.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.help_outline,
            iconColor: Colors.purple,
            title: 'Help & Support',
            subtitle: 'Get help and contact support',
            themeProvider: themeProvider,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContactUsPage(),
                ),
              );
            },
          ),
          _buildDivider(themeProvider),
          _buildMenuItem(
            icon: Icons.info_outline,
            iconColor: Colors.cyan,
            title: 'About',
            subtitle: 'App version and information',
            themeProvider: themeProvider,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AboutUsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(ThemeProvider themeProvider) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          _showLogoutDialog(context, themeProvider);
        },
        icon: const Icon(Icons.logout, size: 20),
        label: const Text(
          'Logout',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Colors.red, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ThemeProvider themeProvider,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: themeProvider.isDarkMode ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: themeProvider.subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: themeProvider.subtitleColor,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: themeProvider.borderColor,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: themeProvider.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Logout',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: themeProvider.textColor,
            ),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: TextStyle(
              fontSize: 15,
              color: themeProvider.textColor,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15,
                  color: themeProvider.subtitleColor,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final authService = context.read<AuthService>();
                Navigator.of(dialogContext, rootNavigator: true).pop();
                if (context.mounted) {
                  await authService.handleLogoutButton(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

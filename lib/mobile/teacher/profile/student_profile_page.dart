import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../authentication/models/user_model.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../admin/shared/notifications_page.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../shared/services/department_service.dart';
import '../../../shared/models/department_model.dart';
import '../../../web/admin/shared/admin_styles.dart';

class StudentProfilePage extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final bool isActive;

  const StudentProfilePage({
    super.key,
    this.scaffoldKey,
    this.isActive = true,
  });

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers — matches the Web fields
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _departmentController;
  late final TextEditingController _positionController;
  late final TextEditingController _employeeIdController;
  late final TextEditingController _phoneController;

  // Focus nodes for interactive tap-to-edit
  final _nameFocusNode = FocusNode();
  final _departmentFocusNode = FocusNode();
  final _positionFocusNode = FocusNode();
  final _employeeIdFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();

  bool _isEditing = false;
  String? _lastUserId;
  bool _isUploadingImage = false;

  List<Department> _departments = [];
  bool _isLoadingDepartments = false;
  String? _selectedDepartmentName;
  String? _selectedDepartmentId;

  late ThemeProvider _themeProvider;
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _initControllers(user);
    _lastUserId = user?.id;
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    setState(() => _isLoadingDepartments = true);
    try {
      final list = await DepartmentService.fetchAll();
      if (!mounted) return;
      setState(() {
        _departments = list;
        _isLoadingDepartments = false;
        if (_selectedDepartmentName != null && _selectedDepartmentId == null) {
          for (final d in list) {
            if (d.name.trim().toLowerCase() == _selectedDepartmentName!.trim().toLowerCase()) {
              _selectedDepartmentId = d.id;
              _selectedDepartmentName = d.name;
              break;
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading departments in student profile: $e');
      if (mounted) {
        setState(() => _isLoadingDepartments = false);
      }
    }
  }

  static String _formatPhoneForDisplay(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '';
    final trimmed = phone.trim();
    if (trimmed.startsWith('+63')) {
      return trimmed.substring(3).trim();
    } else if (trimmed.startsWith('63') && trimmed.length >= 12) {
      return trimmed.substring(2).trim();
    } else if (trimmed.startsWith('09')) {
      return trimmed.substring(1).trim();
    }
    return trimmed;
  }

  static String _normalizeToPlus63(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('09') && digits.length >= 11) {
      return '+63${digits.substring(1)}';
    } else if (digits.startsWith('639') && digits.length >= 12) {
      return '+$digits';
    } else if (digits.startsWith('9') && digits.length == 10) {
      return '+63$digits';
    } else if (trimmed.startsWith('+')) {
      return trimmed;
    }
    return '+63$digits';
  }

  void _initControllers(AppUser? user) {
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _departmentController = TextEditingController(text: user?.department ?? '');
    _positionController = TextEditingController(text: user?.position ?? '');
    _employeeIdController = TextEditingController(text: user?.employeeId ?? '');
    _phoneController = TextEditingController(text: _formatPhoneForDisplay(user?.phone));
    _selectedDepartmentName = user?.department?.trim().isNotEmpty == true ? user!.department!.trim() : null;
    _selectedDepartmentId = user?.departmentId;
  }

  @override
  void didUpdateWidget(StudentProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Discard unsaved changes when navigating away to another tab
    if (oldWidget.isActive && !widget.isActive) {
      if (_isEditing) {
        _cancelEdit();
      }
    }
  }

  void _cancelEdit() {
    final user = context.read<AuthService>().currentUser;
    _nameController.text = user?.name ?? '';
    _emailController.text = user?.email ?? '';
    _departmentController.text = user?.department ?? '';
    _positionController.text = user?.position ?? '';
    _employeeIdController.text = user?.employeeId ?? '';
    _phoneController.text = _formatPhoneForDisplay(user?.phone);
    _selectedDepartmentName = user?.department?.trim().isNotEmpty == true ? user!.department!.trim() : null;
    _selectedDepartmentId = user?.departmentId;
    FocusScope.of(context).unfocus();
    if (mounted) {
      setState(() => _isEditing = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _departmentController.dispose();
    _positionController.dispose();
    _employeeIdController.dispose();
    _phoneController.dispose();
    _nameFocusNode.dispose();
    _departmentFocusNode.dispose();
    _positionFocusNode.dispose();
    _employeeIdFocusNode.dispose();
    _phoneFocusNode.dispose();
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
      _phoneController.text = _formatPhoneForDisplay(user.phone);
      _selectedDepartmentName = user.department?.trim().isNotEmpty == true ? user.department!.trim() : null;
      _selectedDepartmentId = user.departmentId;
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
      final rawExt = file.name.split('.').last.toLowerCase();
      final mimeType = _normalizeMimeType(rawExt);
      final ext = mimeType.split('/').last == 'jpeg' ? 'jpg' : rawExt;
      final path = 'profiles/${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // Upload binary to Supabase storage
      await Supabase.instance.client.storage
          .from('profile-images')
          .uploadBinary(path, bytes,
              fileOptions: FileOptions(upsert: true, contentType: mimeType));

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
        await LoginActivityService.recordAction(
          user: user,
          title: 'Profile Picture Updated',
          details: 'Updated profile picture',
        );
        if (!mounted) return;
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

  String _normalizeMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) return;

    final deptName = _selectedDepartmentName?.trim().isNotEmpty == true
        ? _selectedDepartmentName!.trim()
        : _departmentController.text.trim();

    if (deptName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your department.'),
          backgroundColor: AdminStyles.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final normalizedPhone = _normalizeToPlus63(_phoneController.text);
    try {
      final updated = user.copyWith(
        name: _nameController.text.trim(),
        department: deptName,
        departmentId: _selectedDepartmentId,
        position: _positionController.text.trim(),
        employeeId: _employeeIdController.text.trim(),
        phone: normalizedPhone.isNotEmpty ? normalizedPhone : null,
      );

      final success = await auth.updateProfile(updated);
      if (!mounted) return;

      if (success) {
        setState(() {
          _isEditing = false;
          _phoneController.text = _formatPhoneForDisplay(normalizedPhone);
        });
        FocusScope.of(context).unfocus();
        await LoginActivityService.recordAction(
          user: user,
          title: 'Profile Updated',
          details: 'Updated profile details: Name: ${updated.name}, Department: ${updated.department ?? 'N/A'}, Position: ${updated.position ?? 'N/A'}, Phone: ${updated.phone ?? 'N/A'}',
        );
        if (!mounted) return;
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

    _themeProvider = Provider.of<ThemeProvider>(context);
    _isDark = _themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: _themeProvider.backgroundColor,
      appBar: CommonAppBar(
        roleText: '',
        primaryColor: AdminStyles.primary,
        onMenuPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
        onNotificationPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationsPage(),
            ),
          );
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHero(user, authService.isLoading),
                  const SizedBox(height: 24),
                  _buildRegistrationDetails(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHero(AppUser? user, bool isLoading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: _themeProvider.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark ? Colors.grey.shade800 : AdminStyles.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
            style: AdminStyles.headingStyle(
              fontSize: 22,
              color: _themeProvider.textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            user?.email ?? '',
            style: AdminStyles.bodyStyle(
              color: _isDark ? Colors.grey.shade400 : AdminStyles.textSecondary,
            ),
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
            onPressed: _cancelEdit,
            child: Text(
              'Cancel',
              style: AdminStyles.bodyStyle(
                color: _isDark ? Colors.grey.shade400 : AdminStyles.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: isLoading ? null : _saveProfile,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      );
    }
    return ElevatedButton.icon(
      onPressed: () {
        setState(() => _isEditing = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _nameFocusNode.requestFocus();
        });
      },
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
    final fields = [
      _buildField(
        icon: Icons.person_outline_rounded,
        label: 'Full Name',
        controller: _nameController,
        focusNode: _nameFocusNode,
        isEditable: true,
      ),
      _buildField(
        icon: Icons.email_outlined,
        label: 'Institutional Email',
        controller: _emailController,
        isEditable: false,
        helperText: 'Email address cannot be changed here.',
      ),
      _buildField(
        icon: Icons.badge_outlined,
        label: 'Employee ID',
        controller: _employeeIdController,
        focusNode: _employeeIdFocusNode,
        isEditable: true,
      ),
      _buildField(
        icon: Icons.phone_outlined,
        label: 'Contact Number',
        controller: _phoneController,
        focusNode: _phoneFocusNode,
        isEditable: true,
        keyboardType: TextInputType.phone,
        prefixWidget: _buildPhonePrefix(_isEditing),
      ),
      _buildDepartmentField(),
      _buildField(
        icon: Icons.work_outline_rounded,
        label: 'Designation / Position',
        controller: _positionController,
        focusNode: _positionFocusNode,
        isEditable: true,
        hintText: 'e.g. Faculty, Non-Teaching',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _themeProvider.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark ? Colors.grey.shade800 : AdminStyles.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Personal Information',
                style: AdminStyles.headingStyle(
                  fontSize: 18,
                  color: _themeProvider.textColor,
                ),
              ),
              if (!_isEditing) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.touch_app_rounded, size: 12, color: Color(0xFF0F766E)),
                      SizedBox(width: 3),
                      Text(
                        'Tap field to edit',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'These details were set by the System Admin when your account was created. You may update them here.',
            style: AdminStyles.bodyStyle(
              fontSize: 12,
              color: _isDark ? Colors.grey.shade400 : AdminStyles.textMuted,
            ),
          ),
          const SizedBox(height: 28),
          Column(
            children: fields
                .map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: f,
                    ))
                .toList(),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 16),
            Divider(color: _isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _cancelEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isDark ? Colors.grey.shade300 : const Color(0xFF64748B),
                    side: BorderSide(
                      color: _isDark ? Colors.grey.shade700 : const Color(0xFFCBD5E1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _saveProfile,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminStyles.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDepartmentField() {
    final canEdit = _isEditing;

    final options = _departments.map((d) => d.name.trim()).where((n) => n.isNotEmpty).toSet().toList();

    if (_selectedDepartmentName != null && _selectedDepartmentName!.trim().isNotEmpty) {
      final currentName = _selectedDepartmentName!.trim();
      if (!options.any((o) => o.toLowerCase() == currentName.toLowerCase())) {
        options.insert(0, currentName);
      }
    }

    String? dropdownValue;
    if (_selectedDepartmentName != null && _selectedDepartmentName!.trim().isNotEmpty) {
      final match = options.firstWhere(
        (o) => o.toLowerCase() == _selectedDepartmentName!.trim().toLowerCase(),
        orElse: () => '',
      );
      if (match.isNotEmpty) {
        dropdownValue = match;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.school_outlined,
              size: 16,
              color: _isDark ? Colors.grey.shade400 : AdminStyles.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              'Department',
              style: AdminStyles.bodyStyle(
                fontSize: 13,
                color: _isDark ? Colors.grey.shade300 : AdminStyles.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AdminStyles.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Select from list',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AdminStyles.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!canEdit)
          InkWell(
            onTap: () {
              setState(() => _isEditing = true);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF232323) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isDark ? Colors.grey.shade700 : AdminStyles.border,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      dropdownValue ?? (_departmentController.text.isNotEmpty ? _departmentController.text : 'Select Department'),
                      style: AdminStyles.bodyStyle(
                        color: _isDark
                            ? Colors.white
                            : ((dropdownValue != null || _departmentController.text.isNotEmpty)
                                ? AdminStyles.textPrimary
                                : AdminStyles.textMuted),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: _isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          )
        else if (_isLoadingDepartments)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: _isDark ? const Color(0xFF2D2D2D) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDark ? Colors.grey.shade700 : AdminStyles.border,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading departments...',
                  style: AdminStyles.bodyStyle(
                    color: _isDark ? Colors.grey.shade400 : AdminStyles.textMuted,
                  ),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: dropdownValue,
            dropdownColor: _isDark ? const Color(0xFF2D2D2D) : Colors.white,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminStyles.primary),
            decoration: InputDecoration(
              filled: true,
              fillColor: _isDark ? const Color(0xFF2D2D2D) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _isDark ? Colors.grey.shade700 : AdminStyles.border,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AdminStyles.primary, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AdminStyles.primary, width: 2),
              ),
            ),
            hint: Text(
              options.isEmpty ? 'No departments available' : 'Choose Department',
              style: AdminStyles.bodyStyle(
                color: _isDark ? Colors.grey.shade400 : AdminStyles.textMuted,
              ),
            ),
            items: options.map((deptName) {
              return DropdownMenuItem<String>(
                value: deptName,
                child: Text(
                  deptName,
                  style: AdminStyles.bodyStyle(
                    color: _isDark ? Colors.white : AdminStyles.textPrimary,
                    fontWeight: deptName == dropdownValue ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                Department? matchedDept;
                for (final d in _departments) {
                  if (d.name.trim().toLowerCase() == value.trim().toLowerCase()) {
                    matchedDept = d;
                    break;
                  }
                }
                setState(() {
                  _selectedDepartmentName = value;
                  _selectedDepartmentId = matchedDept?.id;
                  _departmentController.text = value;
                });
              }
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please select a department';
              }
              return null;
            },
          ),
      ],
    );
  }

  Widget _buildPhonePrefix(bool canEdit) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 14),
        const Text('🇵🇭', style: TextStyle(fontSize: 15)),
        const SizedBox(width: 6),
        Text(
          '+63',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _isDark
                ? (canEdit ? Colors.white : Colors.grey.shade400)
                : (canEdit ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 1,
          height: 20,
          color: _isDark ? Colors.grey.shade700 : const Color(0xFFCBD5E1),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    FocusNode? focusNode,
    required bool isEditable,
    String? helperText,
    String? hintText,
    TextInputType? keyboardType,
    Widget? prefixWidget,
  }) {
    final canEdit = isEditable && _isEditing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: _isDark
                  ? (isEditable ? Colors.grey.shade400 : Colors.grey.shade600)
                  : (isEditable ? AdminStyles.textSecondary : AdminStyles.textMuted),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AdminStyles.bodyStyle(
                fontSize: 13,
                color: _isDark
                    ? (isEditable ? Colors.grey.shade300 : Colors.grey.shade500)
                    : (isEditable ? AdminStyles.textSecondary : AdminStyles.textMuted),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!isEditable) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Locked',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: isEditable && !_isEditing
              ? () {
                  setState(() => _isEditing = true);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    focusNode?.requestFocus();
                  });
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: IgnorePointer(
            ignoring: isEditable && !_isEditing,
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              enabled: isEditable,
              readOnly: !isEditable,
              keyboardType: keyboardType,
              style: AdminStyles.bodyStyle(
                color: _isDark
                    ? (isEditable ? Colors.white : Colors.grey.shade400)
                    : (isEditable ? AdminStyles.textPrimary : AdminStyles.textMuted),
              ),
              decoration: InputDecoration(
                prefixIcon: prefixWidget,
                prefixIconConstraints: prefixWidget != null
                    ? const BoxConstraints(minWidth: 0, minHeight: 0)
                    : null,
                hintText: hintText,
                hintStyle: AdminStyles.bodyStyle(
                  fontSize: 13,
                  color: _isDark
                      ? Colors.grey.shade600
                      : AdminStyles.textMuted.withValues(alpha: 0.6),
                ),
                helperText: helperText,
                helperStyle: AdminStyles.bodyStyle(
                  fontSize: 11,
                  color: _isDark ? Colors.grey.shade500 : AdminStyles.textMuted,
                ),
                filled: true,
                fillColor: _isDark
                    ? (canEdit
                        ? const Color(0xFF2D2D2D)
                        : (isEditable
                            ? const Color(0xFF232323)
                            : const Color(0xFF1A1A1A)))
                    : (canEdit
                        ? Colors.white
                        : (isEditable
                            ? const Color(0xFFF8FAFC)
                            : AdminStyles.bg)),
                suffixIcon: isEditable && !_isEditing
                    ? Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: _isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _isDark ? Colors.grey.shade700 : AdminStyles.border,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: canEdit
                        ? AdminStyles.primary
                        : (_isDark ? Colors.grey.shade700 : AdminStyles.border),
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _isDark
                        ? Colors.grey.shade800
                        : AdminStyles.border.withValues(alpha: 0.5),
                  ),
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
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/services/app_settings_service.dart';
import '../../../shared/services/admin_audit_log_service.dart';
import '../../admin/shared/admin_styles.dart';

class TeacherSettingsWeb extends StatefulWidget {
  const TeacherSettingsWeb({super.key});

  @override
  State<TeacherSettingsWeb> createState() => _TeacherSettingsWebState();
}

class _TeacherSettingsWebState extends State<TeacherSettingsWeb> {
  bool _notificationsEnabled = true;
  bool _emailNotifications = false;
  bool _pushNotifications = true;
  bool _isLoadingPreferences = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final settings = await AppSettingsService.getNotificationSettings();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = settings['notificationsEnabled'] ?? true;
      _emailNotifications = settings['emailNotifications'] ?? false;
      _pushNotifications = settings['pushNotifications'] ?? true;
      _isLoadingPreferences = false;
    });
  }

  Future<void> _saveNotificationPreferences() async {
    await AppSettingsService.setNotificationSettings(
      notificationsEnabled: _notificationsEnabled,
      emailNotifications: _emailNotifications,
      pushNotifications: _pushNotifications,
    );
  }

  Future<void> _toggleMasterNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
      if (!value) {
        _emailNotifications = false;
        _pushNotifications = false;
      }
    });
    await _saveNotificationPreferences();
  }

  Future<void> _toggleEmailNotifications(bool value) async {
    if (!_notificationsEnabled) return;
    setState(() => _emailNotifications = value);
    await _saveNotificationPreferences();
  }

  Future<void> _togglePushNotifications(bool value) async {
    if (!_notificationsEnabled) return;
    setState(() => _pushNotifications = value);
    await _saveNotificationPreferences();
  }

  void _showChangePasswordDialog() {
    final formKey = GlobalKey<FormState>();
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSaving = false;

    String? validateStrongPassword(String? value) {
      final password = value ?? '';
      if (password.isEmpty) return 'New password is required';
      if (password.length < 8) return 'Password must be at least 8 characters';
      if (!RegExp(r'[A-Z]').hasMatch(password)) {
        return 'Password must include at least 1 uppercase letter';
      }
      if (!RegExp(r'[a-z]').hasMatch(password)) {
        return 'Password must include at least 1 lowercase letter';
      }
      if (!RegExp(r'[0-9]').hasMatch(password)) {
        return 'Password must include at least 1 number';
      }
      if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
        return 'Password must include at least 1 special character';
      }
      if (password == oldPasswordController.text) {
        return 'New password must be different from old password';
      }
      return null;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Container(
                width: 400,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: oldPasswordController,
                          obscureText: obscureOld,
                          decoration: InputDecoration(
                            labelText: 'Old Password',
                            suffixIcon: IconButton(
                              icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                            ),
                          ),
                          validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: newPasswordController,
                          obscureText: obscureNew,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            suffixIcon: IconButton(
                              icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                            ),
                          ),
                          validator: validateStrongPassword,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            suffixIcon: IconButton(
                              icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Confirm password is required';
                            if (value != newPasswordController.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Password must contain at least 8 characters, with uppercase, lowercase, number, and special character.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AdminStyles.primary, foregroundColor: Colors.white),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSaving = true);

                          final authService = context.read<AuthService>();
                          final error = await authService.changePassword(
                            oldPassword: oldPasswordController.text,
                            newPassword: newPasswordController.text,
                          );

                          setDialogState(() => isSaving = false);

                          if (!context.mounted) return;
                          
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          Navigator.of(dialogContext).pop();

                          if (!mounted) return;

                          await showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (okContext) => AlertDialog(
                              title: const Text('Password Updated'),
                              content: const Text('Your password was changed successfully. Please login again.'),
                              actions: [
                                ElevatedButton(
                                  onPressed: () => Navigator.of(okContext).pop(),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );

                          if (mounted) {
                            await authService.handleLogoutButton(context);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Container(
      color: AdminStyles.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 40),
            _buildSettingsCategory('Notifications', [
              _buildSwitchTile(
                icon: Icons.notifications_active_rounded,
                title: 'Enable Notifications',
                description: 'Receive updates about requests and activity.',
                color: AdminStyles.info,
                value: _notificationsEnabled,
                onChanged: _isLoadingPreferences ? null : _toggleMasterNotifications,
              ),
              _buildSwitchTile(
                icon: Icons.email_rounded,
                title: 'Email Notifications',
                description: 'Receive updates via email.',
                color: AdminStyles.primary,
                value: _emailNotifications,
                onChanged: (!_isLoadingPreferences && _notificationsEnabled) ? _toggleEmailNotifications : null,
              ),
              _buildSwitchTile(
                icon: Icons.phone_android_rounded,
                title: 'Push Notifications',
                description: 'Receive browser push alerts.',
                color: AdminStyles.success,
                value: _pushNotifications,
                onChanged: (!_isLoadingPreferences && _notificationsEnabled) ? _togglePushNotifications : null,
              ),
            ]),
            const SizedBox(height: 32),
            _buildSettingsCategory('Appearance', [
              _buildSwitchTile(
                icon: themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode_outlined,
                title: 'Dark Mode',
                description: themeProvider.isDarkMode ? 'Dark theme enabled' : 'Light theme enabled',
                color: AdminStyles.warning,
                value: themeProvider.isDarkMode,
                onChanged: (value) async {
                  await themeProvider.setDarkMode(value);
                  await AdminAuditLogService.logAction(
                    title: value ? 'Enabled Dark Mode (Web)' : 'Disabled Dark Mode (Web)',
                    details: 'Web Settings > Appearance',
                  );
                },
              ),
            ]),
            const SizedBox(height: 32),
            _buildSettingsCategory('Security & Access', [
              _buildActionTile(
                icon: Icons.lock_rounded,
                title: 'Update Password',
                description: 'Ensure your account remains secure.',
                color: AdminStyles.error,
                onTap: _showChangePasswordDialog,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Settings', style: AdminStyles.headingStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text('Personalize your experience and manage account security.', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontSize: 16)),
      ],
    );
  }

  Widget _buildSettingsCategory(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(title.toUpperCase(), style: AdminStyles.headingStyle(fontSize: 12, color: AdminStyles.textMuted, letterSpacing: 1.0)),
        ),
        Container(
          decoration: AdminStyles.cardDecoration(),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Column(
      children: [
        SwitchListTile.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AdminStyles.primary,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(title, style: AdminStyles.headingStyle(fontSize: 15)),
          subtitle: Text(description, style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary)),
        ),
        Divider(height: 1, color: AdminStyles.border),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AdminStyles.headingStyle(fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(description, style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AdminStyles.textMuted),
          ],
        ),
      ),
    );
  }
}

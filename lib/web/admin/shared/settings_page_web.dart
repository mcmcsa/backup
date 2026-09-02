import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../authentication/services/auth_service.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/services/admin_audit_log_service.dart';
import '../../../shared/services/app_settings_service.dart';
import 'admin_styles.dart';
import '../admin_main_navigation_web.dart';
import '../admin_nav_controller.dart';

class SettingsPageWeb extends StatefulWidget {
  const SettingsPageWeb({super.key});

  @override
  State<SettingsPageWeb> createState() => _SettingsPageWebState();
}

class _SettingsPageWebState extends State<SettingsPageWeb> {
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
    await AdminAuditLogService.logAction(
      title: value ? 'Enabled Notifications (Web)' : 'Disabled Notifications (Web)',
      details: 'Web Settings > Notifications',
    );
  }

  Future<void> _toggleEmailNotifications(bool value) async {
    if (!_notificationsEnabled) return;
    setState(() => _emailNotifications = value);
    await _saveNotificationPreferences();
    await AdminAuditLogService.logAction(
      title: value ? 'Enabled Email Notifications (Web)' : 'Disabled Email Notifications (Web)',
      details: 'Web Settings > Notifications',
    );
  }

  Future<void> _togglePushNotifications(bool value) async {
    if (!_notificationsEnabled) return;
    setState(() => _pushNotifications = value);
    await _saveNotificationPreferences();
    await AdminAuditLogService.logAction(
      title: value ? 'Enabled Push Notifications (Web)' : 'Disabled Push Notifications (Web)',
      details: 'Web Settings > Notifications',
    );
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
    String? errorMessage;

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
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: oldPasswordController,
                          obscureText: obscureOld,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            suffixIcon: IconButton(
                              icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Current password is required' : null,
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            suffixIcon: IconButton(
                              icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Confirm password is required';
                            if (v != newPasswordController.text) return 'Passwords do not match';
                            return null;
                          },
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
                            setDialogState(() {
                              errorMessage = error;
                            });
                            return;
                          }

                          Navigator.of(dialogContext).pop();

                          if (!mounted) return;

                          final shouldLogout = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (okContext) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 28),
                                  SizedBox(width: 10),
                                  Text('Password Updated', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                ],
                              ),
                              content: const Text(
                                'Your password has been updated successfully.\n\nWould you like to keep logged in on this device or log out now?',
                                style: TextStyle(fontSize: 14),
                              ),
                              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              actions: [
                                OutlinedButton(
                                  onPressed: () => Navigator.of(okContext).pop(false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF475569),
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Keep Logged In', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(okContext).pop(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Logout Account', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );

                          if (shouldLogout == true && mounted) {
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
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: AdminStyles.headingStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Configure web preferences and system behavior.',
                style: AdminStyles.bodyStyle(fontSize: 15, color: AdminStyles.textSecondary),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Notifications'),
              const SizedBox(height: 12),
              _settingsCard(
                children: [
                  _switchTile(
                    icon: Icons.notifications_outlined,
                    title: 'Enable Notifications',
                    subtitle: 'Receive updates about requests and activity',
                    value: _notificationsEnabled,
                    onChanged: _isLoadingPreferences ? null : _toggleMasterNotifications,
                  ),
                  _divider(),
                  _switchTile(
                    icon: Icons.email_outlined,
                    title: 'Email Notifications',
                    subtitle: 'Receive updates via email',
                    value: _emailNotifications,
                    onChanged: (!_isLoadingPreferences && _notificationsEnabled)
                        ? _toggleEmailNotifications
                        : null,
                  ),
                  _divider(),
                  _switchTile(
                    icon: Icons.phone_android_outlined,
                    title: 'Push Notifications',
                    subtitle: 'Receive browser/app push alerts',
                    value: _pushNotifications,
                    onChanged: (!_isLoadingPreferences && _notificationsEnabled)
                        ? _togglePushNotifications
                        : null,
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _sectionTitle('Security'),
              const SizedBox(height: 12),
              _settingsCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded, color: AdminStyles.primary),
                    title: Text(
                      'Change Password',
                      style: AdminStyles.bodyStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AdminStyles.textPrimary),
                    ),
                    subtitle: Text(
                      'Update your account login password',
                      style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AdminStyles.textSecondary),
                    onTap: _showChangePasswordDialog,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _sectionTitle('Appearance'),
              const SizedBox(height: 12),
              _settingsCard(
                children: [
                  _switchTile(
                    icon: themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode_outlined,
                    title: 'Dark Mode',
                    subtitle: themeProvider.isDarkMode ? 'Dark theme enabled' : 'Light theme enabled',
                    value: themeProvider.isDarkMode,
                    onChanged: (value) async {
                      await themeProvider.setDarkMode(value);
                      await AdminAuditLogService.logAction(
                        title: value ? 'Enabled Dark Mode (Web)' : 'Disabled Dark Mode (Web)',
                        details: 'Web Settings > Appearance',
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _sectionTitle('System'),
              const SizedBox(height: 12),
              _settingsCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: AdminStyles.secondary),
                    title: Text(
                      'About System',
                      style: AdminStyles.bodyStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AdminStyles.textPrimary),
                    ),
                    subtitle: Text(
                      'System overview and development info',
                      style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AdminStyles.textSecondary),
                    onTap: () {
                      AdminNavController.of(context)?.navigateTo(AdminMainNavigationWeb.aboutIndex);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: AdminStyles.headingStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AdminStyles.textPrimary,
      ),
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    return Container(
      decoration: AdminStyles.cardDecoration(borderRadius: 14, hasShadow: false),
      child: Column(children: children),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AdminStyles.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      secondary: Icon(icon, color: AdminStyles.secondary),
      title: Text(
        title,
        style: AdminStyles.bodyStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AdminStyles.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
      ),
    );
  }

  Widget _divider() {
    return Divider(height: 1, color: AdminStyles.border.withValues(alpha: 0.8));
  }
}

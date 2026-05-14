import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../authentication/models/user_model.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/services/admin_audit_log_service.dart';
import '../../../shared/services/app_settings_service.dart';
import 'admin_styles.dart';

class SettingsPageWeb extends StatefulWidget {
  const SettingsPageWeb({super.key});

  @override
  State<SettingsPageWeb> createState() => _SettingsPageWebState();
}

class _SettingsPageWebState extends State<SettingsPageWeb> {
  bool _notificationsEnabled = true;
  bool _emailNotifications = false;
  bool _pushNotifications = true;
  bool _qrRegenerationEnabled = false;
  bool _isLoadingPreferences = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final settings = await AppSettingsService.getNotificationSettings();
    final qrRegenerationEnabled = await AppSettingsService.isQrRegenerationEnabled();
    if (!mounted) return;

    setState(() {
      _notificationsEnabled = settings['notificationsEnabled'] ?? true;
      _emailNotifications = settings['emailNotifications'] ?? false;
      _pushNotifications = settings['pushNotifications'] ?? true;
      _qrRegenerationEnabled = qrRegenerationEnabled;
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

  Future<void> _toggleQrRegeneration(bool value) async {
    if (value && !_qrRegenerationEnabled) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Enable QR Regeneration?'),
          content: const Text(
            'Regenerating QR codes changes room QR identity and may affect previously printed QR codes. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Enable'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() => _qrRegenerationEnabled = value);
    await AppSettingsService.setQrRegenerationEnabled(value);
    await AdminAuditLogService.logAction(
      title: value ? 'Enabled QR Regeneration (Web)' : 'Disabled QR Regeneration (Web)',
      details: 'Web Settings > QR Code',
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authService = context.watch<AuthService>();
    final isAdmin = authService.currentUser?.role == UserRole.admin;

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
              _sectionTitle('QR Code'),
              const SizedBox(height: 12),
              _settingsCard(
                children: [
                  _switchTile(
                    icon: Icons.qr_code_2_outlined,
                    title: 'Allow QR Regeneration',
                    subtitle: 'Show regenerate option in Add/Edit Room',
                    value: _qrRegenerationEnabled,
                    onChanged: _isLoadingPreferences ? null : _toggleQrRegeneration,
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
              if (isAdmin) ...[
                // About page entry moved to dedicated sidebar item below Settings.
              ],
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
      activeColor: AdminStyles.primary,
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

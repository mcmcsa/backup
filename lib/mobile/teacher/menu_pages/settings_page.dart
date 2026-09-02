import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../authentication/models/user_model.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../router/app_router.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/services/admin_audit_log_service.dart';
import '../../../shared/services/app_settings_service.dart';
import '../../admin/shared/about_system_page.dart';
import '../../admin/shared/change_password_page.dart';
import 'contact_us_page.dart';
import 'system_workflow_page.dart';

class SettingsPage extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const SettingsPage({super.key, this.scaffoldKey});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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

  Future<void> _savePreferences() async {
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
    await _savePreferences();
    await AdminAuditLogService.logAction(
      title: value ? 'Enabled Notifications' : 'Disabled Notifications',
      details: 'Settings > Notifications',
    );
  }

  Future<void> _toggleEmailNotifications(bool value) async {
    if (!_notificationsEnabled) return;
    setState(() {
      _emailNotifications = value;
    });
    await _savePreferences();
    await AdminAuditLogService.logAction(
      title: value ? 'Enabled Email Notifications' : 'Disabled Email Notifications',
      details: 'Settings > Notifications',
    );
  }

  Future<void> _togglePushNotifications(bool value) async {
    if (!_notificationsEnabled) return;
    setState(() {
      _pushNotifications = value;
    });
    await _savePreferences();
    await AdminAuditLogService.logAction(
      title: value ? 'Enabled Push Notifications' : 'Disabled Push Notifications',
      details: 'Settings > Notifications',
    );
  }



  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authService = context.watch<AuthService>();
    final isAdmin = authService.currentUser?.role == UserRole.admin ||
        authService.currentUser?.role == UserRole.campadmin;
    
    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.appBarColor,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: themeProvider.appBarTextColor,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Section
          _buildSectionHeader('Account', themeProvider),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: themeProvider.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeProvider.borderColor),
            ),
            child: Column(
              children: [
                _buildSettingsItem(
                  icon: Icons.lock_outline,
                  iconColor: Colors.blue,
                  title: 'Change Password',
                  subtitle: 'Update your password',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordPage(),
                      ),
                    );
                  },
                  themeProvider: themeProvider,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionHeader('Notifications', themeProvider),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: themeProvider.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeProvider.borderColor),
            ),
            child: Column(
              children: [
                _buildSwitchItem(
                  icon: Icons.notifications_outlined,
                  iconColor: Colors.orange,
                  title: 'Enable Notifications',
                  subtitle: 'Receive updates about your requests',
                  value: _notificationsEnabled,
                  onChanged: _toggleMasterNotifications,
                  themeProvider: themeProvider,
                  enabled: !_isLoadingPreferences,
                ),
                _buildDivider(themeProvider),
                _buildSwitchItem(
                  icon: Icons.email_outlined,
                  iconColor: Colors.red,
                  title: 'Email Notifications',
                  subtitle: 'Receive email updates',
                  value: _emailNotifications,
                  onChanged: _toggleEmailNotifications,
                  themeProvider: themeProvider,
                  enabled: !_isLoadingPreferences && _notificationsEnabled,
                ),
                _buildDivider(themeProvider),
                _buildSwitchItem(
                  icon: Icons.phone_android_outlined,
                  iconColor: Colors.green,
                  title: 'Push Notifications',
                  subtitle: 'Receive push notifications',
                  value: _pushNotifications,
                  onChanged: _togglePushNotifications,
                  themeProvider: themeProvider,
                  enabled: !_isLoadingPreferences && _notificationsEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // QR Code Section


          // Appearance Section
          _buildSectionHeader('Appearance', themeProvider),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: themeProvider.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeProvider.borderColor),
              boxShadow: [
                BoxShadow(
                  color: themeProvider.primaryColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildSwitchItem(
              icon: themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode_outlined,
              iconColor: themeProvider.isDarkMode ? Colors.purple.shade300 : Colors.purple,
              title: 'Dark Mode',
              subtitle: themeProvider.isDarkMode ? 'Dark theme enabled' : 'Light theme enabled',
              value: themeProvider.isDarkMode,
              onChanged: (value) async {
                await themeProvider.setDarkMode(value);
                await AdminAuditLogService.logAction(
                  title: value ? 'Enabled Dark Mode' : 'Disabled Dark Mode',
                  details: 'Settings > Appearance',
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          themeProvider.isDarkMode
                              ? 'Dark mode enabled'
                              : 'Light mode enabled',
                        ),
                      ],
                    ),
                    backgroundColor: themeProvider.primaryColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              themeProvider: themeProvider,
            ),
          ),
          const SizedBox(height: 24),

          // Other Section
          _buildSectionHeader(isAdmin ? 'System' : 'Other', themeProvider),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: themeProvider.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeProvider.borderColor),
            ),
            child: Column(
              children: [
                _buildSettingsItem(
                  icon: Icons.help_outline,
                  iconColor: Colors.amber,
                  title: 'Contact Us',
                  subtitle: 'Get help and contact support',
                  onTap: () {
                    if (isAdmin) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContactUsPage(),
                        ),
                      );
                    } else {
                      context.push(teacherContactRoute);
                    }
                  },
                  themeProvider: themeProvider,
                ),
                _buildDivider(themeProvider),
                _buildSettingsItem(
                  icon: Icons.info_outline,
                  iconColor: Colors.indigo,
                  title: 'About Us',
                  subtitle: 'App version and information',
                  onTap: () {
                    if (isAdmin) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutSystemPage(),
                        ),
                      );
                    } else {
                      context.push(teacherAboutRoute);
                    }
                  },
                  themeProvider: themeProvider,
                ),
                if (isAdmin) _buildDivider(themeProvider),
                if (isAdmin)
                  _buildSettingsItem(
                    icon: Icons.account_tree_outlined,
                    iconColor: Colors.teal,
                    title: 'System workflow',
                    subtitle: 'View maintenance request flow',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SystemWorkflowPage(),
                        ),
                      );
                    },
                    themeProvider: themeProvider,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeProvider themeProvider) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: themeProvider.iconColor,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSettingsItem({
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
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
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

  Widget _buildSwitchItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeProvider themeProvider,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: enabled ? () => onChanged(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
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
              Switch(
                value: value,
                onChanged: enabled ? onChanged : null,
                activeThumbColor: themeProvider.primaryColor,
              ),
            ],
          ),
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
}

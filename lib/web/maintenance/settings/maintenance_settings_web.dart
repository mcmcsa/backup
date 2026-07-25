import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../admin/shared/admin_styles.dart';

class MaintenanceSettingsWeb extends StatefulWidget {
  const MaintenanceSettingsWeb({super.key});

  @override
  State<MaintenanceSettingsWeb> createState() => _MaintenanceSettingsWebState();
}

class _MaintenanceSettingsWebState extends State<MaintenanceSettingsWeb> {
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _smsAlerts = false;
  bool _highContrast = false;
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Container(
      color: AdminStyles.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              children: [
                const Icon(Icons.settings_suggest_rounded, color: AdminStyles.primary, size: 36),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('System Settings', style: AdminStyles.headingStyle(fontSize: 26)),
                    Text(
                      'Manage your portal settings and notification preferences',
                      style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Content Grid/Layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: User details & Notifications
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      _buildSettingsCard(
                        title: 'Profile Information',
                        icon: Icons.person_rounded,
                        children: [
                          _buildDetailRow('Full Name', user?.name ?? 'Maintenance Staff'),
                          _buildDetailRow('Email Address', user?.email ?? 'N/A'),
                          _buildDetailRow('Security Role', 'Maintenance Technician'),
                          _buildDetailRow('Account Status', 'Active'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSettingsCard(
                        title: 'Notification Preferences',
                        icon: Icons.notifications_active_rounded,
                        children: [
                          _buildSwitchRow(
                            'Email Notifications',
                            'Receive daily digest and major updates via email',
                            _emailNotifications,
                            (v) => setState(() => _emailNotifications = v),
                          ),
                          const Divider(height: 24),
                          _buildSwitchRow(
                            'Push Notifications',
                            'Get real-time job assignment alerts instantly',
                            _pushNotifications,
                            (v) => setState(() => _pushNotifications = v),
                          ),
                          const Divider(height: 24),
                          _buildSwitchRow(
                            'SMS Alert Dispatches',
                            'Get text messages for critical high-priority tickets',
                            _smsAlerts,
                            (v) => setState(() => _smsAlerts = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),

                // Right Column: Regional & General Settings
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      _buildSettingsCard(
                        title: 'Interface Settings',
                        icon: Icons.palette_rounded,
                        children: [
                          _buildSwitchRow(
                            'High Contrast Mode',
                            'Increases visibility for text and labels',
                            _highContrast,
                            (v) => setState(() => _highContrast = v),
                          ),
                          const Divider(height: 24),
                          _buildDropdownRow(
                            'Display Language',
                            'Choose your primary working language',
                            _selectedLanguage,
                            ['English', 'Tagalog', 'Spanish'],
                            (v) => setState(() => _selectedLanguage = v ?? 'English'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSettingsCard(
                        title: 'System Information',
                        icon: Icons.info_outline_rounded,
                        children: [
                          _buildDetailRow('App Version', 'v1.4.2 (Production)'),
                          _buildDetailRow('Environment', 'Cloud / Web Client'),
                          _buildDetailRow('Database Connection', 'Connected'),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Preferences saved successfully!'),
                                    backgroundColor: AdminStyles.success,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.save_rounded, size: 18),
                              label: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminStyles.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: AdminStyles.cardDecoration(hasShadow: true),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AdminStyles.primary, size: 22),
              const SizedBox(width: 12),
              Text(
                title,
                style: AdminStyles.headingStyle(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary)),
          Text(value, style: AdminStyles.dataStyle(fontSize: 13, color: AdminStyles.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AdminStyles.headingStyle(fontSize: 14, color: AdminStyles.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle, style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary)),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AdminStyles.primary,
          activeTrackColor: AdminStyles.primary.withValues(alpha: 0.5),
        ),
      ],
    );
  }

  Widget _buildDropdownRow(
    String title,
    String subtitle,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AdminStyles.headingStyle(fontSize: 14, color: AdminStyles.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle, style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminStyles.border),
          ),
          child: DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            items: options.map((opt) {
              return DropdownMenuItem(
                value: opt,
                child: Text(opt, style: AdminStyles.bodyStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

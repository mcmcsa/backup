import 'package:flutter/material.dart';
import '../../admin/shared/admin_styles.dart';

class TeacherSettingsWeb extends StatelessWidget {
  const TeacherSettingsWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminStyles.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 40),
            _buildSettingsCategory('Account Preferences', [
              _SettingItem(icon: Icons.notifications_active_rounded, title: 'Notifications', description: 'Configure how you receive updates.', color: AdminStyles.info),
              _SettingItem(icon: Icons.language_rounded, title: 'Language', description: 'Select your preferred application language.', color: AdminStyles.primary),
              _SettingItem(icon: Icons.palette_rounded, title: 'Visual Theme', description: 'Switch between light and dark modes.', color: AdminStyles.warning),
            ]),
            const SizedBox(height: 32),
            _buildSettingsCategory('Security & Access', [
              _SettingItem(icon: Icons.lock_rounded, title: 'Update Password', description: 'Ensure your account remains secure.', color: AdminStyles.error),
              _SettingItem(icon: Icons.security_rounded, title: 'Multi-Factor Auth', description: 'Add an extra layer of verification.', color: AdminStyles.success),
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

  Widget _buildSettingsCategory(String title, List<_SettingItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(title.toUpperCase(), style: AdminStyles.headingStyle(fontSize: 12, color: AdminStyles.textMuted, letterSpacing: 1.0)),
        ),
        Container(
          decoration: AdminStyles.cardDecoration(),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == items.length - 1;

              return Column(
                children: [
                  InkWell(
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: item.color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: Icon(item.icon, color: item.color, size: 22),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: AdminStyles.headingStyle(fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(item.description, style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: AdminStyles.textMuted),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast) Divider(height: 1, color: AdminStyles.border),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  _SettingItem({required this.icon, required this.title, required this.description, required this.color});
}

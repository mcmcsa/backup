import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../shared/admin_styles.dart';

class AdminProfileWeb extends StatefulWidget {
  const AdminProfileWeb({super.key});

  @override
  State<AdminProfileWeb> createState() => _AdminProfileWebState();
}

class _AdminProfileWebState extends State<AdminProfileWeb> {
  String _userName = 'Administrator';
  String _userEmail = 'admin@psu.edu';
  String _userRoleLabel = 'Campus Administrator';
  String _userPhone = '+1 (555) 123-4567';
  bool _isEditing = false;

  // Mapping local colors to AdminStyles
  static const Color _primaryBlue = AdminStyles.primary;
  static const Color _darkText = AdminStyles.textPrimary;
  static const Color _subtleText = AdminStyles.textSecondary;
  static const Color _pageBg = AdminStyles.bg;
  static const Color _cardBg = AdminStyles.surface;
  static const Color _borderColor = AdminStyles.border;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user != null && mounted) {
      setState(() {
        _userName = user.name;
        _userEmail = user.email;
        _userRoleLabel = user.roleLabel;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile Settings',
              style: AdminStyles.headingStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildProfileCard(),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: _buildSettingsCard(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(color: _primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                child: Center(
                  child: Text(_userName[0].toUpperCase(), style: AdminStyles.headingStyle(fontSize: 48, fontWeight: FontWeight.w700, color: _primaryBlue)),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_userName, style: AdminStyles.headingStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _darkText)),
                    const SizedBox(height: 4),
                    Text(_userRoleLabel, style: AdminStyles.bodyStyle(fontSize: 13, color: _subtleText)),
                    const SizedBox(height: 12),
                    if (_isEditing)
                      ElevatedButton(
                        onPressed: () => setState(() => _isEditing = false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text('Save Changes'),
                      )
                    else
                      OutlinedButton(
                        onPressed: () => setState(() => _isEditing = true),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _borderColor),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Edit Profile', style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _primaryBlue)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(color: _borderColor),
          const SizedBox(height: 32),
          Text(
            'Contact Information',
            style: AdminStyles.headingStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _darkText),
          ),
          const SizedBox(height: 16),
          _buildInfoField('Email', _userEmail),
          const SizedBox(height: 16),
          _buildInfoField('Phone', _userPhone),
        ],
      ),
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminStyles.headingStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _subtleText)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: AdminStyles.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
          child: Text(value, style: AdminStyles.bodyStyle(fontSize: 13, color: _darkText)),
        ),
      ],
    );
  }

  Widget _buildSettingsCard() {
    return Column(
      children: [
        _buildSettingItem('Change Password', Icons.lock_rounded, Color(0xFF0EA5E9)),
        const SizedBox(height: 12),
        _buildSettingItem('Two-Factor Authentication', Icons.security_rounded, Color(0xFFF59E0B)),
        const SizedBox(height: 12),
        _buildSettingItem('Notifications', Icons.notifications_rounded, Color(0xFF10B981)),
        const SizedBox(height: 12),
        _buildSettingItem('Preferences', Icons.tune_rounded, Color(0xFF818CF8)),
      ],
    );
  }

  Widget _buildSettingItem(String title, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _darkText))),
          Icon(Icons.arrow_forward_rounded, color: _subtleText.withValues(alpha: 0.5), size: 18),
        ],
      ),
    );
  }
}

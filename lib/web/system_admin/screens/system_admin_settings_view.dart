import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/system_settings_model.dart';
import '../../../shared/services/system_settings_service.dart';
import '../../../shared/services/app_settings_service.dart';
import '../../../shared/services/admin_audit_log_service.dart';
import '../../../shared/services/web_push_notification_service.dart';
import '../../admin/shared/admin_styles.dart';

class SystemAdminSettingsView extends StatefulWidget {
  const SystemAdminSettingsView({super.key});

  @override
  State<SystemAdminSettingsView> createState() => _SystemAdminSettingsViewState();
}

class _SystemAdminSettingsViewState extends State<SystemAdminSettingsView> {
  bool _loading = true;
  String? _error;
  SystemSettings? _settings;

  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _sessionTimeoutCtrl;
  bool _controllersInitialized = false;

  static const List<String> _timezoneOptions = ['Asia/Manila', 'UTC'];

  String _timezone = 'Asia/Manila';
  bool _enforcePasswordPolicy = true;
  bool _maintenanceMode = false;
  bool _qrRegenerationEnabled = false;

  // Personal Notification Preferences
  bool _notificationsEnabled = true;
  bool _emailNotifications = false;
  bool _pushNotifications = true;
  bool _isLoadingPreferences = true;

  bool _saving = false;

  String _normalizeTimezone(String? val) {
    final clean = (val ?? '').trim();
    if (_timezoneOptions.contains(clean)) return clean;
    return 'Asia/Manila';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    if (_controllersInitialized) {
      _sessionTimeoutCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final s = await SystemSettingsService.fetchSettings();
      final qrEnabled = await AppSettingsService.isQrRegenerationEnabled();
      await _loadNotificationPreferences();
      if (mounted) {
        setState(() {
          _settings = s;
          if (_controllersInitialized) {
            _sessionTimeoutCtrl.text = s.sessionTimeoutMinutes.toString();
          } else {
            _sessionTimeoutCtrl = TextEditingController(text: s.sessionTimeoutMinutes.toString());
            _controllersInitialized = true;
          }
          
          _timezone = _normalizeTimezone(s.timezone);
          _enforcePasswordPolicy = s.enforcePasswordPolicy;
          _maintenanceMode = s.maintenanceMode;
          _qrRegenerationEnabled = qrEnabled;
          
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadNotificationPreferences() async {
    final userId = context.read<AuthService>().currentUser?.id;
    final settings = await AppSettingsService.getNotificationSettings(userId: userId);
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = settings['notificationsEnabled'] ?? true;
      _emailNotifications = settings['emailNotifications'] ?? false;
      _pushNotifications = settings['pushNotifications'] ?? true;
      _isLoadingPreferences = false;
    });
  }

  Future<void> _saveNotificationPreferences() async {
    final userId = context.read<AuthService>().currentUser?.id;
    await AppSettingsService.setNotificationSettings(
      notificationsEnabled: _notificationsEnabled,
      emailNotifications: _emailNotifications,
      pushNotifications: _pushNotifications,
      userId: userId,
    );
  }

  Future<void> _toggleMasterNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    await _saveNotificationPreferences();
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Notifications enabled'
                : 'Notifications disabled. You will not receive notification alerts.',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: value ? AdminStyles.primary : const Color(0xFF475569),
        ),
      );
    }
    await AdminAuditLogService.logAction(
      title: value ? 'Enabled Notifications (System Admin)' : 'Disabled Notifications (System Admin)',
      details: 'System Admin Settings > Notifications',
    );
  }

  Future<void> _toggleEmailNotifications(bool value) async {
    if (!_notificationsEnabled) return;
    setState(() => _emailNotifications = value);
    await _saveNotificationPreferences();
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Email notifications enabled' : 'Email notifications disabled'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    await AdminAuditLogService.logAction(
      title: value ? 'Enabled Email Notifications (System Admin)' : 'Disabled Email Notifications (System Admin)',
      details: 'System Admin Settings > Notifications',
    );
  }

  Future<void> _togglePushNotifications(bool value) async {
    if (!_notificationsEnabled) return;
    if (value && kIsWeb) {
      await WebPushNotificationService.requestPermission();
    }
    setState(() => _pushNotifications = value);
    await _saveNotificationPreferences();
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Push notifications enabled' : 'Push notifications disabled'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    await AdminAuditLogService.logAction(
      title: value ? 'Enabled Push Notifications (System Admin)' : 'Disabled Push Notifications (System Admin)',
      details: 'System Admin Settings > Notifications',
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _saving = true);
    
    final newSettings = _settings!.copyWith(
      timezone: _timezone,
      sessionTimeoutMinutes: int.tryParse(_sessionTimeoutCtrl.text.trim()) ?? 60,
      enforcePasswordPolicy: _enforcePasswordPolicy,
      maintenanceMode: _maintenanceMode,
      updatedAt: DateTime.now(),
    );

    final err = await SystemSettingsService.updateSettings(newSettings);
    
    if (mounted) {
      setState(() => _saving = false);
      if (err == null) {
        _settings = newSettings;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Settings saved successfully'),
            ]),
            backgroundColor: AdminStyles.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $err'),
            backgroundColor: AdminStyles.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AdminStyles.primary));
    if (_error != null) return Center(child: Text('Error: $_error', style: const TextStyle(color: AdminStyles.error)));

    return LayoutBuilder(builder: (ctx, constraints) {
      final isMobile = constraints.maxWidth < 950;
      return Container(
        color: AdminStyles.bg,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: isMobile
                    ? Column(
                        children: [
                          _buildTimezoneCard(),
                          const SizedBox(height: 16),
                          _buildSecurityCard(),
                          const SizedBox(height: 16),
                          _buildMaintenanceCard(),
                          const SizedBox(height: 16),
                          _buildNotificationSettingsCard(),
                          const SizedBox(height: 16),
                          _buildQrCodeCard(),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _buildTimezoneCard(),
                                const SizedBox(height: 24),
                                _buildNotificationSettingsCard(),
                                const SizedBox(height: 24),
                                _buildQrCodeCard(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              children: [
                                _buildSecurityCard(),
                                const SizedBox(height: 24),
                                _buildMaintenanceCard(),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildHeader(bool isMobile) {
    final titleCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('System Settings', style: AdminStyles.headingStyle(fontSize: isMobile ? 22 : 28)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _maintenanceMode
                    ? AdminStyles.error.withValues(alpha: 0.1)
                    : AdminStyles.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _maintenanceMode
                      ? AdminStyles.error.withValues(alpha: 0.4)
                      : AdminStyles.success.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _maintenanceMode ? AdminStyles.error : AdminStyles.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _maintenanceMode ? 'Maintenance Mode' : 'System Online',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _maintenanceMode ? AdminStyles.error : AdminStyles.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Manage system timezone, security policies, QR codes, and personal alerts.',
          style: AdminStyles.bodyStyle(fontSize: 13),
        ),
      ],
    );

    final saveBtn = ElevatedButton.icon(
      onPressed: _saving ? null : _save,
      icon: _saving
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.save_rounded, size: 18),
      label: Text(_saving ? 'Saving...' : 'Save Configuration'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminStyles.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 1,
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleCol,
          const SizedBox(height: 16),
          saveBtn,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: titleCol),
        const SizedBox(width: 16),
        saveBtn,
      ],
    );
  }

  Widget _buildTimezoneCard() {
    DateTime now = DateTime.now();
    if (_timezone == 'UTC') {
      now = now.toUtc();
    }
    final timeStr = DateFormat('MMMM d, yyyy • hh:mm a').format(now);

    return _SettingsCard(
      title: 'System Timezone & Regional',
      icon: Icons.language_rounded,
      children: [
        Text(
          'Configure the primary timezone used for logging timestamps, work order submissions, and audit events.',
          style: AdminStyles.bodyStyle(fontSize: 13),
        ),
        const SizedBox(height: 18),
        _label('Active Timezone'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey(_timezone),
          initialValue: _normalizeTimezone(_timezone),
          decoration: _inputDecor(Icons.access_time_filled_rounded),
          items: const [
            DropdownMenuItem(
              value: 'Asia/Manila',
              child: Text('Asia/Manila (PHT, UTC+8) — Default'),
            ),
            DropdownMenuItem(
              value: 'UTC',
              child: Text('Universal Time (UTC)'),
            ),
          ],
          onChanged: (v) => setState(() => _timezone = v ?? 'Asia/Manila'),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AdminStyles.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminStyles.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AdminStyles.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.schedule_rounded, size: 20, color: AdminStyles.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Reference Time', style: AdminStyles.bodyStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      timeStr,
                      style: AdminStyles.bodyStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AdminStyles.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSettingsCard() {
    return _SettingsCard(
      title: 'Personal Notification Preferences',
      icon: Icons.notifications_active_outlined,
      children: [
        SwitchListTile(
          value: _notificationsEnabled,
          onChanged: _isLoadingPreferences ? null : _toggleMasterNotifications,
          activeThumbColor: AdminStyles.primary,
          title: Text('Enable Notifications', style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Master toggle: overall on/off switch for all alerts.', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
          contentPadding: EdgeInsets.zero,
        ),
        const Divider(height: 24, color: AdminStyles.border),
        Opacity(
          opacity: _notificationsEnabled ? 1.0 : 0.45,
          child: SwitchListTile(
            value: _notificationsEnabled ? _emailNotifications : false,
            onChanged: (_isLoadingPreferences || !_notificationsEnabled) ? null : _toggleEmailNotifications,
            activeThumbColor: AdminStyles.primary,
            title: Text('Email Notifications', style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Receive email updates about critical requests and administrative updates.', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const Divider(height: 24, color: AdminStyles.border),
        Opacity(
          opacity: _notificationsEnabled ? 1.0 : 0.45,
          child: SwitchListTile(
            value: _notificationsEnabled ? _pushNotifications : false,
            onChanged: (_isLoadingPreferences || !_notificationsEnabled) ? null : _togglePushNotifications,
            activeThumbColor: AdminStyles.primary,
            title: Text('Push Notifications', style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Receive real-time desktop browser notifications and audible alerts.', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildQrCodeCard() {
    return _SettingsCard(
      title: 'QR Code Configuration',
      icon: Icons.qr_code_2_outlined,
      children: [
        SwitchListTile(
          value: _qrRegenerationEnabled,
          onChanged: _toggleQrRegeneration,
          activeThumbColor: AdminStyles.primary,
          title: Text('Allow QR Code Regeneration', style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            'Enables the regenerate action in Add/Edit Room forms across all campus facilities.',
            style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Note: Regenerating a QR code generates a new UUID. Previously printed QR physical stickers will no longer scan.',
                  style: AdminStyles.bodyStyle(fontSize: 12, color: const Color(0xFF92400E)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityCard() {
    final timeoutPresets = [15, 30, 60, 120, 240];
    final currentTimeout = int.tryParse(_sessionTimeoutCtrl.text.trim());

    return _SettingsCard(
      title: 'Security & Access Control',
      icon: Icons.security_rounded,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AdminStyles.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_reset_rounded, color: AdminStyles.primary, size: 20),
          ),
          title: Text('Change Password', style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Update your personal account administrator password.', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
          trailing: OutlinedButton(
            onPressed: _showChangePasswordDialog,
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminStyles.primary,
              side: const BorderSide(color: AdminStyles.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Change'),
          ),
        ),
        const Divider(height: 28, color: AdminStyles.border),
        _buildTextField(
          'Session Inactivity Timeout (Minutes)',
          _sessionTimeoutCtrl,
          Icons.timer_outlined,
          isNumber: true,
          required: true,
          validator: _validateSessionTimeout,
          helperText: 'Duration of inactivity before the user is automatically logged out (5 to 1440 min).',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('Quick Presets: ', style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted)),
            const SizedBox(width: 6),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: timeoutPresets.map((m) {
                  final isSelected = currentTimeout == m;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _sessionTimeoutCtrl.text = m.toString();
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AdminStyles.primary : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? AdminStyles.primary : AdminStyles.border,
                        ),
                      ),
                      child: Text(
                        '$m m',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AdminStyles.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const Divider(height: 28, color: AdminStyles.border),
        SwitchListTile(
          value: _enforcePasswordPolicy,
          onChanged: (v) => setState(() => _enforcePasswordPolicy = v),
          title: Text('Enforce Strict Passwords', style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Requires uppercase, lowercase, numbers, and symbols for all system accounts.', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
          activeThumbColor: AdminStyles.primary,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildMaintenanceCard() {
    return _SettingsCard(
      title: 'Maintenance Mode',
      icon: Icons.construction_rounded,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _maintenanceMode ? AdminStyles.error.withValues(alpha: 0.06) : AdminStyles.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _maintenanceMode ? AdminStyles.error.withValues(alpha: 0.4) : AdminStyles.border,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (_maintenanceMode ? AdminStyles.error : AdminStyles.success).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _maintenanceMode ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                      color: _maintenanceMode ? AdminStyles.error : AdminStyles.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _maintenanceMode ? 'System is in Maintenance' : 'System is Live & Online',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _maintenanceMode ? AdminStyles.error : AdminStyles.success,
                          ),
                        ),
                        Text(
                          _maintenanceMode ? 'Normal user access is currently blocked' : 'All users can log in and submit requests',
                          style: AdminStyles.bodyStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _maintenanceMode,
                    activeThumbColor: AdminStyles.error,
                    onChanged: (v) async {
                      if (v) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: AdminStyles.error, size: 24),
                                SizedBox(width: 10),
                                Text('Enable Maintenance Mode?'),
                              ],
                            ),
                            content: const Text(
                              'When maintenance mode is active, only System Administrators can log in. All teachers, maintenance staff, and regular admins will be locked out until maintenance is disabled.\n\nAre you sure you want to proceed?',
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AdminStyles.error,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Enable Maintenance'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                      }
                      setState(() => _maintenanceMode = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'When enabled, all non-system-admin users are prevented from logging in. Use this during planned database maintenance or major updates.',
                style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
              ),
            ],
          ),
        ),
      ],
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

                          if (shouldLogout == true && context.mounted) {
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
      title: value ? 'Enabled QR Regeneration (System Admin)' : 'Disabled QR Regeneration (System Admin)',
      details: 'System Admin Settings > QR Code',
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String? _validateSessionTimeout(String? v) {
    if (v == null || v.trim().isEmpty) return 'Session timeout is required';
    final n = int.tryParse(v.trim());
    if (n == null || n < 5 || n > 1440) {
      return 'Must be between 5 and 1440 minutes (24 hours)';
    }
    return null;
  }

  Widget _label(String text) {
    return Text(text, style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminStyles.textSecondary));
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    bool required = false,
    bool isNumber = false,
    String? Function(String?)? validator,
    String? helperText,
    Widget? suffixWidget,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('$label ${required ? '*' : ''}'),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
          decoration: _inputDecor(icon, suffixWidget: suffixWidget, helperText: helperText),
          onChanged: onChanged,
          validator: validator ?? (required ? (v) => v == null || v.trim().isEmpty ? 'Required field' : null : null),
        ),
      ],
    );
  }

  InputDecoration _inputDecor(IconData icon, {Widget? suffixWidget, String? helperText}) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 18, color: AdminStyles.textSecondary),
      suffixIcon: suffixWidget,
      helperText: helperText,
      helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminStyles.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminStyles.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminStyles.primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminStyles.error, width: 1.5)),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: AdminStyles.border)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AdminStyles.primary),
                const SizedBox(width: 10),
                Text(title, style: AdminStyles.headingStyle(fontSize: 16)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/models/system_settings_model.dart';
import '../../../shared/services/system_settings_service.dart';
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
  late TextEditingController _systemNameCtrl;
  late TextEditingController _campusNameCtrl;
  late TextEditingController _primaryColorCtrl;
  late TextEditingController _academicYearCtrl;
  late TextEditingController _sessionTimeoutCtrl;

  String _theme = 'light';
  String _timezone = 'Asia/Manila';
  String _semester = '1st Semester';
  bool _enforcePasswordPolicy = true;
  bool _maintenanceMode = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    if (_settings != null) {
      _systemNameCtrl.dispose();
      _campusNameCtrl.dispose();
      _primaryColorCtrl.dispose();
      _academicYearCtrl.dispose();
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
      if (mounted) {
        setState(() {
          _settings = s;
          _systemNameCtrl = TextEditingController(text: s.systemName);
          _campusNameCtrl = TextEditingController(text: s.campusName);
          _primaryColorCtrl = TextEditingController(text: s.primaryColor);
          _academicYearCtrl = TextEditingController(text: s.academicYear);
          _sessionTimeoutCtrl = TextEditingController(text: s.sessionTimeoutMinutes.toString());
          
          _theme = s.theme;
          _timezone = s.timezone;
          _semester = s.semester;
          _enforcePasswordPolicy = s.enforcePasswordPolicy;
          _maintenanceMode = s.maintenanceMode;
          
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _saving = true);
    
    final newSettings = _settings!.copyWith(
      systemName: _systemNameCtrl.text.trim(),
      campusName: _campusNameCtrl.text.trim(),
      primaryColor: _primaryColorCtrl.text.trim(),
      academicYear: _academicYearCtrl.text.trim(),
      sessionTimeoutMinutes: int.tryParse(_sessionTimeoutCtrl.text.trim()) ?? 60,
      theme: _theme,
      timezone: _timezone,
      semester: _semester,
      enforcePasswordPolicy: _enforcePasswordPolicy,
      maintenanceMode: _maintenanceMode,
    );

    final err = await SystemSettingsService.updateSettings(newSettings);
    
    if (mounted) {
      setState(() => _saving = false);
      if (err == null) {
        _settings = newSettings;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [Icon(Icons.check_circle_rounded, color: Colors.white, size: 18), SizedBox(width: 10), Text('Global Settings Saved')]),
            backgroundColor: AdminStyles.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
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
      final isMobile = constraints.maxWidth < 800;
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
                          _buildGeneralCard(),
                          const SizedBox(height: 16),
                          _buildAcademicCard(),
                          const SizedBox(height: 16),
                          _buildSecurityCard(),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                _buildGeneralCard(),
                                const SizedBox(height: 24),
                                _buildAcademicCard(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: _buildSecurityCard(),
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Global Settings', style: AdminStyles.headingStyle(fontSize: isMobile ? 22 : 28)),
              const SizedBox(height: 4),
              Text('Manage core system configurations and environment variables.', style: AdminStyles.bodyStyle(fontSize: 13)),
            ],
          ),
        ),
        if (!isMobile) ...[
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded, size: 18),
            label: Text(_saving ? 'Saving...' : 'Save Configuration'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGeneralCard() {
    return _SettingsCard(
      title: 'General Settings',
      icon: Icons.tune_rounded,
      children: [
        _buildTextField('System Name', _systemNameCtrl, Icons.computer_rounded, required: true),
        const SizedBox(height: 16),
        _buildTextField('Campus Name', _campusNameCtrl, Icons.location_city_rounded, required: true),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildTextField('Primary Color (Hex)', _primaryColorCtrl, Icons.color_lens_rounded, required: true)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Theme Default'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _theme,
                    decoration: _inputDecor(Icons.dark_mode_rounded),
                    items: const [
                      DropdownMenuItem(value: 'light', child: Text('Light Theme')),
                      DropdownMenuItem(value: 'dark', child: Text('Dark Theme')),
                      DropdownMenuItem(value: 'system', child: Text('System Default')),
                    ],
                    onChanged: (v) => setState(() => _theme = v ?? 'light'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('System Timezone'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _timezone,
              decoration: _inputDecor(Icons.access_time_filled_rounded),
              items: const [
                DropdownMenuItem(value: 'Asia/Manila', child: Text('Asia/Manila (PST)')),
                DropdownMenuItem(value: 'UTC', child: Text('Universal Time (UTC)')),
              ],
              onChanged: (v) => setState(() => _timezone = v ?? 'Asia/Manila'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAcademicCard() {
    return _SettingsCard(
      title: 'Academic Configuration',
      icon: Icons.school_rounded,
      children: [
        Row(
          children: [
            Expanded(child: _buildTextField('Academic Year', _academicYearCtrl, Icons.calendar_today_rounded, required: true)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Current Semester'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _semester,
                    decoration: _inputDecor(Icons.layers_rounded),
                    items: const [
                      DropdownMenuItem(value: '1st Semester', child: Text('1st Semester')),
                      DropdownMenuItem(value: '2nd Semester', child: Text('2nd Semester')),
                      DropdownMenuItem(value: 'Midyear', child: Text('Midyear / Summer')),
                    ],
                    onChanged: (v) => setState(() => _semester = v ?? '1st Semester'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityCard() {
    return _SettingsCard(
      title: 'Security & Access',
      icon: Icons.security_rounded,
      children: [
        _buildTextField('Session Timeout (Minutes)', _sessionTimeoutCtrl, Icons.timer_rounded, isNumber: true, required: true),
        const SizedBox(height: 24),
        
        SwitchListTile(
          value: _enforcePasswordPolicy,
          onChanged: (v) => setState(() => _enforcePasswordPolicy = v),
          title: Text('Enforce Strict Passwords', style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Requires uppercase, lowercase, numbers, and symbols.', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
          activeThumbColor: AdminStyles.primary,
          contentPadding: EdgeInsets.zero,
        ),
        const Divider(height: 32, color: AdminStyles.border),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _maintenanceMode ? AdminStyles.error.withValues(alpha: 0.05) : AdminStyles.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _maintenanceMode ? AdminStyles.error.withValues(alpha: 0.3) : AdminStyles.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.build_circle_rounded, color: _maintenanceMode ? AdminStyles.error : AdminStyles.textMuted, size: 24),
                  const SizedBox(width: 10),
                  Text('Maintenance Mode', style: AdminStyles.headingStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              Text('When enabled, only System Administrators can log in. All other users will see a maintenance screen.', style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_maintenanceMode ? 'SYSTEM IS OFFLINE' : 'System is Online', style: TextStyle(fontWeight: FontWeight.w800, color: _maintenanceMode ? AdminStyles.error : AdminStyles.success)),
                  Switch(
                    value: _maintenanceMode,
                    onChanged: (v) => setState(() => _maintenanceMode = v),
                    activeThumbColor: AdminStyles.error,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded, size: 18),
            label: Text(_saving ? 'Saving...' : 'Save Configuration'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Widget _label(String text) {
    return Text(text, style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminStyles.textSecondary));
  }

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon, {bool required = false, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('$label ${required ? '*' : ''}'),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
          decoration: _inputDecor(icon),
          validator: required ? (v) => v == null || v.isEmpty ? 'Required field' : null : null,
        ),
      ],
    );
  }

  InputDecoration _inputDecor(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 18, color: AdminStyles.textSecondary),
      filled: true, fillColor: Colors.white,
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
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
            padding: const EdgeInsets.all(24),
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

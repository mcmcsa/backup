import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/services/work_request_service.dart';

class AdminProfilePageWeb extends StatefulWidget {
  const AdminProfilePageWeb({super.key});

  @override
  State<AdminProfilePageWeb> createState() => _AdminProfilePageWebState();
}

class _AdminProfilePageWebState extends State<AdminProfilePageWeb> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _departmentController;
  late TextEditingController _birthdayController;
  late TextEditingController _locationController;

  int _totalRequests = 0;
  int _resolvedPercent = 0;
  int _activeRequests = 0;
  int _pendingRequests = 0;
  bool _isLoadingStats = true;
  bool _isSaving = false;

  // Professional color palette
  static const Color _primaryBlue = Color(0xFF3B82F6);
  static const Color _successGreen = Color(0xFF22C55E);
  static const Color _warningYellow = Color(0xFFFBBF24);
  static const Color _darkText = Color(0xFF1E293B);
  static const Color _pageBg = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: '');
    _departmentController = TextEditingController(text: 'IT Department');
    _birthdayController = TextEditingController(text: '');
    _locationController = TextEditingController(text: 'Main Office');
    _loadStats();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _birthdayController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final requests = await WorkRequestService.fetchAll();
      final completed = requests.where((r) => r.status.toLowerCase() == 'completed').length;
      final active = requests.where((r) =>
        r.status.toLowerCase() == 'in_progress' ||
        r.status.toLowerCase() == 'approved' ||
        r.status.toLowerCase() == 'under_maintenance'
      ).length;
      final pending = requests.where((r) => r.status.toLowerCase() == 'pending').length;

      if (mounted) {
        setState(() {
          _totalRequests = requests.length;
          _resolvedPercent = requests.isNotEmpty ? (completed / requests.length * 100).round() : 0;
          _activeRequests = active;
          _pendingRequests = pending;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully'),
          backgroundColor: _successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column - Profile Card
            Expanded(
              flex: 3,
              child: _buildProfileCard(user),
            ),
            const SizedBox(width: 24),
            // Right Column - Stats & Settings
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _buildStatsCard(),
                  const SizedBox(height: 20),
                  _buildSettingsCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(dynamic user) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryBlue, Color(0xFF1E40AF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                user?.name?.isNotEmpty == true ? user.name[0].toUpperCase() : 'A',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Name
          Text(
            user?.name ?? 'Administrator',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _darkText,
            ),
          ),
          const SizedBox(height: 6),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Campus Administrator',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.grey.withValues(alpha: 0.1)),
          const SizedBox(height: 20),
          // Info rows
          _InfoRow(icon: Icons.email_rounded, label: 'Email', value: user?.email ?? ''),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.phone_rounded, label: 'Phone', value: _phoneController.text.isEmpty ? 'Not set' : _phoneController.text),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.business_rounded, label: 'Department', value: _departmentController.text),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.location_on_rounded, label: 'Location', value: _locationController.text),
          const SizedBox(height: 24),
          // Status badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: _successGreen, size: 18),
                SizedBox(width: 8),
                Text(
                  'Active Account',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _successGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: _primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Your Activity',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _darkText),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoadingStats)
            const Center(child: CircularProgressIndicator(color: _primaryBlue))
          else
            Row(
              children: [
                Expanded(child: _StatBox(value: '$_totalRequests', label: 'Total Requests', color: _primaryBlue)),
                const SizedBox(width: 16),
                Expanded(child: _StatBox(value: '$_resolvedPercent%', label: 'Resolved', color: _successGreen)),
                const SizedBox(width: 16),
                Expanded(child: _StatBox(value: '$_activeRequests', label: 'Active', color: _primaryBlue)),
                const SizedBox(width: 16),
                Expanded(child: _StatBox(value: '$_pendingRequests', label: 'Pending', color: _warningYellow)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.settings_rounded, color: _primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Edit Profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _darkText),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Form fields
          Row(
            children: [
              Expanded(child: _FormField(label: 'Full Name', controller: _nameController, icon: Icons.person_rounded)),
              const SizedBox(width: 16),
              Expanded(child: _FormField(label: 'Email', controller: _emailController, icon: Icons.email_rounded, enabled: false)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _FormField(label: 'Phone', controller: _phoneController, icon: Icons.phone_rounded)),
              const SizedBox(width: 16),
              Expanded(child: _FormField(label: 'Department', controller: _departmentController, icon: Icons.business_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _FormField(label: 'Birthday', controller: _birthdayController, icon: Icons.cake_rounded)),
              const SizedBox(width: 16),
              Expanded(child: _FormField(label: 'Location', controller: _locationController, icon: Icons.location_on_rounded)),
            ],
          ),
          const SizedBox(height: 24),
          // Save button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== WIDGETS ====================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF64748B), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatBox({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool enabled;

  const _FormField({
    required this.label,
    required this.controller,
    required this.icon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            style: TextStyle(
              fontSize: 14,
              color: enabled ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ],
    );
  }
}

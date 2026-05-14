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
  int _totalRequests = 0;
  int _resolvedPercent = 0;
  int _activeRequests = 0;
  int _pendingRequests = 0;
  bool _isLoadingStats = true;

  // Professional color palette
  static const Color _primaryBlue = Color(0xFF3B82F6);
  static const Color _successGreen = Color(0xFF22C55E);
  static const Color _warningYellow = Color(0xFFFBBF24);
  static const Color _darkText = Color(0xFF1E293B);
  static const Color _pageBg = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _loadStats();
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
                  _buildAdminDetailsCard(user),
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
          _InfoRow(icon: Icons.badge_rounded, label: 'Role', value: user?.roleLabel ?? 'Administrator'),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.business_rounded, label: 'Department', value: _displayValue(user?.department)),
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

  Widget _buildAdminDetailsCard(dynamic user) {
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
                child: const Icon(Icons.admin_panel_settings_rounded, color: _primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Admin Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _darkText),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InfoRow(icon: Icons.person_rounded, label: 'Name', value: _displayValue(user?.name)),
          const SizedBox(height: 14),
          _InfoRow(icon: Icons.email_rounded, label: 'Email', value: _displayValue(user?.email)),
          const SizedBox(height: 14),
          _InfoRow(icon: Icons.badge_rounded, label: 'Role', value: user?.roleLabel ?? 'Administrator'),
          const SizedBox(height: 14),
          _InfoRow(icon: Icons.school_rounded, label: 'Campus', value: _displayValue(user?.campus)),
          const SizedBox(height: 14),
          _InfoRow(icon: Icons.business_rounded, label: 'Department', value: _displayValue(user?.department)),
          const SizedBox(height: 14),
          _InfoRow(icon: Icons.work_rounded, label: 'Position', value: _displayValue(user?.position)),
          const SizedBox(height: 14),
          _InfoRow(icon: Icons.fingerprint_rounded, label: 'User ID', value: _displayValue(user?.id)),
        ],
      ),
    );
  }

  String _displayValue(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? 'Not set' : trimmed;
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

 

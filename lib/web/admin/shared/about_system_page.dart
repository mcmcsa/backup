import 'package:flutter/material.dart';

import 'admin_styles.dart';

class AboutSystemPage extends StatelessWidget {
  const AboutSystemPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 1200;
    final isMedium = screenWidth >= 860;

    return Container(
      color: const Color(0xFFF1F5F9),
      child: SingleChildScrollView(
        primary: false,
        padding: EdgeInsets.symmetric(
          horizontal: isMedium ? 32 : 16,
          vertical: isMedium ? 28 : 16,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'About System',
                  style: AdminStyles.headingStyle(
                    color: const Color(0xFF0F172A),
                    fontSize: isMedium ? 34 : 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'System overview, core features, and development ownership.',
                  style: AdminStyles.bodyStyle(
                    fontSize: 15,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 22),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: _buildHeroCard()),
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: _buildSnapshotCard()),
                    ],
                  )
                else ...[
                  _buildHeroCard(),
                  const SizedBox(height: 16),
                  _buildSnapshotCard(),
                ],
                const SizedBox(height: 20),
                _buildMissionCard(),
                const SizedBox(height: 30),
                _buildSectionTitle('Core Features'),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    final cardWidth = availableWidth >= 1024
                        ? (availableWidth - 24) / 3
                        : availableWidth >= 720
                            ? (availableWidth - 12) / 2
                            : availableWidth;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _buildFeatureItem(
                            icon: Icons.insert_drive_file_outlined,
                            iconColor: const Color(0xFF2563EB),
                            title: 'Integrated User Reporting',
                            description:
                                'Efficiently report and manage maintenance issues with real-time status updates and detailed tracking.',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildFeatureItem(
                            icon: Icons.qr_code_2,
                            iconColor: const Color(0xFFF59E0B),
                            title: 'QR-Enabled Tracking',
                            description:
                                'Quickly access asset information, identification and maintenance history through QR codes.',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildFeatureItem(
                            icon: Icons.account_tree_outlined,
                            iconColor: const Color(0xFF7C3AED),
                            title: 'Workflow Management',
                            description:
                                'Automated task assignment and priority tracking for campus maintenance teams.',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                _buildSectionTitle('Development Team'),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    final cardWidth = availableWidth >= 1024
                        ? (availableWidth - 36) / 4
                        : availableWidth >= 720
                            ? (availableWidth - 12) / 2
                            : availableWidth;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _buildTeamMember(
                            role: 'Lead Developer',
                            name: 'Hannah Louise Bergonia',
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildTeamMember(
                            role: 'UI/UX Designer',
                            name: 'Hannah Louise Bergonia',
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildTeamMember(
                            role: 'Mobile Developer',
                            name: 'MC Lester Soriano',
                            color: const Color(0xFF059669),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildTeamMember(
                            role: 'Backend',
                            name: 'Ignacio Loudet Developer',
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                _buildFooterCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4169E1),
            Color(0xFF1E3A8A),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E40AF).withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'San Carlos Campus',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'PSU Maintenance\nManagement System',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Version 1.0.0.0 Production Build',
            style: AdminStyles.bodyStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AdminStyles.cardDecoration(
        color: Colors.white,
        borderRadius: 16,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatTile(
            label: 'Environment',
            value: 'Production',
            icon: Icons.cloud_done_outlined,
            color: Color(0xFF0F766E),
          ),
          SizedBox(height: 10),
          _StatTile(
            label: 'Tracking',
            value: 'QR Enabled',
            icon: Icons.qr_code_scanner_rounded,
            color: Color(0xFF2563EB),
          ),
          SizedBox(height: 10),
          _StatTile(
            label: 'Campus',
            value: 'San Carlos',
            icon: Icons.location_on_outlined,
            color: Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AdminStyles.cardDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: 14,
        hasShadow: false,
      ),
      child: Text(
        '"Empowering the Pangasinan State University - San Carlos Campus through digital innovation, ensuring a safe, functional and well-maintained environment that fosters seamless facility oversight."',
        textAlign: TextAlign.center,
        style: AdminStyles.bodyStyle(
          fontSize: 14,
          color: const Color(0xFF475569),
          fontWeight: FontWeight.w500,
          height: 1.6,
        ).copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF4169E1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: AdminStyles.headingStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminStyles.cardDecoration(borderRadius: 16),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              'assets/images/PsuLogo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, _) => const Icon(
                Icons.school,
                color: Color(0xFF4169E1),
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'PANGASINAN STATE UNIVERSITY',
            textAlign: TextAlign.center,
            style: AdminStyles.bodyStyle(
              fontSize: 13,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Committed to excellence in education, research, and community service',
            textAlign: TextAlign.center,
            style: AdminStyles.bodyStyle(
              fontSize: 12,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showContactDialog(context),
              icon: const Icon(Icons.headset_mic_outlined),
              label: const Text(
                'Contact Support',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: AdminStyles.cardDecoration(borderRadius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AdminStyles.bodyStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: AdminStyles.bodyStyle(
              fontSize: 13,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMember({
    required String role,
    required String name,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AdminStyles.cardDecoration(
        color: Colors.white,
        borderRadius: 12,
        hasShadow: false,
      ).copyWith(
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            role,
            style: AdminStyles.bodyStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: AdminStyles.bodyStyle(
              fontSize: 13,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.headset_mic, color: Color(0xFF4169E1)),
            SizedBox(width: 12),
            Text('Contact Support'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Need help? Reach out to our support team:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildContactInfo(Icons.email, 'support@psu.edu.ph'),
            const SizedBox(height: 8),
            _buildContactInfo(Icons.phone, '+63 123 456 7890'),
            const SizedBox(height: 8),
            _buildContactInfo(Icons.location_on, 'PSU San Carlos Campus'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AdminStyles.bodyStyle(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: AdminStyles.bodyStyle(
                    fontSize: 13,
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

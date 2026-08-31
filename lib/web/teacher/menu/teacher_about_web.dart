import 'package:flutter/material.dart';
import '../../admin/shared/admin_styles.dart';

class TeacherAboutWeb extends StatelessWidget {
  const TeacherAboutWeb({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 650;

    return Container(
      color: AdminStyles.bg,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isNarrow ? 16 : 40),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 40),
                _buildMainCard(isNarrow),
                const SizedBox(height: 32),
                _buildFeaturesGrid(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AdminStyles.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.info_outline_rounded, color: AdminStyles.primary, size: 48),
        ),
        const SizedBox(height: 24),
        Text('About the System', style: AdminStyles.headingStyle(fontSize: 32)),
        const SizedBox(height: 12),
        Text('PSU MMS v2.0', style: AdminStyles.bodyStyle(fontSize: 16, color: AdminStyles.textSecondary)),
      ],
    );
  }

  Widget _buildMainCard(bool isNarrow) {
    return Container(
      padding: EdgeInsets.all(isNarrow ? 20 : 40),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        children: [
          Text(
            'The PSU MMS is designed to streamline the reporting and tracking of facility issues across the university campus. Our goal is to provide a seamless experience for faculty members to ensure a safe and well-maintained learning environment.',
            textAlign: TextAlign.center,
            style: AdminStyles.bodyStyle(fontSize: 16, height: 1.8),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesGrid(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 800;

    if (isNarrow) {
      return Column(
        children: [
          _buildFeatureItem(Icons.qr_code_2_rounded, 'QR Reporting', 'Quick scan room codes to report issues.'),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.timeline_rounded, 'Live Tracking', 'Real-time updates on request status.'),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.verified_user_rounded, 'Secure Sign-off', 'Digital verification of completed work.'),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.analytics_outlined, 'Performance', 'Optimized for university-wide operations.'),
        ],
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 24,
      crossAxisSpacing: 24,
      childAspectRatio: 2.2,
      children: [
        _buildFeatureItem(Icons.qr_code_2_rounded, 'QR Reporting', 'Quick scan room codes to report issues.'),
        _buildFeatureItem(Icons.timeline_rounded, 'Live Tracking', 'Real-time updates on request status.'),
        _buildFeatureItem(Icons.verified_user_rounded, 'Secure Sign-off', 'Digital verification of completed work.'),
        _buildFeatureItem(Icons.analytics_outlined, 'Performance', 'Optimized for university-wide operations.'),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminStyles.cardDecoration(hasShadow: false, borderColor: AdminStyles.border),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AdminStyles.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AdminStyles.headingStyle(fontSize: 15)),
                const SizedBox(height: 4),
                Text(desc, style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../router/app_router.dart';

class AboutUsPage extends StatelessWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const AboutUsPage({super.key, this.scaffoldKey});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final cardBorder = isDark
        ? Border.all(color: Colors.grey.shade800)
        : Border.all(color: Colors.grey.shade200);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.textColor, size: 24),
          onPressed: () {
            final router = GoRouter.maybeOf(context);
            if (router != null) {
              router.go(teacherDashboardRoute);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'About Us',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Logo and Name
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: themeProvider.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: cardBorder,
            ),
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/images/app_logo_v2.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.school,
                      color: Color(0xFF00BFA5),
                      size: 50,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'PSU E-Ayos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Description
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: themeProvider.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: cardBorder,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About the System',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The PSU E-Ayos is a comprehensive platform designed to streamline maintenance requests and operations at Pangasinan State University. Our system enables teachers and staff to efficiently report issues, track maintenance progress, and ensure a well-maintained campus environment.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Features
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: themeProvider.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: cardBorder,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Key Features',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(
                  icon: Icons.qr_code_scanner,
                  iconColor: const Color(0xFF00BFA5),
                  title: 'QR Code Scanning',
                  description: 'Quickly report issues by scanning room QR codes',
                  textColor: themeProvider.textColor,
                  descColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(
                  icon: Icons.track_changes,
                  iconColor: Colors.blue,
                  title: 'Real-time Tracking',
                  description: 'Monitor the status of your maintenance requests',
                  textColor: themeProvider.textColor,
                  descColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(
                  icon: Icons.notifications_active,
                  iconColor: Colors.orange,
                  title: 'Instant Notifications',
                  description: 'Get updates on your request progress',
                  textColor: themeProvider.textColor,
                  descColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(
                  icon: Icons.history,
                  iconColor: Colors.purple,
                  title: 'History & Archives',
                  description: 'Access your complete maintenance history',
                  textColor: themeProvider.textColor,
                  descColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Development Team
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: themeProvider.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: cardBorder,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Development Team',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
                const SizedBox(height: 14),
                _buildTeamMemberItem(
                  name: 'Mc Lester Soriano',
                  color: const Color(0xFF2563EB),
                  textColor: themeProvider.textColor,
                  isDark: isDark,
                  cardColor: themeProvider.cardColor,
                ),
                const SizedBox(height: 10),
                _buildTeamMemberItem(
                  name: 'Hannah Louise Jane Bangayan',
                  color: const Color(0xFFD97706),
                  textColor: themeProvider.textColor,
                  isDark: isDark,
                  cardColor: themeProvider.cardColor,
                ),
                const SizedBox(height: 10),
                _buildTeamMemberItem(
                  name: 'Rizza Jane Abarquez',
                  color: const Color(0xFF059669),
                  textColor: themeProvider.textColor,
                  isDark: isDark,
                  cardColor: themeProvider.cardColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // University Info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: themeProvider.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: cardBorder,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pangasinan State University',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.location_on_outlined,
                  'Lingayen, Pangasinan',
                  isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.phone_outlined,
                  '+63 (075) 542-6103',
                  isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.email_outlined,
                  'info@psu.edu.ph',
                  isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.language_outlined,
                  'www.psu.edu.ph',
                  isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Copyright
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '© 2026 PSU E-Ayos\nAll rights reserved',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required Color textColor,
    required Color descColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: descColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00BFA5)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamMemberItem({
    required String name,
    required Color color,
    required Color textColor,
    required bool isDark,
    required Color cardColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.25 : 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Center(
              child: Icon(Icons.person_rounded, color: color, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

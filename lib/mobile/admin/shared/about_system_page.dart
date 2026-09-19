import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/providers/theme_provider.dart';

class AboutSystemPage extends StatelessWidget {
  const AboutSystemPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final cardBorder = Border.all(
      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
    );

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'About System',
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // PSU System Card
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF1E3A8A), const Color(0xFF0F172A)]
                        : [const Color(0xFF4169E1), const Color(0xFF1E40AF)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4169E1).withValues(alpha: isDark ? 0.2 : 0.15),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // App Logo Container
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/images/app_logo_v2.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.school,
                          color: Color(0xFF4169E1),
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // San Carlos Campus Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'San Carlos Campus',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Title
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'PSU Maintenance\nManagement System',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Version
                    const Text(
                      'Version 1.0.0.0 Production Build',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeProvider.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: cardBorder,
                ),
                child: Text(
                  '"Empowering the Pangasinan State University - San Carlos Campus through digital innovation, ensuring a safe, functional and well-maintained environment that fosters seamless facility oversight."',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    fontSize: 13,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 28),

              // Core Features Section
              Row(
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
                    'Core Features',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Features List
              _buildFeatureItem(
                icon: Icons.insert_drive_file_outlined,
                iconColor: Colors.blue,
                title: 'Integrated User Reporting',
                description:
                    'Efficiently report and manage maintenance issues with real-time status updates and detailed tracking.',
                themeProvider: themeProvider,
                isDark: isDark,
              ),

              const SizedBox(height: 14),

              _buildFeatureItem(
                icon: Icons.qr_code_2,
                iconColor: Colors.orange,
                title: 'QR-Enabled Tracking',
                description:
                    'Quickly access asset information, identification and maintenance history through QR codes.',
                themeProvider: themeProvider,
                isDark: isDark,
              ),

              const SizedBox(height: 14),

              _buildFeatureItem(
                icon: Icons.account_tree_outlined,
                iconColor: Colors.purple,
                title: 'Workflow Management',
                description:
                    'Automated task assignment and priority tracking for campus maintenance teams.',
                themeProvider: themeProvider,
                isDark: isDark,
              ),

              const SizedBox(height: 32),

              // Development Team Section
              Row(
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
                    'Development Team',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Team Members (3 members only, clean presentation, no role titles)
              _buildTeamMember(
                name: 'Mc Lester Soriano',
                color: const Color(0xFF2563EB),
                icon: Icons.person_rounded,
                themeProvider: themeProvider,
                isDark: isDark,
              ),

              const SizedBox(height: 10),

              _buildTeamMember(
                name: 'Hannah Louise Jane Bangayan',
                color: const Color(0xFFD97706),
                icon: Icons.person_rounded,
                themeProvider: themeProvider,
                isDark: isDark,
              ),

              const SizedBox(height: 10),

              _buildTeamMember(
                name: 'Rizza Jane Abarquez',
                color: const Color(0xFF059669),
                icon: Icons.person_rounded,
                themeProvider: themeProvider,
                isDark: isDark,
              ),

              const SizedBox(height: 32),

              // PSU Logo Footer
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/images/app_logo_v2.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.school,
                      color: Color(0xFF4169E1),
                      size: 40,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // PSU Footer Text
              Text(
                'PANGASINAN STATE UNIVERSITY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Committed to excellence in education, research, and community service',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 32),

              // Contact Support Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showContactDialog(context, themeProvider, isDark),
                  icon: const Icon(Icons.headset_mic_outlined),
                  label: const Text(
                    'Contact Support',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4169E1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required ThemeProvider themeProvider,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMember({
    required String name,
    required Color color,
    required IconData icon,
    required ThemeProvider themeProvider,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.25 : 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: themeProvider.textColor,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContactDialog(BuildContext context, ThemeProvider themeProvider, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.headset_mic, color: Color(0xFF4169E1)),
            const SizedBox(width: 12),
            Text(
              'Contact Support',
              style: TextStyle(
                color: themeProvider.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need help? Reach out to our support team:',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            _buildContactInfo(Icons.email, 'support@psu.edu.ph', themeProvider, isDark),
            const SizedBox(height: 8),
            _buildContactInfo(Icons.phone, '+63 123 456 7890', themeProvider, isDark),
            const SizedBox(height: 8),
            _buildContactInfo(Icons.location_on, 'PSU San Carlos Campus', themeProvider, isDark),
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

  Widget _buildContactInfo(IconData icon, String text, ThemeProvider themeProvider, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4169E1)),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

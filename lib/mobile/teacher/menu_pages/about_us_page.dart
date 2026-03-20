import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const AboutUsPage({super.key, this.scaffoldKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'About Us',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 100,
                  width: 100,
                  child: Image.asset(
                    'assets/images/PsuLogo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.school,
                      color: Color(0xFF00BFA5),
                      size: 80,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'PSU Maintenance System',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About the System',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The PSU Maintenance System is a comprehensive platform designed to streamline maintenance requests and operations at Pangasinan State University. Our system enables students, teachers, and staff to efficiently report issues, track maintenance progress, and ensure a well-maintained campus environment.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Key Features',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(
                  icon: Icons.qr_code_scanner,
                  iconColor: const Color(0xFF00BFA5),
                  title: 'QR Code Scanning',
                  description: 'Quickly report issues by scanning room QR codes',
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(
                  icon: Icons.track_changes,
                  iconColor: Colors.blue,
                  title: 'Real-time Tracking',
                  description: 'Monitor the status of your maintenance requests',
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(
                  icon: Icons.notifications_active,
                  iconColor: Colors.orange,
                  title: 'Instant Notifications',
                  description: 'Get updates on your request progress',
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(
                  icon: Icons.history,
                  iconColor: Colors.purple,
                  title: 'History & Archives',
                  description: 'Access your complete maintenance history',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // University Info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pangasinan State University',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.location_on_outlined, 'Lingayen, Pangasinan'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.phone_outlined, '+63 (075) 542-6103'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.email_outlined, 'info@psu.edu.ph'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.language_outlined, 'www.psu.edu.ph'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Copyright
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '© 2026 PSU Maintenance System\nAll rights reserved',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
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
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
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
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00BFA5)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }
}

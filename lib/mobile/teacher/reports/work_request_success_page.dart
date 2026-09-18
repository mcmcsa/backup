import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../router/app_router.dart';
import '../../../authentication/services/auth_service.dart';

class WorkRequestSuccessPage extends StatelessWidget {
  final String trackingNumber;
  final String location;
  final String severity;
  final DateTime reportedDate;

  const WorkRequestSuccessPage({
    super.key,
    required this.trackingNumber,
    required this.location,
    required this.severity,
    required this.reportedDate,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final shortTrack = trackingNumber.trim().isNotEmpty
        ? (trackingNumber.trim().length > 8
            ? trackingNumber.trim().substring(0, 8)
            : trackingNumber.trim())
        : 'N/A';
    final formattedTrackId = shortTrack.startsWith('#') ? shortTrack : '#$shortTrack';

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.textColor),
          onPressed: () {
            context.go(teacherDashboardRoute);
          },
        ),
        title: Text(
          'Submitted!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: themeProvider.textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Success Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 64,
                color: Color(0xFF00BFA5),
              ),
            ),
            const SizedBox(height: 32),
            // Success Title
            Text(
              'Report Submitted\nSuccessfully!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: themeProvider.textColor,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            // Description
            Text(
              'Your maintenance request has been recorded and is being processed by the maintenance team.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            // Request Details Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: themeProvider.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: isDark ? Border.all(color: Colors.grey.shade800) : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REQUEST DETAILS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildDetailRow(
                    label: 'Tracking Number',
                    value: formattedTrackId,
                    valueColor: const Color(0xFF4169E1),
                    isBold: true,
                    textColor: themeProvider.textColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    label: 'Location',
                    value: location,
                    textColor: themeProvider.textColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    label: 'Reported on',
                    value: DateFormat('MMMM dd, yyyy').format(reportedDate),
                    textColor: themeProvider.textColor,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // View Request Status Button
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to request tracking/status page
                    context.push(
                      '/request-details',
                      extra: {
                        'trackingNumber': trackingNumber,
                        'status': 'PENDING',
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'View Request Status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Back to Home Link
            TextButton(
              onPressed: () {
                final user = context.read<AuthService>().currentUser;
                if (user != null) {
                  context.go(user.dashboardRoute);
                } else {
                  context.go(teacherDashboardRoute);
                }
              },
              child: Text(
                'Back to Home',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade300 : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
    required Color textColor,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? textColor,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../router/app_router.dart';

class TeacherRequestSuccessWeb extends StatelessWidget {
  final String trackingNumber;
  final String location;
  final String severity;
  final DateTime reportedDate;
  final bool isDialog;
  final VoidCallback? onViewStatus;
  final VoidCallback? onBackToHome;

  const TeacherRequestSuccessWeb({
    super.key,
    required this.trackingNumber,
    required this.location,
    required this.severity,
    required this.reportedDate,
    this.isDialog = false,
    this.onViewStatus,
    this.onBackToHome,
  });

  static Future<void> showAsDialog(
    BuildContext context, {
    required String trackingNumber,
    required String location,
    required String severity,
    required DateTime reportedDate,
    VoidCallback? onViewStatus,
    VoidCallback? onBackToHome,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.54),
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: TeacherRequestSuccessWeb(
              trackingNumber: trackingNumber,
              location: location,
              severity: severity,
              reportedDate: reportedDate,
              isDialog: true,
              onViewStatus: onViewStatus,
              onBackToHome: onBackToHome,
            ),
          ),
        ),
      ),
    );
  }

  String get _displayTrackingNumber {
    final clean = trackingNumber.trim();
    if (clean.length > 8) {
      return clean.substring(0, 8);
    }
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: EdgeInsets.all(isDialog ? 24 : 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isDialog) ...[
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: () {
                  Navigator.of(context).pop();
                  if (onBackToHome != null) {
                    onBackToHome!();
                  }
                },
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
          ],
          // Success Icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF00BFA5).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 48,
              color: Color(0xFF00BFA5),
            ),
          ),
          const SizedBox(height: 24),
          // Success Title
          const Text(
            'Report Submitted\nSuccessfully!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          // Description
          Text(
            'Your maintenance request has been recorded and is being processed by the maintenance team.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          // Request Details Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REQUEST DETAILS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  label: 'Tracking Number',
                  value: _displayTrackingNumber,
                  valueColor: const Color(0xFF4169E1),
                  isBold: true,
                ),
                const SizedBox(height: 14),
                _buildDetailRow(
                  label: 'Location',
                  value: location,
                ),
                const SizedBox(height: 14),
                _buildDetailRow(
                  label: 'Reported on',
                  value: DateFormat('MMMM dd, yyyy').format(reportedDate),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // View Request Status Button (Constrained Compact Width)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (isDialog) {
                    Navigator.of(context).pop();
                    if (onViewStatus != null) {
                      onViewStatus!();
                      return;
                    }
                  }
                  context.go(teacherDashboardRoute);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'View Request Status',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Back to Home Link
          TextButton(
            onPressed: () {
              if (isDialog) {
                Navigator.of(context).pop();
                if (onBackToHome != null) {
                  onBackToHome!();
                  return;
                }
              }
              context.go(teacherDashboardRoute);
            },
            child: const Text(
              'Back to Home',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          if (!isDialog) const SizedBox(height: 20),
        ],
      ),
    );

    if (isDialog) {
      return Material(
        color: Colors.white,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            context.go(teacherDashboardRoute);
          },
        ),
        title: const Text(
          'Submitted!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: content,
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

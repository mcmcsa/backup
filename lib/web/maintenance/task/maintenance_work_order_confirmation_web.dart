import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MaintenanceWorkOrderConfirmationWeb extends StatelessWidget {
  final String workOrderId;
  final String staffName;
  final DateTime completionDate;
  final String actionSummary;

  const MaintenanceWorkOrderConfirmationWeb({
    super.key,
    required this.workOrderId,
    required this.staffName,
    required this.completionDate,
    required this.actionSummary,
  });

  static const Color _successGreen = Color(0xFF10B981);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _subtleText = Color(0xFF64748B);
  static const Color _pageBg = Color(0xFFF8FAFC);
  static const Color _cardBg = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Success Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 60,
                color: _successGreen,
              ),
            ),
            const SizedBox(height: 32),

            // Success Message
            const Text(
              'Work Order Completed',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _darkText,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The maintenance task has been successfully completed.',
              style: TextStyle(
                fontSize: 15,
                color: _subtleText.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),

            // Confirmation Details
            Container(
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              padding: const EdgeInsets.all(32),
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Completion Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _darkText,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildDetailRow('Work Order ID', workOrderId),
                  const SizedBox(height: 20),
                  _buildDetailRow('Staff Member', staffName),
                  const SizedBox(height: 20),
                  _buildDetailRow(
                    'Completion Date',
                    DateFormat('MMM dd, yyyy • hh:mm a').format(completionDate),
                  ),
                  const SizedBox(height: 20),
                  _buildDetailRow('Status', 'COMPLETED'),
                  const SizedBox(height: 32),
                  const Divider(color: _borderColor),
                  const SizedBox(height: 32),
                  const Text(
                    'Action Summary',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _darkText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    actionSummary,
                    style: TextStyle(
                      fontSize: 13,
                      color: _subtleText,
                      fontWeight: FontWeight.w500,
                      height: 1.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Action Buttons
            MediaQuery.of(context).size.width < 500
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: _borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Back to Dashboard',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _darkText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Report sent')),
                            );
                          },
                          icon: const Icon(Icons.print_rounded),
                          label: const Text('Print Report'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _successGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: _borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Back to Dashboard',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _darkText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 200,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Report sent')),
                            );
                          },
                          icon: const Icon(Icons.print_rounded),
                          label: const Text('Print Report'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _successGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _subtleText,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _darkText,
            ),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

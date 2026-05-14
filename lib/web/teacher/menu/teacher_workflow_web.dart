import 'package:flutter/material.dart';
import '../../admin/shared/admin_styles.dart';

class TeacherSystemWorkflowWeb extends StatelessWidget {
  const TeacherSystemWorkflowWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminStyles.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 40),
                _buildWorkflowSteps(),
                const SizedBox(height: 32),
                _buildStatusGuide(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('System Workflow', style: AdminStyles.headingStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text('Learn how maintenance requests are processed from submission to completion.', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontSize: 16)),
      ],
    );
  }

  Widget _buildWorkflowSteps() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Process Lifecycle', style: AdminStyles.headingStyle(fontSize: 20)),
          const SizedBox(height: 40),
          _buildStep(1, 'Submit Request', 'Report a maintenance issue using the web portal or by scanning a room QR code.', AdminStyles.info),
          _buildStep(2, 'Admin Review', 'System administrators review your request and assign it to the appropriate maintenance staff.', AdminStyles.warning),
          _buildStep(3, 'Execution', 'Maintenance staff performs the required work and updates the request status in real-time.', AdminStyles.primary),
          _buildStep(4, 'Completion', 'Work is verified and signed off. You will receive a notification of the final resolution.', AdminStyles.success, isLast: true),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String title, String desc, Color color, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.3), width: 2)),
                child: Center(child: Text('$number', style: AdminStyles.headingStyle(fontSize: 18, color: color))),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 8), color: AdminStyles.border)),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AdminStyles.headingStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text(desc, style: AdminStyles.bodyStyle(fontSize: 14, color: AdminStyles.textSecondary)),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusGuide() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status Indicators', style: AdminStyles.headingStyle(fontSize: 18)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildStatusInfo('PENDING', 'Waiting for review', AdminStyles.warning)),
              Expanded(child: _buildStatusInfo('IN PROGRESS', 'Staff assigned', AdminStyles.info)),
              Expanded(child: _buildStatusInfo('COMPLETED', 'Issue resolved', AdminStyles.success)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfo(String status, String desc, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status, style: AdminStyles.headingStyle(fontSize: 13, color: color)),
            Text(desc, style: AdminStyles.bodyStyle(fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

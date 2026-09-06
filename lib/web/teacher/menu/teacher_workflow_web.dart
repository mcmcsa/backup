import 'package:flutter/material.dart';
import '../../admin/shared/admin_styles.dart';

class TeacherSystemWorkflowWeb extends StatelessWidget {
  const TeacherSystemWorkflowWeb({super.key});

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
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isNarrow),
                const SizedBox(height: 40),
                _buildWorkflowSteps(isNarrow),
                const SizedBox(height: 32),
                _buildStatusGuide(isNarrow),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Work Request Workflow', style: AdminStyles.headingStyle(fontSize: isNarrow ? 24 : 32)),
        const SizedBox(height: 8),
        Text(
          'Learn how your maintenance request is processed — from submission to verified closure.',
          style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontSize: isNarrow ? 14 : 16),
        ),
      ],
    );
  }

  Widget _buildWorkflowSteps(bool isNarrow) {
    return Container(
      padding: EdgeInsets.all(isNarrow ? 20 : 40),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Work Request Process', style: AdminStyles.headingStyle(fontSize: isNarrow ? 18 : 20)),
          const SizedBox(height: 8),
          Text(
            'Your request goes through the following stages before it is resolved.',
            style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 40),
          _buildStep(1, 'Submit Work Request',
            'You file a ticket by scanning a room QR code or manually selecting a room. Describe the issue, choose the type, and submit.',
            AdminStyles.info, actor: 'You (Teacher / Requestor)', statusLabel: 'PENDING'),
          _buildStep(2, 'Campus Admin Review & Approval',
            'The campus administrator reviews your request, sets a priority level (Standard or High), selects an available maintenance technician, and approves it with an e-signature.',
            AdminStyles.warning, actor: 'Campus Admin', statusLabel: 'APPROVED'),
          _buildStep(3, 'Technician Acceptance',
            'The assigned maintenance technician opens the task, signs an electronic acknowledgment, and officially starts the job.',
            AdminStyles.primary, actor: 'Maintenance Technician', statusLabel: 'IN PROGRESS'),
          _buildStep(4, 'Pre-Inspection Submitted',
            'Before executing the repair, the technician conducts an initial inspection and submits a pre-inspection report documenting the current condition.',
            const Color(0xFF8B5CF6), actor: 'Maintenance Technician', statusLabel: 'IN PROGRESS'),
          _buildStep(5, 'Pre-Inspection Review',
            'The campus administrator reviews the pre-inspection report. If satisfactory, the request is Confirmed and work proceeds. If not, it may be Declined and the ticket is closed.',
            const Color(0xFFEF4444), actor: 'Campus Admin', statusLabel: 'CONFIRMED / DECLINED', isAlternate: true),
          _buildStep(6, 'Work Execution (Under Maintenance)',
            'The technician performs the required repair or maintenance work on-site. The request is now marked as Under Maintenance.',
            const Color(0xFF0EA5E9), actor: 'Maintenance Technician', statusLabel: 'UNDER MAINTENANCE'),
          _buildStep(7, 'Post-Repair Report Submitted',
            'After completing the work, the technician uploads a photo as evidence, notes what was done, and submits the post-repair report with an e-signature.',
            const Color(0xFFF59E0B), actor: 'Maintenance Technician', statusLabel: 'POST-REPAIR SUBMITTED'),
          _buildStep(8, 'Final Evaluation & Closure',
            'The campus administrator evaluates the post-repair report. If satisfactory, the ticket is marked Completed and you receive a notification. If unsatisfactory, a Rework is requested and the process returns to Step 6.',
            AdminStyles.success, actor: 'Campus Admin', statusLabel: 'COMPLETED / REWORK', isAlternate: true, isLast: true),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String title, String desc, Color color,
      {required String actor, required String statusLabel, bool isAlternate = false, bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1), shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
                ),
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
                Text(title, style: AdminStyles.headingStyle(fontSize: 15)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: [
                    _buildPill(Icons.person_outline, actor, color),
                    _buildStatusPill(statusLabel, color, isAlternate: isAlternate),
                  ],
                ),
                const SizedBox(height: 8),
                Text(desc, style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary)),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
      ]),
    );
  }

  Widget _buildStatusPill(String label, Color color, {bool isAlternate = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (isAlternate) ...[Icon(Icons.alt_route_rounded, size: 11, color: color), const SizedBox(width: 4)],
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.4)),
      ]),
    );
  }

  Widget _buildStatusGuide(bool isNarrow) {
    const statuses = [
      _StatusInfo('PENDING', 'Awaiting admin review', Color(0xFFF59E0B)),
      _StatusInfo('APPROVED', 'Admin approved, awaiting technician acceptance', Color(0xFF6366F1)),
      _StatusInfo('IN PROGRESS', 'Technician accepted & pre-inspection ongoing', Color(0xFF0EA5E9)),
      _StatusInfo('CONFIRMED', 'Pre-inspection approved, work can begin', Color(0xFF4169E1)),
      _StatusInfo('UNDER MAINTENANCE', 'Repair work is currently being executed', Color(0xFF0EA5E9)),
      _StatusInfo('COMPLETED', 'Work finished and verified by admin', Color(0xFF10B981)),
      _StatusInfo('DECLINED', 'Request was reviewed but not approved', Color(0xFFEF4444)),
      _StatusInfo('REWORK', 'Work was unsatisfactory — redo has been requested', Color(0xFFF59E0B)),
    ];

    return Container(
      padding: EdgeInsets.all(isNarrow ? 20 : 32),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status Indicators', style: AdminStyles.headingStyle(fontSize: isNarrow ? 16 : 18)),
          const SizedBox(height: 6),
          Text('Each status below represents a stage your request may be in.',
              style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          ...statuses.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(margin: const EdgeInsets.only(top: 3), width: 10, height: 10,
                  decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.label, style: AdminStyles.headingStyle(fontSize: 12, color: s.color)),
                const SizedBox(height: 2),
                Text(s.desc, style: AdminStyles.bodyStyle(fontSize: 12)),
              ])),
            ]),
          )),
        ],
      ),
    );
  }
}

class _StatusInfo {
  final String label;
  final String desc;
  final Color color;
  const _StatusInfo(this.label, this.desc, this.color);
}

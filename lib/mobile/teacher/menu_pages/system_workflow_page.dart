import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../router/app_router.dart';

class SystemWorkflowPage extends StatelessWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const SystemWorkflowPage({super.key, this.scaffoldKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 24),
          onPressed: () {
            final router = GoRouter.maybeOf(context);
            if (router != null) {
              router.go(teacherDashboardRoute);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Work Request Workflow',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Introduction
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
                Row(
                  children: const [
                    Icon(Icons.account_tree_rounded, color: Color(0xFF4169E1), size: 22),
                    SizedBox(width: 10),
                    Text(
                      'How It Works',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Your work request goes through the following stages in the PSU MMS before it is resolved.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Workflow Steps
          _buildWorkflowStep(
            stepNumber: 1,
            title: 'Submit Work Request',
            description: 'Scan a room QR code or manually enter room details to report a maintenance issue. Describe the problem and choose the issue type.',
            icon: Icons.edit_note_rounded,
            iconColor: const Color(0xFF4169E1),
            actor: 'You (Teacher / Requestor)',
            statusLabel: 'PENDING',
          ),
          const SizedBox(height: 12),
          _buildWorkflowStep(
            stepNumber: 2,
            title: 'Admin Review & Approval',
            description: 'The administrator reviews your request, assigns a priority (Standard or High), selects a maintenance technician, and approves it with an e-signature.',
            icon: Icons.rate_review_rounded,
            iconColor: const Color(0xFFF59E0B),
            actor: 'Administrator',
            statusLabel: 'APPROVED',
          ),
          const SizedBox(height: 12),
          _buildWorkflowStep(
            stepNumber: 3,
            title: 'Technician Acceptance',
            description: 'The assigned maintenance technician opens the task, signs an electronic acknowledgment, and officially begins working.',
            icon: Icons.thumb_up_alt_rounded,
            iconColor: const Color(0xFF0EA5E9),
            actor: 'Maintenance Technician',
            statusLabel: 'IN PROGRESS',
          ),
          const SizedBox(height: 12),
          _buildWorkflowStep(
            stepNumber: 4,
            title: 'Pre-Inspection Submitted',
            description: 'Before executing the repair, the technician conducts an initial site inspection and submits a pre-inspection report documenting the current condition.',
            icon: Icons.search_rounded,
            iconColor: const Color(0xFF8B5CF6),
            actor: 'Maintenance Technician',
            statusLabel: 'IN PROGRESS',
          ),
          const SizedBox(height: 12),
          _buildWorkflowStep(
            stepNumber: 5,
            title: 'Pre-Inspection Review',
            description: 'The administrator reviews the pre-inspection report. If satisfactory, the request is Confirmed and work proceeds. If not, the ticket may be Declined.',
            icon: Icons.checklist_rounded,
            iconColor: const Color(0xFFEF4444),
            actor: 'Administrator',
            statusLabel: 'CONFIRMED / DECLINED',
            isAlternate: true,
          ),
          const SizedBox(height: 12),
          _buildWorkflowStep(
            stepNumber: 6,
            title: 'Work Execution',
            description: 'The technician performs the required repair or maintenance work on-site. The request is now marked as Under Maintenance.',
            icon: Icons.engineering,
            iconColor: const Color(0xFF0EA5E9),
            actor: 'Maintenance Technician',
            statusLabel: 'UNDER MAINTENANCE',
          ),
          const SizedBox(height: 12),
          _buildWorkflowStep(
            stepNumber: 7,
            title: 'Post-Repair Report Submitted',
            description: 'After completing the work, the technician uploads a photo as evidence, notes what was done, and submits the post-repair report with an e-signature.',
            icon: Icons.add_a_photo_rounded,
            iconColor: const Color(0xFFF59E0B),
            actor: 'Maintenance Technician',
            statusLabel: 'POST-REPAIR SUBMITTED',
          ),
          const SizedBox(height: 12),
          _buildWorkflowStep(
            stepNumber: 8,
            title: 'Final Evaluation & Closure',
            description: 'The administrator evaluates the post-repair report. If satisfactory, the ticket is marked Completed and you are notified. If unsatisfactory, a Rework is requested and the process returns to Step 6.',
            icon: Icons.verified_rounded,
            iconColor: const Color(0xFF10B981),
            actor: 'Administrator',
            statusLabel: 'COMPLETED / REWORK',
            isAlternate: true,
          ),
          const SizedBox(height: 20),

          // Request Status Info
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
                  'Request Status Guide',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                _buildStatusInfo('PENDING', 'Awaiting admin review', const Color(0xFFF59E0B)),
                const SizedBox(height: 10),
                _buildStatusInfo('APPROVED', 'Admin approved, awaiting technician', const Color(0xFF6366F1)),
                const SizedBox(height: 10),
                _buildStatusInfo('IN PROGRESS', 'Technician accepted & inspecting', const Color(0xFF0EA5E9)),
                const SizedBox(height: 10),
                _buildStatusInfo('CONFIRMED', 'Pre-inspection approved, work can begin', const Color(0xFF4169E1)),
                const SizedBox(height: 10),
                _buildStatusInfo('UNDER MAINTENANCE', 'Repair work is being executed', const Color(0xFF0EA5E9)),
                const SizedBox(height: 10),
                _buildStatusInfo('COMPLETED', 'Work finished and verified', const Color(0xFF10B981)),
                const SizedBox(height: 10),
                _buildStatusInfo('DECLINED', 'Request was not approved', Colors.red),
                const SizedBox(height: 10),
                _buildStatusInfo('REWORK', 'Redo requested — work was unsatisfactory', const Color(0xFFF59E0B)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tips Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF4169E1).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4169E1).withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tips_and_updates, color: Color(0xFF4169E1), size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Tips for Better Service',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTipItem('Provide clear and detailed descriptions of the issue'),
                _buildTipItem('Include photos when possible for faster evaluation'),
                _buildTipItem('Choose the correct category and issue type'),
                _buildTipItem('Monitor the Reports tab to track your request status'),
                _buildTipItem('You will be notified when your request is resolved'),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildWorkflowStep({
    required int stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required String actor,
    required String statusLabel,
    bool isAlternate = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Center(
              child: Text(
                stepNumber.toString(),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: iconColor),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: iconColor, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (isAlternate) ...[
                          Icon(Icons.alt_route_rounded, size: 10, color: iconColor),
                          const SizedBox(width: 3),
                        ],
                        Text(statusLabel,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: iconColor, letterSpacing: 0.4)),
                      ]),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        actor,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfo(String status, String description, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 3),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            description,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF4169E1)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

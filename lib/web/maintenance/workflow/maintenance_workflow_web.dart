import 'package:flutter/material.dart';
import '../../admin/shared/admin_styles.dart';

class MaintenanceWorkflowWeb extends StatelessWidget {
  const MaintenanceWorkflowWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminStyles.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              children: [
                const Icon(Icons.account_tree_rounded, color: AdminStyles.primary, size: 36),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('System Work Flow', style: AdminStyles.headingStyle(fontSize: 26)),
                    Text(
                      'Understanding the lifecycle of a Maintenance Work Request',
                      style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Process Timeline Cards
            _buildStepCard(
              stepNumber: '1',
              title: 'Request Submission',
              actor: 'TEACHER / REQUESTOR',
              icon: Icons.edit_note_rounded,
              color: AdminStyles.info,
              description: 'The requestor files a ticket specifying the facility/room number, type of request (e.g. electrical, plumbing, structural), and details of the issue. Initial status: PENDING.',
            ),
            _buildArrowConnector(),
            _buildStepCard(
              stepNumber: '2',
              title: 'Review & Prioritization',
              actor: 'ADMINISTRATOR',
              icon: Icons.rate_review_rounded,
              color: AdminStyles.warning,
              description: 'Admin evaluates the ticket, assigns priority (Standard/High), selects an assignee from available maintenance staff, and approves it. Status changes to: APPROVED.',
            ),
            _buildArrowConnector(),
            _buildStepCard(
              stepNumber: '3',
              title: 'Acknowledgment & Start',
              actor: 'MAINTENANCE TECHNICIAN',
              icon: Icons.thumb_up_alt_rounded,
              color: AdminStyles.primary,
              description: 'The assigned technician opens the task, signs an electronic acknowledgment signature, and begins work. Status updates to: IN PROGRESS.',
            ),
            _buildArrowConnector(),
            _buildStepCard(
              stepNumber: '4',
              title: 'Maintenance Execution & Accomplishment',
              actor: 'MAINTENANCE TECHNICIAN',
              icon: Icons.add_a_photo_rounded,
              color: AdminStyles.primaryLight,
              description: 'Technician resolves the issue, uploads a picture as evidence of the accomplished work, notes resolution details, and signs off. Status updates to: UNDER MAINTENANCE.',
            ),
            _buildArrowConnector(),
            _buildStepCard(
              stepNumber: '5',
              title: 'Verification & Closure',
              actor: 'TEACHER & ADMINISTRATOR',
              icon: Icons.verified_user_rounded,
              color: AdminStyles.success,
              description: 'The original requestor (Teacher) inspects the completed work and signs off to close the ticket. If work is unsatisfactory, admin/teacher requests REWORK, moving it back to Step 4. Final status: COMPLETED.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required String title,
    required String actor,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return Container(
      decoration: AdminStyles.cardDecoration(hasShadow: true),
      padding: const EdgeInsets.all(28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Circle Badge
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),

          // Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: AdminStyles.headingStyle(fontSize: 18),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, size: 14, color: color),
                          const SizedBox(width: 6),
                          Text(
                            actor,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: AdminStyles.bodyStyle(
                    color: AdminStyles.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrowConnector() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Icon(
          Icons.arrow_downward_rounded,
          color: AdminStyles.primaryLight,
          size: 28,
        ),
      ),
    );
  }
}

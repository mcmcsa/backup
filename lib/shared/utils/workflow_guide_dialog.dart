import 'package:flutter/material.dart';

void showWorkflowGuideDialog(BuildContext context, {String? role}) {
  final cleanRole = role?.toLowerCase() ?? '';
  String title = 'User Guide';
  List<GuideActionItem> items = [];
  String introText = '';

  if (cleanRole == 'teacher' || cleanRole == 'student') {
    title = 'Faculty/Non-Faculty Guide';
    introText = 'As a Faculty or Non-Faculty member, you can report facility issues and track their resolution. Here are your features:';
    items = [
      GuideActionItem(
        icon: Icons.qr_code_scanner_rounded,
        title: 'Create Work Request',
        description: 'Scan a Room QR code, or manually select rooms. Describe the issue, select a category, and upload photos.',
      ),
      GuideActionItem(
        icon: Icons.receipt_long_rounded,
        title: 'Track Request Progress',
        description: 'Go to "Reports" tab to see all your tickets. Follow status updates from Pending to Completion in real-time.',
      ),
      GuideActionItem(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Chat & Collaboration',
        description: 'Open any request details to chat directly with the Campus Administrator (chatting with technicians is restricted).',
      ),
      GuideActionItem(
        icon: Icons.rate_review_rounded,
        title: 'Submit Feedback',
        description: 'Once a work request is completed, you only need to provide feedback.',
      ),
      GuideActionItem(
        icon: Icons.manage_accounts_rounded,
        title: 'Account Settings',
        description: 'Edit your profile name, change password, or switch light/dark mode under "Settings".',
      ),
    ];
  } else if (cleanRole == 'maintenance' || cleanRole == 'technician') {
    title = 'Maintenance Technician Guide';
    introText = 'As a Technician, you receive and execute work orders on campus. Here are your features:';
    items = [
      GuideActionItem(
        icon: Icons.assignment_rounded,
        title: 'Manage Work Orders',
        description: 'View assigned jobs on your Dashboard. Accept a task by signing the electronic acknowledgment.',
      ),
      GuideActionItem(
        icon: Icons.fact_check_rounded,
        title: 'Pre-Inspection Report',
        description: 'Inspect the reported room, document initial findings, and submit a Pre-Inspection report before repairing.',
      ),
      GuideActionItem(
        icon: Icons.build_circle_rounded,
        title: 'Execute Work & Repair',
        description: 'Perform repairs on-site. The request updates to "Under Maintenance" once pre-inspection is approved.',
      ),
      GuideActionItem(
        icon: Icons.add_photo_alternate_rounded,
        title: 'Post-Repair Evidence',
        description: 'After completing work, upload before/after photos, detail your resolution, and sign off with an e-signature.',
      ),
      GuideActionItem(
        icon: Icons.chat_rounded,
        title: 'Communicate on Tickets',
        description: 'Use the integrated chat in any work order to coordinate details directly with the Campus Administrator (chatting with requestors is restricted).',
      ),
      GuideActionItem(
        icon: Icons.history_rounded,
        title: 'Performance History',
        description: 'Track your completed tickets and statistics under the "History" tab.',
      ),
    ];
  } else if (cleanRole == 'admin' ||
      cleanRole == 'system_admin' ||
      cleanRole == 'sysadmin' ||
      cleanRole == 'systemadministrator') {
    title = 'System Administrator Guide';
    introText =
        'As the System Administrator, you manage global settings, user accounts, facility setup, security, system health, and database backups:';
    items = [
      GuideActionItem(
        icon: Icons.manage_accounts_rounded,
        title: 'Global User Accounts',
        description:
            'Create new users, configure credentials, assign user roles (Faculty, Maintenance, Admin), and enable or disable accounts under "Users Management".',
      ),
      GuideActionItem(
        icon: Icons.apartment_rounded,
        title: 'Facility & Location Setup',
        description:
            'Manage departments, facility buildings, floor levels, room categories, request types, and room setups under "Facility Management" & "Rooms Management".',
      ),
      GuideActionItem(
        icon: Icons.qr_code_2_rounded,
        title: 'QR Code Management',
        description:
            'Generate, preview, batch print, and manage room QR codes across campuses for rapid issue reporting.',
      ),
      GuideActionItem(
        icon: Icons.campaign_rounded,
        title: 'System Announcements',
        description:
            'Broadcast system-wide notices to inform requestors and maintenance staff about maintenance schedules or outages.',
      ),
      GuideActionItem(
        icon: Icons.history_edu_rounded,
        title: 'Audit Logging & Security',
        description:
            'Inspect detailed audit trails to track security actions, status modifications, and administrator updates across the system.',
      ),
      GuideActionItem(
        icon: Icons.monitor_heart_rounded,
        title: 'System Health Dashboard',
        description:
            'Monitor real-time system performance, database connection states, response times, and storage health.',
      ),
      GuideActionItem(
        icon: Icons.backup_rounded,
        title: 'Backup & Restore Control',
        description:
            'Perform automated or manual database snapshot backups and execute data restoration when needed.',
      ),
      GuideActionItem(
        icon: Icons.analytics_rounded,
        title: 'Reports & Feedback',
        description:
            'View aggregated facility maintenance expense logs, operational metrics, and user feedback logs.',
      ),
    ];
  } else if (cleanRole == 'campadmin' ||
      cleanRole == 'campus_admin' ||
      cleanRole == 'camp_admin') {
    title = 'Campus Administrator Guide';
    introText =
        'As an Administrator, you orchestrate workflows, assign resources, and manage campus assets:';
    items = [
      GuideActionItem(
        icon: Icons.rate_review_rounded,
        title: 'Review & Approve Tickets',
        description:
            'Approve new tickets under Pending. Set priority (Standard/High), assign technicians, and sign to dispatch.',
      ),
      GuideActionItem(
        icon: Icons.policy_rounded,
        title: 'Inspection Evaluations',
        description:
            'Review submitted Pre-Inspection reports to confirm work starts, and inspect Post-Repair reports to close tickets or request Rework.',
      ),
      GuideActionItem(
        icon: Icons.domain_rounded,
        title: 'Campus Facility Setup',
        description:
            'Under Facilities, manage departments, buildings, floors, rooms, and request categories.',
      ),
      GuideActionItem(
        icon: Icons.people_rounded,
        title: 'Technician Management',
        description:
            'Oversee maintenance staff rosters, view active workloads, and delegate tasks efficiently.',
      ),
      GuideActionItem(
        icon: Icons.campaign_rounded,
        title: 'System Announcements',
        description:
            'Broadcast system-wide notices to inform requestors and maintenance staff about schedules or outages.',
      ),
      GuideActionItem(
        icon: Icons.chat_rounded,
        title: 'Ticket Chat Control',
        description:
            'Chat directly with both the requestor (faculty/non-faculty) and the assigned maintenance technician on any ticket.',
      ),
      GuideActionItem(
        icon: Icons.analytics_rounded,
        title: 'Analytics & Costs',
        description:
            'View overall facility maintenance expense logs, material usage, and response time metrics.',
      ),
    ];
  } else {
    // Default / Generic guide
    title = 'System Administrator Guide';
    introText =
        'As the System Administrator, you manage global settings, security, database integrity, and accounts:';
    items = [
      GuideActionItem(
        icon: Icons.admin_panel_settings_rounded,
        title: 'Global User Accounts',
        description:
            'Create new users, modify roles, reset passwords, or suspend accounts under "Users Management".',
      ),
      GuideActionItem(
        icon: Icons.security_rounded,
        title: 'Audit Logging & Monitoring',
        description:
            'Inspect detailed audit trails to track security actions, status changes, and user updates.',
      ),
      GuideActionItem(
        icon: Icons.health_and_safety_rounded,
        title: 'System Health Dashboard',
        description:
            'Monitor real-time system performance, database connection states, response times, and storage indicators.',
      ),
      GuideActionItem(
        icon: Icons.backup_table_rounded,
        title: 'Backup & Restore Control',
        description:
            'Perform automated or manual database backups and restore them to maintain system reliability.',
      ),
    ];
  }

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 550, maxHeight: 650),
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF0EA5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.help_center_outlined, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              
              // Intro & List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      introText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 18.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              item.icon,
                              color: const Color(0xFF0F766E),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.description,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.grey.shade600,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              
              // Action Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: Colors.grey.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('GOT IT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class GuideActionItem {
  final IconData icon;
  final String title;
  final String description;

  GuideActionItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

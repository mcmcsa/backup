import 'package:flutter/material.dart';

const Color _pageBg = Color(0xFFF8FAFC);
const Color _ink = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);
const Color _border = Color(0xFFE2E8F0);
const Color _card = Colors.white;

class MaintenanceWorkflowWeb extends StatelessWidget {
  const MaintenanceWorkflowWeb({super.key});

  static const _steps = [
    _WorkflowStep(
      step: '01',
      title: 'Request Submission',
      actor: 'TEACHER / REQUESTOR',
      actorRole: _Role.teacher,
      icon: Icons.edit_note_rounded,
      color: Color(0xFF6366F1),
      description:
          'The requestor files a ticket specifying the facility/room number, type of request (e.g., electrical, plumbing, structural), and specific details of the issue via QR scan or manual room entry.',
      statusLabel: 'PENDING',
      actionHint: 'Requestor submits work request ticket with room details.',
    ),
    _WorkflowStep(
      step: '02',
      title: 'Admin Review & Assignment',
      actor: 'ADMINISTRATOR',
      actorRole: _Role.admin,
      icon: Icons.rate_review_rounded,
      color: Color(0xFFF59E0B),
      description:
          'Campus Admin evaluates the ticket, assigns a priority level (Standard or High), selects a qualified maintenance technician, and approves the request with an electronic signature.',
      statusLabel: 'APPROVED',
      actionHint: 'Admin approves request & assigns technician with e-signature.',
    ),
    _WorkflowStep(
      step: '03',
      title: 'Technician Acceptance',
      actor: 'MAINTENANCE TECHNICIAN',
      actorRole: _Role.maintenance,
      icon: Icons.thumb_up_alt_rounded,
      color: Color(0xFF0EA5E9),
      description:
          'The assigned technician opens the task, signs an electronic acknowledgment signature, and officially accepts the job assignment.',
      statusLabel: 'IN PROGRESS',
      actionHint: 'Technician acknowledges & signs task acceptance.',
    ),
    _WorkflowStep(
      step: '04',
      title: 'Pre-Inspection Submitted',
      actor: 'MAINTENANCE TECHNICIAN',
      actorRole: _Role.maintenance,
      icon: Icons.search_rounded,
      color: Color(0xFF8B5CF6),
      description:
          'Before executing the repair, the technician conducts an initial site inspection and submits a pre-inspection report documenting initial findings and scope of work.',
      statusLabel: 'IN PROGRESS',
      actionHint: 'Technician files site pre-inspection assessment report.',
    ),
    _WorkflowStep(
      step: '05',
      title: 'Pre-Inspection Review',
      actor: 'ADMINISTRATOR',
      actorRole: _Role.admin,
      icon: Icons.checklist_rounded,
      color: Color(0xFFEC4899),
      description:
          'Admin reviews the pre-inspection report. If satisfactory, work is Confirmed to proceed. If unacceptable, the ticket is Declined and closed, or Rework is requested.',
      statusLabel: 'CONFIRMED / DECLINED',
      actionHint: 'Admin reviews pre-inspection & confirms work authorization.',
    ),
    _WorkflowStep(
      step: '06',
      title: 'Work Execution',
      actor: 'MAINTENANCE TECHNICIAN',
      actorRole: _Role.maintenance,
      icon: Icons.engineering_rounded,
      color: Color(0xFF0284C7),
      description:
          'The technician performs the required repair or maintenance work on-site. The request status updates to Under Maintenance during active repair execution.',
      statusLabel: 'UNDER MAINTENANCE',
      actionHint: 'Technician carries out physical repairs on facility.',
    ),
    _WorkflowStep(
      step: '07',
      title: 'Post-Repair Report Submitted',
      actor: 'MAINTENANCE TECHNICIAN',
      actorRole: _Role.maintenance,
      icon: Icons.add_a_photo_rounded,
      color: Color(0xFFD97706),
      description:
          'After completing the work, the technician uploads photo evidence of the accomplished repair, details the resolution, and submits the post-repair report with an e-signature.',
      statusLabel: 'POST-REPAIR SUBMITTED',
      actionHint: 'Technician submits completion report with photo proof.',
    ),
    _WorkflowStep(
      step: '08',
      title: 'Final Evaluation & Closure',
      actor: 'ADMINISTRATOR',
      actorRole: _Role.admin,
      icon: Icons.verified_user_rounded,
      color: Color(0xFF10B981),
      description:
          'Admin conducts final evaluation. If satisfactory, the ticket is marked Completed and the requestor is notified. If unsatisfactory, Rework is requested returning to Step 6.',
      statusLabel: 'COMPLETED / REWORK',
      actionHint: 'Admin verifies post-repair report & officially closes ticket.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 850;

    return Scaffold(
      backgroundColor: _pageBg,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 32,
          vertical: isMobile ? 20 : 32,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero Banner Header ─────────────────────────────────────
                _buildHeroHeader(isMobile),
                const SizedBox(height: 32),

                // ── Section Title ──────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Request Lifecycle Steps',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Connected Timeline List ────────────────────────────────
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _steps.length,
                  itemBuilder: (context, index) {
                    final step = _steps[index];
                    final isFirst = index == 0;
                    final isLast = index == _steps.length - 1;
                    return _TimelineItem(
                      step: step,
                      isFirst: isFirst,
                      isLast: isLast,
                      isMobile: isMobile,
                    );
                  },
                ),

                const SizedBox(height: 40),

                // ── Stakeholder Responsibility Summary ─────────────────────
                _buildRoleSummary(isMobile),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_tree_rounded, color: Color(0xFF38BDF8), size: 14),
                    SizedBox(width: 6),
                    Text(
                      'WORKFLOW SPECIFICATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF38BDF8),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Work Request Lifecycle',
            style: TextStyle(
              fontSize: isMobile ? 22 : 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comprehensive 8-step operational flow for PSU MMS requests — from initial submission to post-repair verification and formal closure.',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: const Color(0xFF94A3B8),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _buildMetricChip(Icons.format_list_numbered_rounded, '8 Sequential Steps', const Color(0xFF6366F1)),
              _buildMetricChip(Icons.people_alt_rounded, '3 System Roles', const Color(0xFFF59E0B)),
              _buildMetricChip(Icons.draw_rounded, 'Digital E-Signatures', const Color(0xFF0EA5E9)),
              _buildMetricChip(Icons.verified_rounded, 'Verified Closure', const Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSummary(bool isMobile) {
    final roles = [
      _RoleCardData(
        role: 'Teacher / Requestor',
        icon: Icons.person_pin_rounded,
        color: const Color(0xFF6366F1),
        duties: [
          'Scans QR code or inputs room number',
          'Submits detailed maintenance issue ticket',
          'Receives status updates & completion notification',
        ],
      ),
      _RoleCardData(
        role: 'Campus Administrator',
        icon: Icons.admin_panel_settings_rounded,
        color: const Color(0xFFF59E0B),
        duties: [
          'Evaluates priority & assigns technician',
          'Reviews & confirms pre-inspection reports',
          'Validates post-repair report & closes ticket',
        ],
      ),
      _RoleCardData(
        role: 'Maintenance Technician',
        icon: Icons.engineering_rounded,
        color: const Color(0xFF0EA5E9),
        duties: [
          'Signs digital acknowledgment to accept task',
          'Submits site pre-inspection condition report',
          'Executes repair & uploads photo proof of work',
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Stakeholder Responsibilities',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.3),
            ),
          ],
        ),
        const SizedBox(height: 16),
        isMobile
            ? Column(children: roles.map((r) => Padding(padding: const EdgeInsets.only(bottom: 14), child: _buildRoleCard(r))).toList())
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: roles
                    .map((r) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: _buildRoleCard(r),
                          ),
                        ))
                    .toList(),
              ),
      ],
    );
  }

  Widget _buildRoleCard(_RoleCardData r) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: r.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(r.icon, color: r.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  r.role,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 14),
          ...r.duties.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded, color: r.color, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        d,
                        style: const TextStyle(fontSize: 12, color: _muted, height: 1.4, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

enum _Role { teacher, admin, maintenance }

class _WorkflowStep {
  final String step;
  final String title;
  final String actor;
  final _Role actorRole;
  final IconData icon;
  final Color color;
  final String description;
  final String statusLabel;
  final String actionHint;

  const _WorkflowStep({
    required this.step,
    required this.title,
    required this.actor,
    required this.actorRole,
    required this.icon,
    required this.color,
    required this.description,
    required this.statusLabel,
    required this.actionHint,
  });
}

class _RoleCardData {
  final String role;
  final IconData icon;
  final Color color;
  final List<String> duties;

  const _RoleCardData({
    required this.role,
    required this.icon,
    required this.color,
    required this.duties,
  });
}

class _TimelineItem extends StatefulWidget {
  final _WorkflowStep step;
  final bool isFirst;
  final bool isLast;
  final bool isMobile;

  const _TimelineItem({
    required this.step,
    required this.isFirst,
    required this.isLast,
    required this.isMobile,
  });

  @override
  State<_TimelineItem> createState() => _TimelineItemState();
}

class _TimelineItemState extends State<_TimelineItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.step;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Connected Timeline Line Rail ─────────────────────────────────
          SizedBox(
            width: widget.isMobile ? 44 : 64,
            child: Column(
              children: [
                // Top connecting line
                Expanded(
                  child: Container(
                    width: 3,
                    color: widget.isFirst ? Colors.transparent : _border,
                  ),
                ),
                // Step Node Badge
                Container(
                  width: widget.isMobile ? 36 : 46,
                  height: widget.isMobile ? 36 : 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [s.color, s.color.withValues(alpha: 0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: s.color.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      s.step,
                      style: TextStyle(
                        fontSize: widget.isMobile ? 13 : 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Bottom connecting line
                Expanded(
                  child: Container(
                    width: 3,
                    color: widget.isLast ? Colors.transparent : _border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Step Content Card ──────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: MouseRegion(
                onEnter: (_) => setState(() => _hovered = true),
                onExit: (_) => setState(() => _hovered = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _hovered ? Colors.white : _card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hovered ? s.color.withValues(alpha: 0.5) : _border,
                      width: _hovered ? 1.5 : 1,
                    ),
                    boxShadow: _hovered
                        ? [
                            BoxShadow(
                              color: s.color.withValues(alpha: 0.12),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            )
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Actor Badge + Status Pill
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: s.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: s.color.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(s.icon, size: 13, color: s.color),
                                const SizedBox(width: 6),
                                Text(
                                  s.actor,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: s.color,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              s.statusLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Title
                      Text(
                        s.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Description
                      Text(
                        s.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _muted,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Action Hint Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: s.color.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(left: BorderSide(color: s.color, width: 3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.flash_on_rounded, size: 14, color: s.color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.actionHint,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: s.color.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

const Color _pageBg = Color(0xFFF1F5F9);
const Color _ink = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);
const Color _border = Color(0xFFE2E8F0);
const Color _card = Colors.white;

class MaintenanceWorkflowWeb extends StatelessWidget {
  const MaintenanceWorkflowWeb({super.key});

  static const _steps = [
    _WorkflowStep(
      step: '1',
      title: 'Request Submission',
      actor: 'TEACHER / REQUESTOR',
      icon: Icons.edit_note_rounded,
      color: Color(0xFF6366F1),
      description:
          'The requestor files a ticket specifying the facility/room number, type of request (e.g. electrical, plumbing, structural), and details of the issue.',
      statusLabel: 'PENDING',
    ),
    _WorkflowStep(
      step: '2',
      title: 'Review & Prioritization',
      actor: 'ADMINISTRATOR',
      icon: Icons.rate_review_rounded,
      color: Color(0xFFF59E0B),
      description:
          'Admin evaluates the ticket, assigns priority (Standard/High), selects an assignee from available maintenance staff, and approves it.',
      statusLabel: 'APPROVED',
    ),
    _WorkflowStep(
      step: '3',
      title: 'Acknowledgment & Start',
      actor: 'MAINTENANCE TECHNICIAN',
      icon: Icons.thumb_up_alt_rounded,
      color: Color(0xFF0EA5E9),
      description:
          'The assigned technician opens the task, signs an electronic acknowledgment signature, and begins work.',
      statusLabel: 'IN PROGRESS',
    ),
    _WorkflowStep(
      step: '4',
      title: 'Execution & Documentation',
      actor: 'MAINTENANCE TECHNICIAN',
      icon: Icons.add_a_photo_rounded,
      color: Color(0xFF8B5CF6),
      description:
          'Technician resolves the issue, uploads a photo as evidence of the accomplished work, notes resolution details, and signs off.',
      statusLabel: 'UNDER MAINTENANCE',
    ),
    _WorkflowStep(
      step: '5',
      title: 'Verification & Closure',
      actor: 'TEACHER & ADMINISTRATOR',
      icon: Icons.verified_user_rounded,
      color: Color(0xFF10B981),
      description:
          'The original requestor inspects the completed work and signs off to close the ticket. If unsatisfactory, admin/teacher may request REWORK (returns to Step 4).',
      statusLabel: 'COMPLETED',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            _buildHeader(),
            SizedBox(height: isMobile ? 24 : 32),

            // ── Timeline ─────────────────────────────────────────────────
            ..._steps.asMap().entries.expand((e) {
              final isLast = e.key == _steps.length - 1;
              return [
                _StepCard(step: e.value),
                if (!isLast) const _Connector(),
              ];
            }),

            const SizedBox(height: 32),

            // ── Legend ───────────────────────────────────────────────────
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: const Icon(Icons.account_tree_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Work Request Workflow', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.5)),
              SizedBox(height: 6),
              Text(
                'Step-by-step lifecycle of a PSU Maintenance Work Request — from submission to verified closure.',
                style: TextStyle(fontSize: 14, color: _muted, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Status Flow', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _steps.map((s) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: s.color.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(s.statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: s.color, letterSpacing: 0.3)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _WorkflowStep {
  final String step;
  final String title;
  final String actor;
  final IconData icon;
  final Color color;
  final String description;
  final String statusLabel;

  const _WorkflowStep({
    required this.step,
    required this.title,
    required this.actor,
    required this.icon,
    required this.color,
    required this.description,
    required this.statusLabel,
  });
}

class _StepCard extends StatefulWidget {
  final _WorkflowStep step;

  const _StepCard({required this.step});

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.step;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: _hovered ? s.color.withValues(alpha: 0.03) : _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _hovered ? s.color.withValues(alpha: 0.4) : _border),
          boxShadow: _hovered
              ? [BoxShadow(color: s.color.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 6))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: isMobile ? _buildMobile(s) : _buildDesktop(s),
        ),
      ),
    );
  }

  Widget _buildDesktop(_WorkflowStep s) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step badge
        Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [s.color, s.color.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: s.color.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: Text(s.step, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(s.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
                  ),
                  const SizedBox(width: 12),
                  // Actor pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: s.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: s.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(s.icon, size: 13, color: s.color),
                        const SizedBox(width: 6),
                        Text(s.actor, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: s.color, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Status label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: s.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(s.statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: s.color, letterSpacing: 0.5)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(s.description, style: const TextStyle(fontSize: 13, color: _muted, height: 1.6)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobile(_WorkflowStep s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [s.color, s.color.withValues(alpha: 0.7)]),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(s.step, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(s.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink))),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(s.actor, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: s.color)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(s.statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: s.color)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(s.description, style: const TextStyle(fontSize: 13, color: _muted, height: 1.6)),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: Center(
        child: Column(
          children: [
            Container(width: 2, height: 12, color: const Color(0xFFCBD5E1)),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF64748B), size: 16),
            ),
            Container(width: 2, height: 12, color: const Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}

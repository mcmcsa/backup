import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/pre_inspection_model.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/pre_inspection_service.dart';
import '../../../shared/services/post_repair_service.dart';
import '../shared/admin_styles.dart';
import 'admin_approval_signature_web.dart';
import 'admin_pre_inspection_review_web.dart';
import 'admin_post_repair_evaluation_web.dart';

class AdminWorkProcessWeb extends StatefulWidget {
  final WorkRequest request;

  const AdminWorkProcessWeb({super.key, required this.request});

  @override
  State<AdminWorkProcessWeb> createState() => _AdminWorkProcessWebState();
}

class _AdminWorkProcessWebState extends State<AdminWorkProcessWeb> {
  WorkRequest? _request;
  PreInspectionReport? _preInspection;
  PostRepairReport? _postRepair;
  bool _isLoading = true;
  int _selectedSection = 0;

  final ScrollController _contentScrollController = ScrollController();
  final GlobalKey _overviewKey = GlobalKey();
  final GlobalKey _timelineKey = GlobalKey();
  final GlobalKey _detailsKey = GlobalKey();
  final GlobalKey _actionsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _contentScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _request = await WorkRequestService.fetchById(widget.request.id) ?? widget.request;
      _preInspection = await PreInspectionService.fetchLatestByWorkRequest(_request!.id);
      _postRepair = await PostRepairService.fetchLatestByWorkRequest(_request!.id);
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminStyles.bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary))
          : _request == null
              ? _buildErrorState()
              : Row(
                  children: [
                    _buildSidebar(),
                    Expanded(
                      child: Container(
                        color: AdminStyles.bg,
                        child: SingleChildScrollView(
                          controller: _contentScrollController,
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1440),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(key: _overviewKey, child: _buildHeroSummary()),
                                  const SizedBox(height: 24),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isWide = constraints.maxWidth >= 1120;

                                      if (!isWide) {
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Container(key: _timelineKey, child: _buildTimelineSection()),
                                            const SizedBox(height: 24),
                                            Container(key: _detailsKey, child: _buildDetailsColumn()),
                                          ],
                                        );
                                      }

                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(flex: 7, child: Container(key: _timelineKey, child: _buildTimelineSection())),
                                          const SizedBox(width: 24),
                                          Expanded(flex: 4, child: Container(key: _detailsKey, child: _buildDetailsColumn())),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Color(0xFF0B1F33),
        border: Border(
          right: BorderSide(color: Color(0xFF17324A), width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WORK PROCESS HUB',
                          style: AdminStyles.headingStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _request?.title ?? 'Request details',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AdminStyles.bodyStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Status', style: AdminStyles.bodyStyle(fontSize: 11, color: Colors.white70, letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    _buildStatusPill(),
                    const SizedBox(height: 12),
                    Text(
                      _request?.id.substring(0, 8).toUpperCase() ?? '------',
                      style: AdminStyles.headingStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text('Service request identifier', style: AdminStyles.bodyStyle(fontSize: 11, color: Colors.white60)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  _buildSidebarItem('Overview', Icons.dashboard_rounded, 0, _overviewKey),
                  _buildSidebarItem('Timeline', Icons.route_rounded, 1, _timelineKey),
                  _buildSidebarItem('Details', Icons.info_outline_rounded, 2, _detailsKey),
                  _buildSidebarItem('Actions', Icons.handyman_outlined, 3, _actionsKey),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(String title, IconData icon, int index, GlobalKey key) {
    final isSelected = _selectedSection == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _selectedSection = index);
            _scrollToSection(key);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: AdminStyles.sidebarItemDecoration(isActive: isSelected).copyWith(
              color: isSelected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AdminStyles.headingStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.02,
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: AdminStyles.glassDecoration(
        color: Colors.white,
        opacity: 1.0,
        borderRadius: 0,
        hasBorder: false,
      ).copyWith(
        border: Border(bottom: BorderSide(color: AdminStyles.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: AdminStyles.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AdminStyles.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lifecycle Monitoring',
                style: AdminStyles.headingStyle(fontSize: 10, color: AdminStyles.textMuted, letterSpacing: 1),
              ),
              const SizedBox(height: 2),
              Text(
                'WORK PROCESS HUB',
                style: AdminStyles.headingStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const Spacer(),
          _buildStatusPill(),
          const SizedBox(width: 12),
          _HeaderIconButton(
            icon: Icons.refresh_rounded,
            onTap: _loadData,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AdminStyles.cardDecoration(borderRadius: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 900;

          return isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroTextBlock(),
                    const SizedBox(height: 20),
                    _buildHeroMetaRow(),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildHeroTextBlock()),
                    const SizedBox(width: 24),
                    _buildHeroMetaRow(),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildHeroTextBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _request!.title,
          style: AdminStyles.headingStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AdminStyles.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          'Track the request lifecycle, review workflow milestones, and manage available actions from a single desktop workspace.',
          style: AdminStyles.bodyStyle(fontSize: 14, color: AdminStyles.textSecondary),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildHeroChip('ID ${_request!.id.substring(0, 8).toUpperCase()}'),
            _buildHeroChip(_request!.priorityLabel.toUpperCase()),
            _buildHeroChip((_request!.status).replaceAll('_', ' ').toUpperCase()),
            if ((_request!.officeRoom ?? '').isNotEmpty) _buildHeroChip(_request!.officeRoom!),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroMetaRow() {
    return Container(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminStyles.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryRow('Request ID', _request!.id.substring(0, 8).toUpperCase()),
          _buildSummaryRow('Submitted', DateFormat('MMM dd, HH:mm').format(_request!.dateSubmitted)),
          _buildSummaryRow('Room', _request!.officeRoom ?? 'N/A'),
          const Divider(height: 24),
          _buildTimeMetric('Service Duration', _calculateDuration()),
        ],
      ),
    );
  }

  Widget _buildHeroChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AdminStyles.pillDecoration(color: AdminStyles.primary, isSecondary: true),
      child: Text(
        label,
        style: AdminStyles.headingStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AdminStyles.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AdminStyles.pillDecoration(color: AdminStyles.primary, isSecondary: true),
      child: Text(
        _request?.status.replaceAll('_', ' ').toUpperCase() ?? 'PENDING',
        style: AdminStyles.headingStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AdminStyles.primary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 64, color: AdminStyles.error),
          const SizedBox(height: 16),
          Text('Request not found', style: AdminStyles.headingStyle(fontSize: 18)),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminStyles.cardDecoration(borderRadius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AdminStyles.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.route_rounded, color: AdminStyles.primary, size: 24),
              ),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Maintenance Lifecycle', style: AdminStyles.headingStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  Text('Real-time tracking of the work request workflow stages.', style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 36),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              children: _buildTimelineSteps(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTimelineSteps() {
    final steps = <_TimelineStep>[
      _TimelineStep(
        title: 'Report Submitted',
        subtitle: 'Initial request by ${_request!.requestorName}',
        time: DateFormat('MMM dd, HH:mm').format(_request!.dateSubmitted),
        isCompleted: true,
        isActive: _request!.status == 'pending',
      ),
      _TimelineStep(
        title: 'Admin Approval',
        subtitle: _request!.approvedBy != null ? 'Approved by ${_request!.approvedBy}' : 'Awaiting administrative e-signature',
        time: _request!.approvedDate != null ? DateFormat('MMM dd, HH:mm').format(_request!.approvedDate!) : null,
        isCompleted: _request!.approvedDate != null,
        isActive: _request!.status == 'pending',
      ),
      _TimelineStep(
        title: 'Maintenance Acceptance',
        subtitle: _request!.acceptedByName != null ? 'Accepted by ${_request!.acceptedByName}' : 'Awaiting technician assignment',
        time: _request!.acceptedDate != null ? DateFormat('MMM dd, HH:mm').format(_request!.acceptedDate!) : null,
        isCompleted: _request!.acceptedDate != null,
        isActive: _request!.status == 'approved',
      ),
      _TimelineStep(
        title: 'Pre-Inspection',
        subtitle: _preInspection != null ? 'Report Status: ${_preInspection!.status.toUpperCase()}' : 'Pending technical inspection',
        time: _preInspection != null ? DateFormat('MMM dd, HH:mm').format(_preInspection!.inspectionDate) : null,
        isCompleted: _preInspection?.status == 'approved',
        isActive: _request!.status == 'in_progress',
      ),
      _TimelineStep(
        title: 'Under Maintenance',
        subtitle: _request!.status == 'under_maintenance' || _request!.status == 'completed'
            ? 'Active repair work in progress' : _preInspection?.status == 'submitted' ? 'Awaiting inspection approval' : 'Not yet started',
        time: _request!.maintenanceStartTime != null ? DateFormat('MMM dd, HH:mm').format(_request!.maintenanceStartTime!) : null,
        isCompleted: _request!.status == 'completed' || _postRepair != null,
        isActive: _request!.status == 'under_maintenance',
      ),
      _TimelineStep(
        title: 'Post-Repair Report',
        subtitle: _postRepair != null ? 'Evaluation: ${_postRepair!.adminEvaluation ?? 'In Review'}' : 'Awaiting technician completion report',
        time: _postRepair != null ? DateFormat('MMM dd, HH:mm').format(_postRepair!.repairDate) : null,
        isCompleted: _postRepair?.status == 'evaluated',
        isActive: _postRepair?.status == 'submitted',
      ),
      if (_request!.reworkCount > 0) _TimelineStep(
        title: 'Rework Required',
        subtitle: '${_request!.reworkCount} rework request(s) issued',
        isCompleted: _request!.status != 'rework',
        isActive: _request!.status == 'rework',
        isWarning: true,
      ),
      _TimelineStep(
        title: 'Fully Completed',
        subtitle: _request!.status == 'completed' ? 'Final signature obtained' : 'Final administrative closure pending',
        time: _request!.dateCompleted != null ? DateFormat('MMM dd, HH:mm').format(_request!.dateCompleted!) : null,
        isCompleted: _request!.status == 'completed',
        isActive: false,
      ),
    ];

    return steps.asMap().entries.map((e) => _buildTimelineItem(e.value, isLast: e.key == steps.length - 1)).toList();
  }

  Widget _buildTimelineItem(_TimelineStep step, {bool isLast = false}) {
    Color color = AdminStyles.primary;
    if (step.isCompleted) color = AdminStyles.success;
    else if (step.isActive) color = AdminStyles.primary;
    else if (step.isWarning) color = AdminStyles.error;
    else color = AdminStyles.textMuted.withValues(alpha: 0.3);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.1), border: Border.all(color: color, width: 2)),
                child: Center(child: Icon(step.isCompleted ? Icons.check_rounded : step.isWarning ? Icons.priority_high_rounded : Icons.radio_button_checked_rounded, size: 16, color: color)),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: color.withValues(alpha: 0.2))),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(step.title, style: AdminStyles.headingStyle(fontSize: 15, color: step.isCompleted || step.isActive ? AdminStyles.textPrimary : AdminStyles.textMuted)),
                      if (step.time != null) Text(step.time!, style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(step.subtitle, style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsColumn() {
    return Column(
      children: [
        _buildInfoCard('Request Overview', [
          _buildSummaryRow('ID', _request!.id.substring(0, 8).toUpperCase()),
          _buildSummaryRow('Priority', _request!.priorityLabel),
          _buildSummaryRow('Room', _request!.officeRoom ?? 'N/A'),
          const Divider(height: 24),
          _buildTimeMetric('Service Duration', _calculateDuration()),
        ]),
        const SizedBox(height: 20),
        _buildActionCard(),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminStyles.cardDecoration(borderRadius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AdminStyles.primary),
                const SizedBox(width: 8),
              ],
              Text(
                title.toUpperCase(),
                style: AdminStyles.headingStyle(fontSize: 10, color: AdminStyles.textMuted, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textMuted)),
          Text(value, style: AdminStyles.dataStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTimeMetric(String label, String value) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AdminStyles.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.timer_outlined, color: AdminStyles.primary, size: 20)),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
            Text(value, style: AdminStyles.headingStyle(fontSize: 16)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard() {
    final status = _request!.status;

    return Container(
      key: _actionsKey,
      padding: const EdgeInsets.all(24),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Available Actions', style: AdminStyles.headingStyle(fontSize: 14, color: AdminStyles.textSecondary)),
          const SizedBox(height: 20),
          if (status == 'pending') ...[
            _buildActionButton('Approve with Signature', Icons.draw_rounded, AdminStyles.primary, () async {
              await _navigateTo(AdminApprovalSignatureWeb(request: _request!));
            }),
          ],
          if (_preInspection != null && _preInspection!.status == 'submitted') ...[
            _buildActionButton('Review Pre-Inspection', Icons.fact_check_rounded, AdminStyles.warning, () async {
              await _navigateTo(AdminPreInspectionReviewWeb(request: _request!));
            }),
          ],
          if (_postRepair != null && _postRepair!.status == 'submitted') ...[
            _buildActionButton('Evaluate Post-Repair', Icons.rate_review_rounded, AdminStyles.success, () async {
              await _navigateTo(AdminPostRepairEvaluationWeb(request: _request!));
            }),
          ],
          if (status == 'completed') ...[
            Text('This request has been successfully closed.', style: AdminStyles.bodyStyle(color: AdminStyles.success, fontWeight: FontWeight.bold)),
          ] else if (status != 'pending' && !(_preInspection != null && _preInspection!.status == 'submitted') && !(_postRepair != null && _postRepair!.status == 'submitted')) ...[
            Text('No administrative actions required at this stage.', style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateTo(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => page));
    _loadData();
  }

  String _calculateDuration() {
    final start = _request!.maintenanceStartTime;
    final end = _request!.maintenanceEndTime;
    if (start == null) return 'Not started';
    final actualEnd = end ?? DateTime.now();
    final diff = actualEnd.difference(start);
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    return '${diff.inMinutes}m';
  }
}

class _TimelineStep {
  final String title;
  final String subtitle;
  final String? time;
  final bool isCompleted;
  final bool isActive;
  final bool isWarning;

  _TimelineStep({required this.title, required this.subtitle, this.time, required this.isCompleted, required this.isActive, this.isWarning = false});
}

/// Header icon button with professional styling and badge support
class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final int badge;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    this.badge = 0,
    required this.onTap,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: _isHovered
              ? AdminStyles.glassDecoration(
                  color: const Color(0xFFF1F5F9),
                  opacity: 1.0,
                  borderRadius: 12,
                )
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.transparent),
                ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                widget.icon,
                color: _isHovered ? AdminStyles.primary : const Color(0xFF94A3B8),
                size: 22,
              ),
              if (widget.badge > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AdminStyles.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

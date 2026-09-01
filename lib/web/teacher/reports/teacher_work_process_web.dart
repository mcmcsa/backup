import 'package:flutter/material.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/models/pre_inspection_model.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/pre_inspection_service.dart';
import '../../../shared/services/post_repair_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/user_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../admin/shared/admin_styles.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'teacher_official_form_web.dart';
import 'dart:async';


class TeacherWorkProcessWeb extends StatefulWidget {
  final WorkRequest request;
  final VoidCallback? onBack;

  const TeacherWorkProcessWeb({super.key, required this.request, this.onBack});

  @override
  State<TeacherWorkProcessWeb> createState() => _TeacherWorkProcessWebState();
}

class _TeacherWorkProcessWebState extends State<TeacherWorkProcessWeb>
    with SingleTickerProviderStateMixin {
  List<ESignature> _signatures = [];
  PreInspectionReport? _preInspectionReport;
  List<PostRepairReport> _postRepairReports = [];
  bool _isLoading = true;
  final Map<String, String> _userNames = {};
  Timer? _autoRefreshTimer;
  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

  late WorkRequest _currentRequest;

  WorkRequest get _req => _currentRequest;
  String get _status => _req.status.toLowerCase();

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
    _loadSignatures();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _animController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadSignatures();
    });
  }

  Future<void> _loadSignatures() async {
    try {
      final request = await WorkRequestService.fetchById(_req.id) ?? _req;
      final sigs = await ESignatureService.fetchByWorkRequest(_req.id);
      
      // Populate cache of user names from signatures to bypass RLS issues
      for (final sig in sigs) {
        if (sig.signerId.isNotEmpty && sig.signerName.isNotEmpty) {
          final isAdm = sig.signerRole.toLowerCase() == 'campadmin';
          _userNames[sig.signerId] = isAdm ? 'Campus Admin - ${sig.signerName}' : sig.signerName;
        }
      }

      final preInsp = await PreInspectionService.fetchLatestByWorkRequest(_req.id);
      final postRepairs = await PostRepairService.fetchByWorkRequest(_req.id);
      
      final userIds = <String>{};
      if (preInsp?.adminApprovedBy != null) userIds.add(preInsp!.adminApprovedBy!);
      for (final report in postRepairs) {
        if (report.adminEvaluatedBy != null) userIds.add(report.adminEvaluatedBy!);
      }
      final missingIds = userIds.where((id) => !_userNames.containsKey(id)).toList();
      if (missingIds.isNotEmpty) {
        final names = await UserService.fetchNamesByIds(missingIds);
        if (names.isNotEmpty) {
          _userNames.addAll(names);
        }
      }

      if (mounted) {
        setState(() {
          _currentRequest = request;
          _signatures = sigs;
          _preInspectionReport = preInsp;
          _postRepairReports = postRepairs;
          if (_isLoading) {
            _isLoading = false;
            _animController.forward();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_isLoading) {
            _isLoading = false;
            _animController.forward();
          }
        });
      }
    }
  }

  // ─── Status Helpers ──────────────────────────────────────────────────────────
  Color get _statusColor {
    final status = _status;
    final hasPreInsp = _preInspectionReport != null;
    final isPreInspReviewed = hasPreInsp && 
        (_preInspectionReport!.status == 'Approved' || _preInspectionReport!.status == 'Declined');
    final isPreInspApproved = hasPreInsp && _preInspectionReport!.status == 'Approved';
    final isPreInspDeclined = hasPreInsp && _preInspectionReport!.status == 'Declined';
    
    PostRepairReport? latestPostRepair;
    if (_postRepairReports.isNotEmpty) {
      final list = List<PostRepairReport>.from(_postRepairReports)
        ..sort((a, b) {
          int cmp = a.repairDate.compareTo(b.repairDate);
          if (cmp != 0) return cmp;
          return a.attemptNumber.compareTo(b.attemptNumber);
        });
      latestPostRepair = list.last;
    }
    final hasPostRepair = latestPostRepair != null;
    final isPostRepairEvaluated = latestPostRepair?.adminEvaluation != null;
    final isRework = latestPostRepair?.adminEvaluation == 'rework' || status == 'rework';
    final isCompleted = status == 'completed';

    if (isCompleted) {
      return AdminStyles.success;
    } else if (status == 'declined' || status == 'cancelled' || status == 'declined/cancelled' || isPreInspDeclined) {
      return AdminStyles.error;
    } else if (isRework) {
      return AdminStyles.warning;
    } else if (hasPostRepair && !isPostRepairEvaluated) {
      return AdminStyles.primary;
    } else if (hasPostRepair) {
      return AdminStyles.primary;
    } else if (isPreInspApproved) {
      return AdminStyles.primary;
    } else if (hasPreInsp && !isPreInspReviewed) {
      return AdminStyles.warning;
    } else if (status == 'in progress' || status == 'in_progress' || status == 'assigned' || status == 'accepted by maintenance') {
      return AdminStyles.info;
    } else {
      return AdminStyles.textMuted;
    }
  }

  String get _statusLabel {
    final status = _status;
    final hasPreInsp = _preInspectionReport != null;
    final isPreInspReviewed = hasPreInsp && 
        (_preInspectionReport!.status == 'Approved' || _preInspectionReport!.status == 'Declined');
    final isPreInspApproved = hasPreInsp && _preInspectionReport!.status == 'Approved';
    final isPreInspDeclined = hasPreInsp && _preInspectionReport!.status == 'Declined';
    
    PostRepairReport? latestPostRepair;
    if (_postRepairReports.isNotEmpty) {
      final list = List<PostRepairReport>.from(_postRepairReports)
        ..sort((a, b) {
          int cmp = a.repairDate.compareTo(b.repairDate);
          if (cmp != 0) return cmp;
          return a.attemptNumber.compareTo(b.attemptNumber);
        });
      latestPostRepair = list.last;
    }
    final hasPostRepair = latestPostRepair != null;
    final isPostRepairEvaluated = latestPostRepair?.adminEvaluation != null;
    final isRework = latestPostRepair?.adminEvaluation == 'rework' || status == 'rework';
    final isCompleted = status == 'completed';

    if (isCompleted) {
      return 'COMPLETED';
    } else if (status == 'declined' || status == 'cancelled' || status == 'declined/cancelled' || isPreInspDeclined) {
      return 'DECLINED';
    } else if (isRework) {
      return 'REWORK NEEDED';
    } else if (hasPostRepair && !isPostRepairEvaluated) {
      return 'UNDER EVALUATION';
    } else if (hasPostRepair) {
      return 'POST-REPAIR INSPECTION SUBMITTED';
    } else if (isPreInspApproved) {
      return 'CONFIRMED';
    } else if (hasPreInsp && !isPreInspReviewed) {
      return 'PRE-INSPECTION SUBMITTED';
    } else if (status == 'in progress' || status == 'in_progress' || status == 'assigned' || status == 'accepted by maintenance') {
      if (_req.acceptedDate == null) {
        return 'APPROVED';
      } else {
        return 'ACCEPTED';
      }
    } else {
      return 'AWAITING REVIEW';
    }
  }

  List<_TimelineStep> get _steps {
    final steps = <_TimelineStep>[];
    final task = _req;

    // 1. Request Submitted
    steps.add(_TimelineStep(
      icon: Icons.assignment_turned_in_rounded,
      title: 'Request Submitted',
      desc: 'Initial request submitted by ${task.displayRequestorName}.',
      date: task.dateSubmitted,
      isCompleted: true,
      color: AdminStyles.primary,
    ));

    // 2. Admin Review & Approval
    final isApproved = ['assigned', 'confirmed', 'rework', 'completed', 'in progress', 'in_progress', 'declined'].contains(task.status.toLowerCase());
    final isDeclinedInitially = task.status.toLowerCase() == 'declined' && task.preInspectionId == null;
    steps.add(_TimelineStep(
      icon: Icons.admin_panel_settings_rounded,
      title: isDeclinedInitially ? 'Request Declined' : 'Admin Review & Approval',
      desc: isDeclinedInitially
          ? 'Request was declined and closed.'
          : (isApproved
              ? 'Request approved by ${task.approvedByName ?? "Admin"}.'
              : 'Waiting for admin approval.'),
      date: task.approvedDate,
      isCompleted: isApproved,
      color: isDeclinedInitially ? AdminStyles.error : AdminStyles.secondary,
    ));

    if (isDeclinedInitially) return steps;

    // 3. Maintenance Assignment & Acceptance
    final isAccepted = task.acceptedDate != null;
    steps.add(_TimelineStep(
      icon: Icons.engineering_rounded,
      title: 'Maintenance Assignment',
      desc: isAccepted
          ? 'Accepted by ${task.acceptedByName ?? "Technician"}.'
          : (task.assignedToId != null
              ? 'Assigned to ${task.acceptedByName ?? "Technician"}. Awaiting acceptance.'
              : 'Pending technician assignment.'),
      date: task.acceptedDate,
      isCompleted: isAccepted,
      color: AdminStyles.info,
    ));

    // 4. Pre-Inspection Report Submitted
    final hasPreInsp = _preInspectionReport != null;
    steps.add(_TimelineStep(
      icon: Icons.search_rounded,
      title: 'Pre-Inspection',
      desc: hasPreInsp
          ? 'Submitted by ${_preInspectionReport!.inspectorName}'
          : 'Awaiting pre-inspection.',
      date: _preInspectionReport?.inspectionDate,
      isCompleted: hasPreInsp,
      color: AdminStyles.warning,
    ));

    // 5. Pre-Inspection Review Decision
    if (hasPreInsp) {
      final isReviewed = _preInspectionReport!.status == 'Approved' || _preInspectionReport!.status == 'Declined';
      final isPreInspDeclined = _preInspectionReport!.status == 'Declined';
      final approvedByName = _preInspectionReport!.adminApprovedBy != null
          ? (_userNames[_preInspectionReport!.adminApprovedBy] ?? _preInspectionReport!.adminApprovedBy)
          : "Admin";
      
      steps.add(_TimelineStep(
        icon: isPreInspDeclined ? Icons.cancel_rounded : Icons.fact_check_rounded,
        title: isPreInspDeclined ? 'Pre-Inspection Declined' : 'Pre-Inspection Approved',
        desc: isReviewed
            ? '${_preInspectionReport!.status} by $approvedByName'
            : 'Awaiting pre-inspection review.',
        date: _preInspectionReport?.adminApprovedDate,
        isCompleted: isReviewed && !isPreInspDeclined,
        color: isPreInspDeclined ? AdminStyles.error : AdminStyles.success,
      ));

      if (isPreInspDeclined) return steps;
    }

    // 6. Post-Repair Attempts
    final sortedAttempts = List<PostRepairReport>.from(_postRepairReports)
      ..sort((a, b) {
        int cmp = a.repairDate.compareTo(b.repairDate);
        if (cmp != 0) return cmp;
        return a.attemptNumber.compareTo(b.attemptNumber);
      });

    for (int i = 0; i < sortedAttempts.length; i++) {
      final report = sortedAttempts[i];
      steps.add(_TimelineStep(
        icon: Icons.build_circle_rounded,
        title: 'Post-Repair Report Submitted',
        desc: 'Submitted by ${report.technicianName}',
        date: report.repairDate,
        isCompleted: true,
        color: AdminStyles.primary,
      ));

      final isEvaluated = report.adminEvaluation != null;
      final isRework = report.adminEvaluation == 'rework';
      final evaluatedByName = report.adminEvaluatedBy != null
          ? (_userNames[report.adminEvaluatedBy] ?? report.adminEvaluatedBy)
          : "Admin";
      
      final isLatestReport = i == sortedAttempts.length - 1;
      if (isEvaluated || isLatestReport) {
        steps.add(_TimelineStep(
          icon: isRework ? Icons.refresh_rounded : Icons.check_circle_rounded,
          title: isRework ? 'Post-Repair Evaluation Completed - Rework' : 'Post-Repair Evaluation',
          desc: isEvaluated
              ? (isRework
                  ? 'Rework required by $evaluatedByName'
                  : 'Approved by $evaluatedByName')
              : 'Awaiting evaluation.',
          date: report.adminEvaluatedDate,
          isCompleted: isEvaluated,
          color: isRework ? AdminStyles.warning : AdminStyles.success,
          customBadge: isRework ? 'Rework' : null,
        ));
      }
    }

    // If the latest evaluation was rework, append a pending Post-Repair Report step
    if (sortedAttempts.isNotEmpty && sortedAttempts.last.adminEvaluation == 'rework') {
      steps.add(const _TimelineStep(
        icon: Icons.build_circle_rounded,
        title: 'Post-Repair Report',
        desc: 'Awaiting post-repair report (Rework).',
        isCompleted: false,
        color: Colors.grey,
      ));
    }

    // 7. Final Completion
    final isCompleted = task.status.toLowerCase() == 'completed';
    steps.add(_TimelineStep(
      icon: Icons.verified_rounded,
      title: 'Completed & Verified',
      desc: isCompleted
          ? 'Work request fully verified and completed.'
          : 'Awaiting final verification and close out.',
      date: task.dateCompleted,
      isCompleted: isCompleted,
      color: AdminStyles.success,
      isLast: true,
    ));

    return steps;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 1000;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDFA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary, strokeWidth: 2))
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(isCompact ? 20 : 40),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Column(
                            children: [
                              _buildStatusHero(),
                              const SizedBox(height: 32),
                              isCompact
                                  ? Column(children: [
                                      _buildTimelineCard(),
                                      const SizedBox(height: 24),
                                      _buildInfoPanel(),
                                    ])
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 6, child: _buildTimelineCard()),
                                        const SizedBox(width: 28),
                                        Expanded(flex: 4, child: _buildInfoPanel()),
                                      ],
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

  // ─── Header Bar ──────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 600;
    final trackId = _req.id.length > 8
        ? _req.id.substring(0, 8).toUpperCase()
        : _req.id.toUpperCase();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 24, vertical: isNarrow ? 10 : 0),
      height: isNarrow ? null : 68,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: widget.onBack ?? () => context.pop(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: EdgeInsets.all(isNarrow ? 8 : 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_rounded, size: isNarrow ? 18 : 20, color: AdminStyles.textPrimary),
            ),
          ),
          SizedBox(width: isNarrow ? 8 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Request Progress', style: AdminStyles.headingStyle(fontSize: isNarrow ? 15 : 20)),
                const SizedBox(height: 2),
                Text(
                  'Tracking ID: #$trackId',
                  style: AdminStyles.bodyStyle(fontSize: isNarrow ? 11 : 12, color: AdminStyles.textMuted),
                ),
              ],
            ),
          ),
          SizedBox(width: isNarrow ? 8 : 16),
          ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => TeacherOfficialFormWeb(request: _req),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 14, vertical: isNarrow ? 10 : 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: isNarrow
                ? const Icon(Icons.assignment_rounded, size: 18)
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('View Official Form', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
          ),
          SizedBox(width: isNarrow ? 8 : 16),
          _buildStatusBadge(isNarrow: isNarrow),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({bool isNarrow = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 16, vertical: isNarrow ? 6 : 8),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle)),
          SizedBox(width: isNarrow ? 6 : 8),
          Text(
            _statusLabel, 
            style: TextStyle(
              fontSize: isNarrow ? 10 : 12, 
              fontWeight: FontWeight.w700, 
              color: _statusColor, 
              letterSpacing: 0.5
            )
          ),
        ],
      ),
    );
  }

  // ─── Status Hero ─────────────────────────────────────────────────────────────
  Widget _buildStatusHero() {
    String title, desc;
    IconData icon;

    final req = _req;
    final status = _status;
    final hasPreInsp = _preInspectionReport != null;
    final isPreInspReviewed = hasPreInsp && 
        (_preInspectionReport!.status == 'Approved' || _preInspectionReport!.status == 'Declined');
    final isPreInspApproved = hasPreInsp && _preInspectionReport!.status == 'Approved';
    final isPreInspDeclined = hasPreInsp && _preInspectionReport!.status == 'Declined';
    
    // Check post-repair reports
    PostRepairReport? latestPostRepair;
    if (_postRepairReports.isNotEmpty) {
      final list = List<PostRepairReport>.from(_postRepairReports)
        ..sort((a, b) {
          int cmp = a.repairDate.compareTo(b.repairDate);
          if (cmp != 0) return cmp;
          return a.attemptNumber.compareTo(b.attemptNumber);
        });
      latestPostRepair = list.last;
    }
    final hasPostRepair = latestPostRepair != null;
    final isPostRepairEvaluated = latestPostRepair?.adminEvaluation != null;
    final isRework = latestPostRepair?.adminEvaluation == 'rework' || status == 'rework';
    final isCompleted = status == 'completed';

    if (isCompleted) {
      title = 'Completed';
      desc = 'This maintenance request has been completed and verified. Thank you!';
      icon = Icons.task_alt_rounded;
    } else if (status == 'declined' || status == 'cancelled' || status == 'declined/cancelled' || isPreInspDeclined) {
      title = 'Declined';
      desc = 'This maintenance request has been declined or cancelled.';
      icon = Icons.cancel_rounded;
    } else if (isRework) {
      title = 'Rework Needed';
      desc = 'The administrator requested rework on the performed repairs.';
      icon = Icons.history_rounded;
    } else if (hasPostRepair && !isPostRepairEvaluated) {
      // Step 7: Campus Admin reviews/evaluates post-repair inspection -> Under Evaluation
      title = 'Under Evaluation';
      desc = 'The campus admin is currently evaluating the post-repair inspection.';
      icon = Icons.rate_review_rounded;
    } else if (hasPostRepair) {
      // Step 6: Maintenance user submits post-repair inspection -> Post-Repair Inspection Submitted
      title = 'Post-Repair Inspection Submitted';
      desc = 'Repair completed. Post-repair report has been submitted.';
      icon = Icons.fact_check_rounded;
    } else if (isPreInspApproved) {
      // Step 5: Campus Admin confirms -> Confirmed
      title = 'Confirmed';
      desc = 'The pre-inspection has been confirmed. The repair is in progress.';
      icon = Icons.construction_rounded;
    } else if (hasPreInsp && !isPreInspReviewed) {
      // Step 4: Maintenance user submits pre-inspection -> Pre-Inspection Submitted
      title = 'Pre-Inspection Submitted';
      desc = 'Pre-inspection report has been submitted and is awaiting admin decision.';
      icon = Icons.search_rounded;
    } else if (status == 'in progress' || status == 'in_progress' || status == 'assigned' || status == 'accepted by maintenance') {
      if (req.acceptedDate == null) {
        // Step 2: Campus Admin reviews and approves -> Approved
        title = 'Approved';
        desc = 'The request has been approved and assigned to a technician. Awaiting acceptance.';
        icon = Icons.thumb_up_rounded;
      } else {
        // Step 3: Maintenance user accepts the work request -> Accepted
        title = 'Accepted';
        desc = 'The maintenance user accepted the task and is working on it.';
        icon = Icons.assignment_turned_in_rounded;
      }
    } else {
      // Step 1: Work request submitted -> Awaiting Review
      title = 'Awaiting Review';
      desc = 'Your request has been received and is pending admin review.';
      icon = Icons.pending_actions_rounded;
    }

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    Widget iconContainer = Container(
      width: isMobile ? 60 : 80,
      height: isMobile ? 60 : 80,
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: _statusColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Icon(icon, color: _statusColor, size: isMobile ? 28 : 38),
    );

    Widget textColumn = Column(
      crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title, 
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: AdminStyles.headingStyle(fontSize: isMobile ? 18 : 26, color: _statusColor),
        ),
        const SizedBox(height: 8),
        Text(
          desc, 
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: AdminStyles.bodyStyle(fontSize: isMobile ? 13 : 15, color: AdminStyles.textSecondary, height: 1.5),
        ),
        if (_req.maintenanceNotes != null && _req.maintenanceNotes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AdminStyles.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminStyles.info.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sticky_note_2_rounded, color: AdminStyles.info, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _req.maintenanceNotes!,
                    style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _statusColor.withValues(alpha: 0.12),
            _statusColor.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _statusColor.withValues(alpha: 0.25)),
        color: Colors.white,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                iconContainer,
                const SizedBox(height: 16),
                textColumn,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                iconContainer,
                const SizedBox(width: 28),
                Expanded(child: textColumn),
              ],
            ),
    );
  }

  // ─── Timeline Card ───────────────────────────────────────────────────────────
  Widget _buildTimelineCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminStyles.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timeline_rounded, color: AdminStyles.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Activity Timeline', style: AdminStyles.headingStyle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 32),
          ..._steps.map(_buildTimelineItem),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(_TimelineStep step) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line & Circle
          SizedBox(
            width: 48,
            child: Column(
              children: [
                // Circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (step.isCompleted || step.customBadge != null)
                        ? step.color.withValues(alpha: 0.12)
                        : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (step.isCompleted || step.customBadge != null) ? step.color : const Color(0xFFE2E8F0),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    (step.isCompleted || step.customBadge != null) ? step.icon : Icons.radio_button_unchecked_rounded,
                    color: (step.isCompleted || step.customBadge != null) ? step.color : const Color(0xFFCBD5E1),
                    size: 20,
                  ),
                ),
                // Connector
                if (!step.isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: step.isCompleted
                            ? LinearGradient(
                                colors: [step.color, step.color.withValues(alpha: 0.3)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                            : null,
                        color: step.isCompleted ? null : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: step.isLast ? 0 : 32, top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.title,
                          style: AdminStyles.headingStyle(
                            fontSize: 15,
                            color: step.isCompleted ? AdminStyles.textPrimary : AdminStyles.textMuted,
                            fontWeight: step.isCompleted ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (step.isCompleted || step.customBadge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: step.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            step.customBadge ?? 'Done',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: step.color),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    step.desc,
                    style: AdminStyles.bodyStyle(
                      fontSize: 13,
                      color: step.isCompleted ? AdminStyles.textSecondary : AdminStyles.textMuted,
                      height: 1.5,
                    ),
                  ),
                  if (step.date != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 13, color: step.color.withValues(alpha: 0.7)),
                        const SizedBox(width: 5),
                        Text(
                          DateFormat('MMM dd, yyyy • hh:mm a').format(step.date!),
                          style: TextStyle(fontSize: 11, color: step.color.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Info Panel ──────────────────────────────────────────────────────────────
  Widget _buildInfoPanel() {
    return Column(
      children: [
        _buildRequestInfoCard(),
        if (_signatures.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSignaturesCard(),
        ],
      ],
    );
  }

  Widget _buildRequestInfoCard() {
    // Only show priority if the admin has already reviewed/approved (status != 'pending').
    // While still pending, the admin has not yet assigned a priority level.
    final isPendingReview = _req.status.toLowerCase() == 'pending';
    final priorityDisplay = isPendingReview ? '--' : _req.priorityLabel;
    final priorityLower = _req.priority.toLowerCase();
    final priorityColor = isPendingReview
        ? AdminStyles.textMuted
        : priorityLower == 'high'
            ? AdminStyles.error
            : priorityLower == 'medium'
                ? AdminStyles.warning
                : priorityLower == 'low'
                    ? AdminStyles.success
                    : AdminStyles.textMuted;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminStyles.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_rounded, color: AdminStyles.secondary, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Request Details', style: AdminStyles.headingStyle(fontSize: 17)),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailChip(Icons.location_on_rounded, 'Location', '${_req.buildingName ?? 'N/A'} — ${_req.roomName ?? 'N/A'}', AdminStyles.primary),
          _buildDetailChip(Icons.flag_rounded, 'Priority', priorityDisplay, priorityColor),
          _buildDetailChip(Icons.calendar_today_rounded, 'Submitted', DateFormat('MMM dd, yyyy').format(_req.dateSubmitted), AdminStyles.textSecondary),
          if (_req.requestorName.isNotEmpty)
            _buildDetailChip(Icons.person_rounded, 'Requested by', _req.requestorName, AdminStyles.textPrimary),
          const Divider(height: 32, color: Color(0xFFE2E8F0)),
          Row(
            children: [
              const Icon(Icons.description_rounded, size: 16, color: AdminStyles.textMuted),
              const SizedBox(width: 8),
              Text('Description', style: AdminStyles.headingStyle(fontSize: 13, color: AdminStyles.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              _req.description.isNotEmpty ? _req.description : 'No description provided.',
              style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary, height: 1.7),
            ),
          ),
          if (_req.attachmentUrls != null && _req.attachmentUrls!.isNotEmpty) ...[
            const Divider(height: 32, color: Color(0xFFE2E8F0)),
            Row(
              children: [
                const Icon(Icons.image_rounded, size: 16, color: AdminStyles.textMuted),
                const SizedBox(width: 8),
                Text('Attachments', style: AdminStyles.headingStyle(fontSize: 13, color: AdminStyles.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _req.attachmentUrls!.length,
                itemBuilder: (context, index) {
                  final url = _req.attachmentUrls![index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                clipBehavior: Clip.antiAlias,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.85,
                                    maxHeight: MediaQuery.of(context).size.height * 0.75,
                                  ),
                                  color: Colors.black,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      InteractiveViewer(
                                        maxScale: 3.0,
                                        child: Image.network(
                                          url,
                                          fit: BoxFit.contain,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return const Center(
                                              child: CircularProgressIndicator(
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: CircleAvatar(
                                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                                          child: IconButton(
                                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                                            onPressed: () => Navigator.of(context).pop(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AdminStyles.primary),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: AdminStyles.headingStyle(fontSize: 13, color: AdminStyles.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignaturesCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminStyles.success.withValues(alpha: 0.3)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminStyles.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_rounded, color: AdminStyles.success, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Verified Signatures', style: AdminStyles.headingStyle(fontSize: 17)),
            ],
          ),
          const SizedBox(height: 20),
          ..._signatures.map((s) => _buildSignatureItem(s)),
        ],
      ),
    );
  }

  Widget _buildSignatureItem(ESignature s) {
    final initials = s.signerName.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();
    Uint8List? signatureBytes;
    if (s.signatureData.isNotEmpty) {
      try {
        final cleanBase64 = s.signatureData.contains(',')
            ? s.signatureData.split(',').last
            : s.signatureData;
        signatureBytes = base64Decode(cleanBase64.trim());
      } catch (_) {
        // ignore decode errors
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AdminStyles.success.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminStyles.success.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AdminStyles.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(initials, style: const TextStyle(color: AdminStyles.success, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.signerName, style: AdminStyles.headingStyle(fontSize: 13)),
                  Text(
                    () {
                      final role = s.signerRole.trim().toLowerCase();
                      final type = s.signatureType.trim().toLowerCase();
                      if (role == 'teacher' || role == 'requestor') {
                        if (type == 'approval' || type == 'submission') {
                          return 'Requestor Approval';
                        } else if (type == 'completion') {
                          return 'Requestor Completion';
                        }
                      } else if (role == 'admin' || role == 'approver') {
                        if (type == 'completion') {
                          return 'Admin Completion';
                        } else {
                          return 'Admin Approval';
                        }
                      } else if (role == 'maintenance' || role == 'technician') {
                        if (type == 'completion') {
                          return 'Maintenance Completion';
                        } else {
                          return 'Maintenance Sign';
                        }
                      }
                      return s.signerRole.toUpperCase();
                    }(),
                    style: AdminStyles.bodyStyle(fontSize: 10, color: AdminStyles.textMuted),
                  ),
                  if (signatureBytes != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 50,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Image.memory(
                        signatureBytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.verified_rounded, color: AdminStyles.success, size: 18),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM dd').format(s.signedAt),
                  style: AdminStyles.bodyStyle(fontSize: 10, color: AdminStyles.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data class ──────────────────────────────────────────────────────────────
class _TimelineStep {
  final IconData icon;
  final String title;
  final String desc;
  final DateTime? date;
  final bool isCompleted;
  final bool isLast;
  final Color color;
  final String? customBadge;

  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.desc,
    this.date,
    required this.isCompleted,
    this.isLast = false,
    required this.color,
    this.customBadge,
  });
}

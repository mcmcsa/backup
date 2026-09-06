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
  String _selectedFilter = 'Timeline';
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

  bool _isRequestorSignature(ESignature s) {
    // 1. Explicitly exclude any admin, campus admin, technician, or maintenance roles/types
    final role = s.signerRole.trim().toLowerCase();
    final type = s.signatureType.trim().toLowerCase();
    if (role == 'admin' || role == 'campadmin' || role == 'campus admin' ||
        role == 'maintenance' || role == 'technician') {
      return false;
    }
    if (type.contains('pre_inspection') || type.contains('post_repair')) {
      return false;
    }

    // 2. Check signerId against requestorId or reportedById
    final reqId = _req.requestorId?.trim();
    if (reqId != null && reqId.isNotEmpty && s.signerId.trim() == reqId) {
      return true;
    }
    final reportedId = _req.reportedById?.trim();
    if (reportedId != null && reportedId.isNotEmpty && s.signerId.trim() == reportedId) {
      return true;
    }

    // 3. Check signerName against requestorName, reportedByName, or displayRequestorName
    final signerName = s.signerName.trim().toLowerCase();
    final reqName = _req.requestorName.trim().toLowerCase();
    final dispName = _req.displayRequestorName.trim().toLowerCase();
    final reportedName = (_req.reportedByName ?? '').trim().toLowerCase();
    
    if (signerName.isNotEmpty) {
      if (reqName.isNotEmpty && signerName == reqName) return true;
      if (dispName.isNotEmpty && signerName == dispName) return true;
      if (reportedName.isNotEmpty && signerName == reportedName) return true;
    }

    // 4. Check role: 'teacher' or 'requestor'
    if (role == 'teacher' || role == 'requestor') {
      return true;
    }

    return false;
  }

  List<ESignature> get _requestorSignatures {
    return _signatures.where(_isRequestorSignature).toList();
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

    // 2. Campus Admin Review & Approval
    final isApproved = ['assigned', 'confirmed', 'rework', 'completed', 'in progress', 'in_progress', 'declined'].contains(task.status.toLowerCase());
    final isDeclinedInitially = task.status.toLowerCase() == 'declined' && task.preInspectionId == null;
    final campusAdminName = (task.approvedByName != null && task.approvedByName!.trim().isNotEmpty)
        ? task.approvedByName!.trim()
        : 'Campus Admin';
    steps.add(_TimelineStep(
      icon: Icons.admin_panel_settings_rounded,
      title: isDeclinedInitially ? 'Request Declined by Campus Admin' : 'Campus Admin Review & Approval',
      desc: isDeclinedInitially
          ? 'Request was declined by Campus Admin.'
          : (isApproved
              ? (task.approvedByName != null && task.approvedByName!.trim().isNotEmpty
                  ? 'Request approved by Campus Admin ($campusAdminName).'
                  : 'Request approved by Campus Admin.')
              : 'Waiting for Campus Admin approval.'),
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
          : "Campus Admin";
      
      steps.add(_TimelineStep(
        icon: isPreInspDeclined ? Icons.cancel_rounded : Icons.fact_check_rounded,
        title: isPreInspDeclined ? 'Pre-Inspection Declined' : 'Pre-Inspection Approved',
        desc: isReviewed
            ? '${_preInspectionReport!.status} by $approvedByName'
            : 'Awaiting Campus Admin pre-inspection review.',
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
          : "Campus Admin";
      
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
                      padding: EdgeInsets.all(isCompact ? 16 : 28),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1150),
                          child: isCompact
                              ? _buildCompactLayout()
                              : _buildDesktopLayout(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCompactStatusCard(),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildFilterButtons(),
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(_selectedFilter),
            child: _selectedFilter == 'Timeline'
                ? _buildTimelineCard()
                : (_selectedFilter == 'Details'
                    ? _buildRequestInfoCard()
                    : _buildSignaturesCard()),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (flex: 6): Filter buttons right on top of Work Request Timeline!
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterButtons(),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_selectedFilter),
                  child: _selectedFilter == 'Timeline'
                      ? _buildTimelineCard()
                      : (_selectedFilter == 'Details'
                          ? _buildRequestInfoCard()
                          : _buildSignaturesCard()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right Column (flex: 4): Compact status card (Rework Needed) on the right, plus info
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCompactStatusCard(),
              const SizedBox(height: 20),
              if (_selectedFilter == 'Timeline') ...[
                _buildRequestInfoCard(),
                if (_requestorSignatures.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildSignaturesCard(),
                ],
              ] else if (_selectedFilter == 'Details') ...[
                if (_requestorSignatures.isNotEmpty) ...[
                  _buildSignaturesCard(),
                  const SizedBox(height: 20),
                ],
              ] else if (_selectedFilter == 'Signature') ...[
                _buildRequestInfoCard(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButtons() {
    final filters = [
      {'label': 'Timeline', 'icon': Icons.timeline_rounded},
      {'label': 'Details', 'icon': Icons.description_outlined},
      {'label': 'Signature', 'icon': Icons.draw_outlined},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: filters.map((f) {
          final label = f['label'] as String;
          final icon = f['icon'] as IconData;
          final isSelected = _selectedFilter == label;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (_selectedFilter != label) {
                  setState(() => _selectedFilter = label);
                }
              },
              borderRadius: BorderRadius.circular(9),
              hoverColor: AdminStyles.primary.withValues(alpha: 0.04),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AdminStyles.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AdminStyles.primary.withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<Color?>(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      tween: ColorTween(
                        end: isSelected ? Colors.white : AdminStyles.textSecondary,
                      ),
                      builder: (context, iconColor, _) => Icon(
                        icon,
                        size: 16,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : AdminStyles.textSecondary,
                      ),
                      child: Text(label),
                    ),
                    if (label == 'Signature' && _requestorSignatures.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : AdminStyles.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_requestorSignatures.length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AdminStyles.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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

  // ─── Compact Status Card (Positioned on the Right) ─────────────────────────
  Widget _buildCompactStatusCard() {
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
      desc = 'The Campus Admin requested rework on the performed repairs.';
      icon = Icons.history_rounded;
    } else if (hasPostRepair && !isPostRepairEvaluated) {
      title = 'Under Evaluation';
      desc = 'The Campus Admin is currently evaluating the post-repair inspection.';
      icon = Icons.rate_review_rounded;
    } else if (hasPostRepair) {
      title = 'Post-Repair Submitted';
      desc = 'Repair completed. Post-repair report has been submitted to Campus Admin.';
      icon = Icons.fact_check_rounded;
    } else if (isPreInspApproved) {
      title = 'Confirmed';
      desc = 'The pre-inspection has been confirmed. The repair is in progress.';
      icon = Icons.construction_rounded;
    } else if (hasPreInsp && !isPreInspReviewed) {
      title = 'Pre-Inspection Submitted';
      desc = 'Pre-inspection report has been submitted and is awaiting Campus Admin decision.';
      icon = Icons.search_rounded;
    } else if (status == 'in progress' || status == 'in_progress' || status == 'assigned' || status == 'accepted by maintenance') {
      if (req.acceptedDate == null) {
        title = 'Approved';
        desc = 'The request has been approved by Campus Admin and assigned to a technician.';
        icon = Icons.thumb_up_rounded;
      } else {
        title = 'Accepted';
        desc = 'The maintenance user accepted the task and is working on it.';
        icon = Icons.assignment_turned_in_rounded;
      }
    } else {
      title = 'Awaiting Review';
      desc = 'Your request has been received and is pending Campus Admin review.';
      icon = Icons.pending_actions_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: _statusColor.withValues(alpha: 0.25), width: 1.5),
                ),
                child: Icon(icon, color: _statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AdminStyles.headingStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _statusColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            style: AdminStyles.bodyStyle(
              fontSize: 12,
              color: AdminStyles.textSecondary,
              height: 1.4,
            ),
          ),
          if (_req.maintenanceNotes != null && _req.maintenanceNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCCFBF1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.note_alt_outlined, color: AdminStyles.primary, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _req.maintenanceNotes!.trim(),
                      style: AdminStyles.bodyStyle(
                        fontSize: 11,
                        color: AdminStyles.textPrimary,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              Text('Work Request Timeline', style: AdminStyles.headingStyle(fontSize: 18)),
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
    final sigs = _requestorSignatures;

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
                  color: AdminStyles.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_rounded, color: AdminStyles.success, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Requestor Signature', style: AdminStyles.headingStyle(fontSize: 17)),
            ],
          ),
          const SizedBox(height: 20),
          if (sigs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.draw_rounded, size: 36, color: AdminStyles.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  Text(
                    'No Requestor Signature Recorded',
                    style: AdminStyles.headingStyle(fontSize: 14, color: AdminStyles.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your signature as the requestor will appear here once attached to this work request.',
                    textAlign: TextAlign.center,
                    style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted),
                  ),
                ],
              ),
            )
          else
            ...sigs.map((s) => _buildSignatureItem(s)),
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
                      final type = s.signatureType.trim().toLowerCase();
                      if (type == 'completion') {
                        return 'Requestor (Completion Confirmation)';
                      }
                      return 'Requestor (Submission)';
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

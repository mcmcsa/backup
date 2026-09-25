import 'package:flutter/material.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/models/pre_inspection_model.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/pre_inspection_service.dart';
import '../../../shared/services/post_repair_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/user_service.dart';
import '../../../shared/widgets/attachment_image_widget.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../admin/shared/admin_styles.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_follow_up_model.dart';
import '../../../shared/services/work_request_follow_up_service.dart';
import '../../../shared/services/login_activity_service.dart';
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
  List<WorkRequestFollowUp> _followUps = [];
  bool _isLoading = true;
  final Map<String, String> _userNames = {};
  Timer? _autoRefreshTimer;
  String _selectedFilter = 'Timeline';
  int _selectedAttemptIndex = 0;
  String? _selectedRequestorEval; // 'satisfy' | 'not_satisfy'
  int? _selectedRating; // 1..5
  final _requestorCommentController = TextEditingController();
  bool _isSubmittingEvaluation = false;
  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

  late WorkRequest _currentRequest;
  List<String> _recoveredAttachments = [];

  WorkRequest get _req => _currentRequest;
  String get _status => _req.status.toLowerCase();

  List<String> get _attachments {
    final list = <String>[];
    if (_req.attachmentUrls != null && _req.attachmentUrls!.isNotEmpty) {
      for (final u in _req.attachmentUrls!) {
        final trimmed = u.trim();
        if (trimmed.isNotEmpty && !list.contains(trimmed)) {
          list.add(trimmed);
        }
      }
    }
    if (_req.workEvidence != null && _req.workEvidence!.trim().isNotEmpty) {
      final ev = _req.workEvidence!.trim();
      try {
        final decoded = jsonDecode(ev);
        if (decoded is List) {
          for (final item in decoded) {
            final s = item?.toString().trim() ?? '';
            if (s.isNotEmpty && !list.contains(s)) {
              list.add(s);
            }
          }
        }
      } catch (_) {
        if (ev.startsWith('data:image')) {
          if (!list.contains(ev)) list.add(ev);
        } else {
          for (final part in ev.split(',')) {
            final s = part.trim();
            if (s.isNotEmpty && !list.contains(s)) {
              list.add(s);
            }
          }
        }
      }
    }
    for (final r in _recoveredAttachments) {
      final trimmed = r.trim();
      if (trimmed.isNotEmpty && !list.contains(trimmed)) {
        list.add(trimmed);
      }
    }
    return list;
  }

  Future<List<String>> _recoverStorageAttachments(String requestId) async {
    final results = <String>[];
    try {
      final client = Supabase.instance.client;
      final candidateBuckets = ['work-evidence', 'evidence', 'work_evidence', 'attachments'];
      for (final b in candidateBuckets) {
        try {
          final files = await client.storage.from(b).list(path: requestId);
          for (final f in files) {
            if (f.name.isNotEmpty && !f.name.startsWith('.')) {
              final pubUrl = client.storage.from(b).getPublicUrl('$requestId/${f.name}');
              if (!results.contains(pubUrl)) {
                results.add(pubUrl);
              }
            }
          }
          final subFiles = await client.storage.from(b).list(path: 'work-evidence/$requestId');
          for (final f in subFiles) {
            if (f.name.isNotEmpty && !f.name.startsWith('.')) {
              final pubUrl = client.storage.from(b).getPublicUrl('work-evidence/$requestId/${f.name}');
              if (!results.contains(pubUrl)) {
                results.add(pubUrl);
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return results;
  }

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
    _isLoading = false; // Show ticket immediately using widget.request
    _animController.value = 1.0;
    _loadSignatures();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _requestorCommentController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadSignatures();
      }
    });
  }

  Future<void> _loadSignatures() async {
    try {
      final reqId = _req.id;
      final results = await Future.wait([
        WorkRequestService.fetchById(reqId),
        ESignatureService.fetchByWorkRequest(reqId),
        PreInspectionService.fetchLatestByWorkRequest(reqId),
        PostRepairService.fetchByWorkRequest(reqId),
        WorkRequestFollowUpService.fetchFollowUpsForRequest(reqId),
      ]);

      if (!mounted) return;

      final request = (results[0] as WorkRequest?) ?? _req;
      final sigs = (results[1] as List<ESignature>?) ?? <ESignature>[];
      final preInsp = results[2] as PreInspectionReport?;
      final postRepairs = (results[3] as List<PostRepairReport>?) ?? <PostRepairReport>[];
      final followUps = (results[4] as List<WorkRequestFollowUp>?) ?? <WorkRequestFollowUp>[];
      
      // Populate cache of user names from signatures to bypass RLS issues
      for (final sig in sigs) {
        if (sig.signerId.isNotEmpty && sig.signerName.isNotEmpty) {
          final isAdm = sig.signerRole.toLowerCase() == 'campadmin';
          _userNames[sig.signerId] = isAdm ? 'Campus Admin - ${sig.signerName}' : sig.signerName;
        }
      }

      // Recover attachments asynchronously in background without blocking screen
      if ((request.attachmentUrls == null || request.attachmentUrls!.isEmpty) &&
          (request.workEvidence == null || request.workEvidence!.trim().isEmpty)) {
        _recoverStorageAttachments(request.id).then((found) {
          if (found.isNotEmpty && mounted) {
            setState(() {
              _recoveredAttachments = found;
            });
          }
        }).catchError((_) {});
      }

      final userIds = <String>{};
      if (preInsp?.adminApprovedBy != null) userIds.add(preInsp!.adminApprovedBy!);
      for (final report in postRepairs) {
        if (report.adminEvaluatedBy != null) userIds.add(report.adminEvaluatedBy!);
      }
      final missingIds = userIds.where((id) => !_userNames.containsKey(id)).toList();
      if (missingIds.isNotEmpty && mounted) {
        UserService.fetchNamesByIds(missingIds).then((names) {
          if (names.isNotEmpty && mounted) {
            setState(() {
              _userNames.addAll(names);
            });
          }
        }).catchError((_) {});
      }

      if (mounted) {
        setState(() {
          _currentRequest = request;
          _signatures = sigs;
          _preInspectionReport = preInsp;
          _postRepairReports = postRepairs;
          _followUps = followUps;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
    final isRequestorEvaluated = latestPostRepair?.isRequestorEvaluated == true;
    final isRequestorSatisfied = latestPostRepair?.isRequestorSatisfied == true;
    final hasPostRepair = latestPostRepair != null;
    final isPostRepairEvaluated = latestPostRepair?.adminEvaluation != null;
    final isRework = latestPostRepair?.adminEvaluation == 'rework' || status == 'rework';
    final isCompleted = status == 'completed';

    if (_req.isAcknowledged) {
      return const Color(0xFF6366F1);
    } else if (_req.isCancelled || status == 'cancelled') {
      return AdminStyles.error;
    } else if (isCompleted) {
      return AdminStyles.success;
    } else if (status == 'declined' || status == 'declined/cancelled' || isPreInspDeclined) {
      return AdminStyles.error;
    } else if (isRework) {
      return AdminStyles.warning;
    } else if (hasPostRepair && !isRequestorEvaluated) {
      return AdminStyles.warning;
    } else if (hasPostRepair && !isPostRepairEvaluated) {
      return isRequestorSatisfied ? AdminStyles.success : const Color(0xFFF59E0B);
    } else if (hasPostRepair) {
      return AdminStyles.primary;
    } else if (isPreInspApproved) {
      return AdminStyles.primary;
    } else if (hasPreInsp && !isPreInspReviewed) {
      return AdminStyles.warning;
    } else if (status == 'in progress' || status == 'in_progress' || status == 'assigned' || status == 'accepted by maintenance') {
      return AdminStyles.info;
    } else if (_req.isPendingDeptHead) {
      return const Color(0xFFF59E0B);
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
    final isRequestorEvaluated = latestPostRepair?.isRequestorEvaluated == true;
    final isRequestorSatisfied = latestPostRepair?.isRequestorSatisfied == true;
    final hasPostRepair = latestPostRepair != null;
    final isPostRepairEvaluated = latestPostRepair?.adminEvaluation != null;
    final isRework = latestPostRepair?.adminEvaluation == 'rework' || status == 'rework';
    final isCompleted = status == 'completed';

    if (_req.isAcknowledged) {
      return 'ACKNOWLEDGED BY DEPT HEAD';
    } else if (_req.isCancelled || status == 'cancelled') {
      return 'CANCELLED';
    } else if (isCompleted) {
      return 'COMPLETED';
    } else if (status == 'declined' || status == 'declined/cancelled' || isPreInspDeclined) {
      return 'DECLINED';
    } else if (isRework) {
      return 'REWORK NEEDED';
    } else if (hasPostRepair && !isRequestorEvaluated) {
      return 'WAITING FOR EVALUATION';
    } else if (hasPostRepair && !isPostRepairEvaluated) {
      return isRequestorSatisfied ? 'EVALUATED (SATISFIED)' : 'EVALUATED (NOT SATISFIED)';
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
    } else if (_req.isPendingDeptHead) {
      return 'PENDING DEPT HEAD';
    } else if (status == 'pending campus admin') {
      return 'PENDING CAMPUS ADMIN';
    } else {
      return 'AWAITING REVIEW';
    }
  }

  List<_TimelineStep> get _steps {
    final steps = <_TimelineStep>[];
    final task = _req;

    // 1. Request Submitted
    final photoCount = _attachments.length;
    steps.add(_TimelineStep(
      icon: Icons.assignment_turned_in_rounded,
      title: 'Request Submitted',
      desc: photoCount > 0
          ? 'Initial request submitted by ${task.displayRequestorName} with $photoCount photo${photoCount > 1 ? "s" : ""}.'
          : 'Initial request submitted by ${task.displayRequestorName}.',
      date: task.dateSubmitted,
      isCompleted: true,
      color: AdminStyles.primary,
    ));

    final isBypassed = task.deptHeadStatus.toLowerCase() == 'not_applicable';
    final isAcknowledged = task.isAcknowledged || task.deptHeadStatus.toLowerCase() == 'acknowledged';
    final isCancelled = task.isCancelled || task.status.toLowerCase() == 'cancelled';
    final isDeptHeadDeclined = task.deptHeadStatus.toLowerCase() == 'declined';
    final isDeptHeadApproved = task.deptHeadStatus.toLowerCase() == 'approved';
    final deptHeadDisplayName = (task.deptHeadName != null && task.deptHeadName!.trim().isNotEmpty)
        ? task.deptHeadName!.trim()
        : 'Department Head';

    if (!isBypassed) {
      if (isAcknowledged) {
        steps.add(_TimelineStep(
          icon: Icons.assignment_turned_in_rounded,
          title: 'Acknowledged by Department Head',
          desc: 'Department Head ($deptHeadDisplayName) acknowledged the request. Handled internally by department and centralized maintenance workflow has ended.${task.deptHeadNotes != null && task.deptHeadNotes!.isNotEmpty ? " Notes: ${task.deptHeadNotes}" : ""}',
          date: task.deptHeadEvaluatedDate ?? task.deptHeadApprovedDate,
          isCompleted: true,
          color: const Color(0xFF6366F1),
        ));
        return steps;
      }

      if (isCancelled && task.isPendingDeptHead) {
        steps.add(_TimelineStep(
          icon: Icons.pending_actions_rounded,
          title: 'Department Head Evaluation',
          desc: 'Waiting for Department Head ($deptHeadDisplayName) evaluation.',
          date: null,
          isCompleted: false,
          color: const Color(0xFFF59E0B),
        ));
        steps.add(_TimelineStep(
          icon: Icons.cancel_rounded,
          title: 'Request Cancelled',
          desc: 'Request cancelled by requestor.${task.cancellationReason != null && task.cancellationReason!.isNotEmpty ? " Reason (${task.cancellationReasonType ?? 'Other'}): ${task.cancellationReason}" : ""}',
          date: task.cancelledAt,
          isCompleted: true,
          color: AdminStyles.error,
        ));
        return steps;
      }

      steps.add(_TimelineStep(
        icon: isDeptHeadDeclined
            ? Icons.cancel_rounded
            : (isDeptHeadApproved ? Icons.approval_rounded : Icons.pending_actions_rounded),
        title: isDeptHeadDeclined
            ? 'Declined by Department Head'
            : (isDeptHeadApproved ? 'Department Head Approval' : 'Department Head Evaluation'),
        desc: isDeptHeadDeclined
            ? 'Request was declined by Department Head ($deptHeadDisplayName).${task.deptHeadNotes != null && task.deptHeadNotes!.isNotEmpty ? " Reason: ${task.deptHeadNotes}" : ""}'
            : (isDeptHeadApproved
                ? 'Approved by Department Head ($deptHeadDisplayName) and forwarded to Campus Admin.'
                : 'Waiting for Department Head ($deptHeadDisplayName) evaluation.'),
        date: task.deptHeadApprovedDate ?? task.deptHeadEvaluatedDate,
        isCompleted: isDeptHeadApproved,
        color: isDeptHeadDeclined ? AdminStyles.error : (isDeptHeadApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
      ));

      if (isDeptHeadDeclined) return steps;
    }

    if (isCancelled) {
      steps.add(_TimelineStep(
        icon: Icons.cancel_rounded,
        title: 'Request Cancelled',
        desc: 'Request cancelled by requestor.${task.cancellationReason != null && task.cancellationReason!.isNotEmpty ? " Reason (${task.cancellationReasonType ?? 'Other'}): ${task.cancellationReason}" : ""}',
        date: task.cancelledAt,
        isCompleted: true,
        color: AdminStyles.error,
      ));
      return steps;
    }

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
    final isReviewed = hasPreInsp && (_preInspectionReport!.status == 'Approved' || _preInspectionReport!.status == 'Declined');
    final isPreInspDeclined = hasPreInsp && _preInspectionReport!.status == 'Declined';
    final isPreInspApproved = hasPreInsp && _preInspectionReport!.status == 'Approved';
    final approvedByName = _preInspectionReport?.adminApprovedBy != null
        ? (_userNames[_preInspectionReport!.adminApprovedBy] ?? _preInspectionReport!.adminApprovedBy)
        : "Campus Admin";
    
    steps.add(_TimelineStep(
      icon: isPreInspDeclined ? Icons.cancel_rounded : Icons.fact_check_rounded,
      title: isPreInspDeclined
          ? 'Pre-Inspection Declined'
          : (isPreInspApproved ? 'Pre-Inspection Approved' : 'Pre-Inspection Review'),
      desc: isReviewed
          ? '${_preInspectionReport!.status} by $approvedByName'
          : (hasPreInsp ? 'Awaiting Campus Admin pre-inspection review.' : 'Pending pre-inspection submission.'),
      date: _preInspectionReport?.adminApprovedDate,
      isCompleted: isPreInspApproved,
      color: isPreInspDeclined ? AdminStyles.error : AdminStyles.success,
    ));

    if (isPreInspDeclined) return steps;

    final sortedAttempts = List<PostRepairReport>.from(_postRepairReports)
      ..sort((a, b) {
        int cmp = a.repairDate.compareTo(b.repairDate);
        if (cmp != 0) return cmp;
        return a.attemptNumber.compareTo(b.attemptNumber);
      });
    final hasPostRepair = sortedAttempts.isNotEmpty;
    final isCompleted = task.status.toLowerCase() == 'completed';

    // 6. Post-Repair Attempts & Evaluations
    if (hasPostRepair) {
      for (int i = 0; i < sortedAttempts.length; i++) {
        final report = sortedAttempts[i];
        final attemptSuffix = sortedAttempts.length > 1 ? ' (Attempt #${report.attemptNumber})' : '';
        steps.add(_TimelineStep(
          icon: Icons.build_circle_rounded,
          title: 'Post-Repair Report$attemptSuffix',
          desc: 'Submitted by ${report.technicianName}',
          date: report.repairDate,
          isCompleted: true,
          color: AdminStyles.primary,
        ));

        // 6b. Requestor Evaluation
        final isRequestorEvaluated = report.isRequestorEvaluated;
        final isLatestReport = i == sortedAttempts.length - 1;
        if (isRequestorEvaluated || isLatestReport) {
          steps.add(_TimelineStep(
            icon: isRequestorEvaluated
                ? (report.isRequestorSatisfied
                    ? Icons.thumb_up_alt_rounded
                    : Icons.thumb_down_alt_rounded)
                : Icons.rate_review_rounded,
            title: isRequestorEvaluated
                ? 'Requestor Evaluation: ${report.isRequestorSatisfied ? "Satisfied" : "Not Satisfied"}'
                : 'Requestor Evaluation',
            desc: isRequestorEvaluated
                ? 'Evaluated by ${task.requestorName.isNotEmpty ? task.requestorName : "Requestor"}${report.requestorRating != null ? " • Rating: ${report.requestorRating}/5" : ""}${report.requestorComment != null && report.requestorComment!.isNotEmpty ? ' • "${report.requestorComment}"' : ""}'
                : 'Awaiting your review and evaluation.',
            date: report.requestorEvaluatedDate,
            isCompleted: isRequestorEvaluated,
            color: isRequestorEvaluated
                ? (report.isRequestorSatisfied ? AdminStyles.success : const Color(0xFFF59E0B))
                : AdminStyles.warning,
            customBadge: isRequestorEvaluated
                ? (report.isRequestorSatisfied ? 'Satisfy' : 'Not Satisfy')
                : 'Action Needed',
          ));
        }

        // 6c. Campus Admin Final Decision
        final isEvaluated = report.adminEvaluation != null;
        final isRework = report.adminEvaluation == 'rework';
        final evaluatedByName = report.adminEvaluatedBy != null
            ? (_userNames[report.adminEvaluatedBy] ?? report.adminEvaluatedBy)
            : "Campus Admin";
        
        if (isEvaluated || (isLatestReport && isRequestorEvaluated)) {
          steps.add(_TimelineStep(
            icon: isRework ? Icons.refresh_rounded : Icons.check_circle_rounded,
            title: isRework ? 'Campus Admin Decision - Rework Required' : 'Campus Admin Final Decision',
            desc: isEvaluated
                ? (isRework
                    ? 'Rework required by $evaluatedByName'
                    : 'Approved by $evaluatedByName')
                : 'Awaiting Campus Admin final decision.',
            date: report.adminEvaluatedDate,
            isCompleted: isEvaluated && !isRework,
            color: isRework ? AdminStyles.warning : AdminStyles.success,
            customBadge: isRework ? 'Rework' : null,
          ));
        }
      }

      // If the latest evaluation was rework, append a pending Post-Repair Report step
      if (sortedAttempts.last.adminEvaluation == 'rework') {
        final nextAttempt = sortedAttempts.length + 1;
        steps.add(_TimelineStep(
          icon: Icons.build_circle_rounded,
          title: 'Post-Repair Report (Attempt #$nextAttempt)',
          desc: 'Awaiting post-repair report (Rework).',
          isCompleted: false,
          color: AdminStyles.warning,
        ));
      }
    } else {
      steps.add(_TimelineStep(
        icon: Icons.build_circle_rounded,
        title: 'Post-Repair Report',
        desc: isPreInspApproved
            ? 'Awaiting post-repair report submission.'
            : 'Pending repair completion.',
        isCompleted: false,
        color: isPreInspApproved ? AdminStyles.primary : Colors.grey,
      ));

      steps.add(const _TimelineStep(
        icon: Icons.rate_review_rounded,
        title: 'Requestor Evaluation',
        desc: 'Pending post-repair report submission.',
        isCompleted: false,
        color: Colors.grey,
      ));

      steps.add(const _TimelineStep(
        icon: Icons.gavel_rounded,
        title: 'Campus Admin Final Decision',
        desc: 'Pending requestor evaluation.',
        isCompleted: false,
        color: Colors.grey,
      ));
    }

    // 8. Final Completion
    final hasSatisfiedEval = hasPostRepair && sortedAttempts.last.adminEvaluation == 'satisfied';
    steps.add(_TimelineStep(
      icon: Icons.verified_rounded,
      title: 'Completed & Verified',
      desc: isCompleted
          ? 'Work request fully verified and completed.'
          : (hasSatisfiedEval
              ? 'Awaiting final verification and close out.'
              : 'Pending work completion and evaluation.'),
      date: task.dateCompleted,
      isCompleted: isCompleted,
      color: isCompleted ? AdminStyles.success : Colors.grey,
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

  Future<void> _submitEvaluation(PostRepairReport report) async {
    if (_selectedRequestorEval == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select either Satisfy or Not Satisfy to proceed.'),
          backgroundColor: AdminStyles.warning,
        ),
      );
      return;
    }

    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    if (_req.requestorId != null && _req.requestorId!.isNotEmpty && user.id != _req.requestorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Action Denied: Only the original requestor can submit this evaluation.'),
          backgroundColor: AdminStyles.error,
        ),
      );
      return;
    }

    setState(() => _isSubmittingEvaluation = true);
    try {
      await PostRepairService.submitRequestorEvaluation(
        id: report.id,
        requestorId: user.id,
        evaluation: _selectedRequestorEval!,
        rating: _selectedRating,
        comment: _requestorCommentController.text.trim(),
      );

      try {
        await AppNotificationService.notifyRequestorEvaluationSubmittedToAdmin(
          workRequestId: _req.id,
          requestorName: user.name,
          evaluation: _selectedRequestorEval!,
          adminId: _req.approvedById,
          requestorUserId: user.id,
          rating: _selectedRating,
          comment: _requestorCommentController.text.trim(),
        );
      } catch (e) {
        debugPrint('Post-repair notification error: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your evaluation has been submitted to Campus Admin for final decision.'),
            backgroundColor: AdminStyles.success,
          ),
        );
        setState(() {
          _selectedRequestorEval = null;
          _selectedRating = null;
          _requestorCommentController.clear();
          _isSubmittingEvaluation = false;
        });
        await _loadSignatures();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingEvaluation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit evaluation: $e'),
            backgroundColor: AdminStyles.error,
          ),
        );
      }
    }
  }

  Widget _buildPostRepairEvaluationCard(PostRepairReport report, {required bool isLatest}) {
    final isEvaluated = report.isRequestorEvaluated;
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    final isRequestor = _req.requestorId == null || _req.requestorId!.isEmpty || (currentUser != null && currentUser.id == _req.requestorId);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEvaluated
              ? (report.isRequestorSatisfied
                  ? AdminStyles.success.withValues(alpha: 0.3)
                  : AdminStyles.warning.withValues(alpha: 0.3))
              : AdminStyles.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
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
                  color: (isEvaluated
                          ? (report.isRequestorSatisfied
                              ? AdminStyles.success
                              : AdminStyles.warning)
                          : AdminStyles.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEvaluated
                      ? (report.isRequestorSatisfied
                          ? Icons.verified_rounded
                          : Icons.rate_review_rounded)
                      : Icons.rate_review_rounded,
                  color: isEvaluated
                      ? (report.isRequestorSatisfied
                          ? AdminStyles.success
                          : AdminStyles.warning)
                      : AdminStyles.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maintenance Work Evaluation',
                      style: AdminStyles.headingStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _postRepairReports.length > 1
                          ? 'Attempt #${report.attemptNumber} • Submitted by ${report.technicianName}'
                          : 'Submitted by ${report.technicianName}',
                      style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted),
                    ),
                  ],
                ),
              ),
              if (_postRepairReports.length > 1) ...[
                Wrap(
                  spacing: 6,
                  children: List.generate(_postRepairReports.length, (idx) {
                    final att = _postRepairReports[idx];
                    final isSel = idx == _selectedAttemptIndex;
                    return InkWell(
                      onTap: () => setState(() => _selectedAttemptIndex = idx),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? AdminStyles.primary : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${att.attemptNumber}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSel ? Colors.white : AdminStyles.textMuted,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'REPAIR DETAILS FOR YOUR REVIEW',
            style: AdminStyles.headingStyle(
              fontSize: 11,
              color: AdminStyles.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminStyles.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoLine(Icons.construction_rounded, 'Work Performed', report.workPerformed),
                if (report.materialsUsed != null && report.materialsUsed!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildInfoLine(Icons.inventory_2_outlined, 'Materials Used', report.materialsUsed!),
                ],
                if (report.technicianNotes != null && report.technicianNotes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildInfoLine(Icons.notes_rounded, 'Technician Notes', report.technicianNotes!),
                ],
                const SizedBox(height: 10),
                _buildInfoLine(
                  Icons.calendar_today_rounded,
                  'Repair Date',
                  DateFormat('MMM dd, yyyy • hh:mm a').format(report.repairDate),
                ),
                if (report.photoAfter != null && report.photoAfter!.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildPostRepairPhotoPreview(report.photoAfter!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (!isEvaluated) ...[
            if (isLatest && isRequestor) ...[
              Text(
                'How was the completed maintenance work?',
                style: AdminStyles.headingStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AdminStyles.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please select your assessment. Both decisions will be forwarded to Campus Admin for the final decision.',
                style: AdminStyles.bodyStyle(
                  fontSize: 12,
                  color: AdminStyles.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedRequestorEval = 'satisfy'),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _selectedRequestorEval == 'satisfy'
                              ? AdminStyles.success.withValues(alpha: 0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedRequestorEval == 'satisfy'
                                ? AdminStyles.success
                                : AdminStyles.border,
                            width: _selectedRequestorEval == 'satisfy' ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedRequestorEval == 'satisfy'
                                  ? Icons.check_circle_rounded
                                  : Icons.check_circle_outline_rounded,
                              color: _selectedRequestorEval == 'satisfy'
                                  ? AdminStyles.success
                                  : AdminStyles.textMuted,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Satisfy',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _selectedRequestorEval == 'satisfy'
                                    ? AdminStyles.success
                                    : AdminStyles.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedRequestorEval = 'not_satisfy'),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _selectedRequestorEval == 'not_satisfy'
                              ? AdminStyles.error.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedRequestorEval == 'not_satisfy'
                                ? AdminStyles.error
                                : AdminStyles.border,
                            width: _selectedRequestorEval == 'not_satisfy' ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedRequestorEval == 'not_satisfy'
                                  ? Icons.cancel_rounded
                                  : Icons.cancel_outlined,
                              color: _selectedRequestorEval == 'not_satisfy'
                                  ? AdminStyles.error
                                  : AdminStyles.textMuted,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Not Satisfy',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _selectedRequestorEval == 'not_satisfy'
                                    ? AdminStyles.error
                                    : AdminStyles.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Rating (Optional):',
                    style: AdminStyles.bodyStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AdminStyles.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      final starNum = index + 1;
                      final isFilled = _selectedRating != null && _selectedRating! >= starNum;
                      return IconButton(
                        iconSize: 24,
                        padding: const EdgeInsets.all(2),
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                          color: isFilled ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                        ),
                        onPressed: () {
                          setState(() {
                            if (_selectedRating == starNum) {
                              _selectedRating = null;
                            } else {
                              _selectedRating = starNum;
                            }
                          });
                        },
                      );
                    }),
                  ),
                  if (_selectedRating != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '($_selectedRating / 5)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Additional Comments (Optional):',
                style: AdminStyles.bodyStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AdminStyles.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _requestorCommentController,
                maxLines: 2,
                style: AdminStyles.bodyStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Share any feedback or details about the repair...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: AdminStyles.textMuted.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AdminStyles.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AdminStyles.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AdminStyles.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_selectedRequestorEval != null && !_isSubmittingEvaluation)
                      ? () => _submitEvaluation(report)
                      : null,
                  icon: _isSubmittingEvaluation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _selectedRequestorEval == null
                        ? 'Select Satisfy or Not Satisfy to Submit'
                        : 'Submit Evaluation',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminStyles.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: AdminStyles.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: AdminStyles.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isRequestor
                            ? 'Awaiting evaluation on this attempt.'
                            : 'Awaiting evaluation by the original requestor (${widget.request.requestorName}).',
                        style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: report.isRequestorSatisfied
                    ? AdminStyles.success.withValues(alpha: 0.08)
                    : AdminStyles.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: report.isRequestorSatisfied
                      ? AdminStyles.success.withValues(alpha: 0.3)
                      : AdminStyles.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        report.isRequestorSatisfied
                            ? Icons.check_circle_rounded
                            : Icons.info_rounded,
                        color: report.isRequestorSatisfied
                            ? AdminStyles.success
                            : const Color(0xFFB45309),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Your Decision: ${report.isRequestorSatisfied ? "SATISFY" : "NOT SATISFY"}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: report.isRequestorSatisfied
                              ? AdminStyles.success
                              : const Color(0xFFB45309),
                        ),
                      ),
                      const Spacer(),
                      if (report.requestorRating != null) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 2),
                            Text(
                              '${report.requestorRating}/5',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  if (report.requestorComment != null && report.requestorComment!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Comment: "${report.requestorComment}"',
                      style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textPrimary),
                    ),
                  ],
                  if (report.requestorEvaluatedDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Evaluated on ${DateFormat('MMM dd, yyyy • hh:mm a').format(report.requestorEvaluatedDate!)}',
                      style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        report.adminEvaluation != null
                            ? (report.adminEvaluation == 'satisfied'
                                ? Icons.verified_rounded
                                : Icons.refresh_rounded)
                            : Icons.hourglass_top_rounded,
                        size: 16,
                        color: report.adminEvaluation != null
                            ? (report.adminEvaluation == 'satisfied'
                                ? AdminStyles.success
                                : AdminStyles.error)
                            : AdminStyles.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          report.adminEvaluation != null
                              ? (report.adminEvaluation == 'satisfied'
                                  ? 'Campus Admin approved & completed this work request.'
                                  : 'Campus Admin sent this request for rework.')
                              : 'Campus Admin review status: Awaiting final decision.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: report.adminEvaluation != null
                                ? (report.adminEvaluation == 'satisfied'
                                    ? AdminStyles.success
                                    : AdminStyles.error)
                                : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (report.adminEvaluationNotes != null && report.adminEvaluationNotes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Admin Notes: ${report.adminEvaluationNotes}',
                      style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoLine(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AdminStyles.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AdminStyles.bodyStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AdminStyles.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AdminStyles.bodyStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AdminStyles.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostRepairPhotoPreview(String photoData) {
    List<String> urls = [];
    try {
      final clean = photoData.trim();
      if (clean.startsWith('[') && clean.endsWith(']')) {
        final List<dynamic> decoded = jsonDecode(clean);
        urls = decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      } else if (clean.contains(',')) {
        urls = clean.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } else if (clean.isNotEmpty) {
        urls = [clean];
      }
    } catch (_) {
      if (photoData.trim().isNotEmpty) urls = [photoData.trim()];
    }

    if (urls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_library_outlined, size: 14, color: AdminStyles.primary),
            const SizedBox(width: 6),
            Text(
              'Repair Photos (${urls.length})',
              style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminStyles.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: urls.map((u) {
            return InkWell(
              onTap: () => showAttachmentZoomDialog(context, u),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminStyles.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: AppAttachmentImage(url: u, fit: BoxFit.cover),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCompactLayout() {
    final sortedAttempts = List<PostRepairReport>.from(_postRepairReports)
      ..sort((a, b) => a.attemptNumber.compareTo(b.attemptNumber));
    final int safeIdx = (_selectedAttemptIndex >= 0 && _selectedAttemptIndex < sortedAttempts.length)
        ? _selectedAttemptIndex
        : (sortedAttempts.isNotEmpty ? sortedAttempts.length - 1 : 0);
    final currentPostRepair = sortedAttempts.isNotEmpty ? sortedAttempts[safeIdx] : null;
    final isLatestAttempt = safeIdx == sortedAttempts.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (currentPostRepair != null)
          _buildPostRepairEvaluationCard(currentPostRepair, isLatest: isLatestAttempt),
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
    final sortedAttempts = List<PostRepairReport>.from(_postRepairReports)
      ..sort((a, b) => a.attemptNumber.compareTo(b.attemptNumber));
    final int safeIdx = (_selectedAttemptIndex >= 0 && _selectedAttemptIndex < sortedAttempts.length)
        ? _selectedAttemptIndex
        : (sortedAttempts.isNotEmpty ? sortedAttempts.length - 1 : 0);
    final currentPostRepair = sortedAttempts.isNotEmpty ? sortedAttempts[safeIdx] : null;
    final isLatestAttempt = safeIdx == sortedAttempts.length - 1;

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
              if (currentPostRepair != null)
                _buildPostRepairEvaluationCard(currentPostRepair, isLatest: isLatestAttempt),
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
          SizedBox(width: isNarrow ? 6 : 16),
          Tooltip(
            message: 'View Official Form',
            child: ElevatedButton(
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
          ),
          if (width >= 500) ...[
            const SizedBox(width: 12),
            _buildStatusBadge(isNarrow: isNarrow),
          ],
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
    final authUser = context.watch<AuthService>().currentUser ?? context.read<AuthService>().currentUser;
    final currentUserId = authUser?.id ?? Supabase.instance.client.auth.currentUser?.id;
    final currentUserName = authUser?.name.trim().toLowerCase();

    final isReporter = (currentUserId != null &&
            ((req.requestorId != null && req.requestorId == currentUserId) ||
             (req.reportedById != null && req.reportedById == currentUserId))) ||
        (currentUserName != null &&
            currentUserName.isNotEmpty &&
            req.requestorName.trim().toLowerCase() == currentUserName);

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

    if (req.isAcknowledged) {
      title = 'Acknowledged';
      desc = 'The Department Head has received this issue and the department will handle it internally. The centralized maintenance workflow has ended.';
      icon = Icons.assignment_turned_in_rounded;
    } else if (req.isCancelled || status == 'cancelled') {
      title = 'Cancelled';
      desc = 'This request was cancelled by the requestor.${req.cancellationReason != null ? " Reason: ${req.cancellationReason}" : ""}';
      icon = Icons.cancel_rounded;
    } else if (isCompleted) {
      title = 'Completed';
      desc = 'This maintenance request has been completed and verified. Thank you!';
      icon = Icons.task_alt_rounded;
    } else if (status == 'declined' || status == 'declined/cancelled' || isPreInspDeclined) {
      title = 'Declined';
      desc = 'This maintenance request has been declined.';
      icon = Icons.cancel_rounded;
    } else if (isRework) {
      title = 'Rework Needed';
      desc = 'The Campus Admin requested rework on the performed repairs.';
      icon = Icons.history_rounded;
    } else if (hasPostRepair && !latestPostRepair.isRequestorEvaluated) {
      title = 'Awaiting Your Review';
      desc = 'Maintenance completed the repair. Please review the work and submit your Satisfy / Not Satisfy evaluation.';
      icon = Icons.rate_review_rounded;
    } else if (hasPostRepair && !isPostRepairEvaluated) {
      title = latestPostRepair.isRequestorSatisfied
          ? 'Evaluated (Satisfied)'
          : 'Evaluated (Not Satisfied)';
      desc = 'Your evaluation has been submitted and is awaiting Campus Admin final decision.';
      icon = Icons.hourglass_top_rounded;
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
      if (req.isPendingDeptHead) {
        title = 'Awaiting Dept Head';
        if (isReporter) {
          desc = 'Your request has been received and is awaiting evaluation by your Department Head (${req.deptHeadName ?? "Department Head"}).';
        } else {
          desc = 'This request was submitted by ${req.requestorName.isNotEmpty ? req.requestorName : "a faculty member"} and is awaiting Department Head evaluation.';
        }
        icon = Icons.pending_actions_rounded;
      } else {
        title = 'Awaiting Review';
        if (isReporter) {
          desc = 'Your request has been received and is pending Campus Admin review.';
        } else {
          desc = 'This request is pending Campus Admin review.';
        }
        icon = Icons.pending_actions_rounded;
      }
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
          const SizedBox(height: 14),
          if (req.isAcknowledged) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF6366F1)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Acknowledged by Department Head. Workflow ended & record is read-only in history.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4338CA),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (req.isCancelled || status == 'cancelled') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AdminStyles.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AdminStyles.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.cancel_outlined, size: 16, color: AdminStyles.error),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Request Cancelled. Record is read-only in history.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AdminStyles.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (status == 'completed' || status == 'declined') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: (status == 'completed' ? const Color(0xFF10B981) : AdminStyles.error).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (status == 'completed' ? const Color(0xFF10B981) : AdminStyles.error).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    status == 'completed' ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                    size: 16,
                    color: status == 'completed' ? const Color(0xFF059669) : AdminStyles.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status == 'completed'
                          ? 'Work Request Completed. Record is read-only in history.'
                          : 'Work Request Declined. Record is read-only in history.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: status == 'completed' ? const Color(0xFF047857) : AdminStyles.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (!isReporter) ...[
            // View-only for non-reporters (such as Dept Head viewing details)
            const SizedBox.shrink(),
          ] else ...[
            Builder(builder: (context) {
              final isCancellable = (req.isPendingDeptHead) ||
                  (req.isDeptHeadBypassed && status == 'pending' && req.assignedToId == null && req.approvedDate == null);

              if (isCancellable) {
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.help_outline_rounded, size: 14),
                        label: Text(_followUps.isEmpty ? 'Follow Up' : 'Follow Up (${_followUps.length})', style: const TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F766E),
                          side: const BorderSide(color: Color(0xFF0F766E)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: _showFollowUpDialog,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close_rounded, size: 14),
                        label: const Text('Cancel Request', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminStyles.error,
                          side: const BorderSide(color: AdminStyles.error),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: _showCancelDialog,
                      ),
                    ),
                  ],
                );
              }

              return SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.help_outline_rounded, size: 15),
                  label: Text(_followUps.isEmpty ? 'Send Follow-Up Inquiry' : 'Follow-Up Inquiries (${_followUps.length})'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFF0F766E)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: _showFollowUpDialog,
                ),
              );
            }),
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
          const Divider(height: 32, color: Color(0xFFE2E8F0)),
          Row(
            children: [
              const Icon(Icons.image_rounded, size: 16, color: AdminStyles.textMuted),
              const SizedBox(width: 8),
              Text(
                'Attached Photos',
                style: AdminStyles.headingStyle(fontSize: 13, color: AdminStyles.textSecondary),
              ),
              if (_attachments.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AdminStyles.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_attachments.length}',
                    style: AdminStyles.bodyStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AdminStyles.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (_attachments.isNotEmpty)
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _attachments.length,
                itemBuilder: (context, index) {
                  final url = _attachments[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => showAttachmentZoomDialog(context, url),
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          color: const Color(0xFFF8FAFC),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: AppAttachmentImage(
                                url: url,
                                fit: BoxFit.cover,
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.zoom_in_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AdminStyles.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    'No photos attached to this request.',
                    style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted),
                  ),
                ],
              ),
            ),
          const Divider(height: 32, color: Color(0xFFE2E8F0)),
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF0F766E)),
              const SizedBox(width: 8),
              Text(
                'Follow-Up Inquiries',
                style: AdminStyles.headingStyle(fontSize: 13, color: AdminStyles.textSecondary),
              ),
              Builder(builder: (context) {
                final authUser = context.watch<AuthService>().currentUser ?? context.read<AuthService>().currentUser;
                final currentUserId = authUser?.id ?? Supabase.instance.client.auth.currentUser?.id;
                final currentUserName = authUser?.name.trim().toLowerCase();

                final isReporter = (currentUserId != null &&
                        ((_req.requestorId != null && _req.requestorId == currentUserId) ||
                         (_req.reportedById != null && _req.reportedById == currentUserId))) ||
                    (currentUserName != null &&
                        currentUserName.isNotEmpty &&
                        _req.requestorName.trim().toLowerCase() == currentUserName);

                if (!isReporter ||
                    _req.isAcknowledged ||
                    _req.isCancelled ||
                    _status.toLowerCase() == 'cancelled' ||
                    _status.toLowerCase() == 'completed' ||
                    _status.toLowerCase() == 'declined') {
                  return const SizedBox.shrink();
                }

                return Expanded(
                  child: Row(
                    children: [
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 14),
                        label: const Text('Inquire', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF0F766E)),
                        onPressed: _showFollowUpDialog,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 10),
          if (_followUps.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'No follow-up inquiries submitted for this request yet.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            )
          else
            ..._followUps.map((f) => _buildFollowUpItem(f)),
        ],
      ),
    );
  }

  Widget _buildFollowUpItem(WorkRequestFollowUp f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'To: ${f.targetStageLabel}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
              ),
              const Spacer(),
              Text(
                DateFormat('MMM dd, yyyy · HH:mm').format(f.createdAt),
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(f.message, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
          if (f.adminResponse != null && f.adminResponse!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCCFBF1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.reply_rounded, size: 14, color: Color(0xFF0F766E)),
                      const SizedBox(width: 6),
                      Text(
                        'Response from ${f.responderName ?? "Reviewer"}:',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(f.adminResponse!, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFollowUpDialog() {
    final messageController = TextEditingController();
    final isAwaitingDeptHead = _req.isPendingDeptHead;
    final recipientName = isAwaitingDeptHead
        ? (_req.deptHeadName ?? 'Department Head')
        : 'Campus Admin';
    String? validationError;

    showDialog(
      context: context,
      builder: (dContext) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF0F766E), size: 22),
              SizedBox(width: 10),
              Text('Send Follow-Up Inquiry', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF0F766E)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isAwaitingDeptHead
                              ? 'Your request is currently awaiting Department Head review. This follow-up will be routed to $recipientName.'
                              : 'This follow-up inquiry will be routed directly to Campus Admin.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F766E), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please provide a message explaining why you are following up on this request.*',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'e.g., May update na po ba tungkol sa reported issue? / Urgent po sana ito...',
                    hintStyle: const TextStyle(fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (_) {
                    if (validationError != null) {
                      setDState(() => validationError = null);
                    }
                  },
                ),
                if (validationError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    validationError!,
                    style: const TextStyle(color: AdminStyles.error, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final text = messageController.text.trim();
                if (text.isEmpty) {
                  setDState(() => validationError = 'Message cannot be empty or only whitespace.');
                  return;
                }

                final messenger = ScaffoldMessenger.of(context);
                final user = context.read<AuthService>().currentUser;
                Navigator.pop(dContext);
                if (user == null) return;

                final targetStage = isAwaitingDeptHead ? 'dept_head' : 'campus_admin';
                final recipientUserId = isAwaitingDeptHead ? _req.deptHeadId : null;

                final res = await WorkRequestFollowUpService.createFollowUp(
                  workRequestId: _req.id,
                  requestorId: user.id,
                  message: text,
                  targetStage: targetStage,
                  recipientUserId: recipientUserId,
                  workRequestTitle: _req.title,
                  requestorName: user.name,
                );

                if (res != null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Follow-up inquiry sent successfully.'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                  if (mounted) _loadSignatures();
                } else {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Failed to send follow-up inquiry.'),
                      backgroundColor: AdminStyles.error,
                    ),
                  );
                }
              },
              child: const Text('Send Follow Up'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog() {
    String? selectedReason;
    final otherController = TextEditingController();
    int currentStep = 0;
    String? validationError;

    final reasons = [
      'Submitted by mistake',
      'Issue has already been resolved',
      'Duplicate request',
      'Issue is no longer needed',
      'Incorrect request details',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (dContext) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                currentStep == 0 ? Icons.cancel_outlined : Icons.warning_amber_rounded,
                color: AdminStyles.error,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                currentStep == 0 ? 'Cancel Work Request' : 'Confirm Cancellation',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: currentStep == 0
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Why do you want to cancel this request?',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      ...reasons.map((r) => RadioListTile<String>(
                            title: Text(r, style: const TextStyle(fontSize: 13)),
                            value: r,
                            groupValue: selectedReason,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeColor: AdminStyles.error,
                            onChanged: (val) {
                              setDState(() {
                                selectedReason = val;
                                validationError = null;
                              });
                            },
                          )),
                      if (selectedReason == 'Other') ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Please specify your reason*',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: otherController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Enter reason for cancellation...',
                            hintStyle: const TextStyle(fontSize: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (_) {
                            if (validationError != null) {
                              setDState(() => validationError = null);
                            }
                          },
                        ),
                      ],
                      if (validationError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          validationError!,
                          style: const TextStyle(color: AdminStyles.error, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AdminStyles.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AdminStyles.error.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.info_outline, size: 18, color: AdminStyles.error),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Are you sure you want to cancel this work request? This will end the workflow and mark the request as Cancelled. This action cannot be undone.',
                                style: TextStyle(fontSize: 12, color: AdminStyles.error, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Reason: ${selectedReason == "Other" ? otherController.text.trim() : selectedReason}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
          ),
          actions: [
            if (currentStep == 0) ...[
              TextButton(
                onPressed: () => Navigator.pop(dContext),
                child: const Text('Keep Request'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminStyles.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  if (selectedReason == null) {
                    setDState(() => validationError = 'Please select a reason for cancellation.');
                    return;
                  }
                  if (selectedReason == 'Other' && otherController.text.trim().isEmpty) {
                    setDState(() => validationError = 'Please specify your reason.');
                    return;
                  }
                  setDState(() => currentStep = 1);
                },
                child: const Text('Continue'),
              ),
            ] else ...[
              TextButton(
                onPressed: () => setDState(() => currentStep = 0),
                child: const Text('Back'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dContext),
                child: const Text('Keep Request'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminStyles.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final user = context.read<AuthService>().currentUser;
                  Navigator.pop(dContext);
                  if (user == null) return;

                  try {
                    await WorkRequestService.cancelByRequestor(
                      _req.id,
                      user.id,
                      reasonType: selectedReason!,
                      reason: selectedReason == 'Other' ? otherController.text.trim() : null,
                    );
                    await LoginActivityService.recordAction(
                      user: user,
                      title: 'Cancelled Work Request',
                      details: 'Cancelled work request #${_req.formattedId} (${_req.title}). Reason: $selectedReason',
                      workRequestId: _req.id,
                    );
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Work request cancelled successfully.'),
                        backgroundColor: AdminStyles.error,
                      ),
                    );
                    if (mounted) await _loadSignatures();
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to cancel request: $e'),
                        backgroundColor: AdminStyles.error,
                      ),
                    );
                  }
                },
                child: const Text('Cancel Request'),
              ),
            ],
          ],
        ),
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
    String label = 'Requestor';
    final type = s.signatureType.trim().toLowerCase();
    if (type.contains('dept_head') || type.contains('depthead')) {
      label = 'dept_head_approval';
    } else if (type == 'approval' || type == 'admin_approval') {
      label = 'Admin Approval';
    } else if (type == 'pre_inspection') {
      label = 'Pre-Inspection';
    } else if (type == 'post_repair' || type == 'acceptance') {
      label = 'Maintenance';
    } else if (type == 'completion') {
      label = 'Requestor (Completion Confirmation)';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF0F766E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.signerName,
                  style: AdminStyles.headingStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AdminStyles.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '$label • ${DateFormat('MMM dd, yyyy · HH:mm').format(s.signedAt)}',
                  style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted),
                ),
              ],
            ),
          ),
        ],
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

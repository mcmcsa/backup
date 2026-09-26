import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/models/pre_inspection_model.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/services/pre_inspection_service.dart';
import '../../../shared/services/post_repair_service.dart';
import '../../../shared/models/work_request_follow_up_model.dart';
import '../../../shared/services/work_request_follow_up_service.dart';
import '../../../shared/services/user_service.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../web/teacher/reports/teacher_official_form_web.dart';
import '../../../shared/widgets/attachment_image_widget.dart';

import 'package:printing/printing.dart';
import '../../../shared/services/iso_pdf_service.dart';

class RequestDetailsPage extends StatefulWidget {
  final String trackingNumber;
  final String status;

  const RequestDetailsPage({
    super.key,
    required this.trackingNumber,
    required this.status,
  });

  @override
  State<RequestDetailsPage> createState() => _RequestDetailsPageState();
}

class _RequestDetailsPageState extends State<RequestDetailsPage>
    with WidgetsBindingObserver {
  WorkRequest? _request;
  List<ESignature> _signatures = [];
  Timer? _autoRefreshTimer;

  PreInspectionReport? _preInspectionReport;
  List<PostRepairReport> _postRepairReports = [];
  final Map<String, String> _userNames = {};

  RealtimeChannel? _realtimeChannel;
  String _selectedFilter = 'Timeline';
  List<String> _recoveredAttachments = [];

  String? _selectedRequestorEval;
  int? _selectedRating;
  final _requestorCommentController = TextEditingController();
  bool _isSubmittingEvaluation = false;
  int _selectedAttemptIndex = 0;
  List<WorkRequestFollowUp> _followUps = [];

  List<String> get _attachments {
    final list = <String>[];
    if (_request?.attachmentUrls != null && _request!.attachmentUrls!.isNotEmpty) {
      for (final u in _request!.attachmentUrls!) {
        final trimmed = u.trim();
        if (trimmed.isNotEmpty && !list.contains(trimmed)) {
          list.add(trimmed);
        }
      }
    }
    if (_request?.workEvidence != null && _request!.workEvidence!.trim().isNotEmpty) {
      final ev = _request!.workEvidence!.trim();
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
    WidgetsBinding.instance.addObserver(this);
    _loadRequest();
    _startAutoRefresh();
    _setupRealtime();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRequest();
    }
  }

  @override
  void dispose() {
    _requestorCommentController.dispose();
    _realtimeChannel?.unsubscribe();
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('public:mobile_request_details_${widget.trackingNumber}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'work_requests',
          callback: (_) => _loadRequest(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'e_signatures',
          callback: (_) => _loadRequest(),
        )
        .subscribe();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadRequest();
    });
  }

  Future<void> _loadRequest() async {
    try {
      final request = await WorkRequestService.fetchById(widget.trackingNumber);
      if (request == null) return;
      
      final results = await Future.wait([
        ESignatureService.fetchByWorkRequest(request.id),
        PreInspectionService.fetchLatestByWorkRequest(request.id),
        PostRepairService.fetchByWorkRequest(request.id),
        WorkRequestFollowUpService.fetchFollowUpsForRequest(request.id),
      ]);

      final signatures = (results[0] as List<ESignature>?) ?? <ESignature>[];
      final preInspection = results[1] as PreInspectionReport?;
      final postRepairs = (results[2] as List<PostRepairReport>?) ?? <PostRepairReport>[];
      final followUps = (results[3] as List<WorkRequestFollowUp>?) ?? <WorkRequestFollowUp>[];
          
      // Populate cache of user names from signatures to bypass RLS issues
      for (final sig in signatures) {
        if (sig.signerId.isNotEmpty && sig.signerName.isNotEmpty) {
          final isAdm = sig.signerRole.toLowerCase() == 'campadmin';
          _userNames[sig.signerId] = isAdm ? 'Campus Admin - ${sig.signerName}' : sig.signerName;
        }
      }

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
      if (preInspection?.adminApprovedBy != null) userIds.add(preInspection!.adminApprovedBy!);
      for (final report in postRepairs) {
        if (report.adminEvaluatedBy != null) userIds.add(report.adminEvaluatedBy!);
        if (report.requestorEvaluatedBy != null) userIds.add(report.requestorEvaluatedBy!);
        if (report.technicianId.isNotEmpty) userIds.add(report.technicianId);
      }
      final missingIds = userIds.where((id) => !_userNames.containsKey(id)).toList();
      if (missingIds.isNotEmpty) {
        UserService.fetchNamesByIds(missingIds).then((names) {
          if (names.isNotEmpty && mounted) {
            setState(() {
              _userNames.addAll(names);
            });
          }
        }).catchError((_) {});
      }

      if (mounted) {
        final sorted = List<PostRepairReport>.from(postRepairs)
          ..sort((a, b) {
            int cmp = a.repairDate.compareTo(b.repairDate);
            if (cmp != 0) return cmp;
            return a.attemptNumber.compareTo(b.attemptNumber);
          });
        final defaultAttemptIdx = sorted.isNotEmpty ? sorted.length - 1 : 0;
        setState(() {
          _request = request;
          _signatures = signatures;
          _preInspectionReport = preInspection;
          _postRepairReports = postRepairs;
          _followUps = followUps;
          if (_selectedAttemptIndex >= sorted.length) {
            _selectedAttemptIndex = defaultAttemptIdx;
          }
        });
      }
      await _markRelatedNotificationsRead();
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadFollowUps() async {
    final reqId = _request?.id ?? widget.trackingNumber;
    if (reqId.isEmpty) return;
    try {
      final list = await WorkRequestFollowUpService.fetchFollowUpsForRequest(reqId);
      if (mounted) setState(() => _followUps = list);
    } catch (_) {}
  }

  void _showFollowUpDialog() {
    final req = _request;
    if (req == null) return;
    final messageController = TextEditingController();
    final isAwaitingDeptHead = req.isPendingDeptHead;
    final recipientName = isAwaitingDeptHead
        ? (req.deptHeadName ?? 'Department Head')
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
                    style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
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

                Navigator.pop(dContext);
                final user = context.read<AuthService>().currentUser;
                if (user == null) return;

                final targetStage = isAwaitingDeptHead ? 'dept_head' : 'campus_admin';
                final recipientUserId = isAwaitingDeptHead ? req.deptHeadId : null;

                final res = await WorkRequestFollowUpService.createFollowUp(
                  workRequestId: req.id,
                  requestorId: user.id,
                  message: text,
                  targetStage: targetStage,
                  recipientUserId: recipientUserId,
                  workRequestTitle: req.title,
                  requestorName: user.name,
                );

                if (mounted) {
                  if (res != null) {
                    await LoginActivityService.recordAction(
                      user: user,
                      title: 'Sent Follow-Up Inquiry',
                      details: 'Sent follow-up on work request #${req.formattedId} (${req.title}): $text',
                      workRequestId: req.id,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Follow-up inquiry sent successfully.'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                    _loadFollowUps();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to send follow-up inquiry.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
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
    final req = _request;
    if (req == null) return;
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
                color: Colors.red,
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
                            activeColor: Colors.red,
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
                          style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
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
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.info_outline, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Are you sure you want to cancel this work request? This will end the workflow and mark the request as Cancelled. This action cannot be undone.',
                                style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
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
                  backgroundColor: Colors.red,
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
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  Navigator.pop(dContext);
                  final user = context.read<AuthService>().currentUser;
                  if (user == null) return;

                  try {
                    await WorkRequestService.cancelByRequestor(
                      req.id,
                      user.id,
                      reasonType: selectedReason!,
                      reason: selectedReason == 'Other' ? otherController.text.trim() : null,
                    );
                    await LoginActivityService.recordAction(
                      user: user,
                      title: 'Cancelled Work Request',
                      details: 'Cancelled work request #${req.formattedId} (${req.title}). Reason: $selectedReason',
                      workRequestId: req.id,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Work request cancelled successfully.'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                      _loadRequest();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Cancellation failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Confirm Cancellation'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _markRelatedNotificationsRead() async {
    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      if (user == null) return;

      await AppNotificationService.markWorkRequestAsRead(
        role: user.role.name,
        userId: user.id,
        workRequestId: widget.trackingNumber,
      );
    } catch (_) {}
  }


  void _openOfficialForm() {
    if (_request == null) return;
    showDialog(
      context: context,
      useSafeArea: true,
      barrierDismissible: true,
      builder: (context) => TeacherOfficialFormWeb(request: _request!),
    );
  }

  Color get _statusColor {
    final req = _request;
    final status = (req?.status ?? widget.status).toLowerCase();
    final isAcknowledged = req?.isAcknowledged ?? false;
    final isCancelled = req?.isCancelled ?? (status == 'cancelled');
    final isPendingDeptHead = req?.isPendingDeptHead ?? false;
    final hasPreInsp = _preInspectionReport != null;
    final isPreInspDeclined = hasPreInsp && _preInspectionReport!.status == 'Declined';
    final isPreInspApproved = hasPreInsp && _preInspectionReport!.status == 'Approved';
    final isPreInspReviewed = hasPreInsp && 
        (_preInspectionReport!.status == 'Approved' || _preInspectionReport!.status == 'Declined');
    
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
    final isRequestorEvaluated = latestPostRepair?.isRequestorEvaluated ?? false;
    final isRework = latestPostRepair?.adminEvaluation == 'rework' || status == 'rework';
    final isCompleted = status == 'completed';

    if (isCompleted) {
      return const Color(0xFF10B981);
    } else if (isAcknowledged) {
      return const Color(0xFF6366F1);
    } else if (isCancelled || status == 'cancelled') {
      return const Color(0xFFEF4444);
    } else if (isPendingDeptHead) {
      return const Color(0xFFF59E0B);
    } else if (status == 'declined' || isPreInspDeclined) {
      return const Color(0xFFEF4444);
    } else if (isRework) {
      return const Color(0xFFF59E0B);
    } else if (hasPostRepair && !isRequestorEvaluated) {
      return const Color(0xFFF59E0B);
    } else if (hasPostRepair && !isPostRepairEvaluated) {
      return const Color(0xFF0EA5E9);
    } else if (hasPostRepair) {
      return const Color(0xFF00BFA5);
    } else if (isPreInspApproved) {
      return const Color(0xFF00BFA5);
    } else if (hasPreInsp && !isPreInspReviewed) {
      return const Color(0xFFF59E0B);
    } else if (status == 'in progress' || status == 'in_progress' || status == 'assigned' || status == 'accepted by maintenance') {
      return const Color(0xFF0EA5E9);
    } else {
      return const Color(0xFF94A3B8);
    }
  }

  String get _statusLabel {
    final req = _request;
    final status = (req?.status ?? widget.status).toLowerCase();
    final isAcknowledged = req?.isAcknowledged ?? false;
    final isCancelled = req?.isCancelled ?? (status == 'cancelled');
    final isPendingDeptHead = req?.isPendingDeptHead ?? false;
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
    final isRequestorEvaluated = latestPostRepair?.isRequestorEvaluated ?? false;
    final isRework = latestPostRepair?.adminEvaluation == 'rework' || status == 'rework';
    final isCompleted = status == 'completed';

    if (isCompleted) {
      return 'COMPLETED';
    } else if (isAcknowledged) {
      return 'ACKNOWLEDGED';
    } else if (isCancelled || status == 'cancelled') {
      return 'CANCELLED';
    } else if (isPendingDeptHead) {
      return 'PENDING DEPT HEAD';
    } else if (status == 'declined' || isPreInspDeclined) {
      return 'DECLINED';
    } else if (isRework) {
      return 'REWORK NEEDED';
    } else if (hasPostRepair && !isRequestorEvaluated) {
      return 'WAITING FOR EVALUATION';
    } else if (hasPostRepair && !isPostRepairEvaluated) {
      return latestPostRepair.isRequestorSatisfied ? 'EVALUATED (SATISFIED)' : 'EVALUATED (NOT SATISFIED)';
    } else if (hasPostRepair) {
      return 'POST-REPAIR INSPECTION SUBMITTED';
    } else if (isPreInspApproved) {
      return 'CONFIRMED';
    } else if (hasPreInsp && !isPreInspReviewed) {
      return 'PRE-INSPECTION SUBMITTED';
    } else if (status == 'in progress' || status == 'in_progress' || status == 'assigned' || status == 'accepted by maintenance') {
      if (_request?.acceptedDate == null) {
        return 'APPROVED';
      } else {
        return 'ACCEPTED';
      }
    } else {
      return 'AWAITING REVIEW';
    }
  }

  Widget _buildCompactStatusCard(bool isDark, ThemeProvider themeProvider) {
    String title, desc;
    IconData icon;

    final req = _request;
    final status = (req?.status ?? widget.status).toLowerCase();
    final isAcknowledged = req?.isAcknowledged ?? false;
    final isCancelled = req?.isCancelled ?? (status == 'cancelled');
    final isPendingDeptHead = req?.isPendingDeptHead ?? false;
    final deptHeadDisplayName = (req?.deptHeadName != null && req!.deptHeadName!.trim().isNotEmpty)
        ? req.deptHeadName!.trim()
        : 'Department Head';

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
    final isRequestorEvaluated = latestPostRepair?.isRequestorEvaluated ?? false;
    final isRework = latestPostRepair?.adminEvaluation == 'rework' || status == 'rework';
    final isCompleted = status == 'completed';
    final authUser = Provider.of<AuthService>(context, listen: false).currentUser;
    final currentUserId = authUser?.id ?? Supabase.instance.client.auth.currentUser?.id;
    final currentUserName = authUser?.name.trim().toLowerCase();

    final isReporter = (currentUserId != null &&
            ((req?.requestorId != null && req!.requestorId == currentUserId) ||
             (req?.reportedById != null && req!.reportedById == currentUserId))) ||
        (currentUserName != null &&
            currentUserName.isNotEmpty &&
            req?.requestorName.trim().toLowerCase() == currentUserName);

    if (isCompleted) {
      title = 'Completed';
      desc = 'This maintenance request has been completed and verified. Thank you!';
      icon = Icons.task_alt_rounded;
    } else if (isAcknowledged) {
      title = 'Acknowledged';
      desc = 'Department Head ($deptHeadDisplayName) acknowledged the request. Handled internally by department and centralized maintenance workflow has ended.';
      icon = Icons.lock_outline_rounded;
    } else if (isCancelled) {
      title = 'Cancelled';
      desc = 'This maintenance request was cancelled by the requestor.';
      icon = Icons.cancel_rounded;
    } else if (isPendingDeptHead) {
      title = 'Pending Dept Head';
      if (isReporter) {
        desc = 'Your request is currently awaiting Department Head ($deptHeadDisplayName) approval.';
      } else {
        desc = 'This request was submitted by ${req?.requestorName.isNotEmpty == true ? req!.requestorName : "a faculty member"} and is awaiting Department Head approval.';
      }
      icon = Icons.pending_actions_rounded;
    } else if (status == 'declined' || isPreInspDeclined) {
      title = 'Declined';
      desc = 'This maintenance request has been declined.';
      icon = Icons.cancel_rounded;
    } else if (isRework) {
      title = 'Rework Needed';
      desc = 'The Campus Admin requested rework on the performed repairs.';
      icon = Icons.history_rounded;
    } else if (hasPostRepair && !isRequestorEvaluated) {
      title = 'Waiting for Evaluation';
      desc = 'Maintenance completed the repair. Please review and evaluate the work below to continue.';
      icon = Icons.rate_review_rounded;
    } else if (hasPostRepair && !isPostRepairEvaluated) {
      title = 'Awaiting Admin Decision';
      desc = 'Your evaluation (${latestPostRepair.requestorEvaluationLabel}) has been submitted. Awaiting Campus Admin final decision.';
      icon = Icons.verified_user_rounded;
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
      if (req?.acceptedDate == null) {
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

    final rawTrack = widget.trackingNumber.trim();
    final shortTrackId = rawTrack.length > 8 ? rawTrack.substring(0, 8).toUpperCase() : rawTrack.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withValues(alpha: isDark ? 0.2 : 0.08),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _statusColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? Colors.grey.shade700 : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            '#$shortTrackId',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.grey.shade200 : const Color(0xFF475569),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
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
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          if (_request?.maintenanceNotes != null && _request!.maintenanceNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF132E2B) : const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF0D9488).withValues(alpha: 0.3) : const Color(0xFFCCFBF1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.note_alt_outlined, color: Color(0xFF00BFA5), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _request!.maintenanceNotes!.trim(),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade200 : const Color(0xFF1E293B),
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
          if (isAcknowledged) ...[
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
          ] else if (isCancelled) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Request Cancelled. Record is read-only in history.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isCompleted || status == 'declined') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: (isCompleted ? const Color(0xFF10B981) : Colors.red).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (isCompleted ? const Color(0xFF10B981) : Colors.red).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                    size: 16,
                    color: isCompleted ? const Color(0xFF059669) : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCompleted
                          ? 'Work Request Completed. Record is read-only in history.'
                          : 'Work Request Declined. Record is read-only in history.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isCompleted ? const Color(0xFF047857) : Colors.red,
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
              final isCancellable = (req != null && req.isPendingDeptHead) ||
                  (req != null && req.isDeptHeadBypassed && status == 'pending' && req.assignedToId == null && req.approvedDate == null);

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
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.appBarIconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Request Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: themeProvider.appBarTextColor,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'View Official ISO Form',
            icon: Icon(Icons.assignment_rounded, color: themeProvider.appBarIconColor),
            onPressed: _openOfficialForm,
          ),
          IconButton(
            tooltip: 'Print Form',
            icon: Icon(Icons.print_rounded, color: themeProvider.appBarIconColor),
            onPressed: () async {
              if (_request != null) {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final pdfBytes = await IsoPdfService.generateWorkRequestPdf(_request!);
                  await Printing.layoutPdf(
                    onLayout: (_) => pdfBytes,
                    name: 'Work_Request_Form_${_request!.formattedId}',
                    format: IsoPdfService.standardPortraitFormat,
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to generate PDF: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.share, color: themeProvider.appBarIconColor),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card (Web compact parity with 8-char tracking ID)
            _buildCompactStatusCard(isDark, themeProvider),
            const SizedBox(height: 16),
            // Requestor Post-Repair Evaluation Card
            _buildRequestorEvaluationCard(isDark, themeProvider),
            // Segmented Filter Tabs
            _buildFilterButtons(isDark, themeProvider),
            const SizedBox(height: 16),
            // Active Tab Content
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(_selectedFilter),
                child: _selectedFilter == 'Timeline'
                    ? _buildTimelineSection(isDark, themeProvider)
                    : (_selectedFilter == 'Details'
                        ? _buildDetailsSection(isDark, themeProvider)
                        : _buildSignaturesCard(isDark, themeProvider)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButtons(bool isDark, ThemeProvider themeProvider) {
    final filters = [
      {'label': 'Timeline', 'icon': Icons.timeline_rounded},
      {'label': 'Details', 'icon': Icons.description_outlined},
      {'label': 'Signature', 'icon': Icons.draw_outlined},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeProvider.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: filters.map((f) {
          final label = f['label'] as String;
          final icon = f['icon'] as IconData;
          final isSelected = _selectedFilter == label;

          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (_selectedFilter != label) {
                    setState(() => _selectedFilter = label);
                  }
                },
                borderRadius: BorderRadius.circular(9),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF00BFA5) : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00BFA5).withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                        ),
                      ),
                      if (label == 'Signature' && _requestorSignatures.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : const Color(0xFF00BFA5).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_requestorSignatures.length}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : const Color(0xFF00BFA5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineSection(bool isDark, ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Workflow Timeline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: themeProvider.textColor,
              ),
            ),
            TextButton.icon(
              onPressed: _openOfficialForm,
              icon: const Icon(
                Icons.description,
                size: 16,
                color: Color(0xFF00BFA5),
              ),
              label: const Text(
                'View Official Form',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00BFA5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildWorkflowTimeline(isDark, themeProvider),
      ],
    );
  }

  Widget _buildDetailsSection(bool isDark, ThemeProvider themeProvider) {
    final req = _request;
    if (req == null) return const SizedBox.shrink();

    final isPendingReview = req.status.toLowerCase() == 'pending';
    final priorityDisplay = isPendingReview ? '--' : req.priorityLabel;
    final priorityLower = req.priority.toLowerCase();
    final priorityColor = isPendingReview
        ? const Color(0xFF94A3B8)
        : priorityLower == 'high'
            ? const Color(0xFFEF4444)
            : priorityLower == 'medium'
                ? const Color(0xFFF59E0B)
                : priorityLower == 'low'
                    ? const Color(0xFF10B981)
                    : const Color(0xFF94A3B8);

    final photos = _attachments;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeProvider.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0369A1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_rounded, color: Color(0xFF0369A1), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Request Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailChip(
            icon: Icons.location_on_rounded,
            label: 'Location',
            value: '${req.buildingName ?? 'N/A'} — ${req.roomName ?? 'N/A'}',
            color: const Color(0xFF0F766E),
            themeProvider: themeProvider,
          ),
          _buildDetailChip(
            icon: Icons.flag_rounded,
            label: 'Priority',
            value: priorityDisplay,
            color: priorityColor,
            themeProvider: themeProvider,
          ),
          _buildDetailChip(
            icon: Icons.calendar_today_rounded,
            label: 'Submitted',
            value: DateFormat('MMM dd, yyyy • hh:mm a').format(req.dateSubmitted),
            color: const Color(0xFF475569),
            themeProvider: themeProvider,
          ),
          if (req.requestorName.isNotEmpty || req.displayRequestorName.isNotEmpty)
            _buildDetailChip(
              icon: Icons.person_rounded,
              label: 'Requested by',
              value: req.requestorName.isNotEmpty ? req.requestorName : req.displayRequestorName,
              color: const Color(0xFF134E4A),
              themeProvider: themeProvider,
            ),
          Divider(height: 28, color: themeProvider.borderColor),
          Row(
            children: [
              Icon(Icons.description_rounded, size: 16, color: themeProvider.subtitleColor),
              const SizedBox(width: 8),
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeProvider.borderColor),
            ),
            child: Text(
              req.description.isNotEmpty ? req.description : 'No description provided.',
              style: TextStyle(
                fontSize: 13,
                color: themeProvider.textColor,
                height: 1.5,
              ),
            ),
          ),
          Divider(height: 28, color: themeProvider.borderColor),
          Row(
            children: [
              Icon(Icons.image_rounded, size: 16, color: themeProvider.subtitleColor),
              const SizedBox(width: 8),
              Text(
                'Attached Photos',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                ),
              ),
              if (photos.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${photos.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (photos.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final url = photos[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => showAttachmentZoomDialog(context, url),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: themeProvider.borderColor),
                          color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF8FAFC),
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
                color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: themeProvider.borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: themeProvider.subtitleColor),
                  const SizedBox(width: 8),
                  Text(
                    'No photos attached to this request.',
                    style: TextStyle(fontSize: 12, color: themeProvider.subtitleColor),
                  ),
                ],
              ),
            ),
          Divider(height: 28, color: themeProvider.borderColor),
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF0F766E)),
              const SizedBox(width: 8),
              Text(
                'Follow-Up Inquiries',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                ),
              ),
              if (!req.isAcknowledged &&
                  !req.isCancelled &&
                  req.status.toLowerCase() != 'cancelled' &&
                  req.status.toLowerCase() != 'completed' &&
                  req.status.toLowerCase() != 'declined') ...[
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text('Inquire', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF0F766E)),
                  onPressed: _showFollowUpDialog,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (_followUps.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: themeProvider.borderColor),
              ),
              child: Text(
                'No follow-up inquiries submitted for this request yet.',
                style: TextStyle(fontSize: 12, color: themeProvider.subtitleColor),
              ),
            )
          else
            ..._followUps.map((f) => _buildFollowUpItem(f, isDark, themeProvider)),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _openOfficialForm,
              icon: const Icon(Icons.assignment_rounded, size: 16, color: Color(0xFF00BFA5)),
              label: const Text(
                'View Digital Form',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00BFA5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpItem(WorkRequestFollowUp f, bool isDark, ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeProvider.borderColor),
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
                style: TextStyle(fontSize: 11, color: themeProvider.subtitleColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(f.message, style: TextStyle(fontSize: 13, color: themeProvider.textColor)),
          if (f.adminResponse != null && f.adminResponse!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF132E2B) : const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF0D9488).withValues(alpha: 0.3) : const Color(0xFFCCFBF1),
                ),
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
                  Text(f.adminResponse!, style: TextStyle(fontSize: 12, color: themeProvider.textColor)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeProvider themeProvider,
  }) {
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
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: themeProvider.subtitleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_TimelineStep> get _steps {
    final steps = <_TimelineStep>[];
    final task = _request;
    if (task == null) return steps;

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
      color: const Color(0xFF0F766E),
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
          color: const Color(0xFFEF4444),
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
        color: isDeptHeadDeclined ? const Color(0xFFEF4444) : (isDeptHeadApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
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
        color: const Color(0xFFEF4444),
      ));
      return steps;
    }

    // 2. Campus Admin Review & Approval
    final isApproved = ['assigned', 'confirmed', 'rework', 'completed', 'in progress', 'in_progress', 'declined']
        .contains(task.status.toLowerCase());
    final isDeclinedInitially = task.status.toLowerCase() == 'declined' && task.preInspectionId == null;
    final campusAdminName = (task.approvedByName != null && task.approvedByName!.trim().isNotEmpty)
        ? task.approvedByName!.trim()
        : 'Campus Admin';
    final isAdminStepActive = !isApproved && !task.isPendingDeptHead && (task.isPendingCampusAdmin || task.isDeptHeadApproved);
    steps.add(_TimelineStep(
      icon: Icons.admin_panel_settings_rounded,
      title: isDeclinedInitially ? 'Request Declined by Campus Admin' : 'Campus Admin Review & Approval',
      desc: isDeclinedInitially
          ? 'Request was declined by Campus Admin.'
          : (isApproved
              ? (task.approvedByName != null && task.approvedByName!.trim().isNotEmpty
                  ? 'Request approved by Campus Admin ($campusAdminName).'
                  : 'Request approved by Campus Admin.')
              : (task.isPendingDeptHead
                  ? 'Awaiting Department Head approval first.'
                  : 'Waiting for Campus Admin approval.')),
      date: task.approvedDate,
      isCompleted: isApproved,
      color: isDeclinedInitially ? const Color(0xFFEF4444) : const Color(0xFF0369A1),
      isActive: isAdminStepActive,
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
      color: const Color(0xFF0EA5E9),
    ));

    // 4. Pre-Inspection Conducted
    final hasPreInsp = _preInspectionReport != null;
    steps.add(_TimelineStep(
      icon: Icons.search_rounded,
      title: 'Pre-Inspection Conducted',
      desc: hasPreInsp
          ? 'Pre-inspection completed by ${_preInspectionReport!.inspectorName}.'
          : 'Awaiting pre-inspection.',
      date: _preInspectionReport?.inspectionDate,
      isCompleted: hasPreInsp,
      color: const Color(0xFF0F766E),
    ));

    // 5. Pre-Inspection Review by Campus Admin
    final isPreInspReviewed = hasPreInsp &&
        (_preInspectionReport!.status == 'Approved' || _preInspectionReport!.status == 'Declined');
    final isPreInspApproved = hasPreInsp && _preInspectionReport!.status == 'Approved';
    final isPreInspDeclined = hasPreInsp && _preInspectionReport!.status == 'Declined';
    final approvedByName = _preInspectionReport?.adminApprovedBy != null
        ? (_userNames[_preInspectionReport!.adminApprovedBy] ?? _preInspectionReport!.adminApprovedBy)
        : "Campus Admin";

    steps.add(_TimelineStep(
      icon: isPreInspDeclined
          ? Icons.cancel_rounded
          : (isPreInspApproved ? Icons.verified_rounded : Icons.pending_actions_rounded),
      title: isPreInspDeclined
          ? 'Pre-Inspection Declined'
          : (isPreInspApproved ? 'Pre-Inspection Approved' : 'Pre-Inspection Review'),
      desc: isPreInspReviewed
          ? '${_preInspectionReport!.status} by $approvedByName'
          : (hasPreInsp ? 'Awaiting Campus Admin pre-inspection review.' : 'Pending pre-inspection submission.'),
      date: _preInspectionReport?.adminApprovedDate,
      isCompleted: isPreInspApproved,
      color: isPreInspDeclined ? const Color(0xFFEF4444) : const Color(0xFF10B981),
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
          color: const Color(0xFF0F766E),
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
                ? (report.isRequestorSatisfied ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                : const Color(0xFFF59E0B),
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
            color: isRework ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
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
          color: const Color(0xFFF59E0B),
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
        color: isPreInspApproved ? const Color(0xFF0F766E) : Colors.grey,
      ));

      steps.add(const _TimelineStep(
        icon: Icons.rate_review_rounded,
        title: 'Requestor Evaluation',
        desc: 'Pending post-repair report submission.',
        isCompleted: false,
        color: Colors.grey,
      ));

      steps.add(const _TimelineStep(
        icon: Icons.verified_rounded,
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
      color: isCompleted ? const Color(0xFF10B981) : Colors.grey,
      isLast: true,
    ));

    return steps;
  }

  Widget _buildTimelineItem(_TimelineStep step, bool isDark, ThemeProvider themeProvider) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circle & Line
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Circle
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (step.isCompleted || step.customBadge != null)
                        ? step.color.withValues(alpha: 0.12)
                        : (isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF1F5F9)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (step.isCompleted || step.customBadge != null)
                          ? step.color
                          : (isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0)),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    (step.isCompleted || step.customBadge != null)
                        ? step.icon
                        : Icons.radio_button_unchecked_rounded,
                    color: (step.isCompleted || step.customBadge != null)
                        ? step.color
                        : (isDark ? Colors.grey.shade600 : const Color(0xFFCBD5E1)),
                    size: 18,
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
                        color: step.isCompleted ? null : (isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: step.isLast ? 0 : 26, top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 14,
                            color: step.isCompleted
                                ? themeProvider.textColor
                                : (isDark ? Colors.grey.shade400 : const Color(0xFF94A3B8)),
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
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: step.color,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade300
                          : (step.isCompleted ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                      height: 1.4,
                    ),
                  ),
                  if (step.date != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 13, color: step.color.withValues(alpha: 0.7)),
                        const SizedBox(width: 5),
                        Text(
                          DateFormat('MMM dd, yyyy • hh:mm a').format(step.date!),
                          style: TextStyle(
                            fontSize: 11,
                            color: step.color.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
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

  Widget _buildWorkflowTimeline(bool isDark, ThemeProvider themeProvider) {
    final steps = _steps;
    if (steps.isEmpty) return const SizedBox.shrink();

    return Column(
      children: steps.map((s) => _buildTimelineItem(s, isDark, themeProvider)).toList(),
    );
  }

  bool _isRequestorSignature(ESignature s) {
    final role = s.signerRole.trim().toLowerCase();
    final type = s.signatureType.trim().toLowerCase();

    if (type == 'requestor' || type == 'teacher') {
      return true;
    }

    final signerName = s.signerName.trim().toLowerCase();
    final reqName = (_request?.requestorName ?? '').trim().toLowerCase();
    final dispName = (_request?.displayRequestorName ?? '').trim().toLowerCase();
    final reportedName = (_request?.reportedByName ?? '').trim().toLowerCase();
    
    if (signerName.isNotEmpty) {
      if (reqName.isNotEmpty && signerName == reqName) return true;
      if (dispName.isNotEmpty && signerName == dispName) return true;
      if (reportedName.isNotEmpty && signerName == reportedName) return true;
    }

    if (role == 'teacher' || role == 'requestor') {
      return true;
    }

    return false;
  }

  List<ESignature> get _requestorSignatures {
    return _signatures.where(_isRequestorSignature).toList();
  }

  Widget _buildSignaturesCard(bool isDark, ThemeProvider themeProvider) {
    final sigs = _requestorSignatures;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeProvider.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Requestor Signature',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sigs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: themeProvider.borderColor),
              ),
              child: Column(
                children: [
                  Icon(Icons.draw_rounded, size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No Requestor Signature Recorded',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your signature as the requestor will appear here once attached to this work request.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: themeProvider.subtitleColor,
                    ),
                  ),
                ],
              ),
            )
          else
            ...sigs.map((s) => _buildSignatureItem(s, isDark, themeProvider)),
        ],
      ),
    );
  }

  Widget _buildSignatureItem(ESignature s, bool isDark, ThemeProvider themeProvider) {
    final initials = s.signerName.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF059669).withValues(alpha: isDark ? 0.12 : 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF059669).withValues(alpha: isDark ? 0.3 : 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials.isNotEmpty ? initials : 'RQ',
                  style: const TextStyle(
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.signerName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    () {
                      final type = s.signatureType.trim().toLowerCase();
                      if (type == 'completion') {
                        return 'Requestor (Completion Confirmation)';
                      }
                      return 'Requestor (Submission)';
                    }(),
                    style: TextStyle(
                      fontSize: 11,
                      color: themeProvider.subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 18),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd').format(s.signedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: themeProvider.subtitleColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitEvaluation(PostRepairReport report) async {
    if (_selectedRequestorEval == null) return;
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null || _request == null) return;

    if (_request!.requestorId != user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unauthorized: Only the original requestor can submit this evaluation.'),
          backgroundColor: Colors.red,
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
        comment: _requestorCommentController.text.trim().isEmpty
            ? null
            : _requestorCommentController.text.trim(),
      );

      await AppNotificationService.notifyRequestorEvaluationSubmittedToAdmin(
        workRequestId: _request!.id,
        requestorName: user.name,
        requestorUserId: user.id,
        evaluation: _selectedRequestorEval!,
        rating: _selectedRating,
        comment: _requestorCommentController.text.trim().isEmpty
            ? null
            : _requestorCommentController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedRequestorEval == 'satisfy'
                  ? 'Evaluation submitted: Satisfied. Campus Admin will make the final decision.'
                  : 'Evaluation submitted: Not Satisfied. Campus Admin will review your feedback.',
            ),
            backgroundColor: _selectedRequestorEval == 'satisfy' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          ),
        );
      }
      await _loadRequest();
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('requestor_comment') || errorMsg.contains('PGRST204')) {
          errorMsg = 'Database schema update needed: please run the post-repair SQL migration in Supabase SQL Editor.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingEvaluation = false);
      }
    }
  }

  Widget _buildRequestorEvaluationCard(bool isDark, ThemeProvider themeProvider) {
    if (_postRepairReports.isEmpty) return const SizedBox.shrink();

    final sortedAttempts = List<PostRepairReport>.from(_postRepairReports)
      ..sort((a, b) {
        int cmp = a.repairDate.compareTo(b.repairDate);
        if (cmp != 0) return cmp;
        return a.attemptNumber.compareTo(b.attemptNumber);
      });

    if (_selectedAttemptIndex >= sortedAttempts.length) {
      _selectedAttemptIndex = sortedAttempts.length - 1;
    }
    final report = sortedAttempts[_selectedAttemptIndex];
    final isLatest = _selectedAttemptIndex == sortedAttempts.length - 1;
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final isOriginalRequestor = user != null && _request != null && _request!.requestorId == user.id;

    // Photos extraction
    List<String> evidenceUrls = [];
    if (report.photoAfter != null && report.photoAfter!.trim().isNotEmpty) {
      final clean = report.photoAfter!.trim();
      if (clean.startsWith('[') && clean.endsWith(']')) {
        try {
          final List<dynamic> decoded = jsonDecode(clean);
          evidenceUrls = decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        } catch (_) {
          evidenceUrls = [clean];
        }
      } else {
        evidenceUrls = [clean];
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: report.isRequestorEvaluated
              ? (report.isRequestorSatisfied ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFF59E0B).withValues(alpha: 0.4))
              : const Color(0xFF00BFA5).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Attempt Selector Tabs if multiple attempts exist
          if (sortedAttempts.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(sortedAttempts.length, (idx) {
                  final isSelected = _selectedAttemptIndex == idx;
                  final att = sortedAttempts[idx];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        'Attempt #${att.attemptNumber}${idx == sortedAttempts.length - 1 ? " (Latest)" : ""}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : themeProvider.textColor,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF00BFA5),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedAttemptIndex = idx;
                            if (att.isRequestorEvaluated) {
                              _selectedRequestorEval = att.requestorEvaluation;
                              _selectedRating = att.requestorRating;
                              _requestorCommentController.text = att.requestorComment ?? '';
                            } else {
                              _selectedRequestorEval = null;
                              _selectedRating = null;
                              _requestorCommentController.clear();
                            }
                          });
                        }
                      },
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Card Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.rate_review_rounded, color: Color(0xFF00BFA5), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maintenance Work Evaluation',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                    ),
                    Text(
                      report.isRequestorEvaluated
                          ? 'Evaluation record for Attempt #${report.attemptNumber}'
                          : 'Please review the completed repair work.',
                      style: TextStyle(fontSize: 12, color: themeProvider.subtitleColor),
                    ),
                  ],
                ),
              ),
              if (report.isRequestorEvaluated)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: report.isRequestorSatisfied
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: report.isRequestorSatisfied ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                  ),
                  child: Text(
                    report.requestorEvaluationLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: report.isRequestorSatisfied ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Post-Repair Details Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: themeProvider.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEvalDetailRow('Assigned Technician', report.technicianName, themeProvider),
                _buildEvalDetailRow('Repair Date', DateFormat('MMM dd, yyyy • hh:mm a').format(report.repairDate), themeProvider),
                if (report.repairDuration != null)
                  _buildEvalDetailRow('Duration', report.repairDuration!, themeProvider),
                _buildEvalDetailRow('Work Performed', report.workPerformed, themeProvider),
                if (report.materialsUsed != null && report.materialsUsed!.isNotEmpty)
                  _buildEvalDetailRow('Materials Used', report.materialsUsed!, themeProvider),
                if (report.technicianNotes != null && report.technicianNotes!.isNotEmpty)
                  _buildEvalDetailRow('Technician Notes', report.technicianNotes!, themeProvider),
                if (evidenceUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Work Evidence (${evidenceUrls.length})',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: themeProvider.subtitleColor),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: evidenceUrls.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final url = evidenceUrls[idx];
                        return InkWell(
                          onTap: () => showAttachmentZoomDialog(context, url),
                          borderRadius: BorderRadius.circular(8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 70,
                              height: 70,
                              child: AppAttachmentImage(url: url, fit: BoxFit.cover),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Evaluation View: If already evaluated
          if (report.isRequestorEvaluated) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: report.isRequestorSatisfied
                    ? const Color(0xFF10B981).withValues(alpha: 0.08)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: report.isRequestorSatisfied
                      ? const Color(0xFF10B981).withValues(alpha: 0.3)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        report.isRequestorSatisfied ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                        size: 16,
                        color: report.isRequestorSatisfied ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Your Decision: ${report.requestorEvaluationLabel}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: report.isRequestorSatisfied ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                  if (report.requestorRating != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Rating: ', style: TextStyle(fontSize: 12, color: themeProvider.subtitleColor)),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < report.requestorRating! ? Icons.star_rounded : Icons.star_border_rounded,
                              size: 16,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${report.requestorRating}/5',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeProvider.textColor),
                        ),
                      ],
                    ),
                  ],
                  if (report.requestorComment != null && report.requestorComment!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '"${report.requestorComment!}"',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: themeProvider.textColor),
                    ),
                  ],
                  if (report.requestorEvaluatedDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Evaluated on ${DateFormat('MMM dd, yyyy • hh:mm a').format(report.requestorEvaluatedDate!)}',
                      style: TextStyle(fontSize: 11, color: themeProvider.subtitleColor),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Campus Admin final decision status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: themeProvider.borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    report.adminEvaluation == 'satisfied'
                        ? Icons.check_circle_rounded
                        : (report.adminEvaluation == 'rework' ? Icons.history_rounded : Icons.hourglass_empty_rounded),
                    size: 18,
                    color: report.adminEvaluation == 'satisfied'
                        ? const Color(0xFF10B981)
                        : (report.adminEvaluation == 'rework' ? const Color(0xFFDC2626) : const Color(0xFF0EA5E9)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      report.adminEvaluation == 'satisfied'
                          ? 'Campus Admin final decision: WORK COMPLETED.'
                          : (report.adminEvaluation == 'rework'
                              ? 'Campus Admin final decision: REWORK (${report.adminEvaluationNotes ?? "Corrective work required"}).'
                              : 'Waiting for Campus Admin final decision (Work Completed or Rework).'),
                      style: TextStyle(fontSize: 12, color: themeProvider.textColor),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isLatest && isOriginalRequestor) ...[
            // Evaluation Form: If not yet evaluated
            Text(
              'How was the completed maintenance work? *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: themeProvider.textColor,
              ),
            ),
            const SizedBox(height: 10),

            // Choice 1: SATISFY or NOT SATISFY
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedRequestorEval = 'satisfy'),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _selectedRequestorEval == 'satisfy'
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedRequestorEval == 'satisfy' ? const Color(0xFF10B981) : themeProvider.borderColor,
                          width: _selectedRequestorEval == 'satisfy' ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.thumb_up_rounded,
                            color: _selectedRequestorEval == 'satisfy' ? const Color(0xFF10B981) : Colors.grey,
                            size: 24,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Satisfy',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _selectedRequestorEval == 'satisfy' ? const Color(0xFF10B981) : themeProvider.textColor,
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
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _selectedRequestorEval == 'not_satisfy'
                            ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedRequestorEval == 'not_satisfy' ? const Color(0xFFEF4444) : themeProvider.borderColor,
                          width: _selectedRequestorEval == 'not_satisfy' ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.thumb_down_rounded,
                            color: _selectedRequestorEval == 'not_satisfy' ? const Color(0xFFEF4444) : Colors.grey,
                            size: 24,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Not Satisfy',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _selectedRequestorEval == 'not_satisfy' ? const Color(0xFFEF4444) : themeProvider.textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Optional Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rating (Optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: themeProvider.subtitleColor),
                ),
                if (_selectedRating != null)
                  InkWell(
                    onTap: () => setState(() => _selectedRating = null),
                    child: const Text('Clear', style: TextStyle(fontSize: 11, color: Colors.blue)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(5, (index) {
                final ratingVal = index + 1;
                final isFilled = _selectedRating != null && ratingVal <= _selectedRating!;
                return IconButton(
                  onPressed: () => setState(() => _selectedRating = ratingVal),
                  icon: Icon(
                    isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isFilled ? Colors.amber : Colors.grey.shade400,
                    size: 28,
                  ),
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                );
              }),
            ),
            const SizedBox(height: 12),

            // Optional Comments
            Text(
              'Additional Comments (Optional)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: themeProvider.subtitleColor),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _requestorCommentController,
              maxLines: 3,
              style: TextStyle(fontSize: 13, color: themeProvider.textColor),
              decoration: InputDecoration(
                hintText: 'Share any feedback or notes about the repair...',
                hintStyle: TextStyle(fontSize: 12, color: themeProvider.subtitleColor),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: themeProvider.borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: themeProvider.borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF00BFA5))),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: (_selectedRequestorEval == null || _isSubmittingEvaluation)
                    ? null
                    : () => _submitEvaluation(report),
                icon: _isSubmittingEvaluation
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isSubmittingEvaluation ? 'Submitting...' : 'Submit Evaluation',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ] else ...[
            // When not the original requestor
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Waiting for evaluation by the original requestor (${_request?.requestorName ?? "Requestor"}).',
                      style: TextStyle(fontSize: 12, color: themeProvider.textColor),
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

  Widget _buildEvalDetailRow(String label, String value, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: themeProvider.subtitleColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: themeProvider.textColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStep {
  final IconData icon;
  final String title;
  final String desc;
  final DateTime? date;
  final bool isCompleted;
  final bool isLast;
  final Color color;
  final String? customBadge;
  final bool isActive;

  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.desc,
    this.date,
    required this.isCompleted,
    this.isLast = false,
    required this.color,
    this.customBadge,
    this.isActive = false,
  });
}

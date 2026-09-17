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
import '../../../shared/services/user_service.dart';
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
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _loadRequest();
    });
  }

  Future<void> _loadRequest() async {
    try {
      final request = await WorkRequestService.fetchById(widget.trackingNumber);
      final signatures = request != null
          ? await ESignatureService.fetchByWorkRequest(request.id)
          : <ESignature>[];
          
      // Populate cache of user names from signatures to bypass RLS issues
      for (final sig in signatures) {
        if (sig.signerId.isNotEmpty && sig.signerName.isNotEmpty) {
          final isAdm = sig.signerRole.toLowerCase() == 'campadmin';
          _userNames[sig.signerId] = isAdm ? 'Campus Admin - ${sig.signerName}' : sig.signerName;
        }
      }

      final preInspection = request != null
          ? await PreInspectionService.fetchLatestByWorkRequest(request.id)
          : null;
      final postRepairs = request != null
          ? await PostRepairService.fetchByWorkRequest(request.id)
          : <PostRepairReport>[];

      List<String> recoveredAttachments = _recoveredAttachments;
      if (request != null &&
          (request.attachmentUrls == null || request.attachmentUrls!.isEmpty) &&
          (request.workEvidence == null || request.workEvidence!.trim().isEmpty)) {
        final found = await _recoverStorageAttachments(request.id);
        if (found.isNotEmpty) {
          recoveredAttachments = found;
        }
      }

      final userIds = <String>{};
      if (preInspection?.adminApprovedBy != null) userIds.add(preInspection!.adminApprovedBy!);
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
          _request = request;
          _signatures = signatures;
          _preInspectionReport = preInspection;
          _postRepairReports = postRepairs;
          _recoveredAttachments = recoveredAttachments;
        });
      }
      await _markRelatedNotificationsRead();
    } catch (_) {
      if (mounted) setState(() {});
    }
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
    final status = (_request?.status ?? widget.status).toLowerCase();
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
    final isRework = latestPostRepair?.adminEvaluation == 'rework' || status == 'rework';
    final isCompleted = status == 'completed';

    if (isCompleted) {
      return const Color(0xFF10B981);
    } else if (status == 'declined' || status == 'cancelled' || status == 'declined/cancelled' || isPreInspDeclined) {
      return const Color(0xFFEF4444);
    } else if (isRework) {
      return const Color(0xFFF59E0B);
    } else if (hasPostRepair && !isPostRepairEvaluated) {
      return const Color(0xFF00BFA5);
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
    final status = (_request?.status ?? widget.status).toLowerCase();
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
    final status = (_request?.status ?? widget.status).toLowerCase();
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

    // 2. Campus Admin Review & Approval
    final isApproved = ['assigned', 'confirmed', 'rework', 'completed', 'in progress', 'in_progress', 'declined']
        .contains(task.status.toLowerCase());
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
      color: isDeclinedInitially ? const Color(0xFFEF4444) : const Color(0xFF0369A1),
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

        final isEvaluated = report.adminEvaluation != null;
        final isRework = report.adminEvaluation == 'rework';
        final evaluatedByName = report.adminEvaluatedBy != null
            ? (_userNames[report.adminEvaluatedBy] ?? report.adminEvaluatedBy)
            : "Campus Admin";

        final isLatestReport = i == sortedAttempts.length - 1;
        if (isEvaluated || isLatestReport) {
          steps.add(_TimelineStep(
            icon: isRework ? Icons.refresh_rounded : Icons.check_circle_rounded,
            title: isRework ? 'Post-Repair Evaluation - Rework Required' : 'Post-Repair Evaluation',
            desc: isEvaluated
                ? (isRework ? 'Rework required by $evaluatedByName' : 'Approved by $evaluatedByName')
                : 'Awaiting evaluation.',
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
        title: 'Post-Repair Evaluation',
        desc: 'Pending post-repair report submission.',
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
    Uint8List? signatureBytes;
    if (s.signatureData.isNotEmpty) {
      try {
        final cleanBase64 = s.signatureData.contains(',')
            ? s.signatureData.split(',').last
            : s.signatureData;
        signatureBytes = base64Decode(cleanBase64.trim());
      } catch (_) {}
    }

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
                  if (signatureBytes != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 55,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
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

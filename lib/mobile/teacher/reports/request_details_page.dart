import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Request Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded, color: Colors.black87),
            onPressed: () async {
              if (_request != null) {
                try {
                  final pdfBytes = await IsoPdfService.generateWorkRequestPdf(_request!);
                  await Printing.layoutPdf(
                    onLayout: (_) => pdfBytes,
                    name: 'Work_Request_Form_${_request!.formattedId}',
                    format: IsoPdfService.longLandscapeFormat,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to generate PDF: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BFA5).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          (_request?.status ?? widget.status).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Icon(Icons.menu, color: Colors.white, size: 20),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'TRACKING NUMBER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.trackingNumber,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Location and Category Row
            Row(
              children: [
                Expanded(
                  child: _buildInfoBox(
                    icon: Icons.place_outlined,
                    label: 'LOCATION',
                    value1: _request?.officeRoom ?? 'N/A',
                    value2: _request?.buildingName ?? 'N/A',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoBox(
                    icon: Icons.flag_outlined,
                    label: 'PRIORITY',
                    value1: _request?.priority.isNotEmpty == true ? _request!.priority : 'Normal',
                    value2: 'Pending Review',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Problem Description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 18,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Problem Description',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _request?.description ?? 'No description provided.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Assigned Users
                  Row(
                    children: [
                      _buildAvatar('assets/images/avatar1.png'),
                      Transform.translate(
                        offset: const Offset(-8, 0),
                        child: _buildAvatar('assets/images/avatar2.png'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // View Digital Form Link
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  if (_request != null) {
                    try {
                      final pdfBytes = await IsoPdfService.generateWorkRequestPdf(_request!);
                      await Printing.layoutPdf(
                        onLayout: (_) => pdfBytes,
                        name: 'Work_Request_Form_${_request!.formattedId}',
                        format: IsoPdfService.longLandscapeFormat,
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to generate PDF: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(
                  Icons.description,
                  size: 18,
                  color: Color(0xFF4169E1),
                ),
                label: const Text(
                  'View Digital Form',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4169E1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Workflow Timeline
            const Text(
              'Workflow Timeline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            _buildWorkflowTimeline(),
            const SizedBox(height: 24),
            // Maintenance Office Contact Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.headset_mic,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Maintenance Office',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'For corrections, assistance or safety concerns',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.phone, size: 18),
                          label: const Text(
                            'Call: 8422',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF00BFA5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.email, size: 18),
                          label: const Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF00BFA5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String label,
    required String value1,
    required String value2,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF00BFA5)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value1,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value2,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String imagePath) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipOval(
        child: Icon(Icons.person, size: 18, color: Colors.grey.shade600),
      ),
    );
  }

  bool _isUnassigned(String? staffId) {
    final normalized = staffId?.trim().toLowerCase();
    return normalized == null || normalized.isEmpty || normalized == 'null';
  }

  String _assignedMaintenanceName(String? staffId) {
    if (_isUnassigned(staffId)) return 'Unassigned';
    return _request?.acceptedByName ?? 'Assigned Staff';
  }

  Widget _buildWorkflowTimelineItem({
    required String title,
    required bool isDone,
    bool isRework = false,
    String? subtitle,
    Widget? details,
    ESignature? signature,
    bool isLast = false,
  }) {
    final circleColor = isRework
        ? const Color(0xFFD97706)
        : (isDone ? const Color(0xFF059669) : Colors.grey.shade300);
    final iconData = isRework
        ? Icons.refresh_rounded
        : (isDone ? Icons.check : Icons.circle);
    final iconSize = (isRework || isDone) ? 14.0 : 8.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                size: iconSize,
                color: Colors.white,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 48,
                color: circleColor,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isRework
                      ? const Color(0xFFD97706)
                      : (isDone ? const Color(0xFF111827) : Colors.grey.shade600),
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
              if (details != null) ...[
                const SizedBox(height: 6),
                details,
              ],
              if (signature != null && signature.signatureData.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildWorkflowTimelineSignatureImage(signature.signatureData),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkflowTimelineSignatureImage(String base64Str) {
    try {
      final cleaned = base64Str.trim().replaceAll(RegExp(r'\s+'), '');
      final base64Data = cleaned.contains(',') ? cleaned.split(',')[1] : cleaned;
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Image.memory(
          base64Decode(base64Data),
          height: 35,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.gesture, size: 25, color: Colors.grey),
        ),
      );
    } catch (_) {
      return const Icon(Icons.gesture, size: 25, color: Colors.grey);
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildWorkflowTimeline() {
    final request = _request;
    if (request == null) return const SizedBox.shrink();

    final List<Widget> items = [];

    // 1. Submission
    final reqSig = _signatures.firstWhere(
      (s) => s.signatureType == 'requestor',
      orElse: () => ESignature(
        id: '',
        workRequestId: '',
        signerId: '',
        signerName: '',
        signerRole: '',
        signatureType: '',
        signatureData: '',
        signedAt: DateTime.now(),
      ),
    );
    items.add(
      _buildWorkflowTimelineItem(
        title: 'Work Request Submitted',
        isDone: true,
        subtitle: 'By ${request.requestorName} on ${_formatDateTime(request.dateSubmitted)}',
        signature: reqSig.signatureData.isNotEmpty ? reqSig : null,
      ),
    );

    // 2. Assignment
    final isAssigned = !_isUnassigned(request.assignedToId);
    final assignSig = _signatures.firstWhere(
      (s) => s.signatureType == 'approval',
      orElse: () => ESignature(
        id: '',
        workRequestId: '',
        signerId: '',
        signerName: '',
        signerRole: '',
        signatureType: '',
        signatureData: '',
        signedAt: DateTime.now(),
      ),
    );
    items.add(
      _buildWorkflowTimelineItem(
        title: 'Admin Approved & Assigned',
        isDone: isAssigned,
        subtitle: isAssigned
            ? 'Approved and assigned to ${_assignedMaintenanceName(request.assignedToId)}'
            : 'Awaiting admin review & assignment',
        signature: assignSig.signatureData.isNotEmpty ? assignSig : null,
      ),
    );

    // 3. Acceptance
    final acceptSig = _signatures.firstWhere(
      (s) => s.signatureType == 'acceptance',
      orElse: () => ESignature(
        id: '',
        workRequestId: '',
        signerId: '',
        signerName: '',
        signerRole: '',
        signatureType: '',
        signatureData: '',
        signedAt: DateTime.now(),
      ),
    );
    final isAccepted = acceptSig.signatureData.isNotEmpty ||
        (request.status != 'Pending Assignment' && request.status != 'Assigned');
    items.add(
      _buildWorkflowTimelineItem(
        title: 'Technician Accepted Task',
        isDone: isAccepted,
        subtitle: isAccepted
            ? 'Accepted by ${request.acceptedByName ?? _assignedMaintenanceName(request.assignedToId)} on ${_formatDateTime(request.acceptedDate ?? acceptSig.signedAt)}'
            : 'Awaiting technician acceptance',
        signature: acceptSig.signatureData.isNotEmpty ? acceptSig : null,
      ),
    );

    // 4. Pre-Inspection
    final preInspection = _preInspectionReport;
    final preInspSig = _signatures.firstWhere(
      (s) => s.signatureType == 'pre_inspection',
      orElse: () => ESignature(
        id: '',
        workRequestId: '',
        signerId: '',
        signerName: '',
        signerRole: '',
        signatureType: '',
        signatureData: '',
        signedAt: DateTime.now(),
      ),
    );
    final isPreInspectionSubmitted = preInspection != null;
    items.add(
      _buildWorkflowTimelineItem(
        title: 'Pre-Inspection Report Filed',
        isDone: isPreInspectionSubmitted,
        subtitle: isPreInspectionSubmitted
            ? 'Submitted by ${preInspection.inspectorName}'
            : 'Awaiting pre-inspection submission',
        signature: preInspSig.signatureData.isNotEmpty ? preInspSig : null,
        details: null,
      ),
    );

    // 5. Pre-Inspection Approval/Decline
    final preInspApprovalSig = _signatures.firstWhere(
      (s) => s.signatureType == 'pre_inspection_approval',
      orElse: () => ESignature(
        id: '',
        workRequestId: '',
        signerId: '',
        signerName: '',
        signerRole: '',
        signatureType: '',
        signatureData: '',
        signedAt: DateTime.now(),
      ),
    );
    final isPreInspectionReviewed = preInspection != null &&
        (preInspection.status == 'Approved' || preInspection.status == 'Declined');
    final approvedByName = preInspection?.adminApprovedBy != null
        ? (_userNames[preInspection!.adminApprovedBy] ?? preInspection.adminApprovedBy)
        : "Admin";
    items.add(
      _buildWorkflowTimelineItem(
        title: 'Pre-Inspection Review Decision',
        isDone: isPreInspectionReviewed,
        subtitle: isPreInspectionReviewed
            ? '${preInspection.status} by $approvedByName'
            : 'Awaiting admin pre-inspection decision',
        signature: preInspApprovalSig.signatureData.isNotEmpty ? preInspApprovalSig : null,
        details: null,
      ),
    );

    // 6. Post-Repair Attempts
    final sortedAttempts = List<PostRepairReport>.from(_postRepairReports)
      ..sort((a, b) {
        int cmp = a.repairDate.compareTo(b.repairDate);
        if (cmp != 0) return cmp;
        return a.attemptNumber.compareTo(b.attemptNumber);
      });

    for (int i = 0; i < sortedAttempts.length; i++) {
      final report = sortedAttempts[i];
      final attemptTechSig = _signatures.firstWhere(
        (s) => s.signatureType == 'post_repair' && s.signerId == report.technicianId,
        orElse: () => ESignature(
          id: '',
          workRequestId: '',
          signerId: '',
          signerName: '',
          signerRole: '',
          signatureType: '',
          signatureData: '',
          signedAt: DateTime.now(),
        ),
      );
      items.add(
        _buildWorkflowTimelineItem(
          title: 'Post-Repair Report Submitted',
          isDone: true,
          subtitle: 'Submitted by ${report.technicianName}',
          signature: attemptTechSig.signatureData.isNotEmpty ? attemptTechSig : null,
          details: null,
        ),
      );

      final isEvaluated = report.adminEvaluation != null;
      final attemptAdminSig = _signatures.firstWhere(
        (s) => s.signatureType == 'completion' && s.signerId == report.adminEvaluatedBy,
        orElse: () => ESignature(
          id: '',
          workRequestId: '',
          signerId: '',
          signerName: '',
          signerRole: '',
          signatureType: '',
          signatureData: '',
          signedAt: DateTime.now(),
        ),
      );
      final isRework = report.adminEvaluation == 'rework';
      final evaluatedByName = report.adminEvaluatedBy != null
          ? (_userNames[report.adminEvaluatedBy] ?? report.adminEvaluatedBy)
          : "Admin";
      
      final isLatestReport = i == sortedAttempts.length - 1;
      if (isEvaluated || isLatestReport) {
        items.add(
          _buildWorkflowTimelineItem(
            title: isRework
                ? 'Post-Repair Evaluation Completed - Rework'
                : 'Post-Repair Evaluation',
            isDone: isEvaluated && !isRework,
            isRework: isRework,
            subtitle: isEvaluated
                ? '${isRework ? "REWORK REQUIRED" : "SATISFIED (Approved)"} by $evaluatedByName'
                : 'Awaiting admin post-repair evaluation',
            signature: attemptAdminSig.signatureData.isNotEmpty ? attemptAdminSig : null,
            details: null,
          ),
        );
      }
    }

    // If the latest evaluation was rework, append a pending Post-Repair Report step
    if (sortedAttempts.isNotEmpty && sortedAttempts.last.adminEvaluation == 'rework') {
      items.add(
        _buildWorkflowTimelineItem(
          title: 'Post-Repair Report',
          isDone: false,
          subtitle: 'Awaiting post-repair report (Rework).',
          signature: null,
          details: null,
        ),
      );
    }

    // 7. Final Completion
    final isCompleted = request.status == 'Completed';
    items.add(
      _buildWorkflowTimelineItem(
        title: 'Work Completed & Closed',
        isDone: isCompleted,
        subtitle: isCompleted
            ? 'Completed on ${_formatDateTime(request.updatedAt)}'
            : 'Awaiting final completion approval',
        isLast: true,
      ),
    );

    return Column(
      children: items,
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../shared/services/maintenance_account_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/signature_pad_widget.dart';
import '../../../shared/widgets/availability_status_badge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'work_request_completion_page.dart';
import 'admin_approval_signature_page.dart';
import 'package:printing/printing.dart';
import '../../../shared/services/iso_pdf_service.dart';
import '../../../shared/services/cost_tracking_service.dart';
import '../../../web/admin/tickets/admin_cost_tracking_form.dart';
import '../../../shared/widgets/voice_player_widget.dart';
import '../../../shared/models/pre_inspection_model.dart';
import '../../../shared/services/pre_inspection_service.dart';
import 'admin_pre_inspection_review_page.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/services/post_repair_service.dart';
import '../../maintenance/task/post_repair_page.dart';
import '../../../shared/services/user_service.dart';

class RequestDetailsPage extends StatefulWidget {
  final WorkRequest request;

  const RequestDetailsPage({super.key, required this.request});

  @override
  State<RequestDetailsPage> createState() => _RequestDetailsPageState();
}

class _RequestDetailsPageState extends State<RequestDetailsPage>
    with WidgetsBindingObserver {
  late WorkRequest _request;
  final List<ESignature> _signatures = [];
  final Map<String, String> _maintenanceNamesById = {};
  final Map<String, String> _maintenanceSpecializationsById = {};
  final Map<String, String> _userNames = {};
  final Map<String, String> _maintenanceStatusById = {};
  RealtimeChannel? _realtimeChannel;
  Timer? _autoRefreshTimer;
  bool _isAssigningMaintenance = false;
  bool _isSubmittingAdminCompletionSignature = false;

  bool _isUnassigned(String? staffId) {
    final normalized = staffId?.trim().toLowerCase();
    return normalized == null || normalized.isEmpty || normalized == 'null';
  }

  Future<void> _loadLatestRequest() async {
    try {
      final latest = await WorkRequestService.fetchById(_request.id);
      if (mounted && latest != null) {
        setState(() => _request = latest);
      }
    } catch (_) {}
  }

  PreInspectionReport? _preInspectionReport;
  List<PostRepairReport> _postRepairReports = [];

  Future<void> _loadWorkflowData() async {
    try {
      final latest = await WorkRequestService.fetchById(_request.id);
      final signatures = await ESignatureService.fetchByWorkRequest(
        _request.id,
      );
      
      // Populate cache of user names from signatures to bypass RLS issues
      for (final sig in signatures) {
        if (sig.signerId.isNotEmpty && sig.signerName.isNotEmpty) {
          final isAdm = sig.signerRole.toLowerCase() == 'campadmin';
          _userNames[sig.signerId] = isAdm ? 'Campus Admin - ${sig.signerName}' : sig.signerName;
        }
      }

      final maintenance =
          await MaintenanceAccountService.fetchCreatedByCurrentAdmin();
      final preInspection = await PreInspectionService.fetchLatestByWorkRequest(_request.id);
      final postRepairs = await PostRepairService.fetchByWorkRequest(_request.id);

      if (!mounted) return;
      setState(() {
        if (latest != null) {
          _request = latest;
        }
        _preInspectionReport = preInspection;
        _postRepairReports = postRepairs;
        _signatures
          ..clear()
          ..addAll(signatures);
        _maintenanceNamesById
          ..clear()
          ..addEntries(maintenance.map((m) => MapEntry(m.userId, m.fullName)));
        _maintenanceSpecializationsById
          ..clear()
          ..addEntries(
            maintenance.map(
              (m) => MapEntry(m.userId, (m.specialization ?? '').trim()),
            ),
          );
        _maintenanceStatusById
          ..clear()
          ..addEntries(maintenance.map((m) => MapEntry(m.userId, m.availabilityStatus)));
      });

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
    } catch (_) {}
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _loadWorkflowData(),
    );
  }

  bool get _isMaintenanceConfirmed {
    if (_request.acceptedDate != null) {
      return true;
    }
    return _signatures.any((sig) => sig.signatureType == 'acceptance');
  }

  bool get _hasMaintenanceCompletionSignature {
    return _signatures.any(
      (sig) =>
          sig.signatureType == 'completion' && sig.signerRole == 'maintenance',
    );
  }

  bool get _hasAdminCompletionSignature {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return false;
    return _signatures.any(
      (sig) =>
          sig.signatureType == 'completion' &&
          sig.signerRole == 'admin' &&
          sig.signerId.trim() == user.id,
    );
  }

  Future<void> _adminSignConfirmWorkRequest(String signatureData) async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    if (_hasAdminCompletionSignature) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin completion signature already submitted.'),
          backgroundColor: Color(0xFF1D4ED8),
        ),
      );
      return;
    }

    setState(() => _isSubmittingAdminCompletionSignature = true);

    try {
      await ESignatureService.insert(
        ESignature(
          id: '',
          workRequestId: _request.id,
          signerId: user.id,
          signerName: user.name,
          signerRole: 'admin',
          signatureType: 'completion',
          signatureData: signatureData,
          signedAt: DateTime.now(),
          notes: 'Admin completion confirmation signature',
        ),
      );

      await WorkRequestService.completeRequest(_request.id);

      await AppNotificationService.notifyAdminCompletionSubmittedToRequestor(
        workRequestId: _request.id,
        adminName: user.name,
        requestorId: _request.requestorId,
      );

      await _loadWorkflowData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Admin completion signature submitted. Waiting for requestor final confirmation.',
          ),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit admin signature: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingAdminCompletionSignature = false);
      }
    }
  }

  Future<void> _openAdminConfirmSignatureSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8F9FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final completionSignatures = _signatures
            .where((sig) => sig.signatureType == 'completion')
            .toList();

        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            minChildSize: 0.6,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Admin Confirm Work Request Form',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Request ID', _request.id),
                    _buildInfoRow('Title', _request.title),
                    _buildInfoRow('Status', _request.statusLabel),
                    const SizedBox(height: 10),
                    const Text(
                      'Work Evidence',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if ((_request.workEvidence ?? '').trim().isNotEmpty)
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              _request.workEvidence!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'Unable to load work evidence image.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: const Center(
                          child: Text(
                            'No work evidence uploaded yet.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    const Text(
                      'Maintenance Note',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        (_request.maintenanceNotes ?? '').trim().isNotEmpty
                            ? _request.maintenanceNotes!.trim()
                            : 'No maintenance note provided.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF374151),
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (completionSignatures.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Completion Signers',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...completionSignatures.map(
                        (sig) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildInfoRow(
                            sig.signerRole == 'admin'
                                ? 'Admin Completion'
                                : 'Maintenance Completion',
                            '${sig.signerName} • ${sig.signedAt.toString().substring(0, 16).replaceFirst('T', ' ')}',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SignaturePadWidget(
                      title: 'E-Signature for Admin Confirmation',
                      subtitle:
                          'Sign to confirm the completed work request form',
                      onSignatureComplete: (signatureData) async {
                        Navigator.of(sheetContext).pop();
                        await _adminSignConfirmWorkRequest(signatureData);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _assignedMaintenanceName(String? staffId) {
    if (_isUnassigned(staffId)) return '';
    final trimmed = staffId!.trim();
    final name = _maintenanceNamesById[trimmed];
    if (name == null || name.trim().isEmpty) return trimmed;
    final specialization = (_maintenanceSpecializationsById[trimmed] ?? '')
        .trim();
    if (specialization.isNotEmpty) {
      return '$name ($specialization)';
    }
    return name;
  }

  Future<bool> _hasValidAssignedMaintenance(String staffId) async {
    try {
      final maintenanceStaff =
          await MaintenanceAccountService.fetchCreatedByCurrentAdmin();
      return maintenanceStaff.any((staff) => staff.userId == staffId);
    } catch (_) {
      return false;
    }
  }

  Future<void> _assignMaintenanceToRequest(String maintenanceId) async {
    final normalizedId = maintenanceId.trim();
    if (normalizedId.isEmpty) return;

    final currentAssigned = _request.assignedToId?.trim();
    if (currentAssigned == normalizedId) return;

    setState(() => _isAssigningMaintenance = true);

    try {
      await WorkRequestService.assignTo(_request.id, normalizedId);
      await _loadWorkflowData();

      final maintenanceName = _assignedMaintenanceName(normalizedId);
      try {
        await AppNotificationService.createForUser(
          targetUserId: normalizedId,
          title: 'New Work Request Assignment',
          message: 'You were assigned to work request ${_request.id} by admin.',
          type: 'work_request_assigned',
          workRequestId: _request.id,
        );
      } catch (_) {
        // Assignment is already persisted; ignore notification failure to keep UX consistent.
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assigned to $maintenanceName.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign maintenance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAssigningMaintenance = false);
      }
    }
  }

  Future<void> _onApproveRequest() async {
    final assignedStaffId = _request.assignedToId?.trim();

    if (_isUnassigned(assignedStaffId)) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Assign Maintenance First'),
          content: const Text(
            'Please assign maintenance staff before approving this request.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final hasValidAssignment = await _hasValidAssignedMaintenance(
      assignedStaffId!,
    );
    if (!hasValidAssignment) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Assign Maintenance First'),
          content: const Text(
            'Please assign maintenance staff before approving this request.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final approved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AdminApprovalSignaturePage(
          request: _request.copyWith(assignedToId: assignedStaffId),
        ),
      ),
    );

    if (approved == true && mounted) {
      await _loadLatestRequest();
      Navigator.pop(context, true);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _request = widget.request;
    _markRelatedNotificationsRead();
    _recordViewedRequest();
    _loadWorkflowData();
    _startAutoRefresh();
    _setupRealtime();
  }

  void _setupRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('public:maintenance_users_mobile')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'maintenance_users',
          callback: (payload) {
            final updatedRecord = payload.newRecord;
            final userId = updatedRecord['user_id'] as String?;
            final newStatus = updatedRecord['availability_status'] as String?;
            if (userId != null && newStatus != null) {
              if (mounted) {
                setState(() {
                  _maintenanceStatusById[userId] = newStatus;
                });
              }
            }
          },
        )
        .subscribe();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadWorkflowData();
    }
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_realtimeChannel!);
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _markRelatedNotificationsRead() async {
    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      if (user == null) return;

      await AppNotificationService.markWorkRequestAsRead(
        role: user.role.name,
        userId: user.id,
        workRequestId: _request.id,
      );
    } catch (_) {}
  }

  Future<void> _recordViewedRequest() async {
    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      if (user == null) return;

      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Viewed Request',
        details: 'Viewed request details for ${_request.officeRoom}',
        workRequestId: _request.id,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    Color statusColor;
    Color statusBgColor;

    switch (request.status.toLowerCase()) {
      case 'pending':
      case 'pending assignment':
        statusColor = Colors.grey;
        statusBgColor = Colors.grey.shade100;
        break;
      case 'in progress':
      case 'in_progress':
      case 'assigned':
      case 'accepted by maintenance':
        statusColor = const Color(0xFF3B82F6);
        statusBgColor = const Color(0xFFEFF6FF);
        break;
      case 'declined':
      case 'cancelled':
      case 'declined/cancelled':
      case 'pre-inspection declined':
        statusColor = Colors.red;
        statusBgColor = const Color(0xFFFEE2E2);
        break;
      case 'confirmed':
      case 'pre-inspection approved':
      case 'under_maintenance':
        statusColor = const Color(0xFF00BFA5);
        statusBgColor = const Color(0xFFE0F2F1);
        break;
      case 'rework':
      case 'for rework':
        statusColor = Colors.orange;
        statusBgColor = const Color(0xFFFFF7ED);
        break;
      case 'completed':
        statusColor = const Color(0xFF22C55E);
        statusBgColor = const Color(0xFFDCFCE7);
        break;
      default:
        statusColor = Colors.grey;
        statusBgColor = Colors.grey.shade100;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4169E1)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Request Details',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_rounded, color: Color(0xFF8B5CF6)),
            tooltip: 'Collaboration Workspace',
            onPressed: () {
              // Note: For a real app, we'd open a bottom sheet or push a new page
              // with the mobile equivalent of AdminCollaborationWorkspaceWidget
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Collaboration Workspace is primarily managed via Web Interface.')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.attach_money_rounded, color: Color(0xFF10B981)),
            tooltip: 'Manage Costs',
            onPressed: () async {
              final existingCost = await CostTrackingService.fetchByWorkRequestId(request.id);
              if (!mounted) return;
              await showDialog(
                context: context,
                builder: (context) => AdminCostTrackingForm(
                  workRequest: request,
                  existingCost: existingCost,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded, color: Color(0xFF4169E1)),
            onPressed: () async {
              final pdfBytes = await IsoPdfService.generateWorkRequestPdf(request);
              await Printing.layoutPdf(
                onLayout: (_) => pdfBytes,
                name: 'Work_Request_Form_${request.formattedId}',
                format: IsoPdfService.longLandscapeFormat,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning Alert
              if (request.status.toLowerCase() == 'in progress' || request.status.toLowerCase() == 'in_progress')
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFCD34D),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_outlined,
                        color: Color(0xFFCA8A04),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Action Restricted',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFCA8A04),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'This request is currently ongoing. Please wait for completion & do not exceed before finalizing',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8B5CF6).withValues(alpha: 0.8),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: const Icon(
                          Icons.close,
                          color: Color(0xFFCA8A04),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              if (request.status.toLowerCase() == 'in progress' || request.status.toLowerCase() == 'in_progress') const SizedBox(height: 16),

              // REQUEST ID Header
              const Text(
                'REQUEST ID',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4169E1),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 390;

                  final idText = Text(
                    '#${request.id.split('-').last}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  );

                  final chips = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          request.statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (request.priority == 'high')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'HIGH PRIORITY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDC2626),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [idText, const SizedBox(height: 8), chips],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: idText),
                      const SizedBox(width: 12),
                      Flexible(child: chips),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Title with Location
              Text(
                request.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${request.officeRoom} - ${request.typeOfRequest.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Nature of Work Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 20,
                          color: const Color(0xFF4169E1),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Request Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_hasMaintenanceCompletionSignature) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Text(
                          'Maintenance already signed the Confirm Work Request form. You can now add admin completion signature.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1D4ED8),
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isSubmittingAdminCompletionSignature)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ElevatedButton.icon(
                        onPressed:
                            (_isSubmittingAdminCompletionSignature ||
                                _hasAdminCompletionSignature)
                            ? null
                            : _openAdminConfirmSignatureSheet,
                        icon: const Icon(Icons.verified, size: 18),
                        label: Text(
                          _hasAdminCompletionSignature
                              ? 'Admin Confirmation Already Signed'
                              : 'Admin Sign Confirm Work Request Form',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade600,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildInfoRow('Title', request.title),
                    _buildInfoRow('Type', request.typeOfRequest),
                    _buildInfoRow('Priority', request.priorityLabel),
                    _buildInfoRow(
                      'Date Submitted',
                      request.dateSubmitted.toString().substring(0, 10),
                    ),
                    if (request.voiceNotes != null && request.voiceNotes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Voice Notes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...request.voiceNotes!.map((url) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: VoicePlayerWidget(audioUrl: url),
                          )),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Location Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: const Color(0xFF4169E1),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Building', request.buildingName ?? ''),
                    _buildInfoRow('Room', request.officeRoom ?? ''),
                    _buildInfoRow('Department', request.department ?? ''),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Issue Description Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 20,
                          color: const Color(0xFF4169E1),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Issue Description',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      request.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF374151),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Requestor Info Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: Color(0xFF4169E1),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person_2,
                                size: 16,
                                color: const Color(0xFF4169E1),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Requestor Info',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${request.requestorName}\n${request.requestorPosition}\nReported By: ${request.reportedBy ?? ''}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Assignment & Signature Progress
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 20,
                          color: const Color(0xFF4169E1),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Workflow Signatures',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Assign Maintenance',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: (() {
                        final assignedId = request.assignedToId?.trim();
                        if (assignedId == null || assignedId.isEmpty) {
                          return null;
                        }
                        return _maintenanceNamesById.containsKey(assignedId)
                            ? assignedId
                            : null;
                      })(),
                      isExpanded: true,
                      hint: const Text('Select maintenance staff'),
                      items: _maintenanceNamesById.entries
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.key,
                              child: Row(
                                children: [
                                  AvailabilityStatusBadge(
                                    status: _maintenanceStatusById[entry.key] ?? 'offline',
                                    size: BadgeSize.small,
                                    showLabel: false,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    (() {
                                      final specialization =
                                          (_maintenanceSpecializationsById[entry
                                                      .key] ??
                                                  '')
                                              .trim();
                                      if (specialization.isNotEmpty) {
                                        return '${entry.value} ($specialization)';
                                      }
                                      return entry.value;
                                    })(),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _isAssigningMaintenance
                          ? null
                          : (value) {
                              if (value != null) {
                                _assignMaintenanceToRequest(value);
                              }
                            },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF4169E1),
                          ),
                        ),
                        suffixIcon: _isAssigningMaintenance
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Assigned Maintenance',
                      _assignedMaintenanceName(request.assignedToId),
                    ),
                    if (_isMaintenanceConfirmed) ...[
                      _buildInfoRow(
                        'Confirmed By',
                        request.acceptedByName ??
                            _signatures
                                .where(
                                  (sig) => sig.signatureType == 'acceptance',
                                )
                                .map((sig) => sig.signerName)
                                .join(', '),
                      ),
                      _buildInfoRow(
                        'Confirmed Date',
                        request.acceptedDate != null
                            ? request.acceptedDate!
                                  .toString()
                                  .substring(0, 16)
                                  .replaceFirst('T', ' ')
                            : '',
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Workflow Timeline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildWorkflowTimeline(),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Timestamps
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: const Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'SUBMITTED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Oct ${request.dateSubmitted.day}, ${_formatTime(request.dateSubmitted)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.update,
                              size: 14,
                              color: const Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'LAST UPDATED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Oct ${request.dateSubmitted.day}, 11:50 AM',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              if (request.status.toLowerCase() == 'pending' || request.status.toLowerCase() == 'pending assignment') ...[
                ElevatedButton.icon(
                  onPressed: _onApproveRequest,
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: const Text(
                    'Approve Request',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (_preInspectionReport != null) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminPreInspectionReviewPage(request: _request),
                      ),
                    ).then((_) => _loadWorkflowData());
                  },
                  icon: const Icon(Icons.assignment_outlined, size: 20),
                  label: const Text(
                    'View Pre-Inspection Report',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4169E1),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (_postRepairReports.isNotEmpty) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostRepairPage(request: _request),
                      ),
                    ).then((_) => _loadWorkflowData());
                  },
                  icon: const Icon(Icons.history, size: 20),
                  label: const Text(
                    'View Post-Repair Reports',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4169E1),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Update Work Request Form Button
              ElevatedButton.icon(
                onPressed: request.status == 'completed'
                    ? () {
                        _showUpdateConfirmationDialog(context);
                      }
                    : null,
                icon: const Icon(Icons.edit_document, size: 20),
                label: const Text(
                  'Update Work Request Form',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: request.status.toLowerCase() == 'completed'
                      ? const Color(0xFF4169E1)
                      : Colors.grey.shade300,
                  foregroundColor: request.status.toLowerCase() == 'completed'
                      ? Colors.white
                      : Colors.grey.shade600,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEvidencePlaceholder(String label) {
    return Column(
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Center(
            child: Icon(
              Icons.image_outlined,
              size: 40,
              color: Colors.grey.shade400,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void _showUpdateConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Confirmation Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4169E1).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 32,
                      color: Color(0xFF4169E1),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                const Text(
                  'Confirm Work Request Form?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),

                // Message
                const Text(
                  'Are you sure you want to mark this work as completed? This will update the work request form to your done reports in your history.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Confirm Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              WorkRequestCompletionPage(request: _request),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4169E1),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: const BorderSide(
                        color: Color(0xFFE5E7EB),
                        width: 1.5,
                      ),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineItem({
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
                _buildTimelineSignatureImage(signature.signatureData),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineSignatureImage(String base64Str) {
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
      _buildTimelineItem(
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
      _buildTimelineItem(
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
        (request.status.toLowerCase() != 'pending' && request.status.toLowerCase() != 'pending assignment');
    items.add(
      _buildTimelineItem(
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
      _buildTimelineItem(
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
      _buildTimelineItem(
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
        _buildTimelineItem(
          title: 'Post-Repair Report Submitted',
          isDone: true,
          subtitle: 'Submitted by ${report.technicianName}',
          signature: attemptTechSig.signatureData.isNotEmpty ? attemptTechSig : null,
          details: null,
        ),
      );

      final isEvaluated = report.adminEvaluation != null;
      final isRework = report.adminEvaluation == 'rework';
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
      final evaluatedByName = report.adminEvaluatedBy != null
          ? (_userNames[report.adminEvaluatedBy] ?? report.adminEvaluatedBy)
          : "Admin";
      
      final isLatestReport = i == sortedAttempts.length - 1;
      if (isEvaluated || isLatestReport) {
        items.add(
          _buildTimelineItem(
            title: isRework
                ? 'Post-Repair Evaluation Completed - Rework'
                : 'Post-Repair Evaluation',
            isDone: isEvaluated && !isRework,
            isRework: isRework,
            subtitle: isEvaluated
                ? '${report.adminEvaluation == "satisfied" ? "SATISFIED (Approved)" : "REWORK REQUIRED"} by $evaluatedByName'
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
        _buildTimelineItem(
          title: 'Post-Repair Report',
          isDone: false,
          subtitle: 'Awaiting post-repair report (Rework).',
          signature: null,
          details: null,
        ),
      );
    }

    // 7. Final Completion
    final isCompleted = request.status.toLowerCase() == 'completed';
    items.add(
      _buildTimelineItem(
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

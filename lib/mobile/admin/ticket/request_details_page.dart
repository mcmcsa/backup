import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/attachment_image_widget.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart';
import 'work_request_completion_page.dart';
import 'admin_approval_signature_page.dart';
import 'package:printing/printing.dart';
import '../../../shared/services/iso_pdf_service.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../web/teacher/reports/teacher_official_form_web.dart';
import '../../../shared/services/chat_service.dart';
import '../../../shared/widgets/chat/chat_messages_panel.dart';
import '../../../shared/widgets/voice_player_widget.dart';
import '../../../shared/models/pre_inspection_model.dart';
import '../../../shared/services/pre_inspection_service.dart';
import 'admin_pre_inspection_review_page.dart';
import 'admin_post_repair_evaluation_page.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/services/post_repair_service.dart';
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
  bool _isSubmittingAdminCompletionSignature = false;
  int _selectedTab = 0; // 0: Work Request Timeline, 1: Details

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
                              errorBuilder: (context, error, stackTrace) => const Center(
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

  Future<void> _onApproveRequest() async {
    final nav = Navigator.of(context);
    final approved = await nav.push<bool>(
      MaterialPageRoute(
        builder: (context) => AdminApprovalSignaturePage(
          request: _request,
        ),
      ),
    );

    if (approved == true && mounted) {
      await _loadLatestRequest();
      nav.pop(true);
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

  Future<void> _openChatWithRequestor() async {
    final req = _request;
    final reqId = req.requestorId;
    if (reqId == null || reqId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Requestor user information not found')),
      );
      return;
    }

    final authService = context.read<AuthService>();
    final currentUser = authService.currentUser;
    if (currentUser == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Color(0xFF4169E1))),
    );

    try {
      final room = await ChatService.findOrCreateDirectRoom(
        currentUserId: currentUser.id,
        currentUserName: currentUser.name,
        currentUserRole: currentUser.role.name,
        otherUserId: reqId,
        otherUserName: req.requestorName,
        otherUserRole: 'teacher',
        workRequestId: req.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              top: false,
              child: ChatMessagesPanel(
                key: ValueKey(room.id),
                room: room,
                currentUserId: currentUser.id,
                currentUserName: currentUser.name,
                currentUserRole: currentUser.role.name,
                onBack: () => Navigator.pop(context),
                onRoomDeleted: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat: $e')),
      );
    }
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
      case 'pending_assignment':
        statusColor = const Color(0xFFD97706);
        statusBgColor = const Color(0xFFFEF3C7);
        break;
      case 'confirmed':
      case 'pre-inspection approved':
      case 'under_maintenance':
        statusColor = const Color(0xFF00C2A8);
        statusBgColor = const Color(0xFFE0F2F1);
        break;
      case 'in progress':
      case 'in_progress':
      case 'assigned':
      case 'accepted by maintenance':
        statusColor = const Color(0xFF00C2A8);
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
      case 'declined':
      case 'cancelled':
      case 'declined/cancelled':
      case 'pre-inspection declined':
        statusColor = Colors.red;
        statusBgColor = const Color(0xFFFEE2E2);
        break;
      default:
        statusColor = Colors.grey;
        statusBgColor = Colors.grey.shade100;
    }

    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Request Details',
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_rounded, color: Color(0xFF4169E1)),
            tooltip: 'View Official Form',
            onPressed: () {
              showDialog(
                context: context,
                useSafeArea: true,
                barrierDismissible: true,
                builder: (context) => TeacherOfficialFormWeb(request: request),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF4169E1)),
            tooltip: 'Message Requestor',
            onPressed: _openChatWithRequestor,
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded, color: Color(0xFF4169E1)),
            tooltip: 'Print Form',
            onPressed: () async {
              final pdfBytes = await IsoPdfService.generateWorkRequestPdf(request);
              await Printing.layoutPdf(
                onLayout: (_) => pdfBytes,
                name: 'Work_Request_Form_${request.formattedId}',
                format: IsoPdfService.standardPortraitFormat,
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
                  margin: const EdgeInsets.only(bottom: 16),
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
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.8),
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

              // REQUEST ID Header
              const Text(
                'REQUEST ID',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4169E1),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 390;

                  final idText = Text(
                    '#${request.id.split('-').last}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
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
                      if (request.status.toLowerCase() != 'pending' &&
                          request.status.toLowerCase() != 'pending assignment' &&
                          request.priority == 'high')
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

              const SizedBox(height: 16),

              // Title with Location
              Text(
                request.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 18,
                    color: themeProvider.subtitleColor,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${request.officeRoom} - ${request.typeOfRequest.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 14,
                        color: themeProvider.subtitleColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 3-Tab Filter (Work Request Timeline, Details, Signature)
              _buildFilterTabs(themeProvider),

              const SizedBox(height: 16),

              // Tab Views
              if (_selectedTab == 0)
                _buildTimelineTab(themeProvider, request)
              else if (_selectedTab == 1)
                _buildDetailsTab(themeProvider, request)
              else
                _buildSignatureTab(themeProvider, request),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(ThemeProvider themeProvider) {
    final tabs = [
      {'title': 'Work Request Timeline', 'icon': Icons.timeline_rounded},
      {'title': 'Details', 'icon': Icons.info_outline_rounded},
      {'title': 'Signature', 'icon': Icons.draw_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Padding(
            padding: EdgeInsets.only(right: index < tabs.length - 1 ? 8 : 0),
            child: InkWell(
              onTap: () => setState(() => _selectedTab = index),
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4169E1)
                      : themeProvider.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF4169E1)
                        : themeProvider.borderColor,
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF4169E1).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tabs[index]['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : (themeProvider.isDarkMode ? Colors.grey.shade400 : const Color(0xFF6B7280)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tabs[index]['title'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (themeProvider.isDarkMode ? Colors.grey.shade300 : const Color(0xFF374151)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTimelineTab(ThemeProvider themeProvider, WorkRequest request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Quick Action Buttons
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
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (_preInspectionReport != null && _postRepairReports.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminPreInspectionReviewPage(request: _request),
                      ),
                    ).then((_) => _loadWorkflowData());
                  },
                  icon: const Icon(Icons.fact_check, size: 16),
                  label: Text(
                    _preInspectionReport!.status == 'Pending' ? 'Review Pre-Insp.' : 'Pre-Inspection',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _preInspectionReport!.status == 'Pending'
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF4169E1),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminPostRepairEvaluationPage(request: _request),
                      ),
                    ).then((_) => _loadWorkflowData());
                  },
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text(
                    'Post-Repair',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4169E1),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ] else if (_preInspectionReport != null) ...[
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminPreInspectionReviewPage(request: _request),
                ),
              ).then((_) => _loadWorkflowData());
            },
            icon: const Icon(Icons.fact_check, size: 18),
            label: Text(
              _preInspectionReport!.status == 'Pending' ? 'Review Pre-Inspection' : 'View Pre-Inspection',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _preInspectionReport!.status == 'Pending'
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF4169E1),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 12),
        ] else if (_postRepairReports.isNotEmpty) ...[
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminPostRepairEvaluationPage(request: _request),
                ),
              ).then((_) => _loadWorkflowData());
            },
            icon: const Icon(Icons.history, size: 18),
            label: const Text(
              'View Post-Repair Reports',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4169E1),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (request.status.toLowerCase() == 'completed') ...[
          ElevatedButton.icon(
            onPressed: () => _showUpdateConfirmationDialog(context),
            icon: const Icon(Icons.edit_document, size: 18),
            label: const Text(
              'Update Work Request Form',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4169E1),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Workflow Timeline Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeProvider.borderColor),
            boxShadow: [
              BoxShadow(
                color: themeProvider.shadowColor,
                blurRadius: 10,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4169E1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.timeline_rounded,
                      size: 20,
                      color: Color(0xFF4169E1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WORKFLOW TIMELINE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4169E1),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'End-to-End Progress Tracking',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.textColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildWorkflowTimeline(themeProvider),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Timestamps Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeProvider.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeProvider.borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: themeProvider.mutedTextColor),
                        const SizedBox(width: 4),
                        Text(
                          'SUBMITTED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.mutedTextColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('MMM dd, yyyy · HH:mm').format(request.dateSubmitted),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.textColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 36,
                width: 1,
                color: themeProvider.borderColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.update, size: 14, color: themeProvider.mutedTextColor),
                        const SizedBox(width: 4),
                        Text(
                          'LAST UPDATED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.mutedTextColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      request.updatedAt != null
                          ? DateFormat('MMM dd, yyyy · HH:mm').format(request.updatedAt!)
                          : 'N/A',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDetailsTab(ThemeProvider themeProvider, WorkRequest request) {
    final attachments = request.attachmentUrls ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Request Details Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeProvider.borderColor),
            boxShadow: [
              BoxShadow(
                color: themeProvider.shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(
                icon: Icons.assignment_outlined,
                tag: 'INFORMATION',
                title: 'Request Details',
                themeProvider: themeProvider,
              ),
              const SizedBox(height: 16),
              _buildInfoRow('Tracking #', request.id.substring(0, 8).toUpperCase(), themeProvider: themeProvider),
              _buildInfoRow('Title', request.title, themeProvider: themeProvider),
              _buildInfoRow('Type', request.typeWithSpecify, themeProvider: themeProvider),
              _buildInfoRow('Priority', request.priorityLabel, themeProvider: themeProvider),
              _buildInfoRow(
                'Date Submitted',
                DateFormat('MMM dd, yyyy · HH:mm').format(request.dateSubmitted),
                themeProvider: themeProvider,
              ),
              if (request.voiceNotes != null && request.voiceNotes!.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text(
                  'Voice Notes (${request.voiceNotes!.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.subtitleColor,
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

        // 2. Location Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeProvider.borderColor),
            boxShadow: [
              BoxShadow(
                color: themeProvider.shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(
                icon: Icons.location_on_outlined,
                tag: 'LOCATION',
                title: 'Campus & Room Details',
                themeProvider: themeProvider,
              ),
              const SizedBox(height: 16),
              _buildInfoRow('Building', request.buildingName ?? 'N/A', themeProvider: themeProvider),
              _buildInfoRow('Room', request.officeRoom ?? request.roomName ?? 'N/A', themeProvider: themeProvider),
              _buildInfoRow('Department', request.departmentName ?? request.department ?? 'N/A', themeProvider: themeProvider),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Issue Description & Attachments Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeProvider.borderColor),
            boxShadow: [
              BoxShadow(
                color: themeProvider.shadowColor,
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4169E1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.description_outlined, size: 18, color: Color(0xFF4169E1)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ISSUE DESCRIPTION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4169E1),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Problem Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (attachments.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4169E1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${attachments.length} photo${attachments.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4169E1),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode ? const Color(0xFF181818) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeProvider.borderColor),
                ),
                child: Text(
                  request.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: themeProvider.textColor,
                    height: 1.5,
                  ),
                ),
              ),
              if (attachments.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Attached Photos',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.subtitleColor,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: attachments.length,
                    itemBuilder: (context, index) {
                      final url = attachments[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: InkWell(
                          onTap: () => showAttachmentZoomDialog(context, url),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: themeProvider.borderColor),
                            ),
                            child: AppAttachmentImage(
                              url: url,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(10),
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
        ),

        const SizedBox(height: 16),

        // 4. Requestor Information Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeProvider.borderColor),
            boxShadow: [
              BoxShadow(
                color: themeProvider.shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(
                icon: Icons.person_outline,
                tag: 'REQUESTOR',
                title: 'Requestor Information',
                themeProvider: themeProvider,
              ),
              const SizedBox(height: 16),
              _buildInfoRow('Name', request.requestorName, themeProvider: themeProvider),
              _buildInfoRow('Position', request.requestorPosition, themeProvider: themeProvider),

            ],
          ),
        ),

        const SizedBox(height: 16),

        // 5. Staff Assignment Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeProvider.borderColor),
            boxShadow: [
              BoxShadow(
                color: themeProvider.shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(
                icon: Icons.engineering_outlined,
                tag: 'STAFF ASSIGNMENT',
                title: 'Maintenance Assigned',
                themeProvider: themeProvider,
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                'Assigned Staff',
                _assignedMaintenanceName(request.assignedToId),
                themeProvider: themeProvider,
              ),
              if (_isMaintenanceConfirmed) ...[
                _buildInfoRow(
                  'Confirmed By',
                  request.acceptedByName ??
                      _signatures
                          .where((sig) => sig.signatureType == 'acceptance')
                          .map((sig) => sig.signerName)
                          .join(', '),
                  themeProvider: themeProvider,
                ),
                _buildInfoRow(
                  'Confirmed Date',
                  request.acceptedDate != null
                      ? DateFormat('MMM dd, yyyy · HH:mm').format(request.acceptedDate!)
                      : '',
                  themeProvider: themeProvider,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSignatureTab(ThemeProvider themeProvider, WorkRequest request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Admin Sign action banner if maintenance completion signed and admin hasn't signed
        if (_hasMaintenanceCompletionSignature) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_user, size: 18, color: Color(0xFF059669)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Admin Verification Ready',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Technician has signed the completion form. Campus Administrator signature can now finalize this confirmation.',
                  style: TextStyle(fontSize: 12, color: themeProvider.textColor, height: 1.4),
                ),
                const SizedBox(height: 12),
                if (_isSubmittingAdminCompletionSignature)
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                else
                  ElevatedButton.icon(
                    onPressed: _hasAdminCompletionSignature ? null : _openAdminConfirmSignatureSheet,
                    icon: const Icon(Icons.draw, size: 18),
                    label: Text(_hasAdminCompletionSignature ? 'Admin Signed Already' : 'Sign Confirm Work Request Form'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade600,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Verified Signatures Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeProvider.borderColor),
            boxShadow: [
              BoxShadow(
                color: themeProvider.shadowColor,
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4169E1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.draw_rounded, color: Color(0xFF4169E1), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VERIFIED SIGNATURES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4169E1),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_signatures.length} signature(s) collected',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: themeProvider.textColor),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: themeProvider.borderColor),
              const SizedBox(height: 16),

              if (_signatures.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.gesture, size: 40, color: themeProvider.mutedTextColor.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text(
                          'No electronic signatures collected yet.',
                          style: TextStyle(fontSize: 13, color: themeProvider.mutedTextColor),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._signatures.map((sig) => _buildSignatureCardItem(sig, themeProvider)),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCardHeader({
    required IconData icon,
    required String tag,
    required String title,
    required ThemeProvider themeProvider,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4169E1).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF4169E1)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tag,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4169E1),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignatureCardItem(ESignature sig, ThemeProvider themeProvider) {
    final roleLower = sig.signerRole.toLowerCase();
    final roleColor = roleLower.contains('admin')
        ? const Color(0xFF2563EB)
        : (roleLower.contains('maintenance') || roleLower.contains('tech')
            ? const Color(0xFFD97706)
            : const Color(0xFF059669));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: roleColor.withValues(alpha: themeProvider.isDarkMode ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: roleColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified_rounded, size: 16, color: roleColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sig.signerName.isNotEmpty ? sig.signerName : 'Unknown',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sig.signatureTypeLabel} · ${DateFormat('MMM dd, yyyy · HH:mm').format(sig.signedAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: themeProvider.mutedTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                sig.signerRole.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: roleColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    ThemeProvider? themeProvider,
  }) {
    final labelColor = themeProvider?.subtitleColor ?? const Color(0xFF6B7280);
    final valueColor = themeProvider?.textColor ?? const Color(0xFF111827);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdateConfirmationDialog(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: themeProvider.cardColor,
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
                Text(
                  'Confirm Work Request Form?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  'Are you sure you want to mark this work as completed? This will update the work request form to your done reports in your history.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: themeProvider.subtitleColor,
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
                      foregroundColor: themeProvider.mutedTextColor,
                      side: BorderSide(
                        color: themeProvider.borderColor,
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
    ThemeProvider? themeProvider,
  }) {
    final circleColor = isRework
        ? const Color(0xFFD97706)
        : (isDone ? const Color(0xFF059669) : (themeProvider?.isDarkMode == true ? Colors.grey.shade700 : Colors.grey.shade300));
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
                      : (isDone ? (themeProvider?.textColor ?? const Color(0xFF111827)) : Colors.grey.shade500),
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: themeProvider?.mutedTextColor ?? Colors.grey.shade500,
                  ),
                ),
              ],
              if (details != null) ...[
                const SizedBox(height: 6),
                details,
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildWorkflowTimeline(ThemeProvider themeProvider) {
    final request = _request;
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
        themeProvider: themeProvider,
      ),
    );

    // 2. Assignment
    final isAssigned = !_isUnassigned(request.assignedToId);
    final assignSig = _signatures.firstWhere(
      (s) => s.signatureType == 'approval' || s.signatureType == 'admin_approval',
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

    final hasAdminSig = assignSig.signatureData.isNotEmpty ||
        _signatures.any((s) =>
            (s.signatureType == 'approval' || s.signatureType == 'admin_approval') &&
            s.signatureData.isNotEmpty);
    final isStatusApproved = request.status.toLowerCase() != 'pending' &&
        request.status.toLowerCase() != 'pending approval' &&
        request.status.toLowerCase() != 'rejected' &&
        request.status.toLowerCase() != 'cancelled';
    final isAdminApproved = isStatusApproved && hasAdminSig && isAssigned;

    items.add(
      _buildTimelineItem(
        title: 'Admin Approved & Assigned',
        isDone: isAdminApproved,
        subtitle: isAdminApproved
            ? 'Approved and assigned to ${_assignedMaintenanceName(request.assignedToId)}'
            : (isAssigned
                ? 'Assigned to ${_assignedMaintenanceName(request.assignedToId)} (Awaiting admin approval & signature)'
                : 'Awaiting admin review & assignment'),
        signature: isAdminApproved && assignSig.signatureData.isNotEmpty ? assignSig : null,
        themeProvider: themeProvider,
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
    final isAccepted = isAdminApproved &&
        (acceptSig.signatureData.isNotEmpty ||
            (request.status.toLowerCase() != 'pending' &&
                request.status.toLowerCase() != 'pending assignment' &&
                request.status.toLowerCase() != 'approved'));
    items.add(
      _buildTimelineItem(
        title: 'Technician Accepted Task',
        isDone: isAccepted,
        subtitle: isAccepted
            ? 'Accepted by ${request.acceptedByName ?? _assignedMaintenanceName(request.assignedToId)} on ${_formatDateTime(request.acceptedDate ?? acceptSig.signedAt)}'
            : 'Awaiting technician acceptance',
        signature: isAccepted && acceptSig.signatureData.isNotEmpty ? acceptSig : null,
        themeProvider: themeProvider,
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
        themeProvider: themeProvider,
      ),
    );

    // 5. Pre-Inspection Approval/Decline
    final preInspApprovalSig = _signatures.firstWhere(
      (s) => s.signatureType == 'pre_inspection_admin' || s.signatureType == 'pre_inspection_approval',
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
    final isPreInspApproved = preInspection?.status == 'Approved';
    final approvedByName = preInspection?.adminApprovedBy != null
        ? (_userNames[preInspection!.adminApprovedBy] ?? preInspection.adminApprovedBy)
        : "Admin";
    items.add(
      _buildTimelineItem(
        title: preInspection?.status == 'Approved'
            ? 'Pre-Inspection Approved'
            : (preInspection?.status == 'Declined' ? 'Pre-Inspection Declined' : 'Pre-Inspection Review'),
        isDone: isPreInspectionReviewed,
        subtitle: isPreInspectionReviewed
            ? '${preInspection.status} by $approvedByName'
            : (preInspection != null ? 'Awaiting admin pre-inspection decision' : 'Pending pre-inspection submission'),
        signature: preInspApprovalSig.signatureData.isNotEmpty ? preInspApprovalSig : null,
        details: null,
        themeProvider: themeProvider,
      ),
    );

    final sortedAttempts = List<PostRepairReport>.from(_postRepairReports)
      ..sort((a, b) {
        int cmp = a.repairDate.compareTo(b.repairDate);
        if (cmp != 0) return cmp;
        return a.attemptNumber.compareTo(b.attemptNumber);
      });
    final hasPostRepair = sortedAttempts.isNotEmpty;
    final isCompleted = request.status.toLowerCase() == 'completed';

    // 6. Post-Repair Attempts & Evaluations
    if (hasPostRepair) {
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
        final attemptSuffix = sortedAttempts.length > 1 ? ' (Attempt #${report.attemptNumber})' : '';
        items.add(
          _buildTimelineItem(
            title: 'Post-Repair Report$attemptSuffix',
            isDone: true,
            subtitle: 'Submitted by ${report.technicianName}',
            signature: attemptTechSig.signatureData.isNotEmpty ? attemptTechSig : null,
            details: null,
            themeProvider: themeProvider,
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
                  ? 'Post-Repair Evaluation - Rework Required'
                  : 'Post-Repair Evaluation',
              isDone: isEvaluated && !isRework,
              isRework: isRework,
              subtitle: isEvaluated
                  ? '${isRework ? "REWORK REQUIRED" : "SATISFIED (Approved)"} by $evaluatedByName'
                  : 'Awaiting admin post-repair evaluation',
              signature: attemptAdminSig.signatureData.isNotEmpty ? attemptAdminSig : null,
              details: null,
              themeProvider: themeProvider,
            ),
          );
        }
      }

      // If the latest evaluation was rework, append a pending Post-Repair Report step
      if (sortedAttempts.last.adminEvaluation == 'rework') {
        final nextAttempt = sortedAttempts.length + 1;
        items.add(
          _buildTimelineItem(
            title: 'Post-Repair Report (Attempt #$nextAttempt)',
            isDone: false,
            subtitle: 'Awaiting post-repair submission (Rework).',
            signature: null,
            details: null,
            themeProvider: themeProvider,
          ),
        );
      }
    } else {
      // Keep Post-Repair Report and Post-Repair Evaluation visible even before first report submission!
      items.add(
        _buildTimelineItem(
          title: 'Post-Repair Report',
          isDone: false,
          subtitle: isPreInspApproved
              ? 'Awaiting post-repair submission from technician.'
              : 'Pending repair completion.',
          signature: null,
          details: null,
          themeProvider: themeProvider,
        ),
      );

      items.add(
        _buildTimelineItem(
          title: 'Post-Repair Evaluation',
          isDone: false,
          subtitle: 'Pending post-repair report submission.',
          signature: null,
          details: null,
          themeProvider: themeProvider,
        ),
      );
    }

    // 8. Final Completion
    final hasSatisfiedEval = hasPostRepair && sortedAttempts.last.adminEvaluation == 'satisfied';
    items.add(
      _buildTimelineItem(
        title: 'Completed & Verified',
        isDone: isCompleted,
        subtitle: isCompleted
            ? 'Completed on ${_formatDateTime(request.updatedAt)}'
            : (hasSatisfiedEval
                ? 'Awaiting final verification and close out.'
                : 'Pending work completion and evaluation.'),
        isLast: true,
        themeProvider: themeProvider,
      ),
    );

    return Column(
      children: items,
    );
  }
}


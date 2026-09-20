import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/signature_pad_widget.dart';
import 'pre_inspection_page.dart';
import '../../../shared/models/pre_inspection_model.dart';
import '../../../shared/services/pre_inspection_service.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/services/post_repair_service.dart';
import 'post_repair_page.dart';
import '../../../shared/services/user_service.dart';
import '../../../shared/providers/theme_provider.dart';

class TaskDetailsPage extends StatefulWidget {
  final String taskId;
  final String title;
  final String location;

  const TaskDetailsPage({
    super.key,
    required this.taskId,
    required this.title,
    required this.location,
  });

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage>
    with WidgetsBindingObserver {
  WorkRequest? _request;
  List<ESignature> _signatures = [];
  int _selectedTab = 0; // 0 = Timeline, 1 = Details, 2 = Signatures
  final Map<String, String> _userNames = {};
  AuthService? _cachedAuthService;
  bool _didBindAuthService = false;
  Timer? _autoRefreshTimer;
  bool _isLoading = true;
  bool _isStartingWork = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRequest();
    _startAutoRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didBindAuthService) {
      _cachedAuthService = context.read<AuthService>();
      _didBindAuthService = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRequest();
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _loadRequest();
    });
  }

  PreInspectionReport? _preInspectionReport;
  List<PostRepairReport> _postRepairReports = [];

  Future<void> _loadRequest() async {
    try {
      final request = await WorkRequestService.fetchById(widget.taskId);
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
      if (request?.assignedToId != null && request!.assignedToId!.trim().isNotEmpty) {
        userIds.add(request.assignedToId!.trim());
      }
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

      var resolvedRequest = request;
      if (resolvedRequest != null && resolvedRequest.requestorName.trim().isEmpty) {
        ESignature? reqSig;
        for (final s in signatures) {
          final type = s.signatureType.toLowerCase();
          final role = s.signerRole.toLowerCase();
          if (type == 'requestor' ||
              type == 'request' ||
              role == 'teacher' ||
              (resolvedRequest.requestorId != null && s.signerId == resolvedRequest.requestorId)) {
            reqSig = s;
            break;
          }
        }
        if (reqSig != null && reqSig.signerName.trim().isNotEmpty) {
          final sName = reqSig.signerName.trim();
          resolvedRequest = resolvedRequest.copyWith(
            requestorName: sName,
            reportedByName: sName,
          );
        } else if (resolvedRequest.requestorId != null && _userNames.containsKey(resolvedRequest.requestorId)) {
          final uName = _userNames[resolvedRequest.requestorId]!;
          resolvedRequest = resolvedRequest.copyWith(
            requestorName: uName,
            reportedByName: uName,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _request = resolvedRequest;
        _preInspectionReport = preInspection;
        _postRepairReports = postRepairs;
        _signatures = signatures;
        _isLoading = false;
      });
      if (!mounted) return;
      await _markRelatedNotificationsRead();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markRelatedNotificationsRead() async {
    try {
      if (!mounted) return;
      final user = _cachedAuthService?.currentUser;
      if (user == null) return;

      await AppNotificationService.markWorkRequestAsRead(
        role: user.role.name,
        userId: user.id,
        workRequestId: widget.taskId,
      );
    } catch (_) {}
  }

  bool get _isAssignedToCurrentUser {
    final request = _request;
    final user = _cachedAuthService?.currentUser;
    if (request == null || user == null) return false;
    return request.assignedToId?.trim() == user.id;
  }

  bool get _canStartWork {
    final request = _request;
    if (request == null) return false;
    final status = (request.status).toLowerCase();
    const allowedStatuses = {'in progress', 'in_progress', 'assigned'};
    final hasAccepted = request.acceptedDate != null;
    return _isAssignedToCurrentUser &&
        !hasAccepted &&
        allowedStatuses.contains(status);
  }

  bool get _canSubmitPreInspection {
    final request = _request;
    if (request == null) return false;
    final s = request.status.toLowerCase();
    return (s == 'in progress' || s == 'in_progress' || s == 'accepted by maintenance') &&
        _preInspectionReport == null;
  }

  bool get _canSubmitPostRepair {
    final request = _request;
    if (request == null) return false;
    if (_isCompleted) return false;
    final s = request.status.toLowerCase();
    final isConfirmed = s == 'confirmed';
    final isPreInspApproved = _preInspectionReport != null &&
        (_preInspectionReport!.status.toLowerCase() == 'approved' ||
            _preInspectionReport!.adminApproved == true);
    final isRework = s == 'rework' || s == 'for rework' || s == 'rework needed';

    if (_postRepairReports.isNotEmpty) {
      final sortedAttempts = List<PostRepairReport>.from(_postRepairReports)
        ..sort((a, b) => a.attemptNumber.compareTo(b.attemptNumber));
      final latest = sortedAttempts.last;
      // If latest report is still pending admin evaluation, technician CANNOT submit another report!
      if (latest.adminEvaluation == null ||
          latest.status.toLowerCase() == 'pending' ||
          latest.status.toLowerCase() == 'submitted') {
        return false;
      }
      // If latest report was evaluated as rework, technician CAN submit a new report!
      if (latest.adminEvaluation == 'rework') return true;
      return false;
    }

    return (isConfirmed && isPreInspApproved) || isRework || (s == 'in progress' && isPreInspApproved);
  }

  bool get _isCompleted {
    return _request?.status.toLowerCase() == 'completed';
  }


  Future<void> _startWorkWithSignature(String signatureData) async {
    final request = _request;
    final user = _cachedAuthService?.currentUser;
    if (request == null || user == null) return;

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Do you want to proceed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    setState(() {
      _isStartingWork = true;
    });

    try {
      await ESignatureService.insert(
        ESignature(
          id: '',
          workRequestId: request.id,
          signerId: user.id,
          signerName: user.name,
          signerRole: 'maintenance',
          signatureType: 'acceptance',
          signatureData: signatureData,
          signedAt: DateTime.now(),
        ),
      );

      await WorkRequestService.acceptByMaintenance(
        request.id,
        user.id,
        user.name,
      );

      await AppNotificationService.notifyAcceptedToAdminAndRequestor(
        workRequestId: request.id,
        maintenanceName: user.name,
        maintenanceUserId: user.id,
        adminId: request.approvedById,
        requestorId: request.requestorId,
      );

      await _loadRequest();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Work started successfully.'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStartingWork = false;
        });
      }
    }
  }



  Widget _buildTabBar(ThemeProvider themeProvider) {
    final tabs = ['Timeline', 'Details', 'Signatures'];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeProvider.borderColor),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF4169E1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF4169E1).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    tabs[index],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : themeProvider.subtitleColor,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: themeProvider.backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final request = _request;
    final assignedToCurrentUser = _isAssignedToCurrentUser;

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.appBarColor,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Work Request Details',
          style: TextStyle(
            color: themeProvider.appBarTextColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: themeProvider.appBarIconColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTabBar(themeProvider),
              if (_selectedTab == 0) ...[
                _buildHeaderCard(request),
                const SizedBox(height: 16),
                if (!assignedToCurrentUser) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: const Text(
                      'This request is assigned to another maintenance staff. You can only view the request details.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFF59E0B),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_preInspectionReport != null) ...[
                    _buildPreInspectionStatusBanner(themeProvider),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final req = _request;
                          if (req == null) return;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PreInspectionPage(request: req),
                            ),
                          );
                          _loadRequest();
                        },
                        icon: const Icon(Icons.assignment_outlined, size: 18),
                        label: const Text(
                          'View Pre-Inspection Report',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4169E1),
                          side: const BorderSide(color: Color(0xFF4169E1)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_postRepairReports.isNotEmpty) ...[
                    _buildPostRepairStatusBanner(themeProvider),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final req = _request;
                          if (req == null) return;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostRepairPage(
                                request: req,
                                forceHistoryView: true,
                              ),
                            ),
                          );
                          _loadRequest();
                        },
                        icon: const Icon(Icons.history_outlined, size: 18),
                        label: Text(
                          _postRepairReports.length > 1
                              ? 'View Post-Inspection Reports (${_postRepairReports.length} Attempts)'
                              : 'View Post-Inspection Report',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          side: const BorderSide(color: Color(0xFF10B981)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
                if (assignedToCurrentUser) ...[
                  if (_canStartWork) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: themeProvider.isDarkMode ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Text(
                        'You are assigned to this work request. Sign below to confirm and start work.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF10B981),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isStartingWork)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4169E1),
                          ),
                        ),
                      )
                    else
                      SignaturePadWidget(
                        title: 'E-Signature to Start Work',
                        subtitle:
                            'Sign to confirm you will start this assigned request',
                        onSignatureComplete: _startWorkWithSignature,
                      ),
                    const SizedBox(height: 16),
                  ] else ...[
                    // Pre-Inspection Section
                    if (_preInspectionReport != null) ...[
                      _buildPreInspectionStatusBanner(themeProvider),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final req = _request;
                            if (req == null) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PreInspectionPage(request: req),
                              ),
                            );
                            _loadRequest();
                          },
                          icon: const Icon(Icons.assignment_outlined, size: 18),
                          label: const Text(
                            'View Pre-Inspection Report',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4169E1),
                            side: const BorderSide(color: Color(0xFF4169E1)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else if (_isAssignedToCurrentUser && _canSubmitPreInspection) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final req = _request;
                            if (req == null) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PreInspectionPage(
                                  request: req,
                                ),
                              ),
                            );
                            _loadRequest();
                          },
                          icon: const Icon(Icons.assignment_outlined),
                          label: const Text(
                            'Start Pre-Inspection',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4169E1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Post-Inspection / Post-Repair Section
                    if (_postRepairReports.isNotEmpty) ...[
                      _buildPostRepairStatusBanner(themeProvider),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final req = _request;
                            if (req == null) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostRepairPage(
                                  request: req,
                                  forceHistoryView: true,
                                ),
                              ),
                            );
                            _loadRequest();
                          },
                          icon: const Icon(Icons.history_outlined, size: 18),
                          label: Text(
                            _postRepairReports.length > 1
                                ? 'View Post-Inspection Reports (${_postRepairReports.length} Attempts)'
                                : 'View Post-Inspection Report',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_isAssignedToCurrentUser && _canSubmitPostRepair) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final req = _request;
                            if (req == null) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostRepairPage(
                                  request: req,
                                  forceHistoryView: false,
                                ),
                              ),
                            );
                            _loadRequest();
                          },
                          icon: const Icon(Icons.build_outlined),
                          label: Text(
                            _postRepairReports.isEmpty
                                ? 'Submit Post-Repair Report'
                                : 'Submit Rework / Post-Repair Report',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_isCompleted) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'This work request has been completed.',
                          style: TextStyle(
                            fontSize: 12,
                            color: themeProvider.subtitleColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
                _buildDetailCard(
                  title: 'WORKFLOW TIMELINE',
                  children: [
                    _buildWorkflowTimeline(),
                  ],
                ),
              ],
              if (_selectedTab == 1) ...[
                _buildDetailCard(
                  title: 'WORK REQUEST DETAILS',
                  children: [
                    _buildDetailRow(
                      'Tracking Number',
                      (request?.id ?? widget.taskId).length > 8
                          ? '#${(request?.id ?? widget.taskId).substring(0, 8).toUpperCase()}'
                          : '#${(request?.id ?? widget.taskId).toUpperCase()}',
                    ),
                    _buildDetailRow('Title', request?.title ?? widget.title),
                    _buildDetailRow('Type', _safeValue(request?.typeOfRequest)),
                    _buildDetailRow(
                      'Priority',
                      _priorityLabel(request?.priority),
                    ),
                    _buildDetailRow('Status', _statusLabel(request?.status)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailCard(
                  title: 'REQUESTOR INFORMATION',
                  children: [
                    _buildDetailRow(
                      'Requestor',
                      _safeValue(request?.requestorName),
                    ),
                    _buildDetailRow(
                      'Position',
                      _safeValue(request?.requestorPosition),
                    ),
                    _buildDetailRow(
                      'Reported By',
                      _safeValue(request?.reportedByName ?? request?.requestorName),
                    ),
                    _buildDetailRow(
                      'Submitted',
                      _formatDate(request?.dateSubmitted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailCard(
                  title: 'LOCATION',
                  children: [
                    _buildDetailRow(
                      'Building',
                      _safeValue(request?.buildingName),
                    ),
                    _buildDetailRow(
                      'Room',
                      _safeValue(request?.roomName ?? widget.location),
                    ),
                    _buildDetailRow(
                      'Department',
                      _safeValue(request?.departmentName),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailCard(
                  title: 'ASSIGNMENT',
                  children: [
                    _buildDetailRow(
                      'Assigned To',
                      _assignedMaintenanceName(request?.assignedToId),
                    ),
                    _buildDetailRow(
                      'Accepted Date',
                      _getAcceptedDateFormatted(request),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailCard(
                  title: 'ISSUE DESCRIPTION',
                  children: [
                    Text(
                      (request?.description.isNotEmpty == true)
                          ? request!.description
                          : 'No issue description provided.',
                      style: TextStyle(
                        fontSize: 13,
                        color: themeProvider.textColor,
                        height: 1.5,
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final req = request;
                        if (req == null) return const SizedBox.shrink();
                        final attachments = [
                          if (req.attachmentUrls != null) ...req.attachmentUrls!,
                          if (req.workEvidence != null &&
                              req.workEvidence!.trim().isNotEmpty &&
                              (req.attachmentUrls == null ||
                                  !req.attachmentUrls!.contains(req.workEvidence!.trim())))
                            req.workEvidence!.trim(),
                        ];

                        if (attachments.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            Text(
                              'Photo Evidence / Attachments',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.subtitleColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 90,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: attachments.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 8),
                                itemBuilder: (context, idx) {
                                  final url = attachments[idx];
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildAttachmentThumbnail(url),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ],
              if (_selectedTab == 2) ...[
                _buildSignaturesTab(request),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignaturesTab(WorkRequest? request) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    if (_signatures.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: themeProvider.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: themeProvider.borderColor),
        ),
        child: Column(
          children: [
            Icon(Icons.verified_user_outlined, size: 48, color: themeProvider.subtitleColor.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No signatures recorded yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: themeProvider.subtitleColor,
              ),
            ),
          ],
        ),
      );
    }

    final sorted = [..._signatures]..sort((a, b) => a.signedAt.compareTo(b.signedAt));

    return Column(
      children: sorted.map((sig) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeProvider.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeProvider.borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _signatureLabel(sig, request),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Signed by: ${sig.signerName}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Role: ${sig.signerRole.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: themeProvider.subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: themeProvider.borderColor),
                ),
                child: Text(
                  _formatDateTime(sig.signedAt),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.subtitleColor,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAttachmentThumbnail(String url) {
    if (url.startsWith('data:image')) {
      try {
        final base64Str = url.split(',').last;
        return Image.memory(
          base64Decode(base64Str),
          width: 90,
          height: 90,
          fit: BoxFit.cover,
        );
      } catch (_) {
        return Container(
          width: 90,
          height: 90,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
        );
      }
    }
    return Image.network(
      url,
      width: 90,
      height: 90,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: 90,
        height: 90,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
      ),
    );
  }

  Widget _buildHeaderCard(WorkRequest? request) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final status = _statusLabel(request?.status);
    final priority = _priorityLabel(request?.priority);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeProvider.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request?.title ?? widget.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: themeProvider.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _safeValue(request?.typeOfRequest),
            style: TextStyle(fontSize: 12, color: themeProvider.subtitleColor),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(
                status,
                const Color(0xFFE0E7FF),
                const Color(0xFF1D4ED8),
              ),
              _buildChip(
                priority,
                themeProvider.isDarkMode ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                themeProvider.isDarkMode ? Colors.white : const Color(0xFF374151),
              ),
              _buildChip(
                _isAssignedToCurrentUser ? 'Assigned to you' : 'View only',
                _isAssignedToCurrentUser
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFEF3C7),
                _isAssignedToCurrentUser
                    ? const Color(0xFF065F46)
                    : const Color(0xFF92400E),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String text, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required List<Widget> children,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeProvider.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: themeProvider.subtitleColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: themeProvider.subtitleColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: themeProvider.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _safeValue(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  String _priorityLabel(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'low':
        return 'Low Priority';
      case 'medium':
        return 'Medium Priority';
      case 'high':
        return 'High Priority';
      default:
        return '-';
    }
  }

  String _statusLabel(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'pending':
      case 'pending assignment':
        return 'Pending';
      case 'in progress':
      case 'in_progress':
      case 'assigned':
      case 'accepted by maintenance':
        return 'In Progress';
      case 'declined':
      case 'cancelled':
      case 'declined/cancelled':
      case 'pre-inspection declined':
        return 'Declined';
      case 'confirmed':
      case 'pre-inspection approved':
      case 'under_maintenance':
        return 'Confirmed';
      case 'rework':
      case 'for rework':
        return 'Rework';
      case 'completed':
        return 'Completed';
      default:
        return _safeValue(value);
    }
  }

  String _signatureLabel(ESignature signature, WorkRequest? request) {
    final role = signature.signerRole.trim().toLowerCase();
    final type = signature.signatureType.trim().toLowerCase();

    // 1. Campus Admin approval signature must ALWAYS be labeled "Approved By:"
    if (type == 'approval' || type == 'admin_approval' || type == 'admin') {
      return 'Approved By:';
    }

    // 2. Specific workflow steps
    if (type == 'pre_inspection') return 'Pre-Inspection';
    if (type == 'pre_inspection_approval' || type == 'pre_inspection_admin') return 'Pre-Inspection Approval';
    if (type == 'post_repair') return 'Post-Repair';
    if (type == 'acceptance') return 'Maintenance Acceptance';

    // 3. Completion
    if (type == 'completion') {
      if (role == 'admin' || role == 'campadmin' || role == 'campus admin') return 'Admin Completion';
      if (role == 'maintenance') return 'Maintenance Completion';
      return 'Completion Signature';
    }

    // 4. Initial request creation signature
    if (type == 'request' || type == 'requestor' || type == 'submission') {
      return 'Requestor Signature';
    }

    final isRequestor =
        (request?.requestorId?.trim().isNotEmpty == true &&
            signature.signerId.trim() == request!.requestorId!.trim()) ||
        role == 'teacher' ||
        role == 'faculty';

    if (isRequestor && (type.isEmpty || type == 'requestor_sign')) {
      return 'Requestor Signature';
    }

    return signature.signatureTypeLabel;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }


  bool _isUnassigned(String? staffId) {
    final normalized = staffId?.trim().toLowerCase();
    return normalized == null || normalized.isEmpty || normalized == 'null';
  }

  String _assignedMaintenanceName(String? staffId) {
    if (_isUnassigned(staffId)) return 'Unassigned';
    if (staffId != null && _userNames.containsKey(staffId) && _userNames[staffId]!.trim().isNotEmpty) {
      return _userNames[staffId]!;
    }
    if (_request?.acceptedByName != null && _request!.acceptedByName!.trim().isNotEmpty) {
      return _request!.acceptedByName!;
    }
    final current = _cachedAuthService?.currentUser;
    if (current != null && current.id == staffId) {
      return current.name;
    }
    return 'Assigned Staff';
  }

  String _getAcceptedDateFormatted(WorkRequest? request) {
    if (request == null) return '-';
    DateTime? date = request.acceptedDate;
    if (date == null) {
      for (final s in _signatures) {
        if (s.signatureType.toLowerCase() == 'acceptance') {
          date = s.signedAt;
          break;
        }
      }
    }
    if (date == null) return '-';
    return _formatDateTime(date);
  }

  Widget _buildPreInspectionStatusBanner(ThemeProvider themeProvider) {
    final rep = _preInspectionReport;
    if (rep == null) return const SizedBox.shrink();

    final isApproved = rep.status == 'Approved';
    final isDeclined = rep.status == 'Declined';
    final color = isApproved
        ? const Color(0xFF059669)
        : (isDeclined ? const Color(0xFFDC2626) : const Color(0xFF2563EB));
    final bg = isApproved
        ? (themeProvider.isDarkMode ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5))
        : (isDeclined
            ? (themeProvider.isDarkMode ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2))
            : (themeProvider.isDarkMode ? const Color(0xFF1E3A5F).withValues(alpha: 0.3) : const Color(0xFFEEF2FF)));
    final border = isApproved
        ? const Color(0xFFA7F3D0)
        : (isDeclined ? const Color(0xFFFECACA) : const Color(0xFFBFDBFE));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            isApproved
                ? Icons.verified_outlined
                : (isDeclined ? Icons.cancel_outlined : Icons.pending_actions_rounded),
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pre-Inspection: ${rep.status.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (rep.reviewNotes != null && rep.reviewNotes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Notes: ${rep.reviewNotes}',
                    style: TextStyle(
                      fontSize: 11,
                      color: themeProvider.textColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostRepairStatusBanner(ThemeProvider themeProvider) {
    if (_postRepairReports.isEmpty) return const SizedBox.shrink();
    final sortedAttempts = List<PostRepairReport>.from(_postRepairReports)
      ..sort((a, b) => a.attemptNumber.compareTo(b.attemptNumber));
    final last = sortedAttempts.last;
    final isSatisfied = last.adminEvaluation == 'satisfied' || _isCompleted;
    final isRework = last.adminEvaluation == 'rework';

    final color = isSatisfied
        ? const Color(0xFF059669)
        : (isRework ? const Color(0xFFDC2626) : const Color(0xFFD97706));
    final bg = isSatisfied
        ? (themeProvider.isDarkMode ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5))
        : (isRework
            ? (themeProvider.isDarkMode ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2))
            : (themeProvider.isDarkMode ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFFFBEB)));
    final border = isSatisfied
        ? const Color(0xFFA7F3D0)
        : (isRework ? const Color(0xFFFECACA) : const Color(0xFFFDE68A));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            isSatisfied
                ? Icons.check_circle_outline
                : (isRework ? Icons.warning_amber_rounded : Icons.hourglass_top_rounded),
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSatisfied
                      ? 'Post-Inspection: APPROVED / COMPLETED'
                      : (isRework
                          ? 'Post-Inspection: REWORK REQUIRED'
                          : 'Post-Inspection: SUBMITTED (Awaiting Evaluation)'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (last.adminEvaluationNotes != null && last.adminEvaluationNotes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Notes: ${last.adminEvaluationNotes}',
                    style: TextStyle(
                      fontSize: 11,
                      color: themeProvider.textColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required bool isDone,
    bool isRework = false,
    String? subtitle,
    Widget? details,
    bool isLast = false,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final circleColor = isRework
        ? const Color(0xFFD97706)
        : (isDone ? const Color(0xFF059669) : (isDark ? Colors.grey.shade700 : Colors.grey.shade300));
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
                      : (isDone ? themeProvider.textColor : themeProvider.subtitleColor),
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: themeProvider.subtitleColor,
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

  Widget _buildWorkflowTimeline() {
    final request = _request;
    if (request == null) return const SizedBox.shrink();

    final List<Widget> items = [];

    // 1. Submission
    items.add(
      _buildTimelineItem(
        title: 'Work Request Submitted',
        isDone: true,
        subtitle: 'By ${request.requestorName} on ${_formatDateTime(request.dateSubmitted)}',
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
            request.acceptedDate != null);
    items.add(
      _buildTimelineItem(
        title: 'Technician Accepted Task',
        isDone: isAccepted,
        subtitle: isAccepted
            ? 'Accepted by ${request.acceptedByName ?? _assignedMaintenanceName(request.assignedToId)} on ${_formatDateTime(request.acceptedDate ?? acceptSig.signedAt)}'
            : 'Awaiting technician acceptance',
      ),
    );

    // 4. Pre-Inspection
    final preInspection = _preInspectionReport;
    final isPreInspectionSubmitted = preInspection != null;
    items.add(
      _buildTimelineItem(
        title: 'Pre-Inspection Report Filed',
        isDone: isPreInspectionSubmitted,
        subtitle: isPreInspectionSubmitted
            ? 'Submitted by ${preInspection.inspectorName}'
            : 'Awaiting pre-inspection submission',
        details: null,
      ),
    );

    // 5. Pre-Inspection Approval/Decline
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
        details: null,
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
        final attemptSuffix = sortedAttempts.length > 1 ? ' (Attempt #${report.attemptNumber})' : '';
        items.add(
          _buildTimelineItem(
            title: 'Post-Repair Report$attemptSuffix',
            isDone: true,
            subtitle: 'Submitted by ${report.technicianName}',
            details: null,
          ),
        );

        final isEvaluated = report.adminEvaluation != null;
        final isRework = report.adminEvaluation == 'rework';
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
              details: null,
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
            details: null,
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
          details: null,
        ),
      );

      items.add(
        _buildTimelineItem(
          title: 'Post-Repair Evaluation',
          isDone: false,
          subtitle: 'Pending post-repair report submission.',
          details: null,
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
      ),
    );

    return Column(
      children: items,
    );
  }
}

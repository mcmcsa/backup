import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
import '../../admin/ticket/admin_pre_inspection_review_page.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/services/post_repair_service.dart';
import 'post_repair_page.dart';
import '../../../shared/services/user_service.dart';

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
  final ImagePicker _picker = ImagePicker();
  final Map<String, String> _userNames = {};
  AuthService? _cachedAuthService;
  bool _didBindAuthService = false;
  Timer? _autoRefreshTimer;
  bool _isLoading = true;
  bool _isStartingWork = false;
  bool _isConfirmingWork = false;

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

      if (!mounted) return;
      setState(() {
        _request = request;
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
    const allowedStatuses = {'in progress', 'in_progress'};
    final hasAccepted = request.acceptedDate != null;
    return _isAssignedToCurrentUser &&
        !hasAccepted &&
        allowedStatuses.contains(status);
  }

  bool get _hasCurrentUserCompletionSignature {
    final user = _cachedAuthService?.currentUser;
    if (user == null) return false;
    return _signatures.any(
      (sig) =>
          sig.signatureType == 'completion' && sig.signerId.trim() == user.id,
    );
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

  Future<void> _confirmWorkWithSignature(String signatureData) async {
    final request = _request;
    final user = _cachedAuthService?.currentUser;
    if (request == null || user == null) return;

    if (_hasCurrentUserCompletionSignature) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already submitted your completion signature.'),
          backgroundColor: Color(0xFF1D4ED8),
        ),
      );
      return;
    }

    setState(() => _isConfirmingWork = true);

    try {
      await ESignatureService.insert(
        ESignature(
          id: '',
          workRequestId: request.id,
          signerId: user.id,
          signerName: user.name,
          signerRole: 'maintenance',
          signatureType: 'completion',
          signatureData: signatureData,
          signedAt: DateTime.now(),
          notes: 'Maintenance completion confirmation signature',
        ),
      );

      await AppNotificationService.notifyCompletionSubmittedToAdmin(
        workRequestId: request.id,
        maintenanceName: user.name,
        adminId: request.approvedById,
      );

      await WorkRequestService.updateStatus(request.id, request.status);
      await _loadRequest();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completion signature submitted. Awaiting admin approval.',
          ),
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
        setState(() => _isConfirmingWork = false);
      }
    }
  }

  Future<void> _openConfirmWorkRequestSheet() async {
    final request = _request;
    if (request == null) return;

    File? selectedEvidenceImage;
    String? uploadedEvidenceUrl = request.workEvidence;
    bool isUploadingEvidence = false;
    final maintenanceNoteController = TextEditingController(
      text: request.maintenanceNotes ?? '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8F9FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.9,
            minChildSize: 0.65,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return StatefulBuilder(
                builder: (context, setModalState) {
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
                          'Confirm Work Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Review request details and sign to submit your completion confirmation.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailCard(
                          title: 'WORK REQUEST DETAILS',
                          children: [
                            _buildDetailRow('Tracking Number', request.id),
                            _buildDetailRow('Title', request.title),
                            _buildDetailRow(
                              'Status',
                              _statusLabel(request.status),
                            ),
                            _buildDetailRow(
                              'Requestor',
                              _safeValue(request.requestorName),
                            ),
                            _buildDetailRow(
                              'Building',
                              _safeValue(request.buildingName),
                            ),
                            _buildDetailRow(
                              'Room',
                              _safeValue(request.roomName),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_signatures.isNotEmpty) ...[
                          _buildDetailCard(
                            title: 'CURRENT SIGNATURES',
                            children:
                                ([..._signatures]..sort(
                                      (a, b) =>
                                          a.signedAt.compareTo(b.signedAt),
                                    ))
                                    .map(
                                      (sig) => _buildDetailRow(
                                        _signatureLabel(sig, request),
                                        '${sig.signerName} (${_formatDate(sig.signedAt)})',
                                      ),
                                    )
                                    .toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _buildDetailCard(
                          title: 'WORK EVIDENCE',
                          children: [
                            if (uploadedEvidenceUrl != null &&
                                uploadedEvidenceUrl!.trim().isNotEmpty) ...[
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
                                      uploadedEvidenceUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: const Text(
                                          'Uploaded evidence preview unavailable',
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
                              const SizedBox(height: 10),
                              const Text(
                                'Evidence uploaded successfully.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ] else if (selectedEvidenceImage != null) ...[
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
                                    child: Image.file(
                                      selectedEvidenceImage!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Selected image ready for upload.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ] else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 22,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: const Text(
                                  'No work evidence image selected.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: isUploadingEvidence
                                        ? null
                                        : () async {
                                            final image =
                                                await _pickEvidenceImage(
                                                  ImageSource.camera,
                                                );
                                            if (image == null || !mounted) {
                                              return;
                                            }
                                            setModalState(() {
                                              selectedEvidenceImage = image;
                                              uploadedEvidenceUrl = null;
                                            });
                                          },
                                    icon: const Icon(Icons.camera_alt_outlined),
                                    label: const Text('Take Photo'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: isUploadingEvidence
                                        ? null
                                        : () async {
                                            final image =
                                                await _pickEvidenceImage(
                                                  ImageSource.gallery,
                                                );
                                            if (image == null || !mounted) {
                                              return;
                                            }
                                            setModalState(() {
                                              selectedEvidenceImage = image;
                                              uploadedEvidenceUrl = null;
                                            });
                                          },
                                    icon: const Icon(
                                      Icons.photo_library_outlined,
                                    ),
                                    label: const Text('Gallery'),
                                  ),
                                ),
                              ],
                            ),
                            if (isUploadingEvidence) ...[
                              const SizedBox(height: 10),
                              const Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Uploading evidence image...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailCard(
                          title: 'MAINTENANCE NOTE',
                          children: [
                            TextField(
                              controller: maintenanceNoteController,
                              maxLines: 4,
                              minLines: 3,
                              decoration: InputDecoration(
                                hintText:
                                    'Add note about the work done, findings, or reminders for admin/requestor...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
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
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SignaturePadWidget(
                          title: 'E-Signature to Confirm Work Request',
                          subtitle: 'Sign to confirm this task is completed',
                          onSignatureComplete: (signatureData) async {
                            if (uploadedEvidenceUrl == null &&
                                selectedEvidenceImage == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please attach a work evidence image before signing.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            try {
                              if (uploadedEvidenceUrl == null &&
                                  selectedEvidenceImage != null) {
                                setModalState(() {
                                  isUploadingEvidence = true;
                                });

                                final uploadedUrl =
                                    await _uploadWorkEvidenceImage(
                                      requestId: request.id,
                                      imageFile: selectedEvidenceImage!,
                                    );

                                await WorkRequestService.updateWorkEvidence(
                                  request.id,
                                  uploadedUrl,
                                );

                                uploadedEvidenceUrl = uploadedUrl;
                              }

                              await WorkRequestService.updateMaintenanceNote(
                                request.id,
                                maintenanceNoteController.text,
                              );

                              if (!context.mounted) return;
                              Navigator.of(sheetContext).pop();
                              await _confirmWorkWithSignature(signatureData);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Evidence upload failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } finally {
                              if (context.mounted) {
                                setModalState(() {
                                  isUploadingEvidence = false;
                                });
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );

    maintenanceNoteController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final request = _request;
    final assignedToCurrentUser = _isAssignedToCurrentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Work Request Details',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(request),
              const SizedBox(height: 16),
              _buildDetailCard(
                title: 'WORK REQUEST DETAILS',
                children: [
                  _buildDetailRow(
                    'Tracking Number',
                    request?.id ?? widget.taskId,
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
                title: 'ISSUE DESCRIPTION',
                children: [
                  Text(
                    (request?.description.isNotEmpty == true)
                        ? request!.description
                        : 'No issue description provided.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailCard(
                title: 'ASSIGNMENT',
                children: [
                  _buildDetailRow(
                    'Assigned To',
                    _safeValue(request?.assignedToId),
                  ),
                  _buildDetailRow(
                    'Accepted By',
                    _safeValue(request?.acceptedByName),
                  ),
                  _buildDetailRow(
                    'Accepted Date',
                    _formatDate(request?.acceptedDate),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailCard(
                title: 'WORKFLOW TIMELINE',
                children: [
                  _buildWorkflowTimeline(),
                ],
              ),
              const SizedBox(height: 16),
              if (!assignedToCurrentUser)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: const Text(
                    'This request is assigned to another maintenance staff. You can only view the request details.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF92400E),
                      height: 1.5,
                    ),
                  ),
                ),
              if (assignedToCurrentUser) ...[
                if (_canStartWork) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Text(
                      'You are assigned to this work request. Sign below to confirm and start work.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF065F46),
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
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      (request?.acceptedDate != null)
                          ? 'You already confirmed this request.'
                          : (request?.status.toLowerCase() == 'pending' || request?.status.toLowerCase() == 'pending assignment')
                          ? 'Waiting for admin approval before you can confirm this request.'
                          : 'This request cannot be confirmed at the moment.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1D4ED8),
                        height: 1.5,
                      ),
                    ),
                  ),
                  if ((request?.status.toLowerCase() == 'in progress' || request?.status.toLowerCase() == 'in_progress') && _preInspectionReport == null) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PreInspectionPage(request: request!),
                          ),
                        ).then((_) => _loadRequest());
                      },
                      icon: const Icon(Icons.assignment_outlined, color: Colors.white),
                      label: const Text(
                        'Start Pre-Inspection',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4169E1),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                  if (_preInspectionReport != null) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminPreInspectionReviewPage(request: request!),
                          ),
                        ).then((_) => _loadRequest());
                      },
                      icon: const Icon(Icons.assignment_outlined, color: Colors.white),
                      label: const Text(
                        'View Pre-Inspection Report',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4169E1),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                  if (request?.status.toLowerCase() == 'confirmed' || request?.status.toLowerCase() == 'rework') ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostRepairPage(request: request!),
                          ),
                        ).then((_) => _loadRequest());
                      },
                      icon: const Icon(Icons.build_circle_outlined, color: Colors.white),
                      label: const Text(
                        'Start Post-Repair Inspection',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFA5),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                  if (_postRepairReports.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostRepairPage(request: request!),
                          ),
                        ).then((_) => _loadRequest());
                      },
                      icon: const Icon(Icons.history, color: Colors.white),
                      label: const Text(
                        'View Post-Repair Reports',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4169E1),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                  if (request?.status.toLowerCase() == 'confirmed' || request?.status.toLowerCase() == 'rework') ...[
                    const SizedBox(height: 16),
                    if (_isConfirmingWork)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4169E1),
                          ),
                        ),
                      ),
                    ElevatedButton(
                      onPressed:
                          (_isConfirmingWork ||
                              _hasCurrentUserCompletionSignature)
                          ? null
                          : _openConfirmWorkRequestSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFD1D5DB),
                        disabledForegroundColor: const Color(0xFF6B7280),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: Text(
                            _hasCurrentUserCompletionSignature
                                ? 'Work Request Already Confirmed'
                                : 'Confirm Work Request',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_hasCurrentUserCompletionSignature)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Your completion signature has already been submitted for this request.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                  ],
                ],
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(WorkRequest? request) {
    final status = _statusLabel(request?.status);
    final priority = _priorityLabel(request?.priority);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request?.title ?? widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _safeValue(request?.typeOfRequest),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                const Color(0xFFF3F4F6),
                const Color(0xFF374151),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
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
    final isRequestor =
        (request?.requestorId?.trim().isNotEmpty == true &&
            signature.signerId.trim() == request!.requestorId!.trim()) ||
        role == 'teacher';

    if (isRequestor && (type == 'approval' || type == 'completion')) {
      return 'Requestor Sign';
    }

    if (type == 'completion') {
      if (role == 'admin') return 'Admin Completion';
      if (role == 'maintenance') return 'Maintenance Completion';
    }

    return signature.signatureTypeLabel;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<File?> _pickEvidenceImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );
      if (image == null) return null;
      return File(image.path);
    } catch (_) {
      return null;
    }
  }

  Future<String> _uploadWorkEvidenceImage({
    required String requestId,
    required File imageFile,
  }) async {
    final client = Supabase.instance.client;
    const candidateBuckets = <String>[
      'work-evidence',
      'work_evidence',
      'evidence',
      'images',
      'public',
    ];
    final fileName = imageFile.path.split(RegExp(r'[\\/]')).last;
    final path =
        '$requestId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    Exception? lastError;

    for (final bucket in candidateBuckets) {
      try {
        await client.storage
            .from(bucket)
            .upload(
              path,
              imageFile,
              fileOptions: const FileOptions(upsert: false),
            );
        return client.storage.from(bucket).getPublicUrl(path);
      } catch (e) {
        lastError = Exception(e.toString());
      }
    }

    throw Exception(
      'No usable storage bucket found for work evidence upload. '
      'Tried: ${candidateBuckets.join(', ')}. '
      'Last error: ${lastError?.toString() ?? 'unknown'}',
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

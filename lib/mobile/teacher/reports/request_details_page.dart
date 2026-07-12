import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/signature_pad_widget.dart';

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
  bool _isSubmittingCompletionSignature = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRequest();
    _startAutoRefresh();
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

  Future<void> _loadRequest() async {
    try {
      final request = await WorkRequestService.fetchById(widget.trackingNumber);
      final signatures = request != null
          ? await ESignatureService.fetchByWorkRequest(request.id)
          : <ESignature>[];
      if (mounted) {
        setState(() {
          _request = request;
          _signatures = signatures;
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

  bool get _hasAdminCompletionSignature {
    return _signatures.any(
      (sig) => sig.signatureType == 'completion' && sig.signerRole == 'admin',
    );
  }

  bool get _hasCurrentUserCompletionSignature {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return false;
    return _signatures.any(
      (sig) =>
          sig.signatureType == 'completion' && sig.signerId.trim() == user.id,
    );
  }

  Future<void> _submitRequestorCompletionSignature(String signatureData) async {
    final request = _request;
    final user = context.read<AuthService>().currentUser;
    if (request == null || user == null) return;

    if (_hasCurrentUserCompletionSignature) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already signed the confirm work request form.'),
          backgroundColor: Color(0xFF1D4ED8),
        ),
      );
      return;
    }

    setState(() => _isSubmittingCompletionSignature = true);

    try {
      await ESignatureService.insert(
        ESignature(
          id: '',
          workRequestId: request.id,
          signerId: user.id,
          signerName: user.name,
          signerRole: user.role.name,
          signatureType: 'completion',
          signatureData: signatureData,
          signedAt: DateTime.now(),
          notes: 'Requestor completion confirmation signature',
        ),
      );

      await WorkRequestService.completeRequest(request.id);

      await _loadRequest();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirm work request form signed successfully.'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit signature: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingCompletionSignature = false);
      }
    }
  }

  Future<void> _openRequestorConfirmSignatureSheet() async {
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
                      'Confirm Work Request Form',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Request ID: ${_request?.id ?? widget.trackingNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      'Title: ${_request?.title ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
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
                    if (((_request?.workEvidence ?? '')).trim().isNotEmpty)
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
                              _request!.workEvidence!,
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
                        ((_request?.maintenanceNotes ?? '')).trim().isNotEmpty
                            ? _request!.maintenanceNotes!.trim()
                            : 'No maintenance note provided.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF374151),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (completionSignatures.isNotEmpty) ...[
                      const Text(
                        'Current Completion Signers',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...completionSignatures.map(
                        (sig) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${sig.signatureTypeLabel}: ${sig.signerName} (${_formatDate(sig.signedAt)})',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SignaturePadWidget(
                      title: 'E-Signature for Requestor Confirmation',
                      subtitle: 'Sign to confirm completion of your request',
                      onSignatureComplete: (signatureData) async {
                        Navigator.of(sheetContext).pop();
                        await _submitRequestorCompletionSignature(
                          signatureData,
                        );
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

  int _getWorkflowStep() {
    if (_request == null) return 0;
    switch (_request!.status) {
      case 'pending':
        return 1;
      case 'approved':
        return 2;
      case 'in_progress':
        return 3;
      case 'under_maintenance':
        return 4;
      case 'completed':
        return 6;
      case 'rework':
        return 3;
      default:
        return 1;
    }
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
                    icon: Icons.category_outlined,
                    label: 'CATEGORY',
                    value1: _request?.typeOfRequest ?? 'N/A',
                    value2: _request?.priority ?? 'N/A',
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
                onPressed: () {},
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
            if (_hasAdminCompletionSignature) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  _hasCurrentUserCompletionSignature
                      ? 'You already signed the confirm work request form.'
                      : 'Admin already signed the confirm work request form. You can now add your signature.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1D4ED8),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_isSubmittingCompletionSignature)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ElevatedButton.icon(
                onPressed:
                    (_isSubmittingCompletionSignature ||
                        _hasCurrentUserCompletionSignature)
                    ? null
                    : _openRequestorConfirmSignatureSheet,
                icon: const Icon(Icons.verified, size: 18),
                label: Text(
                  _hasCurrentUserCompletionSignature
                      ? 'Confirm Form Already Signed'
                      : 'Sign Confirm Work Request Form',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Progress Timeline
            const Text(
              'Progress Timeline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            _buildTimelineItem(
              icon: _getWorkflowStep() >= 1
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              iconColor: _getWorkflowStep() >= 1
                  ? const Color(0xFF4CAF50)
                  : Colors.grey.shade400,
              title: 'Request Submitted',
              date: _request != null
                  ? _formatDate(_request!.dateSubmitted)
                  : 'Pending...',
              description: 'Logged via Mobile App',
              isCompleted: _getWorkflowStep() >= 1,
            ),
            _buildTimelineItem(
              icon: _getWorkflowStep() >= 2
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              iconColor: _getWorkflowStep() >= 2
                  ? const Color(0xFF4CAF50)
                  : Colors.grey.shade400,
              title: 'Request Approved',
              date: _getWorkflowStep() >= 2
                  ? 'Admin approved'
                  : 'Waiting for approval',
              description: '',
              isCompleted: _getWorkflowStep() >= 2,
            ),
            _buildTimelineItem(
              icon: _getWorkflowStep() >= 3
                  ? Icons.check_circle
                  : (_getWorkflowStep() == 2
                        ? Icons.circle
                        : Icons.circle_outlined),
              iconColor: _getWorkflowStep() >= 3
                  ? const Color(0xFF4CAF50)
                  : (_getWorkflowStep() == 2
                        ? const Color(0xFF2196F3)
                        : Colors.grey.shade400),
              title: 'Maintenance Accepted',
              date: _request?.acceptedDate != null
                  ? _formatDate(_request!.acceptedDate!)
                  : 'Waiting...',
              description: _request?.acceptedByName ?? '',
              isCompleted: _getWorkflowStep() >= 3,
            ),
            _buildTimelineItem(
              icon: _getWorkflowStep() >= 4
                  ? Icons.check_circle
                  : (_getWorkflowStep() == 3
                        ? Icons.circle
                        : Icons.circle_outlined),
              iconColor: _getWorkflowStep() >= 4
                  ? const Color(0xFF4CAF50)
                  : (_getWorkflowStep() == 3
                        ? const Color(0xFF2196F3)
                        : Colors.grey.shade400),
              title: 'Pre-Inspection & Repair',
              date: _request?.maintenanceStartTime != null
                  ? 'Started ${_formatDate(_request!.maintenanceStartTime!)}'
                  : 'Not started',
              description: _getWorkflowStep() == 3
                  ? 'Pre-inspection in progress'
                  : '',
              isCompleted: _getWorkflowStep() >= 4,
            ),
            _buildTimelineItem(
              icon: _getWorkflowStep() >= 5
                  ? Icons.check_circle
                  : (_getWorkflowStep() == 4
                        ? Icons.circle
                        : Icons.circle_outlined),
              iconColor: _getWorkflowStep() >= 5
                  ? const Color(0xFF4CAF50)
                  : (_getWorkflowStep() == 4
                        ? Colors.orange
                        : Colors.grey.shade400),
              title: 'Under Maintenance',
              date: _getWorkflowStep() >= 4 ? 'Work in progress' : 'Pending...',
              description: '',
              isCompleted: _getWorkflowStep() >= 5,
            ),
            _buildTimelineItem(
              icon: _getWorkflowStep() >= 6
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              iconColor: _getWorkflowStep() >= 6
                  ? const Color(0xFF4CAF50)
                  : Colors.grey.shade400,
              title: 'Resolution & Sign-off',
              date: _request?.maintenanceEndTime != null
                  ? _formatDate(_request!.maintenanceEndTime!)
                  : 'Pending...',
              description: _getWorkflowStep() >= 6 ? 'Completed' : '',
              isCompleted: _getWorkflowStep() >= 6,
              isLast: true,
            ),
            if (_request?.status == 'rework') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.red.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rework requested (${_request!.reworkCount} time${_request!.reworkCount > 1 ? 's' : ''})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

  Widget _buildTimelineItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String date,
    required String description,
    String? subtitle,
    bool isCompleted = false,
    bool isLast = false,
    bool showActions = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            if (!isLast)
              Container(width: 2, height: 60, color: Colors.grey.shade300),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
              if (showActions) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4169E1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 16,
                        color: Color(0xFF4169E1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.phone, size: 18),
                      color: const Color(0xFF2196F3),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.message, size: 18),
                      color: const Color(0xFF2196F3),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
              if (!isLast) const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} - $hour:$minute $period';
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/pre_inspection_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../shared/services/pre_inspection_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/workflow_status_badge.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/inspection_pdf_service.dart';
import '../../../shared/services/user_service.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/signature_pad_widget.dart';

/// Admin screen to review pre-inspection report and approve/reject it
class AdminPreInspectionReviewPage extends StatefulWidget {
  final WorkRequest request;

  const AdminPreInspectionReviewPage({
    super.key,
    required this.request,
  });

  @override
  State<AdminPreInspectionReviewPage> createState() => _AdminPreInspectionReviewPageState();
}

class _AdminPreInspectionReviewPageState extends State<AdminPreInspectionReviewPage> {
  bool _isLoading = true;
  bool _isProcessing = false;
  PreInspectionReport? _report;
  final _reviewNotesController = TextEditingController();
  final _rejectionNotesController = TextEditingController();

  List<ESignature> _signatures = [];
  final Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final report = await PreInspectionService.fetchLatestByWorkRequest(widget.request.id);
      final signatures = await ESignatureService.fetchByWorkRequest(widget.request.id);
      for (final sig in signatures) {
        if (sig.signerId.isNotEmpty && sig.signerName.isNotEmpty) {
          final isAdm = sig.signerRole.toLowerCase() == 'campadmin';
          _userNames[sig.signerId] = isAdm ? 'Campus Admin - ${sig.signerName}' : sig.signerName;
        }
      }
      if (report?.adminApprovedBy != null && !_userNames.containsKey(report!.adminApprovedBy)) {
        final names = await UserService.fetchNamesByIds([report.adminApprovedBy!]);
        _userNames.addAll(names);
      }
      if (!mounted) return;
      _reviewNotesController.text = report?.reviewNotes ?? '';
      setState(() {
        _report = report;
        _signatures = signatures;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _reviewNotesController.dispose();
    _rejectionNotesController.dispose();
    super.dispose();
  }

  void _openApprovalSignatureDialog() {
    showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SignaturePadWidget(
                title: 'E-Signature Required',
                subtitle: 'Sign to confirm pre-inspection approval',
                onSignatureComplete: (base64) {
                  Navigator.pop(ctx, base64);
                },
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
              ),
            ],
          ),
        ),
      ),
    ).then((signature) {
      if (signature != null && signature.isNotEmpty) {
        _approvePreInspectionWithSignature(signature);
      }
    });
  }

  Future<void> _approvePreInspectionWithSignature(String signatureData) async {
    if (_report == null) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isProcessing = true);

    try {
      // 1. Save signature
      await ESignatureService.insert(
        ESignature(
          id: '',
          workRequestId: widget.request.id,
          signerId: user.id,
          signerName: user.name,
          signerRole: 'campadmin',
          signatureType: 'pre_inspection_admin',
          signatureData: signatureData,
          signedAt: DateTime.now(),
        ),
      );

      // 2. Approve Pre-Inspection Report
      await PreInspectionService.approve(
        _report!.id,
        user.id,
        reviewNotes: _reviewNotesController.text,
      );

      // 3. Update Work Request Status to Confirmed
      await WorkRequestService.setUnderMaintenance(
        widget.request.id,
      );

      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Pre-Inspection Approved',
        details: 'Approved pre-inspection with signature for ${widget.request.officeRoom}',
        workRequestId: widget.request.id,
      );

      // 4. Notify Maintenance User & Requestor
      await AppNotificationService.notifyPreInspectionApproved(
        workRequestId: widget.request.id,
        maintenanceId: widget.request.assignedToId ?? _report?.inspectorId,
        adminName: user.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pre-inspection approved successfully!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectPreInspection() async {
    final notes = _rejectionNotesController.text.trim();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide rejection notes'), backgroundColor: Colors.orange),
      );
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isProcessing = true);

    try {
      await PreInspectionService.reject(
        _report!.id,
        notes,
        reviewNotes: _reviewNotesController.text,
      );

      // Update Work Request Status
      await WorkRequestService.updateStatus(
        widget.request.id,
        'Declined',
      );

      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Pre-Inspection Declined',
        details: 'Declined pre-inspection for ${widget.request.officeRoom}. Reason: $notes',
        workRequestId: widget.request.id,
      );

      // Notify Maintenance User & Requestor
      await AppNotificationService.notifyPreInspectionDeclined(
        workRequestId: widget.request.id,
        maintenanceId: widget.request.assignedToId ?? _report?.inspectorId,
        adminName: user.name,
        notes: notes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pre-inspection declined.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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

    if (_report == null) {
      return Scaffold(
        backgroundColor: themeProvider.backgroundColor,
        appBar: AppBar(
          backgroundColor: themeProvider.cardColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: themeProvider.textColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Pre Inspection Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeProvider.textColor)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF4169E1).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF4169E1).withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.hourglass_top_rounded, size: 48, color: Color(0xFF4169E1)),
                    const SizedBox(height: 16),
                    Text(
                      'Waiting for Pre-Inspection Report',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The assigned maintenance technician has not yet submitted a pre-inspection report for this request. Please check back later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: themeProvider.subtitleColor,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'PENDING SUBMISSION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSection('WORK REQUEST DETAILS', [
                _buildInfoRow('Request ID', '#${widget.request.id.split('-').last}'),
                _buildInfoRow('Title', widget.request.title),
                _buildInfoRow('Location', widget.request.officeRoom ?? 'N/A'),
                _buildInfoRow('Status', widget.request.statusLabel),
              ], themeProvider),
            ],
          ),
        ),
      );
    }

    final report = _report!;
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    final isAdmin = user?.role.name == 'campadmin' || user?.role.name == 'admin';
    final showActions = isAdmin && (widget.request.status == 'Pre-Inspection Submitted' || report.status.toLowerCase() == 'pending');

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
          'Pre Inspection Report',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeProvider.textColor),
        ),
        centerTitle: true,
        actions: [
          if (_report != null && (_report!.status == 'Approved' || _report!.adminApproved))
            IconButton(
              icon: const Icon(Icons.print_rounded, color: Color(0xFF4169E1)),
              tooltip: 'Print Report',
              onPressed: () {
                InspectionPdfService.printPreInspection(
                  context: context,
                  request: widget.request,
                  report: _report!,
                );
              },
            ),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4169E1)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header - fixed overflow by wrapping Column in Expanded
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: themeProvider.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4169E1), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WORK REQUEST',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: themeProvider.subtitleColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '#${widget.request.id.split('-').last}',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: themeProvider.textColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.request.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: themeProvider.subtitleColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      WorkflowStatusBadge(status: report.status),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Inspector info
                _buildSection('INSPECTOR DETAILS', [
                  _buildInfoRow('Inspected By', report.inspectorName, themeProvider),
                  _buildInfoRow('Date', _formatDate(report.inspectionDate), themeProvider),
                ], themeProvider),
                const SizedBox(height: 16),

                // Findings
                _buildSection('INITIAL FINDINGS', [
                  _buildInfoRow('Condition Found', report.conditionFound, themeProvider),
                  if (report.description != null) _buildInfoRow('Description', report.description!, themeProvider),
                  if (report.rootCause != null) _buildInfoRow('Root Cause', report.rootCause!, themeProvider),
                  _buildInfoRow('Severity Level', report.severityLevel, themeProvider),
                  if (report.recommendedAction != null) _buildInfoRow('Recommended Action', report.recommendedAction!, themeProvider),
                  if (report.estimatedTime != null) _buildInfoRow('Estimated Time', report.estimatedTime!, themeProvider),
                ], themeProvider),
                const SizedBox(height: 16),

                _buildSection('INSPECTION REVIEW NOTES', [
                  TextFormField(
                    controller: _reviewNotesController,
                    enabled: showActions,
                    maxLines: 4,
                    style: TextStyle(color: themeProvider.textColor, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Add notes for this inspection...',
                      hintStyle: TextStyle(fontSize: 13, color: themeProvider.subtitleColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: themeProvider.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: themeProvider.borderColor),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                      filled: true,
                      fillColor: !showActions ? themeProvider.cardColor.withValues(alpha: 0.5) : themeProvider.inputFillColor,
                    ),
                  ),
                ], themeProvider),
                const SizedBox(height: 16),

                // Materials needed
                _buildSection('MATERIALS NEEDED', [
                  Text(
                    report.materialsNeeded?.isNotEmpty == true ? report.materialsNeeded! : 'No materials listed',
                    style: TextStyle(fontSize: 13, color: themeProvider.textColor, height: 1.5),
                  ),
                ], themeProvider),
                const SizedBox(height: 16),

                // Severity indicator
                _buildSeverityCard(report.severityLevel, themeProvider),
                const SizedBox(height: 24),

                if (showActions) ...[
                  // Approve button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openApprovalSignatureDialog,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Approve & Let Maintenance Proceed',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Rejection notes
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: themeProvider.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: themeProvider.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('REJECTION NOTES (if rejecting)',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: themeProvider.subtitleColor)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _rejectionNotesController,
                          maxLines: 3,
                          style: TextStyle(color: themeProvider.textColor, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Provide reason for rejection...',
                            hintStyle: TextStyle(fontSize: 13, color: themeProvider.subtitleColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: themeProvider.borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: themeProvider.borderColor),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                            filled: true,
                            fillColor: themeProvider.inputFillColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _rejectPreInspection,
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text('Reject Pre-Inspection',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFDC2626)),
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (report.status.toLowerCase() != 'pending' || widget.request.status != 'Pre-Inspection Submitted') ...[
                  _buildResultSummaryCard(report, themeProvider),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4169E1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4169E1).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF4169E1), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pre-Inspection report has been submitted and is pending review by Campus Administrator.',
                            style: TextStyle(fontSize: 13, color: themeProvider.textColor, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildResultSummaryCard(PreInspectionReport report, ThemeProvider themeProvider) {
    final adminSig = _signatures.firstWhere(
      (sig) => sig.signatureType == 'pre_inspection_admin',
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

    final isApproved = report.status.toLowerCase() == 'approved';
    final statusColor = isApproved ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final deciderName = adminSig.signerName.isNotEmpty
        ? adminSig.signerName
        : (_userNames[report.adminApprovedBy] ?? report.adminApprovedBy ?? 'Campus Administrator');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeProvider.borderColor),
        boxShadow: [
          BoxShadow(
            color: themeProvider.shadowColor,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REVIEW DECISION RESULT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: themeProvider.subtitleColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(isApproved ? Icons.check_circle : Icons.cancel, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Text(
                isApproved ? 'APPROVED' : 'DECLINED',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Decided By', deciderName, themeProvider),
          _buildInfoRow('Decided Date', _formatDate(report.adminApprovedDate ?? report.updatedAt), themeProvider),
          if (!isApproved && report.notes != null)
            _buildInfoRow('Rejection Remarks', report.notes!, themeProvider),
          if (isApproved && adminSig.signatureData.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Admin E-Signature:',
              style: TextStyle(fontSize: 12, color: themeProvider.subtitleColor),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Center(
                child: _buildSignatureImage(adminSig.signatureData),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignatureImage(String base64Str) {
    try {
      final cleaned = base64Str.trim().replaceAll(RegExp(r'\s+'), '');
      final base64Data = cleaned.contains(',') ? cleaned.split(',')[1] : cleaned;
      return Image.memory(
        base64Decode(base64Data),
        height: 60,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.gesture, size: 40, color: Colors.grey),
      );
    } catch (_) {
      return const Icon(Icons.gesture, size: 40, color: Colors.grey);
    }
  }

  Widget _buildSection(String title, List<Widget> children, [ThemeProvider? themeProvider]) {
    final tp = themeProvider ?? Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tp.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tp.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tp.subtitleColor, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSeverityCard(String severity, [ThemeProvider? themeProvider]) {
    final tp = themeProvider ?? Provider.of<ThemeProvider>(context, listen: false);
    Color color;
    switch (severity) {
      case 'Critical':
        color = Colors.red;
        break;
      case 'Moderate':
        color = Colors.orange;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Severity: $severity',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(severity == 'Critical'
                  ? 'Requires immediate attention'
                  : severity == 'Moderate'
                      ? 'Should be addressed soon'
                      : 'Can be scheduled for maintenance',
                  style: TextStyle(fontSize: 12, color: tp.subtitleColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [ThemeProvider? themeProvider]) {
    final tp = themeProvider ?? Provider.of<ThemeProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 12, color: tp.subtitleColor)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tp.textColor)),
          ),
        ],
      ),
    );
  }
  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }
}

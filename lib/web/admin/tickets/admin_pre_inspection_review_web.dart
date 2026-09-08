import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../shared/services/app_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/pre_inspection_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../shared/services/pre_inspection_service.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/signature_pad_widget.dart';
import '../../../shared/widgets/attachment_image_widget.dart';
import '../../../shared/services/inspection_pdf_service.dart';
import '../shared/admin_styles.dart';

class AdminPreInspectionReviewWeb extends StatefulWidget {
  final WorkRequest request;
  final VoidCallback? onBack;
  final bool isAdminView;

  const AdminPreInspectionReviewWeb({
    super.key,
    required this.request,
    this.onBack,
    this.isAdminView = false,
  });

  @override
  State<AdminPreInspectionReviewWeb> createState() => _AdminPreInspectionReviewWebState();
}

class _AdminPreInspectionReviewWebState extends State<AdminPreInspectionReviewWeb> {
  bool _isLoading = true;
  bool _isProcessing = false;
  PreInspectionReport? _report;
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  
  String? _adminSignatureBase64;
  
  // Form Controllers
  final _conditionFoundController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rootCauseController = TextEditingController();
  final _recommendedActionController = TextEditingController();
  final _materialsNeededController = TextEditingController();
  final _estimatedTimeController = TextEditingController();
  final _photoEvidenceController = TextEditingController();
  final _notesController = TextEditingController();
  final _reviewNotesController = TextEditingController();
  final _rejectionNotesController = TextEditingController();

  final DateTime _inspectionDate = DateTime.now();
  bool _isUploadingPhotoEvidence = false;
  String? _uploadedPhotoEvidenceUrl;
  String _selectedSeverity = 'Minor';

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final report = await PreInspectionService.fetchLatestByWorkRequest(widget.request.id);
      if (!mounted) return;
      if (report != null) {
        _reviewNotesController.text = report.reviewNotes ?? '';
      }
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _conditionFoundController.dispose();
    _descriptionController.dispose();
    _rootCauseController.dispose();
    _recommendedActionController.dispose();
    _materialsNeededController.dispose();
    _estimatedTimeController.dispose();
    _photoEvidenceController.dispose();
    _notesController.dispose();
    _reviewNotesController.dispose();
    _rejectionNotesController.dispose();
    super.dispose();
  }

  // --- LOGIC PORTED FROM MOBILE ---

  Future<void> _submitPreInspectionReport() async {
    if (!_formKey.currentState!.validate()) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isProcessing = true);
    try {
      final inserted = await PreInspectionService.insert(
        PreInspectionReport(
          id: '',
          workRequestId: widget.request.id,
          inspectorId: user.id,
          inspectorName: user.name,
          inspectionDate: _inspectionDate,
          conditionFound: _conditionFoundController.text.trim(),
          description: _nullIfEmpty(_descriptionController.text),
          rootCause: _nullIfEmpty(_rootCauseController.text),
          severityLevel: _selectedSeverity,
          recommendedAction: _nullIfEmpty(_recommendedActionController.text),
          materialsNeeded: _nullIfEmpty(_materialsNeededController.text),
          estimatedTime: _nullIfEmpty(_estimatedTimeController.text),
          photoEvidence: _nullIfEmpty(_photoEvidenceController.text),
          notes: _nullIfEmpty(_notesController.text),
          status: 'submitted',
        ),
      );

      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Pre-Inspection Report Created',
        details: 'Created pre-inspection report for ${widget.request.officeRoom}',
        workRequestId: widget.request.id,
      );

      if (!mounted) return;
      setState(() {
        _report = inserted;
        _isProcessing = false;
      });
      _showSuccess('Pre-inspection report submitted successfully.');
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Error: $e');
      }
    }
  }

  Future<void> _approvePreInspection() async {
    if (_report == null) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    if (_adminSignatureBase64 == null) {
      _showWarning('Please provide your signature to approve this request.');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await PreInspectionService.approve(_report!.id, user.id, reviewNotes: _reviewNotesController.text);
      
      final signature = ESignature(
        id: '', // Will be generated by DB
        workRequestId: widget.request.id,
        signerId: user.id,
        signerName: user.name,
        signerRole: 'admin',
        signatureType: 'approval',
        signatureData: _adminSignatureBase64!,
        signedAt: DateTime.now(),
      );
      await ESignatureService.insert(signature);
      
      await WorkRequestService.setUnderMaintenance(widget.request.id);
      
      await AppNotificationService.notifyPreInspectionApproved(
        workRequestId: widget.request.id,
        maintenanceId: widget.request.assignedToId ?? _report?.inspectorId,
        adminName: user.name,
      );
      
      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Pre-Inspection Approved',
        details: 'Approved pre-inspection for ${widget.request.officeRoom}',
        workRequestId: widget.request.id,
      );
      if (mounted) {
        _showSuccess('Pre-inspection approved.');
        if (widget.onBack != null) widget.onBack!();
        else Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Error: $e');
      }
    }
  }

  Future<void> _rejectPreInspection() async {
    final notes = _rejectionNotesController.text.trim();
    if (notes.isEmpty) {
      _showWarning('Please provide rejection notes');
      return;
    }
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isProcessing = true);
    try {
       await PreInspectionService.reject(_report!.id, notes, reviewNotes: _reviewNotesController.text);
      await WorkRequestService.updateStatus(widget.request.id, 'Declined');
      await AppNotificationService.notifyPreInspectionDeclined(
        workRequestId: widget.request.id,
        maintenanceId: widget.request.assignedToId ?? _report?.inspectorId,
        adminName: user.name,
        notes: notes,
      );
      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Pre-Inspection Rejected',
        details: 'Rejected pre-inspection for ${widget.request.officeRoom}',
        workRequestId: widget.request.id,
      );
      if (mounted) {
        _showSuccess('Pre-inspection rejected.');
        if (widget.onBack != null) widget.onBack!();
        else Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Error: $e');
      }
    }
  }



  Future<void> _pickAndUploadPhotoEvidence() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploadingPhotoEvidence = true);
    try {
      final client = Supabase.instance.client;
      final bytes = await picked.readAsBytes();
      final extension = picked.name.split('.').last;
      final path = 'pre-inspection/${widget.request.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';
      
      await client.storage.from('work-evidence').uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
      final uploadedUrl = client.storage.from('work-evidence').getPublicUrl(path);

      if (!mounted) return;
      setState(() {
        _uploadedPhotoEvidenceUrl = uploadedUrl;
        _photoEvidenceController.text = uploadedUrl;
        _isUploadingPhotoEvidence = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhotoEvidence = false);
        _showError('Photo upload failed: $e');
      }
    }
  }

  // --- UI BUILDING REDESIGNED FOR WEB ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminStyles.bg,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary))
              : _isProcessing 
                ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary))
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1400),
                           child: LayoutBuilder(
                             builder: (context, constraints) {
                               final isMobile = constraints.maxWidth < 900;
                               if (isMobile) {
                                 return Column(
                                   children: [
                                     _buildContextColumn(),
                                     const SizedBox(height: 24),
                                     _report == null ? _buildSubmissionForm() : _buildReviewForm(),
                                     const SizedBox(height: 60),
                                   ],
                                 );
                               }
                               return Row(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   // Left Column: Sticky Context
                                   SizedBox(
                                     width: 320,
                                     child: _buildContextColumn(),
                                   ),
                                   const SizedBox(width: 28),
                                   // Right Column: Professional Flow
                                   Expanded(
                                     child: Column(
                                       children: [
                                         _report == null ? _buildSubmissionForm() : _buildReviewForm(),
                                         const SizedBox(height: 100), // Spacing at bottom
                                       ],
                                     ),
                                   ),
                                 ],
                               );
                             },
                           ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: AdminStyles.glassDecoration(
        color: Colors.white,
        opacity: 1.0,
        borderRadius: 0,
        hasBorder: false,
      ).copyWith(
        border: Border(bottom: BorderSide(color: AdminStyles.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.pop(context);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: AdminStyles.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AdminStyles.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workflow Phase',
                style: AdminStyles.headingStyle(fontSize: 10, color: AdminStyles.textMuted, letterSpacing: 1),
              ),
              const SizedBox(height: 2),
              Text(
                'PRE-INSPECTION REVIEW',
                style: AdminStyles.headingStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const Spacer(),
          if (_report != null && (_report!.status == 'Approved' || _report!.adminApproved)) ...[
            ElevatedButton.icon(
              onPressed: () {
                InspectionPdfService.printPreInspection(
                  context: context,
                  request: widget.request,
                  report: _report!,
                );
              },
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Print Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminStyles.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 14),
          ],
          _buildStatusBadge(),
        ],
      ),
    );
  }

  Widget _buildContextColumn() {
    return Column(
      children: [
        _buildInfoCard('Work Request', [
          _buildSummaryRow('ID', widget.request.id.substring(0, 8).toUpperCase()),
          _buildSummaryRow('Title', widget.request.title),
          _buildSummaryRow('Room', widget.request.officeRoom ?? 'N/A'),
           _buildSummaryRow(
            'Requestor',
            widget.request.displayRequestorName,
          ),
          _buildSummaryRow('Submitted', _formatDate(widget.request.dateSubmitted)),
        ]),
        const SizedBox(height: 24),
        if (_report != null) _buildInfoCard('Inspector Info', [
          _buildSummaryRow('Name', _report!.inspectorName),
          _buildSummaryRow('Date', _formatDate(_report!.inspectionDate)),
          _buildSummaryRow('Severity', _report!.severityLevel),
        ]),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: AdminStyles.cardDecoration(borderRadius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AdminStyles.primary),
                const SizedBox(width: 8),
              ],
              Text(
                title.toUpperCase(),
                style: AdminStyles.headingStyle(fontSize: 10, color: AdminStyles.textMuted, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AdminStyles.headingStyle(fontSize: 10, color: AdminStyles.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: AdminStyles.dataStyle(fontSize: 13, color: AdminStyles.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildSubmissionForm() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminStyles.cardDecoration(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Pre-Inspection Report', style: AdminStyles.headingStyle(fontSize: 18)),
            const SizedBox(height: 32),
            _buildWebTextField(_conditionFoundController, 'Condition Found *', 'Describe clinical findings...', maxLines: 3, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
            const SizedBox(height: 20),
            if (isMobile) ...[
              _buildSeverityDropdown(),
              const SizedBox(height: 20),
              _buildWebTextField(_estimatedTimeController, 'Estimated Time', 'e.g. 2 days'),
            ] else
              Row(
                children: [
                  Expanded(child: _buildSeverityDropdown()),
                  const SizedBox(width: 20),
                  Expanded(child: _buildWebTextField(_estimatedTimeController, 'Estimated Time', 'e.g. 2 days')),
                ],
              ),
            const SizedBox(height: 20),
            _buildWebTextField(_rootCauseController, 'Possible Root Cause', 'What caused this issue?', maxLines: 2),
            const SizedBox(height: 20),
            _buildWebTextField(_materialsNeededController, 'Materials Needed', 'List required parts...', maxLines: 2),
            const SizedBox(height: 20),
            _buildPhotoUploadSection(),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitPreInspectionReport,
                style: ElevatedButton.styleFrom(backgroundColor: AdminStyles.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Submit Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewForm() {
    final report = _report!;
    final isActioned = report.status.toLowerCase() != 'pending' && report.status.toLowerCase() != 'submitted';
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: AdminStyles.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Inspection Findings', style: AdminStyles.headingStyle(fontSize: 18)),
              const SizedBox(height: 32),
              _buildReadOnlyBlock('Condition Found', report.conditionFound),
              const SizedBox(height: 20),
              if (isMobile) ...[
                _buildReadOnlyBlock('Severity', report.severityLevel),
                const SizedBox(height: 20),
                _buildReadOnlyBlock('Est. Time', report.estimatedTime ?? 'N/A'),
              ] else
                Row(
                  children: [
                    Expanded(child: _buildReadOnlyBlock('Severity', report.severityLevel)),
                    const SizedBox(width: 20),
                    Expanded(child: _buildReadOnlyBlock('Est. Time', report.estimatedTime ?? 'N/A')),
                  ],
                ),
              if (report.description != null && report.description!.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildReadOnlyBlock('Description', report.description!),
              ],
              if (report.rootCause != null && report.rootCause!.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildReadOnlyBlock('Possible Root Cause', report.rootCause!),
              ],
              if (report.recommendedAction != null && report.recommendedAction!.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildReadOnlyBlock('Recommended Action', report.recommendedAction!),
              ],
              if (report.materialsNeeded != null && report.materialsNeeded!.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildReadOnlyBlock('Materials Needed', report.materialsNeeded!),
              ],
              if (report.notes != null && report.notes!.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildReadOnlyBlock('Notes', report.notes!),
              ],
              if (report.photoEvidence != null) ...[
                const SizedBox(height: 24),
                _buildPhotoPreview(report.photoEvidence!),
              ],
              if (widget.isAdminView) ...[
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 32),
                Text('Review Actions', style: AdminStyles.headingStyle(fontSize: 18)),
                const SizedBox(height: 24),
                _buildWebTextField(_reviewNotesController, 'Internal Review Notes', 'Keep track of administrative decisions...', maxLines: 3, enabled: !isActioned),
                if (!isActioned) ...[
                  const SizedBox(height: 32),
                  SignaturePadWidget(
                    title: 'Admin Signature',
                    onSignatureComplete: (v) => setState(() => _adminSignatureBase64 = v),
                  ),
                  const SizedBox(height: 32),
                  if (isMobile) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _showRejectionDialog,
                        style: OutlinedButton.styleFrom(foregroundColor: AdminStyles.error, side: const BorderSide(color: AdminStyles.error), padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Decline Report'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _approvePreInspection,
                        style: ElevatedButton.styleFrom(backgroundColor: AdminStyles.success, foregroundColor: Colors.white, padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Confirm Work Request'),
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _showRejectionDialog,
                            style: OutlinedButton.styleFrom(foregroundColor: AdminStyles.error, side: const BorderSide(color: AdminStyles.error), padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: const Text('Decline Report'),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _approvePreInspection,
                            style: ElevatedButton.styleFrom(backgroundColor: AdminStyles.success, foregroundColor: Colors.white, padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: const Text('Confirm Work Request'),
                          ),
                        ),
                      ],
                    ),
                ] else ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: report.status == 'Approved'
                          ? AdminStyles.success.withValues(alpha: 0.08)
                          : AdminStyles.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: report.status == 'Approved'
                            ? AdminStyles.success.withValues(alpha: 0.3)
                            : AdminStyles.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          report.status == 'Approved' ? Icons.verified_rounded : Icons.cancel_rounded,
                          color: report.status == 'Approved' ? AdminStyles.success : AdminStyles.error,
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report.status == 'Approved' ? 'Pre-Inspection Approved' : 'Pre-Inspection Declined',
                                style: AdminStyles.headingStyle(
                                  fontSize: 15,
                                  color: report.status == 'Approved' ? AdminStyles.success : AdminStyles.error,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                report.status == 'Approved'
                                    ? 'This pre-inspection report has been officially approved.'
                                    : 'This pre-inspection report was declined by Campus Admin.',
                                style: AdminStyles.bodyStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebTextField(TextEditingController controller, String label, String hint, {int maxLines = 1, String? Function(String?)? validator, bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminStyles.textPrimary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          enabled: enabled,
          style: AdminStyles.bodyStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AdminStyles.textMuted.withValues(alpha: 0.5)),
            filled: true,
            fillColor: enabled ? Colors.white : AdminStyles.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AdminStyles.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AdminStyles.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminStyles.primary, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminStyles.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: AdminStyles.bodyStyle(fontSize: 14, color: AdminStyles.textPrimary)),
      ],
    );
  }

  Widget _buildSeverityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Severity Level *', style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedSeverity,
          items: ['Minor', 'Moderate', 'Critical'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => setState(() => _selectedSeverity = v!),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AdminStyles.border)),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photo Evidence', style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickAndUploadPhotoEvidence,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AdminStyles.border, style: BorderStyle.solid), borderRadius: BorderRadius.circular(12)),
            child: _uploadedPhotoEvidenceUrl == null 
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.cloud_upload_outlined, color: AdminStyles.textMuted), const SizedBox(height: 8), Text(_isUploadingPhotoEvidence ? 'Uploading...' : 'Click to Upload Photo', style: AdminStyles.bodyStyle(fontSize: 12))]))
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppAttachmentImage(url: _uploadedPhotoEvidenceUrl!, fit: BoxFit.contain),
                ),
          ),
        ),
      ],
    );
  }


  Widget _buildPhotoPreview(String urlData) {
    List<String> urls = [];
    try {
      final clean = urlData.trim();
      if (clean.startsWith('[') && clean.endsWith(']')) {
        final List<dynamic> decoded = jsonDecode(clean);
        urls = decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      } else if (clean.contains(',')) {
        urls = clean.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } else if (clean.isNotEmpty) {
        urls = [clean];
      }
    } catch (e) {
      if (urlData.trim().isNotEmpty) urls = [urlData.trim()];
    }

    if (urls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_library_outlined, size: 16, color: AdminStyles.primary),
            const SizedBox(width: 8),
            Text(
              'Photo Evidence (${urls.length})',
              style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminStyles.textPrimary),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AdminStyles.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Click to enlarge',
                style: AdminStyles.bodyStyle(fontSize: 10, color: AdminStyles.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminStyles.border),
          ),
          child: urls.length == 1
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Tooltip(
                    message: 'Click to enlarge photo',
                    child: InkWell(
                      onTap: () => showAttachmentZoomDialog(context, urls.first),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: 360,
                          maxHeight: 260,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AdminStyles.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AppAttachmentImage(
                                url: urls.first,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: 240,
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text('View full', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: urls.map((url) {
                    return Tooltip(
                      message: 'Click to enlarge photo',
                      child: InkWell(
                        onTap: () => showAttachmentZoomDialog(context, url),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AdminStyles.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AppAttachmentImage(
                                url: url,
                                fit: BoxFit.cover,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              Positioned(
                                bottom: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final status = _report?.status ?? 'Pending Inspection';
    Color color = Colors.grey;
    if (status == 'submitted') color = AdminStyles.warning;
    if (status == 'approved') color = AdminStyles.success;
    if (status == 'rejected') color = AdminStyles.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: AdminStyles.pillDecoration(color: color, isSecondary: true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            status.toUpperCase(),
            style: AdminStyles.headingStyle(fontSize: 10, color: color, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  void _showRejectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Report', style: AdminStyles.headingStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please provide a reason for rejection. This will be shared with the maintenance team.', style: AdminStyles.bodyStyle()),
            const SizedBox(height: 20),
            _buildWebTextField(_rejectionNotesController, 'Rejection Notes', 'Explain why the report was rejected...'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () { Navigator.pop(context); _rejectPreInspection(); }, style: ElevatedButton.styleFrom(backgroundColor: AdminStyles.error, foregroundColor: Colors.white), child: const Text('Reject')),
        ],
      ),
    );
  }

  // --- HELPERS ---

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.success));
  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.error));
  void _showWarning(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.warning));

  String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();
  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}


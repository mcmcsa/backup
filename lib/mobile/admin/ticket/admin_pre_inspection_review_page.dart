import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import '../../../shared/widgets/signature_pad_widget.dart';
import 'dart:convert';

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
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _conditionFoundController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rootCauseController = TextEditingController();
  final _recommendedActionController = TextEditingController();
  final _materialsNeededController = TextEditingController();
  final _estimatedTimeController = TextEditingController();
  final _photoEvidenceController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _inspectionDate = DateTime.now();
  bool _isUploadingPhotoEvidence = false;
  String? _uploadedPhotoEvidenceUrl;
  String _selectedSeverity = 'Minor';
  final _reviewNotesController = TextEditingController();
  final _rejectionNotesController = TextEditingController();

  List<ESignature> _signatures = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final report = await PreInspectionService.fetchLatestByWorkRequest(widget.request.id);
      final signatures = await ESignatureService.fetchByWorkRequest(widget.request.id);
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pre-inspection report submitted successfully.'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickInspectionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _inspectionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) return;
    setState(() {
      _inspectionDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _inspectionDate.hour,
        _inspectionDate.minute,
      );
    });
  }

  Future<void> _pickAndUploadPhotoEvidence() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploadingPhotoEvidence = true);
    try {
      final uploadedUrl = await _uploadPreInspectionEvidenceImage(
        requestId: widget.request.id,
        imageFile: picked,
      );

      if (!mounted) return;
      setState(() {
        _uploadedPhotoEvidenceUrl = uploadedUrl;
        _photoEvidenceController.text = uploadedUrl;
        _isUploadingPhotoEvidence = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhotoEvidence = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo upload failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<String> _uploadPreInspectionEvidenceImage({
    required String requestId,
    required XFile imageFile,
  }) async {
    final client = Supabase.instance.client;
    const candidateBuckets = <String>[
      'work-evidence',
      'work_evidence',
      'pre-inspection-evidence',
      'pre_inspection_evidence',
      'inspection-evidence',
      'images',
      'public',
    ];

    final bytes = await imageFile.readAsBytes();
    final rawName = imageFile.name.trim().isNotEmpty
        ? imageFile.name.trim()
        : 'pre_inspection_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final safeName = rawName.replaceAll(RegExp(r'\s+'), '_');
    final path = 'pre-inspection/$requestId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final contentType = _contentTypeFromFileName(safeName);

    Exception? lastError;

    for (final bucket in candidateBuckets) {
      try {
        await client.storage.from(bucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(upsert: false, contentType: contentType),
            );
        return client.storage.from(bucket).getPublicUrl(path);
      } catch (e) {
        lastError = Exception(e.toString());
      }
    }

    throw Exception(
      'No usable storage bucket found for pre-inspection evidence upload. '
      'Tried: ${candidateBuckets.join(', ')}. '
      'Last error: ${lastError?.toString() ?? 'unknown'}',
    );
  }

  String _contentTypeFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
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

      // 3. Update Work Request Status
      await WorkRequestService.updateStatus(
        widget.request.id,
        'Pre-Inspection Approved',
      );

      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Pre-Inspection Approved',
        details: 'Approved pre-inspection with signature for ${widget.request.officeRoom}',
        workRequestId: widget.request.id,
      );

      // 4. Notify Maintenance User & Requestor
      final maintId = widget.request.assignedToId;
      if (maintId != null && maintId.trim().isNotEmpty && maintId.trim() != 'null') {
        await AppNotificationService.notifyPreInspectionApproved(
          workRequestId: widget.request.id,
          maintenanceId: maintId,
          adminName: user.name,
        );
      }

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
        'Pre-Inspection Declined',
      );

      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Pre-Inspection Declined',
        details: 'Declined pre-inspection for ${widget.request.officeRoom}. Reason: $notes',
        workRequestId: widget.request.id,
      );

      // Notify Maintenance User & Requestor
      final maintId = widget.request.assignedToId;
      if (maintId != null && maintId.trim().isNotEmpty && maintId.trim() != 'null') {
        await AppNotificationService.notifyPreInspectionDeclined(
          workRequestId: widget.request.id,
          maintenanceId: maintId,
          adminName: user.name,
          notes: notes,
        );
      }

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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_report == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Pre Inspection Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        body: _isProcessing
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4169E1)))
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSection('REPORT DETAILS', [
                      _buildInfoRow('Work Request ID', widget.request.id),
                      _buildInfoRow('Inspector', Provider.of<AuthService>(context, listen: false).currentUser?.name ?? 'Unknown'),
                      _buildInfoRow('Inspection Date', _formatDate(_inspectionDate)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickInspectionDate,
                        icon: const Icon(Icons.calendar_today_outlined, size: 16),
                        label: const Text('Change Inspection Date'),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('PRE-INSPECTION FINDINGS', [
                      _buildTextField(
                        controller: _conditionFoundController,
                        label: 'Condition Found *',
                        hint: 'Describe the current condition found during inspection',
                        maxLines: 3,
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Condition found is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        hint: 'Additional findings details',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _rootCauseController,
                        label: 'Root Cause',
                        hint: 'Possible root cause of the issue',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      const Text('Severity Level *',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedSeverity,
                        items: const [
                          DropdownMenuItem(value: 'Minor', child: Text('Minor')),
                          DropdownMenuItem(value: 'Moderate', child: Text('Moderate')),
                          DropdownMenuItem(value: 'Critical', child: Text('Critical')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedSeverity = value);
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _recommendedActionController,
                        label: 'Recommended Action',
                        hint: 'Suggested corrective action',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _materialsNeededController,
                        label: 'Materials Needed',
                        hint: 'List required materials',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _estimatedTimeController,
                        label: 'Estimated Time',
                        hint: 'e.g. 2 hours, 1 day',
                      ),
                      const SizedBox(height: 12),
                      const Text('Photo Evidence',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isUploadingPhotoEvidence ? null : _pickAndUploadPhotoEvidence,
                              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                              label: Text(_isUploadingPhotoEvidence ? 'Uploading...' : 'Upload Photo'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_uploadedPhotoEvidenceUrl != null)
                            IconButton(
                              tooltip: 'Clear uploaded photo',
                              onPressed: () {
                                setState(() {
                                  _uploadedPhotoEvidenceUrl = null;
                                  _photoEvidenceController.clear();
                                });
                              },
                              icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                            ),
                        ],
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _photoEvidenceController,
                        builder: (context, value, child) {
                          final previewUrl = _uploadedPhotoEvidenceUrl ?? _previewableEvidenceUrl(value.text);
                          if (previewUrl == null) return const SizedBox.shrink();

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  color: const Color(0xFFF3F4F6),
                                  child: Image.network(
                                    previewUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    alignment: Alignment.center,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Text(
                                          'Image preview unavailable',
                                          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                        const SizedBox(height: 12),
                      _buildTextField(
                        controller: _notesController,
                        label: 'Notes',
                        hint: 'Additional notes',
                        maxLines: 3,
                      ),
                    ]),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _submitPreInspectionReport,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Submit Pre Inspection Report',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4169E1),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      );
    }

    final report = _report!;
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    final isAdmin = user?.role.name == 'campadmin' || user?.role.name == 'admin';
    final showActions = isAdmin && widget.request.status == 'Pre-Inspection Submitted';

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
          'Pre Inspection Report',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4169E1)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4169E1), width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WORK REQUEST',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                          const SizedBox(height: 6),
                          Text(widget.request.id,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      WorkflowStatusBadge(status: report.status),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Inspector info
                _buildSection('INSPECTOR DETAILS', [
                  _buildInfoRow('Inspected By', report.inspectorName),
                  _buildInfoRow('Date', _formatDate(report.inspectionDate)),
                ]),
                const SizedBox(height: 16),

                // Findings
                _buildSection('INITIAL FINDINGS', [
                  _buildInfoRow('Condition Found', report.conditionFound),
                  if (report.description != null) _buildInfoRow('Description', report.description!),
                  if (report.rootCause != null) _buildInfoRow('Root Cause', report.rootCause!),
                  _buildInfoRow('Severity Level', report.severityLevel),
                  if (report.recommendedAction != null) _buildInfoRow('Recommended Action', report.recommendedAction!),
                  if (report.estimatedTime != null) _buildInfoRow('Estimated Time', report.estimatedTime!),
                ]),
                const SizedBox(height: 16),

                _buildSection('INSPECTION REVIEW NOTES', [
                  TextFormField(
                    controller: _reviewNotesController,
                    enabled: showActions,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Add notes for this inspection...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                      filled: true,
                      fillColor: !showActions ? const Color(0xFFF9FAFB) : Colors.white,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                // Materials needed
                _buildSection('MATERIALS NEEDED', [
                  Text(
                    report.materialsNeeded?.isNotEmpty == true ? report.materialsNeeded! : 'No materials listed',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5),
                  ),
                ]),
                const SizedBox(height: 16),

                // Severity indicator
                _buildSeverityCard(report.severityLevel),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('REJECTION NOTES (if rejecting)',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _rejectionNotesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Provide reason for rejection...',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            contentPadding: const EdgeInsets.all(12),
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
                  _buildResultSummaryCard(report),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pre-Inspection report has been submitted and is pending review by Campus Administrator.',
                            style: TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.w500),
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

  Widget _buildResultSummaryCard(PreInspectionReport report) {
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REVIEW DECISION RESULT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
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
          _buildInfoRow('Decided By', adminSig.signerName.isNotEmpty ? adminSig.signerName : (report.adminApprovedBy ?? 'Campus Administrator')),
          _buildInfoRow('Decided Date', _formatDate(report.adminApprovedDate ?? report.updatedAt)),
          if (!isApproved && report.notes != null)
            _buildInfoRow('Rejection Remarks', report.notes!),
          if (isApproved && adminSig.signatureData.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Admin E-Signature:',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _buildSignatureImage(adminSig.signatureData),
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

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSeverityCard(String severity) {
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
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(color: Color(0xFF00C2A8), width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(12),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _previewableEvidenceUrl(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }
    return trimmed;
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }
}

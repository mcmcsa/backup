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
import '../shared/admin_styles.dart';

class AdminPreInspectionReviewWeb extends StatefulWidget {
  final WorkRequest request;

  const AdminPreInspectionReviewWeb({
    super.key,
    required this.request,
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

    setState(() => _isProcessing = true);
    try {
      await PreInspectionService.approve(_report!.id, user.id, reviewNotes: _reviewNotesController.text);
      await WorkRequestService.setUnderMaintenance(widget.request.id);
      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Pre-Inspection Approved',
        details: 'Approved pre-inspection for ${widget.request.officeRoom}',
        workRequestId: widget.request.id,
      );
      if (mounted) {
        _showSuccess('Pre-inspection approved.');
        Navigator.pop(context, true);
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
      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Pre-Inspection Rejected',
        details: 'Rejected pre-inspection for ${widget.request.officeRoom}',
        workRequestId: widget.request.id,
      );
      if (mounted) {
        _showSuccess('Pre-inspection rejected.');
        Navigator.pop(context, true);
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
    return Container(
      color: AdminStyles.bg,
      child: Column(
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
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Column: Sticky Context
                              SizedBox(
                                width: 400,
                                child: _buildContextColumn(),
                              ),
                              const SizedBox(width: 40),
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
              onTap: () => Navigator.pop(context),
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
          _buildSummaryRow('Requestor', widget.request.requestorName),
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
    final isActioned = report.status != 'submitted';

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
              Row(
                children: [
                  Expanded(child: _buildReadOnlyBlock('Severity', report.severityLevel)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildReadOnlyBlock('Est. Time', report.estimatedTime ?? 'N/A')),
                ],
              ),
              if (report.photoEvidence != null) ...[
                const SizedBox(height: 24),
                _buildPhotoPreview(report.photoEvidence!),
              ],
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),
              Text('Review Actions', style: AdminStyles.headingStyle(fontSize: 18)),
              const SizedBox(height: 24),
              _buildWebTextField(_reviewNotesController, 'Internal Review Notes', 'Keep track of administrative decisions...', maxLines: 3, enabled: !isActioned),
              if (!isActioned) ...[
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _showRejectionDialog,
                        style: OutlinedButton.styleFrom(foregroundColor: AdminStyles.error, side: const BorderSide(color: AdminStyles.error), padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Reject Report'),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _approvePreInspection,
                        style: ElevatedButton.styleFrom(backgroundColor: AdminStyles.success, foregroundColor: Colors.white, padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Approve Maintenance'),
                      ),
                    ),
                  ],
                ),
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
              : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_uploadedPhotoEvidenceUrl!, fit: BoxFit.cover)),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPreview(String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photo Evidence', style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(url, height: 300, width: double.infinity, fit: BoxFit.cover),
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

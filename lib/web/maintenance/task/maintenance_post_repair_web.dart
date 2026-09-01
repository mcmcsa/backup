import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/post_repair_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../admin/shared/admin_styles.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class MaintenancePostRepairWeb extends StatefulWidget {
  final WorkRequest request;
  final VoidCallback? onBack;
  final bool forceHistoryView;

  const MaintenancePostRepairWeb({
    super.key, 
    required this.request, 
    this.onBack,
    this.forceHistoryView = false,
  });

  @override
  State<MaintenancePostRepairWeb> createState() => _MaintenancePostRepairWebState();
}

class _MaintenancePostRepairWebState extends State<MaintenancePostRepairWeb> {
  final _formKey = GlobalKey<FormState>();
  final _workPerformedController = TextEditingController();
  final _materialsController = TextEditingController();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();

  String _repairStatus = 'completed';
  bool _isLoading = true;
  bool _isSubmitting = false;

  List<PostRepairReport> _history = [];
  int _nextAttemptNumber = 1;
  int _selectedAttemptIndex = 0;
  bool _showNewSubmissionForm = true;
  String? _technicianSignatureBase64;
  
  List<XFile> _evidenceImages = [];
  bool _isUploadingEvidence = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _workPerformedController.dispose();
    _materialsController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final history = await PostRepairService.fetchByWorkRequest(widget.request.id);
      
      if (!mounted) return;
      setState(() {
        _history = history;
        _nextAttemptNumber = history.length + 1;
        _selectedAttemptIndex = history.isNotEmpty ? history.length - 1 : 0;
        _showNewSubmissionForm = _isEntryMode;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isEntryMode {
    if (widget.forceHistoryView) return false;
    
    final status = widget.request.status;
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    final isMaintenance = user?.role.name == 'maintenance';
    return isMaintenance && (status == 'Confirmed' || status == 'Rework' || status == 'Pre-Inspection Approved' || status == 'For Rework');
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() => _evidenceImages.addAll(images));
    }
  }

  void _removeImage(int index) {
    setState(() => _evidenceImages.removeAt(index));
  }

  Future<Map<String, String>> _uploadWorkEvidenceImages({
    required String requestId,
    required List<XFile> imageFiles,
  }) async {
    final client = Supabase.instance.client;
    List<String> urls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      final imageFile = imageFiles[i];
      final bytes = await imageFile.readAsBytes();
      final extension = imageFile.name.contains('.')
          ? imageFile.name.split('.').last.toLowerCase()
          : 'jpg';
      // Normalize MIME type — Supabase rejects 'image/jpg', needs 'image/jpeg'
      final mimeType = extension == 'jpg' ? 'image/jpeg' : 'image/$extension';
      final path = 'work-evidence/$requestId/${DateTime.now().millisecondsSinceEpoch}_$i.$extension';

      await client.storage.from('work-evidence').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: mimeType,
          upsert: true,
        ),
      );

      final url = client.storage.from('work-evidence').getPublicUrl(path);
      urls.add(url);
    }

    return {
      'new': jsonEncode(urls),
      'single_url': urls.isNotEmpty ? urls.first : '',
    };
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      _showError('Please fill out the required fields.');
      return;
    }

    if (_evidenceImages.isEmpty && widget.request.workEvidence == null) {
      _showError('Please upload at least one work evidence photo.');
      return;
    }

    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      // Upload Evidence Images if new ones exist
      String? reportPhotoAfter;
      if (_evidenceImages.isNotEmpty) {
        setState(() => _isUploadingEvidence = true);
        final uploadResult = await _uploadWorkEvidenceImages(
          requestId: widget.request.id,
          imageFiles: _evidenceImages,
        );
        reportPhotoAfter = uploadResult['new'];
        if (uploadResult['single_url']!.isNotEmpty) {
          await WorkRequestService.updateWorkEvidence(widget.request.id, uploadResult['single_url']!);
        }
      }

      // 2. Insert Post-Repair Report
      await PostRepairService.insert(
        PostRepairReport(
          id: '',
          workRequestId: widget.request.id,
          attemptNumber: _nextAttemptNumber,
          technicianId: user.id,
          technicianName: user.name,
          repairDate: DateTime.now(),
          workPerformed: _workPerformedController.text.trim(),
          materialsUsed: _materialsController.text.trim().isEmpty ? null : _materialsController.text.trim(),
          photoAfter: reportPhotoAfter,
          repairDuration: _durationController.text.trim().isEmpty ? null : _durationController.text.trim(),
          repairStatus: _repairStatus,
          technicianNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          status: 'Pending',
        ),
      );

      // 3. Update work_request status back to 'Confirmed' so campus admin
      //    can evaluate the newly submitted post-repair report
      await WorkRequestService.updateStatus(widget.request.id, 'Confirmed');

      // 4. Notify Campus Admin (best-effort – RLS may block non-admin inserts)
      try {
        await AppNotificationService.notifyPostRepairSubmittedToAdmin(
          workRequestId: widget.request.id,
          maintenanceName: user.name,
          adminId: widget.request.approvedById,
        );
      } catch (_) {
        // Notification failure should not block the submission success
      }

      if (mounted) {
        _showSuccess('Post-Repair report submitted successfully!');
        if (widget.onBack != null) {
          widget.onBack!();
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) _showError('Submission failed: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.success));
  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.error));

  void _showImageDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 900;

    return Scaffold(
      backgroundColor: AdminStyles.bg,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: _isLoading || _isSubmitting
                ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary))
                : SingleChildScrollView(
                    padding: EdgeInsets.all(isCompact ? 16 : 32),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTaskSummary(),
                            const SizedBox(height: 24),
                            _buildAttemptTabs(),
                            if (_showNewSubmissionForm)
                              Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFormFields(isCompact),
                                    const SizedBox(height: 24),
                                    _buildSubmitSection(),
                                  ],
                                ),
                              )
                            else if (_history.isNotEmpty)
                              _buildDetailedView(_history[_selectedAttemptIndex]),
                          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: AdminStyles.surface, border: Border(bottom: BorderSide(color: AdminStyles.border))),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AdminStyles.textPrimary),
            onPressed: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 16),
          Text(_isEntryMode ? 'Submit Post-Repair Report' : 'Repair History', style: AdminStyles.headingStyle(fontSize: 20)),
        ],
      ),
    );
  }

  Widget _buildAttemptTabs() {
    if (_history.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ..._history.asMap().entries.map((entry) {
              final idx = entry.key;
              final report = entry.value;
              final isSelected = !_showNewSubmissionForm && _selectedAttemptIndex == idx;
              
              String statusText = 'Attempt #${report.attemptNumber}';
              if (report.adminEvaluation == 'satisfied') {
                statusText += ' (Approved)';
              } else if (report.adminEvaluation == 'rework') {
                statusText += ' (Rework)';
              } else {
                statusText += ' (Pending)';
              }
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _showNewSubmissionForm = false;
                      _selectedAttemptIndex = idx;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AdminStyles.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AdminStyles.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (_isEntryMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _showNewSubmissionForm = true;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _showNewSubmissionForm ? AdminStyles.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'New Submission (Attempt #$_nextAttemptNumber)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _showNewSubmissionForm ? FontWeight.bold : FontWeight.normal,
                        color: _showNewSubmissionForm ? Colors.white : AdminStyles.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedView(PostRepairReport report) {
    final isApproved = report.status.toLowerCase() == 'approved' || report.status.toLowerCase() == 'confirmed';
    final isDeclined = report.status.toLowerCase() == 'declined' || report.status.toLowerCase() == 'rework';
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Repair Details', style: AdminStyles.headingStyle(fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isApproved ? AdminStyles.success.withOpacity(0.1) : (isDeclined ? AdminStyles.warning.withOpacity(0.1) : AdminStyles.textMuted.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  report.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isApproved ? AdminStyles.success : (isDeclined ? AdminStyles.warning : AdminStyles.textMuted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Work Performed', report.workPerformed),
          if (report.materialsUsed != null) _buildInfoRow('Materials Used', report.materialsUsed!),
          if (report.repairDuration != null) _buildInfoRow('Duration', report.repairDuration!),
          if (report.technicianNotes != null) _buildInfoRow('Notes', report.technicianNotes!),
          _buildInfoRow('Date', DateFormat('MMM dd, yyyy').format(report.repairDate)),
          
          if (report.photoAfter != null && report.photoAfter!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Work Evidence', style: AdminStyles.bodyStyle(fontWeight: FontWeight.bold, color: AdminStyles.textPrimary)),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                List<String> urls = [];
                try {
                  if (report.photoAfter!.startsWith('[')) {
                    final List<dynamic> decoded = jsonDecode(report.photoAfter!);
                    urls = decoded.map((e) => e.toString()).toList();
                  } else {
                    urls = [report.photoAfter!];
                  }
                } catch (e) {
                  urls = [report.photoAfter!];
                }

                if (urls.length == 1) {
                  return InkWell(
                    onTap: () => _showImageDialog(context, urls.first),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        urls.first,
                        width: double.infinity,
                        height: 250,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: urls.map((url) {
                    return InkWell(
                      onTap: () => _showImageDialog(context, url),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          url,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
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
          SizedBox(width: 140, child: Text('$label:', style: AdminStyles.bodyStyle(fontWeight: FontWeight.bold, color: AdminStyles.textPrimary))),
          Expanded(child: Text(value, style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildTaskSummary() {
    final trackId = widget.request.id.length > 8 ? widget.request.id.substring(0, 8).toUpperCase() : widget.request.id.toUpperCase();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminStyles.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.build_circle_rounded, color: AdminStyles.primary),
              const SizedBox(width: 12),
              Text(_isEntryMode ? 'Post-Repair - Attempt #$_nextAttemptNumber' : 'Post-Repair Report', style: AdminStyles.headingStyle(fontSize: 16, color: AdminStyles.primary)),
            ],
          ),
          const SizedBox(height: 16),
          Text(widget.request.title, style: AdminStyles.headingStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text('Location: ${widget.request.buildingName} • ${widget.request.officeRoom}', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
          const SizedBox(height: 8),
          Text('Requestor: ${widget.request.displayRequestorName}', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildFormFields(bool isCompact) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Repair Details', style: AdminStyles.headingStyle(fontSize: 16)),
          const SizedBox(height: 24),
          _buildWebTextField(_workPerformedController, 'Work Performed *', 'Describe the exact work done...', required: true, maxLines: 3, maxLength: 490),
          const SizedBox(height: 16),
          if (isCompact) ...[
            _buildWebTextField(_materialsController, 'Materials Used', 'Parts, materials, tools used...'),
            const SizedBox(height: 16),
            _buildStatusDropdown(),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildWebTextField(_materialsController, 'Materials Used', 'Parts, materials, tools used...')),
                const SizedBox(width: 16),
                Expanded(child: _buildStatusDropdown()),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (isCompact) ...[
            _buildWebTextField(_durationController, 'Repair Duration', 'e.g., 3 hours'),
            const SizedBox(height: 16),
            _buildWebTextField(_notesController, 'Additional Notes', 'Any comments for the admin?'),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildWebTextField(_durationController, 'Repair Duration', 'e.g., 3 hours')),
                const SizedBox(width: 16),
                Expanded(child: _buildWebTextField(_notesController, 'Additional Notes', 'Any comments for the admin?')),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text('Work Evidence', style: AdminStyles.headingStyle(fontSize: 16)),
          const SizedBox(height: 16),
          _buildEvidencePicker(),
        ],
      ),
    );
  }

  Widget _buildEvidencePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Work Evidence Photos (Mandatory) *', style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_evidenceImages.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(_evidenceImages.length, (index) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _evidenceImages[index].path,
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4, 
                    right: 4, 
                    child: InkWell(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        if (_evidenceImages.isNotEmpty) const SizedBox(height: 12),
        InkWell(
          onTap: _pickImages,
          child: Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(color: AdminStyles.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminStyles.border, style: BorderStyle.solid)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_photo_alternate_rounded, color: AdminStyles.primary),
                const SizedBox(height: 8),
                Text('Upload Evidence Images', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.primary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Repair Status', style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminStyles.textPrimary)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _repairStatus,
          decoration: _inputDecoration('Select repair status'),
          items: [
            DropdownMenuItem(value: 'completed', child: Text('Completed', style: AdminStyles.bodyStyle(fontSize: 14))),
            DropdownMenuItem(value: 'partial', child: Text('Partially Completed', style: AdminStyles.bodyStyle(fontSize: 14))),
            DropdownMenuItem(value: 'cannot_repair', child: Text('Cannot Repair', style: AdminStyles.bodyStyle(fontSize: 14))),
          ],
          onChanged: (v) => setState(() => _repairStatus = v!),
        ),
      ],
    );
  }

  Widget _buildWebTextField(TextEditingController controller, String label, String hint, {int maxLines = 1, bool required = false, int maxLength = 490}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminStyles.textPrimary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
            if (maxLength == null) return null;
            final remaining = maxLength - currentLength;
            if (remaining > 100) return null; // Hidden when plenty of space left
            final color = remaining <= 20 ? AdminStyles.error : const Color(0xFFF59E0B);
            return Text(
              '$currentLength/$maxLength',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            );
          },
          style: AdminStyles.bodyStyle(fontSize: 14),
          decoration: _inputDecoration(hint),
          validator: required ? (v) => v == null || v.trim().isEmpty ? 'This field is required' : null : null,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AdminStyles.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AdminStyles.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AdminStyles.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AdminStyles.error, width: 1.5),
      ),
    );
  }

  Widget _buildSubmitSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminStyles.success,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Submit Post-Repair Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}


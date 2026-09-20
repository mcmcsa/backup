import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/post_repair_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/signature_pad_widget.dart';

class PostRepairPage extends StatefulWidget {
  final WorkRequest request;
  final bool forceHistoryView;

  const PostRepairPage({
    super.key,
    required this.request,
    this.forceHistoryView = false,
  });

  @override
  State<PostRepairPage> createState() => _PostRepairPageState();
}

class _PostRepairPageState extends State<PostRepairPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _workPerformedController = TextEditingController();
  final TextEditingController _materialsController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<XFile> _evidenceImages = [];
  bool _isUploadingEvidence = false;

  String _repairStatus = 'completed';
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showWorkCompletionButton = false;

  List<PostRepairReport> _history = [];
  List<ESignature> _signatures = [];
  int _nextAttemptNumber = 1;

  @override
  void initState() {
    super.initState();
    _workPerformedController.addListener(_checkRequiredFields);
    _loadData();
  }

  @override
  void dispose() {
    _workPerformedController.removeListener(_checkRequiredFields);
    _workPerformedController.dispose();
    _materialsController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _checkRequiredFields() {
    final hasWork = _workPerformedController.text.trim().isNotEmpty;
    final hasEvidence = _evidenceImages.isNotEmpty ||
        (widget.request.workEvidence != null && widget.request.workEvidence!.trim().isNotEmpty);
    final canSubmit = hasWork && hasEvidence;
    if (_showWorkCompletionButton != canSubmit) {
      setState(() {
        _showWorkCompletionButton = canSubmit;
      });
    }
  }

  void _pickImages() async {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF4169E1)),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await picker.pickMultiImage();
                if (picked.isNotEmpty) {
                  setState(() => _evidenceImages.addAll(picked));
                  _checkRequiredFields();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF4169E1)),
              title: const Text('Take a Photo'),
              onTap: () async {
                Navigator.pop(ctx);
                final photo = await picker.pickImage(source: ImageSource.camera);
                if (photo != null) {
                  setState(() => _evidenceImages.add(photo));
                  _checkRequiredFields();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeImage(int index) {
    setState(() => _evidenceImages.removeAt(index));
    _checkRequiredFields();
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
      final rawExt = imageFile.name.contains('.')
          ? imageFile.name.split('.').last.toLowerCase()
          : 'jpg';
      final extension = rawExt == 'jpg' ? 'jpeg' : rawExt;
      final mimeType = 'image/$extension';
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

  Future<void> _loadData() async {
    try {
      final history = await PostRepairService.fetchByWorkRequest(widget.request.id);
      final sorted = List<PostRepairReport>.from(history)
        ..sort((a, b) => a.attemptNumber.compareTo(b.attemptNumber));
      final signatures = await ESignatureService.fetchByWorkRequest(widget.request.id);
      
      if (!mounted) return;
      setState(() {
        _history = sorted;
        _signatures = signatures;
        _nextAttemptNumber = sorted.length + 1;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isEntryMode {
    if (widget.forceHistoryView) return false;

    final status = widget.request.status.toLowerCase().trim();
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    final isMaintenance = user?.role.name == 'maintenance';
    if (!isMaintenance) return false;

    if (status == 'completed' || status == 'cancelled' || status == 'declined' || status == 'rejected') {
      return false;
    }

    if (_history.isEmpty) {
      return status == 'confirmed' ||
          status == 'under_maintenance' ||
          status == 'in_progress' ||
          status == 'in progress' ||
          status == 'in progress (post-repair)' ||
          status == 'pre-inspection approved' ||
          status == 'rework' ||
          status == 'for rework';
    }

    final sorted = List<PostRepairReport>.from(_history)
      ..sort((a, b) => a.attemptNumber.compareTo(b.attemptNumber));
    final latest = sorted.last;

    // If report is already submitted and pending admin evaluation, show history!
    if (latest.adminEvaluation == null ||
        latest.status.toLowerCase() == 'pending' ||
        latest.status.toLowerCase() == 'submitted') {
      return false;
    }

    // If latest attempt was marked rework, allow entry mode
    if (latest.adminEvaluation == 'rework') {
      return true;
    }

    return false;
  }

  void _openSignatureDialog() {
    if (!_formKey.currentState!.validate()) return;

    if (_evidenceImages.isEmpty && (widget.request.workEvidence == null || widget.request.workEvidence!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one work evidence photo.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
                subtitle: 'Sign to confirm post-repair completion',
                onSignatureComplete: (base64) {
                  Navigator.pop(ctx, base64);
                },
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((signature) {
      if (signature != null && signature.isNotEmpty) {
        _submitPostRepair(signature);
      }
    });
  }

  Future<void> _submitPostRepair(String signatureData) async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      // 0. Upload Evidence Images if new ones exist
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

      // 1. Insert E-Signature
      await ESignatureService.insert(
        ESignature(
          id: '',
          workRequestId: widget.request.id,
          signerId: user.id,
          signerName: user.name,
          signerRole: 'maintenance',
          signatureType: 'post_repair',
          signatureData: signatureData,
          signedAt: DateTime.now(),
        ),
      );

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
          materialsUsed: _materialsController.text.trim().isEmpty
              ? null
              : _materialsController.text.trim(),
          photoAfter: reportPhotoAfter,
          repairDuration: _durationController.text.trim().isEmpty
              ? null
              : _durationController.text.trim(),
          repairStatus: _repairStatus,
          technicianNotes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          status: 'Pending',
        ),
      );

      // 3. Update Work Request Status back to 'Confirmed' so campus admin can evaluate
      await WorkRequestService.updateStatus(
        widget.request.id,
        'Confirmed',
      );

      // 4. Notify Campus Admin and Requestor for transparency
      try {
        await AppNotificationService.notifyPostRepairSubmittedToAdmin(
          workRequestId: widget.request.id,
          maintenanceName: user.name,
          maintenanceUserId: user.id,
          adminId: widget.request.approvedById,
          requestorId: widget.request.requestorId,
        );
      } catch (e) {
        debugPrint('Post-repair notification error: $e');
      }

      await LoginActivityService.recordMaintenanceAction(
        user: user,
        title: 'Submitted Post-Repair Report',
        details: 'Submitted post-repair report for #${widget.request.id} (${widget.request.title}) - Status: $_repairStatus',
        workRequestId: widget.request.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post-Repair report submitted successfully!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isUploadingEvidence = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: CommonAppBar(
        titleText: _isEntryMode ? 'Post-Inspection Form' : 'Post-Inspection Report',
        roleText: _isEntryMode ? '' : 'VIEW ONLY',
        primaryColor: themeProvider.primaryColor,
        showBack: true,
        onBackPressed: () => Navigator.pop(context),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4169E1)),
            )
          : _isSubmitting
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF4169E1)),
                      const SizedBox(height: 16),
                      Text(
                        _isUploadingEvidence
                            ? 'Uploading evidence photos...'
                            : 'Submitting report...',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : _isEntryMode
                  ? _buildEntryForm(themeProvider)
                  : _buildHistoryView(themeProvider),
    );
  }

  Widget _buildEntryForm(ThemeProvider themeProvider) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Overview Card
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
                Text(
                  'Work Request #${widget.request.id.substring(0, 8).toUpperCase()} • Attempt #$_nextAttemptNumber',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4169E1),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.request.title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: themeProvider.textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Location: ${widget.request.buildingName} • ${widget.request.officeRoom}',
                  style: TextStyle(fontSize: 11, color: themeProvider.subtitleColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Requestor: ${widget.request.displayRequestorName}',
                  style: TextStyle(
                    fontSize: 11,
                    color: themeProvider.subtitleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Fields Group Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: themeProvider.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeProvider.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'POST-REPAIR REPORT DETAILS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Work Performed (Required)
                _buildLabel('Work Performed * REQUIRED', themeProvider),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _workPerformedController,
                  maxLines: 4,
                  style: TextStyle(fontSize: 14, color: themeProvider.textColor),
                  decoration: _inputDecoration('Describe details of work performed...', themeProvider),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please describe work performed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Repair Status (Dropdown)
                _buildLabel('Repair Outcome Status', themeProvider),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _repairStatus,
                  dropdownColor: themeProvider.cardColor,
                  style: TextStyle(fontSize: 14, color: themeProvider.textColor),
                  decoration: _inputDecoration('', themeProvider),
                  items: [
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed', style: TextStyle(color: themeProvider.textColor)),
                    ),
                    DropdownMenuItem(
                      value: 'partial',
                      child: Text('Partial', style: TextStyle(color: themeProvider.textColor)),
                    ),
                    DropdownMenuItem(
                      value: 'needs_followup',
                      child: Text('Needs Follow-up', style: TextStyle(color: themeProvider.textColor)),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _repairStatus = v);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Materials Used (Optional)
                _buildLabel('Materials Used', themeProvider),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _materialsController,
                  maxLines: 2,
                  style: TextStyle(fontSize: 14, color: themeProvider.textColor),
                  decoration: _inputDecoration('List materials used for the repair...', themeProvider),
                ),
                const SizedBox(height: 16),

                // Duration (Optional)
                _buildLabel('Duration of Repair', themeProvider),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _durationController,
                  style: TextStyle(fontSize: 14, color: themeProvider.textColor),
                  decoration: _inputDecoration('e.g., 3 hours, 2 days', themeProvider),
                ),
                const SizedBox(height: 16),

                // Technician Notes (Optional)
                _buildLabel('Technician Notes', themeProvider),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  style: TextStyle(fontSize: 14, color: themeProvider.textColor),
                  decoration: _inputDecoration('Any extra completion notes...', themeProvider),
                ),
                const SizedBox(height: 16),

                // Photo Evidence (Required)
                Row(
                  children: [
                    _buildLabel('Photo Evidence', themeProvider),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'REQUIRED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildEvidenceSection(),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Conditional "Work Completion" button appearance
          if (_showWorkCompletionButton)
            ElevatedButton(
              onPressed: _openSignatureDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const SizedBox(
                width: double.infinity,
                child: Center(
                  child: Text(
                    'Work Completion',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? const Color(0xFF1E293B)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: themeProvider.borderColor),
              ),
              child: Center(
                child: Text(
                  'Please fill in Work Performed and attach Photo Evidence to proceed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: themeProvider.subtitleColor,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHistoryView(ThemeProvider themeProvider) {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No repair reports submitted yet.',
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final displayList = List<PostRepairReport>.from(_history)
      ..sort((a, b) => b.attemptNumber.compareTo(a.attemptNumber));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final report = displayList[index];
        final techSig = _signatures.firstWhere(
          (sig) => sig.signatureType == 'post_repair' && sig.signerId == report.technicianId,
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

        final adminSig = _signatures.firstWhere(
          (sig) => sig.signatureType == 'completion' && sig.signerId == report.adminEvaluatedBy,
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

        final evaluationSatisfied = report.adminEvaluation == 'satisfied';
        final isEvaluationMade = report.adminEvaluation != null;

        return Card(
          color: themeProvider.cardColor,
          margin: const EdgeInsets.only(bottom: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: themeProvider.borderColor),
          ),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header
              Container(
                color: themeProvider.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFF1A1A2E),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ATTEMPT #${report.attemptNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: report.status == 'Completed'
                            ? const Color(0xFF059669)
                            : report.status == 'Rework'
                                ? const Color(0xFFDC2626)
                                : Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        report.statusLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Details Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Technician', report.technicianName),
                    _buildInfoRow('Repair Date', _formatDate(report.repairDate)),
                    _buildInfoRow('Outcome Status', report.repairStatusLabel),
                    _buildInfoRow('Work Performed', report.workPerformed),
                    if (report.materialsUsed != null) _buildInfoRow('Materials Used', report.materialsUsed!),
                    if (report.repairDuration != null) _buildInfoRow('Duration', report.repairDuration!),
                    if (report.technicianNotes != null) _buildInfoRow('Notes', report.technicianNotes!),
                    
                    if (report.photoAfter != null && report.photoAfter!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Photo Evidence:', style: TextStyle(fontSize: 11, color: themeProvider.subtitleColor)),
                      const SizedBox(height: 6),
                      _buildHistoryEvidencePhotos(report.photoAfter!),
                    ],

                    if (techSig.signatureData.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Technician Signature:', style: TextStyle(fontSize: 11, color: themeProvider.subtitleColor)),
                      const SizedBox(height: 4),
                      _buildSignatureImage(techSig.signatureData),
                    ],

                    // Evaluation decision card
                    if (isEvaluationMade) ...[
                      const Divider(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: themeProvider.isDarkMode
                              ? (evaluationSatisfied
                                  ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                                  : const Color(0xFF7F1D1D).withValues(alpha: 0.3))
                              : (evaluationSatisfied ? Colors.green.shade50 : Colors.red.shade50),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: themeProvider.isDarkMode
                                ? (evaluationSatisfied
                                    ? const Color(0xFF059669).withValues(alpha: 0.5)
                                    : const Color(0xFFDC2626).withValues(alpha: 0.5))
                                : (evaluationSatisfied ? Colors.green.shade200 : Colors.red.shade200),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              evaluationSatisfied ? 'EVALUATION: SATISFIED' : 'EVALUATION: REWORK REQUIRED',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: evaluationSatisfied ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              'Evaluated By',
                              adminSig.signerName.isNotEmpty
                                  ? adminSig.signerName
                                  : ((report.adminEvaluatedBy != null && report.adminEvaluatedBy!.length < 20)
                                      ? report.adminEvaluatedBy!
                                      : 'Campus Administrator'),
                            ),
                            _buildInfoRow('Evaluated Date', _formatDate(report.adminEvaluatedDate ?? report.updatedAt)),
                            if (report.adminEvaluationNotes != null)
                              _buildInfoRow('Evaluation Notes', report.adminEvaluationNotes!),
                            if (evaluationSatisfied && adminSig.signatureData.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Admin E-Signature:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 4),
                              _buildSignatureImage(adminSig.signatureData),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      const Divider(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: themeProvider.isDarkMode
                              ? const Color(0xFF78350F).withValues(alpha: 0.3)
                              : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: themeProvider.isDarkMode
                                ? const Color(0xFFD97706).withValues(alpha: 0.5)
                                : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pending_actions_rounded, color: Color(0xFFD97706), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Awaiting Campus Admin Evaluation',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.isDarkMode
                                      ? const Color(0xFFFCD34D)
                                      : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEvidenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_evidenceImages.isNotEmpty) ...[
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _evidenceImages.length,
              itemBuilder: (context, index) {
                final file = _evidenceImages[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: kIsWeb
                              ? Image.network(file.path, fit: BoxFit.cover)
                              : Image.file(File(file.path), fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _pickImages,
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: Text(
            _evidenceImages.isEmpty
                ? 'Upload Photo Evidence'
                : 'Add More Photos (${_evidenceImages.length} selected)',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4169E1),
            side: const BorderSide(color: Color(0xFF4169E1)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryEvidencePhotos(String photoAfterStr) {
    List<String> urls = [];
    try {
      if (photoAfterStr.startsWith('[')) {
        final List<dynamic> decoded = jsonDecode(photoAfterStr);
        urls = decoded.map((e) => e.toString()).toList();
      } else {
        urls = [photoAfterStr];
      }
    } catch (_) {
      urls = [photoAfterStr];
    }

    if (urls.isEmpty && widget.request.workEvidence != null && widget.request.workEvidence!.trim().isNotEmpty) {
      final cleanReq = widget.request.workEvidence!.trim();
      if (cleanReq.startsWith('[')) {
        try {
          final List<dynamic> decoded = jsonDecode(cleanReq);
          urls = decoded.map((e) => e.toString()).toList();
        } catch (_) {
          urls = [cleanReq];
        }
      } else {
        urls = [cleanReq];
      }
    }

    if (urls.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        itemBuilder: (context, idx) {
          final url = urls[idx];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _showImageDialog(url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 90,
                    height: 90,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showImageDialog(String url) {
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
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, ThemeProvider themeProvider) {
    return InputDecoration(
      hintText: hint.isNotEmpty ? hint : null,
      hintStyle: TextStyle(
        color: themeProvider.subtitleColor.withValues(alpha: 0.7),
        fontSize: 14,
      ),
      filled: true,
      fillColor: themeProvider.isDarkMode
          ? const Color(0xFF1E293B)
          : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: themeProvider.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: themeProvider.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF4169E1), width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(12),
    );
  }

  Widget _buildLabel(String text, [ThemeProvider? tp]) {
    final themeProvider = tp ?? Provider.of<ThemeProvider>(context, listen: false);
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: themeProvider.textColor,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 12, color: themeProvider.subtitleColor)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: themeProvider.textColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureImage(String base64Str) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    try {
      final cleaned = base64Str.trim().replaceAll(RegExp(r'\s+'), '');
      final base64Data = cleaned.contains(',') ? cleaned.split(',')[1] : cleaned;
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode ? const Color(0xFF1E293B) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: themeProvider.borderColor),
        ),
        child: Image.memory(
          base64Decode(base64Data),
          height: 50,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.gesture, size: 30, color: Colors.grey),
        ),
      );
    } catch (_) {
      return const Icon(Icons.gesture, size: 30, color: Colors.grey);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }
}

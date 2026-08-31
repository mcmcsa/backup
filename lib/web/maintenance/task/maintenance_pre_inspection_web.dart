import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/models/pre_inspection_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/pre_inspection_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/signature_pad_widget.dart';
import '../../admin/shared/admin_styles.dart';

class MaintenancePreInspectionWeb extends StatefulWidget {
  final WorkRequest request;
  final VoidCallback? onBack;

  const MaintenancePreInspectionWeb({super.key, required this.request, this.onBack});

  @override
  State<MaintenancePreInspectionWeb> createState() => _MaintenancePreInspectionWebState();
}

class _MaintenancePreInspectionWebState extends State<MaintenancePreInspectionWeb> {
  final _formKey = GlobalKey<FormState>();
  final _conditionController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rootCauseController = TextEditingController();
  final _recommendedActionController = TextEditingController();
  final _materialsController = TextEditingController();
  final _estimatedTimeController = TextEditingController();
  final _notesController = TextEditingController();

  String _severityLevel = 'Minor';
  String? _inspectorSignatureBase64;
  bool _isLoading = false;
  
  final List<XFile> _inspectionImages = [];
  bool _isUploadingImages = false;

  @override
  void dispose() {
    _conditionController.dispose();
    _descriptionController.dispose();
    _rootCauseController.dispose();
    _recommendedActionController.dispose();
    _materialsController.dispose();
    _estimatedTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      _showError('Please fill out the required fields.');
      return;
    }

    if (_inspectorSignatureBase64 == null) {
      _showError('Please provide your signature.');
      return;
    }

    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // 0. Upload Images
      String? photoUrl;
      if (_inspectionImages.isNotEmpty) {
        setState(() => _isUploadingImages = true);
        photoUrl = await _uploadImages(
          requestId: widget.request.id,
          imageFiles: _inspectionImages,
        );
      }

      // 1. Insert E-Signature
      await ESignatureService.insert(
        ESignature(
          id: '',
          workRequestId: widget.request.id,
          signerId: user.id,
          signerName: user.name,
          signerRole: 'maintenance',
          signatureType: 'pre_inspection',
          signatureData: _inspectorSignatureBase64!,
          signedAt: DateTime.now(),
        ),
      );

      // 2. Insert Pre-Inspection Report
      await PreInspectionService.insert(
        PreInspectionReport(
          id: '',
          workRequestId: widget.request.id,
          inspectorId: user.id,
          inspectorName: user.name,
          inspectionDate: DateTime.now(),
          conditionFound: _conditionController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          rootCause: _rootCauseController.text.trim().isEmpty ? null : _rootCauseController.text.trim(),
          severityLevel: _severityLevel,
          recommendedAction: _recommendedActionController.text.trim().isEmpty ? null : _recommendedActionController.text.trim(),
          materialsNeeded: _materialsController.text.trim().isEmpty ? null : _materialsController.text.trim(),
          estimatedTime: _estimatedTimeController.text.trim().isEmpty ? null : _estimatedTimeController.text.trim(),
          photoEvidence: photoUrl,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          status: 'Pending',
        ),
      );

      // 3. Update Work Request Status
      await WorkRequestService.updateStatus(widget.request.id, 'In Progress');

      // 4. Notify Campus Admin
      await AppNotificationService.notifyPreInspectionSubmittedToAdmin(
        workRequestId: widget.request.id,
        maintenanceName: user.name,
        adminId: widget.request.approvedById,
      );

      if (mounted) {
        _showSuccess('Pre-Inspection report submitted successfully!');
        if (widget.onBack != null) {
          widget.onBack!();
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) _showError('Submission failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.success));
  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.error));

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() => _inspectionImages.addAll(picked));
    }
  }

  void _removeImage(int index) {
    setState(() => _inspectionImages.removeAt(index));
  }

  Future<String> _uploadImages({
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
      final path = 'work-evidence/$requestId/pre_${DateTime.now().millisecondsSinceEpoch}_$i.$extension';

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
    return jsonEncode(urls);
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 960;

    return Scaffold(
      backgroundColor: AdminStyles.bg,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary))
                : SingleChildScrollView(
                    padding: EdgeInsets.all(isCompact ? 16 : 32),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTaskSummary(),
                              const SizedBox(height: 24),
                              _buildFormFields(isCompact),
                              const SizedBox(height: 24),
                              _buildSignatureSection(),
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
          Text('Submit Pre-Inspection Report', style: AdminStyles.headingStyle(fontSize: 20)),
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
              const Icon(Icons.assignment_rounded, color: AdminStyles.primary),
              const SizedBox(width: 12),
              Text('Work Request #$trackId', style: AdminStyles.headingStyle(fontSize: 16, color: AdminStyles.primary)),
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
          Text('Inspection Details', style: AdminStyles.headingStyle(fontSize: 16)),
          const SizedBox(height: 24),
          _buildWebTextField(_conditionController, 'Condition Found *', 'Describe the exact issue found...', required: true),
          const SizedBox(height: 16),
          _buildWebTextField(_descriptionController, 'Detailed Description', 'Provide more context about the condition...', maxLines: 3),
          const SizedBox(height: 16),
          if (isCompact) ...[
            _buildWebTextField(_rootCauseController, 'Root Cause (Optional)', 'What caused the issue?'),
            const SizedBox(height: 16),
            _buildSeverityDropdown(),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildWebTextField(_rootCauseController, 'Root Cause (Optional)', 'What caused the issue?')),
                const SizedBox(width: 16),
                Expanded(child: _buildSeverityDropdown()),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _buildWebTextField(_recommendedActionController, 'Recommended Action', 'What needs to be done?', maxLines: 2),
          const SizedBox(height: 16),
          _buildWebTextField(_materialsController, 'Materials/Parts Needed', 'List required parts and estimated costs...'),
          const SizedBox(height: 16),
          if (isCompact) ...[
            _buildWebTextField(_estimatedTimeController, 'Estimated Repair Time', 'e.g., 2 hours, 1 day'),
            const SizedBox(height: 16),
            _buildWebTextField(_notesController, 'Additional Notes', 'Any other information for the admin?'),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildWebTextField(_estimatedTimeController, 'Estimated Repair Time', 'e.g., 2 hours, 1 day')),
                const SizedBox(width: 16),
                Expanded(child: _buildWebTextField(_notesController, 'Additional Notes', 'Any other information for the admin?')),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text('Inspection Photos', style: AdminStyles.headingStyle(fontSize: 16)),
          const SizedBox(height: 16),
          _buildImageUploadSection(),
        ],
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upload Images (Optional)', style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_inspectionImages.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(_inspectionImages.length, (index) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _inspectionImages[index].path,
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
        if (_inspectionImages.isNotEmpty) const SizedBox(height: 12),
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
                Text('Upload Photos', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.primary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeverityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Severity Level', style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminStyles.textPrimary)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _severityLevel,
          decoration: _inputDecoration('Select severity'),
          items: ['Minor', 'Moderate', 'Critical']
              .map((e) => DropdownMenuItem(value: e, child: Text(e, style: AdminStyles.bodyStyle(fontSize: 14))))
              .toList(),
          onChanged: (v) => setState(() => _severityLevel = v!),
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

  Widget _buildSignatureSection() {
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
          SignaturePadWidget(
            title: 'Inspector Signature',
            subtitle: 'Sign below to confirm your inspection findings',
            onSignatureComplete: (v) => setState(() => _inspectorSignatureBase64 = v),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminStyles.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Confirm Work Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

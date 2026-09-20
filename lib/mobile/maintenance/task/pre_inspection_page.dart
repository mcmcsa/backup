import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/pre_inspection_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/pre_inspection_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/signature_pad_widget.dart';

class PreInspectionPage extends StatefulWidget {
  final WorkRequest request;

  const PreInspectionPage({super.key, required this.request});

  @override
  State<PreInspectionPage> createState() => _PreInspectionPageState();
}

class _PreInspectionPageState extends State<PreInspectionPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _rootCauseController = TextEditingController();
  final TextEditingController _recommendedActionController = TextEditingController();
  final TextEditingController _materialsController = TextEditingController();
  final TextEditingController _estimatedTimeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<XFile> _inspectionImages = [];
  bool _isUploadingImages = false;

  String _severityLevel = 'Minor';
  bool _isLoading = true;
  bool _showConfirmButton = false;

  PreInspectionReport? _existingReport;
  ESignature? _existingSignature;
  bool get isReadonly => _existingReport != null;

  @override
  void initState() {
    super.initState();
    _conditionController.addListener(_checkRequiredFields);
    _loadExistingReport();
  }

  Future<void> _loadExistingReport() async {
    try {
      final report = await PreInspectionService.fetchLatestByWorkRequest(widget.request.id);
      ESignature? signature;
      if (report != null) {
        try {
          final sigs = await ESignatureService.fetchByWorkRequest(widget.request.id);
          signature = sigs.firstWhere(
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
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _existingReport = report;
          _existingSignature = (signature != null && signature.signatureData.isNotEmpty) ? signature : null;
          if (report != null) {
            _conditionController.text = report.conditionFound;
            _descriptionController.text = report.description ?? '';
            _rootCauseController.text = report.rootCause ?? '';
            _severityLevel = ['Minor', 'Moderate', 'Critical'].contains(report.severityLevel)
                ? report.severityLevel
                : 'Minor';
            _recommendedActionController.text = report.recommendedAction ?? '';
            _materialsController.text = report.materialsNeeded ?? '';
            _estimatedTimeController.text = report.estimatedTime ?? '';
            _notesController.text = report.notes ?? '';
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _parseEvidenceUrls(String? evidence) {
    if (evidence == null || evidence.trim().isEmpty) return [];
    final clean = evidence.trim();
    if (clean.startsWith('[') && clean.endsWith(']')) {
      try {
        final List<dynamic> decoded = jsonDecode(clean);
        return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    if (clean.contains(',')) {
      return clean.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [clean];
  }

  @override
  void dispose() {
    _conditionController.removeListener(_checkRequiredFields);
    _conditionController.dispose();
    _descriptionController.dispose();
    _rootCauseController.dispose();
    _recommendedActionController.dispose();
    _materialsController.dispose();
    _estimatedTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _checkRequiredFields() {
    if (isReadonly) return;
    final hasCondition = _conditionController.text.trim().isNotEmpty;
    if (_showConfirmButton != hasCondition) {
      setState(() {
        _showConfirmButton = hasCondition;
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
                  setState(() => _inspectionImages.addAll(picked));
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
                  setState(() => _inspectionImages.add(photo));
                }
              },
            ),
          ],
        ),
      ),
    );
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
      final file = imageFiles[i];
      final bytes = await file.readAsBytes();
      final rawExt = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : 'jpg';
      final extension = rawExt == 'jpg' ? 'jpeg' : rawExt;
      final mimeType = 'image/$extension';
      final fileName = 'pre_${DateTime.now().millisecondsSinceEpoch}_$i.$rawExt';
      final path = 'work-evidence/$requestId/$fileName';

      String? url;
      for (final bucket in ['work-evidence', 'work-request-attachments']) {
        try {
          await client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );
          url = client.storage.from(bucket).getPublicUrl(path);
          if (url.isNotEmpty) break;
        } catch (_) {}
      }

      url ??= 'data:$mimeType;base64,${base64Encode(bytes)}';
      urls.add(url);
    }
    return jsonEncode(urls);
  }

  void _openSignatureDialog() {
    if (!_formKey.currentState!.validate()) return;

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
                subtitle: 'Sign to confirm this pre-inspection report',
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
        _submitReport(signature);
      }
    });
  }

  Future<void> _submitReport(String signatureData) async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // 0. Upload inspection photos if any
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
          signatureData: signatureData,
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
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          rootCause: _rootCauseController.text.trim().isEmpty
              ? null
              : _rootCauseController.text.trim(),
          severityLevel: _severityLevel,
          recommendedAction: _recommendedActionController.text.trim().isEmpty
              ? null
              : _recommendedActionController.text.trim(),
          materialsNeeded: _materialsController.text.trim().isEmpty
              ? null
              : _materialsController.text.trim(),
          estimatedTime: _estimatedTimeController.text.trim().isEmpty
              ? null
              : _estimatedTimeController.text.trim(),
          photoEvidence: photoUrl,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          status: 'Pending',
        ),
      );

      // 3. Update Work Request Status to Confirmed once pre-inspection is submitted
      await WorkRequestService.updateStatus(
        widget.request.id,
        'Confirmed',
      );

      // 4. Notify Campus Admin and Requestor for transparency
      try {
        await AppNotificationService.notifyPreInspectionSubmittedToAdmin(
          workRequestId: widget.request.id,
          maintenanceName: user.name,
          maintenanceUserId: user.id,
          adminId: widget.request.approvedById,
          requestorId: widget.request.requestorId,
        );
      } catch (e) {
        debugPrint('Pre-inspection notification error: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pre-Inspection report submitted successfully!'),
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
          _isLoading = false;
          _isUploadingImages = false;
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
        titleText: isReadonly ? 'Pre-Inspection Report' : 'Pre-Inspection Form',
        roleText: isReadonly ? 'VIEW ONLY' : '',
        primaryColor: themeProvider.primaryColor,
        showBack: true,
        onBackPressed: () => Navigator.pop(context),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF4169E1)),
                  const SizedBox(height: 16),
                  Text(
                    _isUploadingImages
                        ? 'Uploading photos...'
                        : (isReadonly ? 'Loading inspection report...' : 'Please wait...'),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4169E1)),
                  ),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Form Header Overview
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: themeProvider.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: themeProvider.borderColor,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Work Request #${widget.request.id.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4169E1),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.request.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Location: ${widget.request.buildingName} • ${widget.request.officeRoom}',
                          style: TextStyle(
                            fontSize: 11,
                            color: themeProvider.subtitleColor,
                          ),
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

                  // If already submitted, show Status and Evaluation Card at top
                  if (isReadonly) ...[
                    _buildStatusAndEvaluationCard(themeProvider),
                    const SizedBox(height: 20),
                  ],

                  // Fields Group Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: themeProvider.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: themeProvider.borderColor,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'PRE-INSPECTION DETAILS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (isReadonly)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'READ-ONLY',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Condition Found (Required)
                        _buildLabel('Condition Found * REQUIRED', themeProvider),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _conditionController,
                          readOnly: isReadonly,
                          maxLines: 3,
                          style: TextStyle(fontSize: 14, color: themeProvider.textColor),
                          decoration: InputDecoration(
                            hintText: 'Describe physical condition found...',
                            filled: isReadonly,
                            fillColor: isReadonly
                                ? (themeProvider.isDarkMode
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.grey.shade50)
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please describe condition found';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Severity Level (Dropdown)
                        _buildLabel('Severity Level', themeProvider),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _severityLevel,
                          decoration: InputDecoration(
                            filled: isReadonly,
                            fillColor: isReadonly
                                ? (themeProvider.isDarkMode
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.grey.shade50)
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: ['Minor', 'Moderate', 'Critical']
                              .map(
                                (level) => DropdownMenuItem(
                                  value: level,
                                  child: Text(level),
                                ),
                              )
                              .toList(),
                          onChanged: isReadonly
                              ? null
                              : (v) {
                                  if (v != null) {
                                    setState(() => _severityLevel = v);
                                  }
                                },
                        ),
                        const SizedBox(height: 16),

                        // Description (Optional)
                        _buildLabel('Additional Description', themeProvider),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          readOnly: isReadonly,
                          maxLines: 2,
                          style: TextStyle(fontSize: 14, color: themeProvider.textColor),
                          decoration: InputDecoration(
                            hintText: 'Any extra details regarding inspection...',
                            filled: isReadonly,
                            fillColor: isReadonly
                                ? (themeProvider.isDarkMode
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.grey.shade50)
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Root Cause (Optional)
                        _buildLabel('Root Cause', themeProvider),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _rootCauseController,
                          readOnly: isReadonly,
                          maxLines: 2,
                          style: TextStyle(fontSize: 14, color: themeProvider.textColor),
                          decoration: InputDecoration(
                            hintText: 'What caused the damage/defect?',
                            filled: isReadonly,
                            fillColor: isReadonly
                                ? (themeProvider.isDarkMode
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.grey.shade50)
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Recommended Action (Optional)
                        _buildLabel('Recommended Action', themeProvider),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _recommendedActionController,
                          readOnly: isReadonly,
                          maxLines: 2,
                          style: TextStyle(fontSize: 14, color: themeProvider.textColor),
                          decoration: InputDecoration(
                            hintText: 'Action path recommended to solve the issue...',
                            filled: isReadonly,
                            fillColor: isReadonly
                                ? (themeProvider.isDarkMode
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.grey.shade50)
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Materials Needed (Optional)
                        _buildLabel('Materials Needed', themeProvider),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _materialsController,
                          readOnly: isReadonly,
                          maxLines: 2,
                          style: TextStyle(fontSize: 14, color: themeProvider.textColor),
                          decoration: InputDecoration(
                            hintText: 'List materials required for repair...',
                            filled: isReadonly,
                            fillColor: isReadonly
                                ? (themeProvider.isDarkMode
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.grey.shade50)
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Estimated Time (Optional)
                        _buildLabel('Estimated Repair Duration', themeProvider),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _estimatedTimeController,
                          readOnly: isReadonly,
                          style: TextStyle(fontSize: 14, color: themeProvider.textColor),
                          decoration: InputDecoration(
                            hintText: 'e.g., 2 hours, 1 day',
                            filled: isReadonly,
                            fillColor: isReadonly
                                ? (themeProvider.isDarkMode
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.grey.shade50)
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Notes (Optional)
                        _buildLabel('General Notes', themeProvider),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _notesController,
                          readOnly: isReadonly,
                          maxLines: 2,
                          style: TextStyle(fontSize: 14, color: themeProvider.textColor),
                          decoration: InputDecoration(
                            hintText: 'Any other observations...',
                            filled: isReadonly,
                            fillColor: isReadonly
                                ? (themeProvider.isDarkMode
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.grey.shade50)
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Inspection Photos
                        _buildLabel('Inspection Photos', themeProvider),
                        const SizedBox(height: 8),
                        _buildImageSection(themeProvider),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Bottom action buttons
                  if (isReadonly) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text(
                          'Back to Task Details',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4169E1),
                          side: const BorderSide(color: Color(0xFF4169E1)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    if (_showConfirmButton)
                      ElevatedButton(
                        onPressed: _openSignatureDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BFA5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const SizedBox(
                          width: double.infinity,
                          child: Center(
                            child: Text(
                              'Confirm Work Request',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: const Center(
                          child: Text(
                            'Please fill in Condition Found to proceed',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusAndEvaluationCard(ThemeProvider themeProvider) {
    if (_existingReport == null) return const SizedBox.shrink();
    final rep = _existingReport!;
    final isApproved = rep.status == 'Approved';
    final isDeclined = rep.status == 'Declined';

    final badgeColor = isApproved
        ? const Color(0xFF059669)
        : (isDeclined ? const Color(0xFFDC2626) : const Color(0xFFD97706));
    final badgeBg = isApproved
        ? (themeProvider.isDarkMode ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5))
        : (isDeclined
            ? (themeProvider.isDarkMode ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2))
            : (themeProvider.isDarkMode ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFFFBEB)));
    final badgeBorder = isApproved
        ? const Color(0xFFA7F3D0)
        : (isDeclined ? const Color(0xFFFECACA) : const Color(0xFFFDE68A));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeProvider.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_turned_in_rounded, color: badgeColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'REPORT EVALUATION STATUS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.subtitleColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Filed by ${rep.inspectorName}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: themeProvider.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Date: ${_formatDateTime(rep.inspectionDate)}',
            style: TextStyle(fontSize: 12, color: themeProvider.subtitleColor),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isApproved
                      ? Icons.verified_rounded
                      : (isDeclined ? Icons.cancel_rounded : Icons.pending_actions_rounded),
                  color: badgeColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isApproved
                            ? 'PRE-INSPECTION APPROVED'
                            : (isDeclined
                                ? 'PRE-INSPECTION DECLINED'
                                : 'PENDING CAMPUS ADMIN REVIEW'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                      if (rep.reviewNotes != null && rep.reviewNotes!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Admin Review Notes: ${rep.reviewNotes}',
                          style: TextStyle(
                            fontSize: 12,
                            color: themeProvider.textColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_existingSignature != null) ...[
            const SizedBox(height: 14),
            Text(
              'Technician Signature:',
              style: TextStyle(fontSize: 11, color: themeProvider.subtitleColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              height: 60,
              width: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildNetworkOrBase64Image(_existingSignature!.signatureData),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageSection(ThemeProvider themeProvider) {
    if (isReadonly) {
      final evidence = _existingReport?.photoEvidence;
      final urls = _parseEvidenceUrls(evidence);
      if (urls.isEmpty) {
        return Text(
          'No photo evidence attached.',
          style: TextStyle(
            fontSize: 13,
            color: themeProvider.subtitleColor,
            fontStyle: FontStyle.italic,
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              itemBuilder: (context, index) {
                final url = urls[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () => _showImageDialog(url),
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: themeProvider.borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _buildNetworkOrBase64Image(url),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap photo to view full size',
            style: TextStyle(fontSize: 11, color: themeProvider.subtitleColor),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_inspectionImages.isNotEmpty) ...[
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _inspectionImages.length,
              itemBuilder: (context, index) {
                final file = _inspectionImages[index];
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
            _inspectionImages.isEmpty
                ? 'Add Inspection Photos'
                : 'Add More Photos (${_inspectionImages.length} selected)',
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

  Widget _buildNetworkOrBase64Image(String url) {
    if (url.startsWith('data:image')) {
      try {
        final base64Str = url.split(',').last;
        return Image.memory(base64Decode(base64Str), fit: BoxFit.cover);
      } catch (_) {
        return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
    );
  }

  void _showImageDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                child: _buildNetworkOrBase64Image(url),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
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
}

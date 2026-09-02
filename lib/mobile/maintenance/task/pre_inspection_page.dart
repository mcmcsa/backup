import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  String _severityLevel = 'Minor';
  bool _isLoading = false;
  bool _showConfirmButton = false;

  @override
  void initState() {
    super.initState();
    _conditionController.addListener(_checkRequiredFields);
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
    final hasCondition = _conditionController.text.trim().isNotEmpty;
    if (_showConfirmButton != hasCondition) {
      setState(() {
        _showConfirmButton = hasCondition;
      });
    }
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
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          status: 'Pending',
        ),
      );

      // 3. Update Work Request Status (Keep as In Progress, but triggers updated_at)
      await WorkRequestService.updateStatus(
        widget.request.id,
        'In Progress',
      );

      // 4. Notify Campus Admin
      await AppNotificationService.notifyPreInspectionSubmittedToAdmin(
        workRequestId: widget.request.id,
        maintenanceName: user.name,
        adminId: widget.request.approvedById,
      );

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: CommonAppBar(
        roleText: 'Pre-Inspection Entry',
        primaryColor: themeProvider.primaryColor,
        showBack: true,
        onBackPressed: () => Navigator.pop(context),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4169E1)),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
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
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Location: ${widget.request.buildingName} • ${widget.request.officeRoom}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Requestor: ${widget.request.displayRequestorName}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(height: 16),

                        // Condition Found (Required)
                        _buildLabel('Condition Found * REQUIRED'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _conditionController,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Describe physical condition found...',
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
                        _buildLabel('Severity Level'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _severityLevel,
                          decoration: InputDecoration(
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
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _severityLevel = v);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Description (Optional)
                        _buildLabel('Additional Description'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Any extra details regarding inspection...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Root Cause (Optional)
                        _buildLabel('Root Cause'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _rootCauseController,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'What caused the damage/defect?',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Recommended Action (Optional)
                        _buildLabel('Recommended Action'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _recommendedActionController,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Action path recommended to solve the issue...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Materials Needed (Optional)
                        _buildLabel('Materials Needed'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _materialsController,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'List materials required for repair...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Estimated Time (Optional)
                        _buildLabel('Estimated Repair Duration'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _estimatedTimeController,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'e.g., 2 hours, 1 day',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Notes (Optional)
                        _buildLabel('General Notes'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Any other observations...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Confirm button conditional appearance
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}

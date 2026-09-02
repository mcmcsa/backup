import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/post_repair_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/signature_pad_widget.dart';
import 'dart:convert';

class PostRepairPage extends StatefulWidget {
  final WorkRequest request;

  const PostRepairPage({super.key, required this.request});

  @override
  State<PostRepairPage> createState() => _PostRepairPageState();
}

class _PostRepairPageState extends State<PostRepairPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _workPerformedController = TextEditingController();
  final TextEditingController _materialsController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

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
    if (_showWorkCompletionButton != hasWork) {
      setState(() {
        _showWorkCompletionButton = hasWork;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final history = await PostRepairService.fetchByWorkRequest(widget.request.id);
      final signatures = await ESignatureService.fetchByWorkRequest(widget.request.id);
      
      if (!mounted) return;
      setState(() {
        _history = history;
        _signatures = signatures;
        _nextAttemptNumber = history.length + 1;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isEntryMode {
    final status = widget.request.status;
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    final isMaintenance = user?.role.name == 'maintenance';
    return isMaintenance && (status == 'Confirmed' || status == 'Rework' || status == 'Pre-Inspection Approved' || status == 'For Rework');
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

      // 3. Update Work Request Status (Keep as current status, but triggers updated_at)
      await WorkRequestService.updateStatus(
        widget.request.id,
        widget.request.status,
      );

      // 4. Notify Campus Admin
      await AppNotificationService.notifyPostRepairSubmittedToAdmin(
        workRequestId: widget.request.id,
        maintenanceName: user.name,
        adminId: widget.request.approvedById,
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: CommonAppBar(
        roleText: _isEntryMode ? 'Post-Repair Report' : 'Repair Attempts History',
        primaryColor: themeProvider.primaryColor,
        showBack: true,
        onBackPressed: () => Navigator.pop(context),
      ),
      body: _isLoading || _isSubmitting
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4169E1)),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Location: ${widget.request.buildingName} • ${widget.request.officeRoom}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
              border: Border.all(color: const Color(0xFFE5E7EB)),
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
                _buildLabel('Work Performed * REQUIRED'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _workPerformedController,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Describe details of work performed...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please describe work performed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Repair Status (Dropdown)
                _buildLabel('Repair Outcome Status'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _repairStatus,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'partial', child: Text('Partial')),
                    DropdownMenuItem(value: 'needs_followup', child: Text('Needs Follow-up')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _repairStatus = v);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Materials Used (Optional)
                _buildLabel('Materials Used'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _materialsController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'List materials used for the repair...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),

                // Duration (Optional)
                _buildLabel('Duration of Repair'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _durationController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g., 3 hours, 2 days',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),

                // Technician Notes (Optional)
                _buildLabel('Technician Notes'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Any extra completion notes...',
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
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Center(
                child: Text(
                  'Please fill in Work Performed to proceed',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
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

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final report = _history[index];
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
          margin: const EdgeInsets.only(bottom: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header
              Container(
                color: const Color(0xFF1A1A2E),
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
                    
                    if (techSig.signatureData.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Technician Signature:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      _buildSignatureImage(techSig.signatureData),
                    ],

                    // Evaluation decision card
                    if (isEvaluationMade) ...[
                      const Divider(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: evaluationSatisfied ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: evaluationSatisfied ? Colors.green.shade200 : Colors.red.shade200,
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
                                color: evaluationSatisfied ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow('Evaluated By', adminSig.signerName.isNotEmpty ? adminSig.signerName : (report.adminEvaluatedBy ?? 'Admin')),
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureImage(String base64Str) {
    try {
      final cleaned = base64Str.trim().replaceAll(RegExp(r'\s+'), '');
      final base64Data = cleaned.contains(',') ? cleaned.split(',')[1] : cleaned;
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade200),
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

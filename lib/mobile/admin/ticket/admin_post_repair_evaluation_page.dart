import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../shared/services/post_repair_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/widgets/workflow_status_badge.dart';
import '../../../shared/widgets/signature_pad_widget.dart';
import 'dart:convert';

/// Admin screen to evaluate post-repair report - mark satisfied or rework
class AdminPostRepairEvaluationPage extends StatefulWidget {
  final WorkRequest request;

  const AdminPostRepairEvaluationPage({super.key, required this.request});

  @override
  State<AdminPostRepairEvaluationPage> createState() =>
      _AdminPostRepairEvaluationPageState();
}

class _AdminPostRepairEvaluationPageState
    extends State<AdminPostRepairEvaluationPage> {
  bool _isLoading = true;
  bool _isProcessing = false;
  PostRepairReport? _report;
  final _reworkNotesController = TextEditingController();

  List<PostRepairReport> _history = [];
  List<ESignature> _signatures = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final history = await PostRepairService.fetchByWorkRequest(widget.request.id);
      final signatures = await ESignatureService.fetchByWorkRequest(widget.request.id);
      if (mounted) {
        setState(() {
          _history = history;
          _report = history.isNotEmpty ? history.first : null;
          _signatures = signatures;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _reworkNotesController.dispose();
    super.dispose();
  }

  void _openCompletionSignatureDialog() {
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
                subtitle: 'Sign to confirm work completion approval',
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
        _markCompletedWithSignature(signature);
      }
    });
  }

  Future<void> _markCompletedWithSignature(String signatureData) async {
    if (_report == null) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isProcessing = true);

    try {
      // 1. Save Admin E-Signature (type 'completion')
      await ESignatureService.insert(
        ESignature(
          id: '',
          workRequestId: widget.request.id,
          signerId: user.id,
          signerName: user.name,
          signerRole: 'campadmin',
          signatureType: 'completion',
          signatureData: signatureData,
          signedAt: DateTime.now(),
        ),
      );

      // 2. Mark Satisfied in database
      await PostRepairService.markSatisfied(_report!.id, user.id);

      // 3. Mark Request Completed
      await WorkRequestService.updateStatus(widget.request.id, 'Completed');

      // 4. Notify requestor
      await AppNotificationService.notifyAdminCompletionSubmittedToRequestor(
        workRequestId: widget.request.id,
        adminName: user.name,
        requestorId: widget.request.requestorId,
      );

      // 5. Notify maintenance user & Requestor
      final maintId = widget.request.assignedToId;
      if (maintId != null && maintId.trim().isNotEmpty && maintId.trim() != 'null') {
        await AppNotificationService.notifyPostRepairCompleted(
          workRequestId: widget.request.id,
          maintenanceId: maintId,
          adminName: user.name,
        );
      }

      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Post-Repair Completed',
        details: 'Marked request as completed with signature for ${widget.request.officeRoom}',
        workRequestId: widget.request.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Post-repair approved. Work request completed successfully.',
            ),
            backgroundColor: Color(0xFF059669),
          ),
        );
        Navigator.pop(context, 'completed');
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

  Future<void> _markRework() async {
    if (_report == null) return;
    final notes = _reworkNotesController.text.trim();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide rework notes'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isProcessing = true);

    try {
      await PostRepairService.markRework(_report!.id, user.id, notes);
      await WorkRequestService.setRework(widget.request.id, notes);

      // Notify maintenance user of rework
      final maintId = widget.request.assignedToId;
      if (maintId != null && maintId.trim().isNotEmpty && maintId.trim() != 'null') {
        await AppNotificationService.notifyPostRepairRework(
          workRequestId: widget.request.id,
          maintenanceId: maintId,
          adminName: user.name,
        );
      }

      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Post-Repair Rework',
        details: 'Returned request to rework for ${widget.request.officeRoom}',
        workRequestId: widget.request.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Work request sent back for rework'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        Navigator.pop(context, 'rework');
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
          'Post-Repair Evaluation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4169E1)))
          : _history.isEmpty
              ? const Center(child: Text('No post-repair reports found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final report = _history[index];
                    final authService = Provider.of<AuthService>(context, listen: false);
                    final user = authService.currentUser;
                    final isAdmin = user?.role.name == 'campadmin' || user?.role.name == 'admin';
                    
                    // Show evaluation buttons ONLY on the latest attempt (first element) and only when request is pending evaluation
                    final showActions = index == 0 &&
                        isAdmin &&
                        widget.request.status == 'Post-Repair Submitted' &&
                        report.status.toLowerCase() == 'pending';

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
                          // Attempt Header
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

                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow('Technician', report.technicianName),
                                _buildInfoRow('Repair Date', _formatDate(report.repairDate)),
                                _buildInfoRow('Duration', report.repairDuration ?? 'Not recorded'),
                                _buildInfoRow('Repair Outcome Status', report.repairStatusLabel),
                                const SizedBox(height: 12),

                                _buildSection('WORK PERFORMED', [
                                  Text(
                                    report.workPerformed,
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5),
                                  ),
                                ]),
                                const SizedBox(height: 12),

                                _buildSection('MATERIALS USED', [
                                  Text(
                                    report.materialsUsed?.isNotEmpty == true ? report.materialsUsed! : 'No materials recorded',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5),
                                  ),
                                ]),
                                const SizedBox(height: 12),

                                if (report.technicianNotes?.isNotEmpty == true) ...[
                                  _buildSection('TECHNICIAN NOTES', [
                                    Text(
                                      report.technicianNotes!,
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5),
                                    ),
                                  ]),
                                  const SizedBox(height: 12),
                                ],

                                if (techSig.signatureData.isNotEmpty) ...[
                                  const Text('Technician Signature:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  _buildSignatureImage(techSig.signatureData),
                                  const SizedBox(height: 12),
                                ],

                                if (showActions) ...[
                                  const Divider(height: 24),
                                  // Mark completed satisfied action button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _openCompletionSignatureDialog,
                                      icon: const Icon(Icons.check_circle, size: 18),
                                      label: const Text(
                                        'Mark as Completed (Satisfied)',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF059669),
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(double.infinity, 50),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Send back for Rework input section
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
                                        const Text(
                                          'SEND FOR REWORK',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _reworkNotesController,
                                          maxLines: 3,
                                          decoration: InputDecoration(
                                            hintText: 'Describe what needs to be reworked...',
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
                                            onPressed: _markRework,
                                            icon: const Icon(Icons.refresh, size: 18),
                                            label: const Text(
                                              'Send for Rework',
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                            ),
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
                                ] else if (isEvaluationMade) ...[
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
                ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
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
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.gesture, size: 35, color: Colors.grey),
        ),
      );
    } catch (_) {
      return const Icon(Icons.gesture, size: 35, color: Colors.grey);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }
}

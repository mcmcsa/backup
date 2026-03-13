import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/post_repair_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/workflow_status_badge.dart';

/// Admin screen to evaluate post-repair report - mark satisfied or rework
class AdminPostRepairEvaluationPage extends StatefulWidget {
  final WorkRequest request;

  const AdminPostRepairEvaluationPage({
    super.key,
    required this.request,
  });

  @override
  State<AdminPostRepairEvaluationPage> createState() => _AdminPostRepairEvaluationPageState();
}

class _AdminPostRepairEvaluationPageState extends State<AdminPostRepairEvaluationPage> {
  bool _isLoading = true;
  bool _isProcessing = false;
  PostRepairReport? _report;
  final _reworkNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final report = await PostRepairService.fetchLatestByWorkRequest(widget.request.id);
      if (mounted) setState(() { _report = report; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _reworkNotesController.dispose();
    super.dispose();
  }

  Future<void> _markCompleted() async {
    if (_report == null) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isProcessing = true);

    try {
      await PostRepairService.markSatisfied(_report!.id, user.id);
      await WorkRequestService.completeRequest(widget.request.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Work request marked as COMPLETED!'),
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
        const SnackBar(content: Text('Please provide rework notes'), backgroundColor: Colors.orange),
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
          title: const Text('Post-Repair Evaluation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        body: const Center(child: Text('No post-repair report found')),
      );
    }

    final report = _report!;
    final isAlreadyEvaluated = report.status != 'submitted';

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
                      WorkflowStatusBadge(status: widget.request.status),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Technician info
                _buildSection('TECHNICIAN DETAILS', [
                  _buildInfoRow('Technician', report.technicianName),
                  _buildInfoRow('Repair Date', _formatDate(report.repairDate)),
                  _buildInfoRow('Duration', report.repairDuration ?? 'Not recorded'),
                  _buildInfoRow('Repair Status', report.repairStatusLabel),
                ]),
                const SizedBox(height: 16),

                // Work performed
                _buildSection('WORK PERFORMED', [
                  Text(report.workPerformed,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5)),
                ]),
                const SizedBox(height: 16),

                // Materials used
                _buildSection('MATERIALS USED', [
                  Text(
                    report.materialsUsed?.isNotEmpty == true ? report.materialsUsed! : 'No materials recorded',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5),
                  ),
                ]),
                const SizedBox(height: 16),

                // Technician notes
                if (report.technicianNotes?.isNotEmpty == true) ...[
                  _buildSection('TECHNICIAN NOTES', [
                    Text(report.technicianNotes!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5)),
                  ]),
                  const SizedBox(height: 16),
                ],

                // Photo evidence
                _buildSection('PHOTO EVIDENCE', [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Before', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                            const SizedBox(height: 8),
                            Container(
                              height: 100,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(Icons.image_outlined, color: Color(0xFF9CA3AF), size: 32),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('After', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                            const SizedBox(height: 8),
                            Container(
                              height: 100,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(Icons.image_outlined, color: Color(0xFF9CA3AF), size: 32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ]),
                const SizedBox(height: 24),

                // Rework count
                if (widget.request.reworkCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.refresh, size: 18, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Text(
                          'Rework count: ${widget.request.reworkCount}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (!isAlreadyEvaluated) ...[
                  // Mark completed
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _markCompleted,
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Mark as Completed (Satisfied)',
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
                  const SizedBox(height: 16),

                  // Rework section
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
                        const Text('SEND FOR REWORK',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                        const SizedBox(height: 8),
                        const Text('If the maintenance work is not satisfactory, provide notes and send back for rework.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                        const SizedBox(height: 12),
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
                            label: const Text('Send for Rework',
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
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: report.adminEvaluation == 'satisfied'
                          ? const Color(0xFF059669).withOpacity(0.1)
                          : const Color(0xFFDC2626).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          report.adminEvaluation == 'satisfied' ? Icons.check_circle : Icons.refresh,
                          color: report.adminEvaluation == 'satisfied' ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            report.adminEvaluation == 'satisfied'
                                ? 'This repair has been evaluated and marked as COMPLETED'
                                : 'This repair has been sent back for REWORK',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: report.adminEvaluation == 'satisfied' ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }
}

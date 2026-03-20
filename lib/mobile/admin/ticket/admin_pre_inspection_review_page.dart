import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/pre_inspection_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../shared/services/pre_inspection_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/workflow_status_badge.dart';

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
  final _rejectionNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final report = await PreInspectionService.fetchLatestByWorkRequest(widget.request.id);
      if (mounted) setState(() { _report = report; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _rejectionNotesController.dispose();
    super.dispose();
  }

  Future<void> _approvePreInspection() async {
    if (_report == null) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isProcessing = true);

    try {
      await PreInspectionService.approve(_report!.id, user.id);
      await WorkRequestService.setUnderMaintenance(widget.request.id);

      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Pre-Inspection Approved',
        details: 'Approved pre-inspection for ${widget.request.officeRoom}',
        workRequestId: widget.request.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pre-inspection approved. Maintenance can proceed.'),
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
      await PreInspectionService.reject(_report!.id, notes);

      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Pre-Inspection Rejected',
        details: 'Rejected pre-inspection for ${widget.request.officeRoom}',
        workRequestId: widget.request.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pre-inspection rejected.'),
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
          title: const Text('Pre-Inspection Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        body: const Center(child: Text('No pre-inspection report found')),
      );
    }

    final report = _report!;
    final isAlreadyActioned = report.status != 'submitted';

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
          'Pre-Inspection Review',
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

                if (!isAlreadyActioned) ...[
                  // Approve button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _approvePreInspection,
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
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: report.status == 'approved'
                          ? const Color(0xFF059669).withOpacity(0.1)
                          : const Color(0xFFDC2626).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          report.status == 'approved' ? Icons.check_circle : Icons.cancel,
                          color: report.status == 'approved' ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          report.status == 'approved' ? 'This pre-inspection has been approved' : 'This pre-inspection has been rejected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: report.status == 'approved' ? const Color(0xFF059669) : const Color(0xFFDC2626),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }
}

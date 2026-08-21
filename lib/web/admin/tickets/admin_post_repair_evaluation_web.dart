import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../shared/services/post_repair_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../shared/admin_styles.dart';

class AdminPostRepairEvaluationWeb extends StatefulWidget {
  final WorkRequest request;
  final VoidCallback? onBack;

  const AdminPostRepairEvaluationWeb({
    super.key,
    required this.request,
    this.onBack,
  });

  @override
  State<AdminPostRepairEvaluationWeb> createState() => _AdminPostRepairEvaluationWebState();
}

class _AdminPostRepairEvaluationWebState extends State<AdminPostRepairEvaluationWeb> {
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
      if (mounted) {
        setState(() {
          _report = report;
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

  // --- LOGIC PORTED FROM MOBILE ---

  Future<void> _markCompleted() async {
    if (_report == null) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isProcessing = true);
    try {
      await PostRepairService.markSatisfied(_report!.id, user.id);
      // Logic from mobile: update status to under_maintenance (awaiting final signature)
      await WorkRequestService.updateStatus(widget.request.id, 'under_maintenance');

      await AppNotificationService.notifyAdminCompletionSubmittedToRequestor(
        workRequestId: widget.request.id,
        adminName: user.name,
        requestorId: widget.request.requestorId,
      );

      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Post-Repair Completed',
        details: 'Marked request as completed for ${widget.request.officeRoom}',
        workRequestId: widget.request.id,
      );

      if (mounted) {
        _showSuccess('Post-repair approved. Waiting for requestor final confirmation.');
        Navigator.pop(context, 'under_maintenance');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Error: $e');
      }
    }
  }

  Future<void> _markRework() async {
    if (_report == null) return;
    final notes = _reworkNotesController.text.trim();
    if (notes.isEmpty) {
      _showWarning('Please provide rework notes');
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isProcessing = true);
    try {
      await PostRepairService.markRework(_report!.id, user.id, notes);
      await WorkRequestService.setRework(widget.request.id, notes);

      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Post-Repair Rework',
        details: 'Returned request to rework for ${widget.request.officeRoom}',
        workRequestId: widget.request.id,
      );

      if (mounted) {
        _showSuccess('Work request sent back for rework');
        Navigator.pop(context, 'rework');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Error: $e');
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
                : _report == null
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1400),
                           child: LayoutBuilder(
                             builder: (context, constraints) {
                               final isMobile = constraints.maxWidth < 900;
                               if (isMobile) {
                                 return Column(
                                   children: [
                                     _buildContextColumn(),
                                     const SizedBox(height: 24),
                                     _buildEvaluationForm(),
                                     const SizedBox(height: 60),
                                   ],
                                 );
                               }
                               return Row(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   // Left Column: Sticky Context
                                   SizedBox(
                                     width: 400,
                                     child: _buildContextColumn(),
                                   ),
                                   const SizedBox(width: 40),
                                   // Right Column: Professional flow
                                   Expanded(
                                     child: Column(
                                       children: [
                                         _buildEvaluationForm(),
                                         const SizedBox(height: 100),
                                       ],
                                     ),
                                   ),
                                 ],
                               );
                             },
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
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.pop(context);
                }
              },
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
                'POST-REPAIR EVALUATION',
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.report_gmailerrorred_rounded, size: 64, color: AdminStyles.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('No post-repair report found', style: AdminStyles.headingStyle(fontSize: 18, color: AdminStyles.textMuted)),
          const SizedBox(height: 8),
          Text('Technician has not submitted a completion report yet.', style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
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
          _buildSummaryRow('Category', widget.request.typeOfRequest),
        ]),
        const SizedBox(height: 24),
        _buildInfoCard('Technician Info', [
          _buildSummaryRow('Name', _report!.technicianName),
          _buildSummaryRow('Date', _formatDate(_report!.repairDate)),
          _buildSummaryRow('Duration', _report!.repairDuration ?? 'N/A'),
        ]),
        if (widget.request.reworkCount > 0) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AdminStyles.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AdminStyles.warning.withValues(alpha: 0.3))),
            child: Row(
              children: [
                const Icon(Icons.refresh_rounded, color: AdminStyles.warning),
                const SizedBox(width: 12),
                Text('Rework Count: ${widget.request.reworkCount}', style: AdminStyles.headingStyle(fontSize: 14, color: AdminStyles.warning)),
              ],
            ),
          ),
        ],
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

  Widget _buildEvaluationForm() {
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
              Text('Repair Submission Details', style: AdminStyles.headingStyle(fontSize: 18)),
              const SizedBox(height: 32),
              _buildReadOnlyBlock('Work Performed', report.workPerformed),
              const SizedBox(height: 32),
              _buildReadOnlyBlock('Materials Used', report.materialsUsed?.isNotEmpty == true ? report.materialsUsed! : 'No materials recorded'),
              const SizedBox(height: 32),
              if (report.technicianNotes?.isNotEmpty == true) ...[
                _buildReadOnlyBlock('Technician Notes', report.technicianNotes!),
                const SizedBox(height: 32),
              ],
              const Divider(),
              const SizedBox(height: 32),
              Text('Evaluation Action', style: AdminStyles.headingStyle(fontSize: 18)),
              const SizedBox(height: 24),
              if (!isActioned) ...[
                Text('If the work is satisfactory, click "Mark as Satisfied". If issues remain, provide notes below and send for rework.', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
                const SizedBox(height: 24),
                _buildWebTextField(_reworkNotesController, 'Rework Instructions (Required only for rework)', 'Describe what is still missing or incorrect...', maxLines: 3),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _markRework,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Send for Rework'),
                        style: OutlinedButton.styleFrom(foregroundColor: AdminStyles.error, side: const BorderSide(color: AdminStyles.error), padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _markCompleted,
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Mark as Satisfied'),
                        style: ElevatedButton.styleFrom(backgroundColor: AdminStyles.success, foregroundColor: Colors.white, padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: report.adminEvaluation == 'satisfied' ? AdminStyles.success.withValues(alpha: 0.1) : AdminStyles.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: report.adminEvaluation == 'satisfied' ? AdminStyles.success.withValues(alpha: 0.3) : AdminStyles.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(report.adminEvaluation == 'satisfied' ? Icons.verified_rounded : Icons.history_rounded, color: report.adminEvaluation == 'satisfied' ? AdminStyles.success : AdminStyles.error, size: 32),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(report.adminEvaluation == 'satisfied' ? 'Evaluation: Satisfied' : 'Evaluation: Rework Required', style: AdminStyles.headingStyle(fontSize: 16, color: report.adminEvaluation == 'satisfied' ? AdminStyles.success : AdminStyles.error)),
                            const SizedBox(height: 4),
                            Text(report.adminEvaluation == 'satisfied' ? 'Maintenance work was approved and marked as completed.' : 'Work was rejected and sent back for further repair.', style: AdminStyles.bodyStyle()),
                          ],
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
    );
  }

  Widget _buildWebTextField(TextEditingController controller, String label, String hint, {int maxLines = 1, bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminStyles.textPrimary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
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
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AdminStyles.bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AdminStyles.border)),
          child: Text(value, style: AdminStyles.bodyStyle(fontSize: 14, color: AdminStyles.textPrimary, height: 1.6)),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final status = _report?.status ?? 'Pending';
    Color color = Colors.grey;
    if (status == 'submitted') color = AdminStyles.warning;
    if (status == 'satisfied' || status == 'completed') color = AdminStyles.success;
    if (status == 'rework') color = AdminStyles.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(status.toUpperCase(), style: AdminStyles.headingStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }

  // --- HELPERS ---

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.success));
  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.error));
  void _showWarning(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.warning));

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

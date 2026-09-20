import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../shared/services/post_repair_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/inspection_pdf_service.dart';
import '../../../shared/widgets/attachment_image_widget.dart';
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

  List<PostRepairReport> _history = [];
  int _selectedAttemptIndex = 0;

  Future<void> _loadReport() async {
    try {
      final history = await PostRepairService.fetchByWorkRequest(widget.request.id);
      if (mounted) {
        final sorted = List<PostRepairReport>.from(history)
          ..sort((a, b) => a.attemptNumber.compareTo(b.attemptNumber));
        final pendingIdx = sorted.indexWhere((r) => r.adminEvaluation == null);
        final selectedIdx = pendingIdx != -1 ? pendingIdx : (sorted.isNotEmpty ? sorted.length - 1 : 0);
        setState(() {
          _history = sorted;
          _selectedAttemptIndex = selectedIdx;
          _report = sorted.isNotEmpty ? sorted[selectedIdx] : null;
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
    if (_history.isEmpty) return;
    final targetReport = _history[_selectedAttemptIndex];
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isProcessing = true);
    try {
      await PostRepairService.markSatisfied(targetReport.id, user.id);
      await WorkRequestService.completeRequest(widget.request.id);

      await AppNotificationService.notifyAdminCompletionSubmittedToRequestor(
        workRequestId: widget.request.id,
        adminName: user.name,
        requestorId: widget.request.requestorId,
      );

      await AppNotificationService.notifyPostRepairCompleted(
        workRequestId: widget.request.id,
        maintenanceId: widget.request.assignedToId ?? targetReport.technicianId,
        adminName: user.name,
      );

      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Post-Repair Completed',
        details: 'Marked request as completed for ${widget.request.officeRoom}',
        workRequestId: widget.request.id,
      );

      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Work Request Successfully Completed'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (widget.onBack != null) {
          widget.onBack!();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Error: $e');
      }
    }
  }

  Future<void> _markRework() async {
    if (_history.isEmpty) return;
    final targetReport = _history[_selectedAttemptIndex];
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
      await PostRepairService.markRework(targetReport.id, user.id, notes);
      await WorkRequestService.setRework(widget.request.id, notes);

      await AppNotificationService.notifyPostRepairRework(
        workRequestId: widget.request.id,
        maintenanceId: widget.request.assignedToId ?? targetReport.technicianId,
        adminName: user.name,
      );

      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Post-Repair Rework',
        details: 'Returned request to rework for ${widget.request.officeRoom}',
        workRequestId: widget.request.id,
      );

      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Work request sent back for rework'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (widget.onBack != null) {
          widget.onBack!();
        }
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
                                     width: 320,
                                     child: _buildContextColumn(),
                                   ),
                                   const SizedBox(width: 28),
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
          if (_report != null && (_report!.adminEvaluation != null || _report!.status == 'Completed')) ...[
            ElevatedButton.icon(
              onPressed: () {
                InspectionPdfService.printPostRepair(
                  context: context,
                  request: widget.request,
                  report: _report!,
                );
              },
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Print Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminStyles.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 14),
          ],
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
    if (_history.isEmpty) return const SizedBox.shrink();
    final report = _history[_selectedAttemptIndex];
    return Column(
      children: [
        _buildInfoCard('Work Request', [
          _buildSummaryRow('ID', widget.request.id.substring(0, 8).toUpperCase()),
          _buildSummaryRow('Title', widget.request.title),
          _buildSummaryRow('Room', widget.request.officeRoom ?? 'N/A'),
          _buildSummaryRow('Category', widget.request.typeDisplay),
        ]),
        const SizedBox(height: 24),
        _buildInfoCard('Technician Info', [
          _buildSummaryRow('Name', report.technicianName),
          _buildSummaryRow('Date', _formatDate(report.repairDate)),
          _buildSummaryRow('Duration', report.repairDuration ?? 'N/A'),
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
    if (_history.isEmpty) return _buildEmptyState();
    final report = _history[_selectedAttemptIndex];
    final isLatest = _selectedAttemptIndex == _history.length - 1;
    final isEvaluated = report.adminEvaluation != null;
    final canEvaluate = isLatest && !isEvaluated;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      children: [
        _buildAttemptTabs(),
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
              if (report.photoAfter?.isNotEmpty == true) ...[
                _buildPhotoPreview(report.photoAfter!),
                const SizedBox(height: 32),
              ],
              const Divider(),
              const SizedBox(height: 32),
              Text('Evaluation Action', style: AdminStyles.headingStyle(fontSize: 18)),
              const SizedBox(height: 24),
              if (canEvaluate) ...[
                Text('If the work is satisfactory, click "Work Completed". If issues remain, provide notes below and send for rework.', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
                const SizedBox(height: 24),
                _buildWebTextField(_reworkNotesController, 'Rework Instructions (Required only for rework)', 'Describe what is still missing or incorrect...', maxLines: 3),
                const SizedBox(height: 32),
                if (isMobile) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _markRework,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Send for Rework'),
                      style: OutlinedButton.styleFrom(foregroundColor: AdminStyles.error, side: const BorderSide(color: AdminStyles.error), padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _markCompleted,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Work Completed'),
                      style: ElevatedButton.styleFrom(backgroundColor: AdminStyles.success, foregroundColor: Colors.white, padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ] else
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
                          label: const Text('Work Completed'),
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
                            Text(report.adminEvaluation == 'satisfied' ? 'Evaluation: Work Completed' : 'Evaluation: Rework Required', style: AdminStyles.headingStyle(fontSize: 16, color: report.adminEvaluation == 'satisfied' ? AdminStyles.success : AdminStyles.error)),
                            const SizedBox(height: 4),
                            Text(report.adminEvaluation == 'satisfied' ? 'Maintenance work was approved and marked as completed.' : 'Work was rejected and sent back for further repair.', style: AdminStyles.bodyStyle()),
                            if (report.adminEvaluationNotes != null && report.adminEvaluationNotes!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('Notes: ${report.adminEvaluationNotes}', style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary)),
                            ],
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
              final isSelected = _selectedAttemptIndex == idx;
              
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
                      _selectedAttemptIndex = idx;
                      _report = report;
                      _reworkNotesController.clear();
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
          ],
        ),
      ),
    );
  }


  Widget _buildPhotoPreview(String photoData) {
    List<String> urls = [];
    try {
      final clean = photoData.trim();
      if (clean.startsWith('[') && clean.endsWith(']')) {
        final List<dynamic> decoded = jsonDecode(clean);
        urls = decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      } else if (clean.contains(',')) {
        urls = clean.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } else if (clean.isNotEmpty) {
        urls = [clean];
      }
    } catch (e) {
      if (photoData.trim().isNotEmpty) urls = [photoData.trim()];
    }

    if (urls.isEmpty && widget.request.workEvidence != null && widget.request.workEvidence!.trim().isNotEmpty) {
      final cleanReq = widget.request.workEvidence!.trim();
      if (cleanReq.startsWith('[') && cleanReq.endsWith(']')) {
        try {
          final List<dynamic> decoded = jsonDecode(cleanReq);
          urls = decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        } catch (_) {
          urls = [cleanReq];
        }
      } else {
        urls = [cleanReq];
      }
    }

    if (urls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_library_outlined, size: 16, color: AdminStyles.primary),
            const SizedBox(width: 8),
            Text(
              'Work Evidence (${urls.length})',
              style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminStyles.textPrimary),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AdminStyles.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Click to enlarge',
                style: AdminStyles.bodyStyle(fontSize: 10, color: AdminStyles.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminStyles.border),
          ),
          child: urls.length == 1
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Tooltip(
                    message: 'Click to enlarge photo',
                    child: InkWell(
                      onTap: () => showAttachmentZoomDialog(context, urls.first),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: 360,
                          maxHeight: 260,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AdminStyles.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AppAttachmentImage(
                                url: urls.first,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: 240,
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text('View full', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: urls.map((url) {
                    return Tooltip(
                      message: 'Click to enlarge photo',
                      child: InkWell(
                        onTap: () => showAttachmentZoomDialog(context, url),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AdminStyles.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AppAttachmentImage(
                                url: url,
                                fit: BoxFit.cover,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              Positioned(
                                bottom: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.error));
  void _showWarning(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.warning));

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

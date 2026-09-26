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
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
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

    if (!targetReport.isRequestorEvaluated) {
      _showWarning('Action Blocked: Requestor must evaluate the repair before Campus Admin can finalize.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Completion',
          style: AdminStyles.headingStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Do you want to mark this work request as Completed?',
          style: AdminStyles.bodyStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'No',
              style: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.success,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
        setState(() => _isProcessing = false);
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AdminStyles.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: AdminStyles.success, size: 24),
                ),
                const SizedBox(width: 10),
                Text(
                  'Success',
                  style: AdminStyles.headingStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              'Work Request Successfully Completed',
              style: AdminStyles.bodyStyle(fontSize: 14),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminStyles.success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
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
    if (!targetReport.isRequestorEvaluated) {
      _showWarning('Action Blocked: Requestor must evaluate the repair before Campus Admin can send for rework.');
      return;
    }
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
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 900;
                        return SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 32,
                            vertical: isMobile ? 16 : 28,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1400),
                              child: isMobile
                                  ? Column(
                                      children: [
                                        _buildContextColumn(isMobile),
                                        const SizedBox(height: 18),
                                        _buildEvaluationForm(isMobile),
                                        const SizedBox(height: 40),
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Left Column: Sticky Context
                                        SizedBox(
                                          width: 320,
                                          child: _buildContextColumn(isMobile),
                                        ),
                                        const SizedBox(width: 24),
                                        // Right Column: Professional flow
                                        Expanded(
                                          child: Column(
                                            children: [
                                              _buildEvaluationForm(isMobile),
                                              const SizedBox(height: 60),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 32,
        vertical: isCompact ? 12 : 18,
      ),
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
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: AdminStyles.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: AdminStyles.textPrimary),
              ),
            ),
          ),
          SizedBox(width: isCompact ? 10 : 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Workflow Phase',
                  style: AdminStyles.headingStyle(fontSize: 10, color: AdminStyles.textMuted, letterSpacing: 0.8),
                ),
                const SizedBox(height: 2),
                Text(
                  'POST-REPAIR EVALUATION',
                  style: AdminStyles.headingStyle(
                    fontSize: isCompact ? 14 : 20,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_report != null && (_report!.adminEvaluation != null || _report!.status == 'Completed')) ...[
            ElevatedButton.icon(
              onPressed: () {
                InspectionPdfService.printPostRepair(
                  context: context,
                  request: widget.request,
                  report: _report!,
                );
              },
              icon: const Icon(Icons.print_rounded, size: 14),
              label: isCompact ? const SizedBox.shrink() : const Text('Print Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminStyles.success,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
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

  Widget _buildContextColumn(bool isMobile) {
    if (_history.isEmpty) return const SizedBox.shrink();
    final report = _history[_selectedAttemptIndex];
    return Column(
      children: [
        _buildInfoCard(
          title: 'Work Request',
          icon: Icons.assignment_outlined,
          isMobile: isMobile,
          children: [
            _buildDetailTile(
              label: 'Request ID',
              value: widget.request.id.length >= 8 ? widget.request.id.substring(0, 8).toUpperCase() : widget.request.id,
              isCode: true,
            ),
            _buildDetailTile(
              label: 'Title',
              value: widget.request.title,
            ),
            _buildDetailTile(
              label: 'Room / Location',
              value: widget.request.officeRoom ?? 'N/A',
              icon: Icons.meeting_room_outlined,
            ),
            _buildDetailTile(
              label: 'Category',
              value: widget.request.typeDisplay,
              icon: Icons.category_outlined,
            ),
          ],
        ),
        SizedBox(height: isMobile ? 14 : 20),
        _buildInfoCard(
          title: 'Technician Info',
          icon: Icons.engineering_outlined,
          isMobile: isMobile,
          children: [
            _buildDetailTile(
              label: 'Technician Name',
              value: report.technicianName,
              icon: Icons.person_outline_rounded,
            ),
            _buildDetailTile(
              label: 'Repair Date',
              value: _formatDate(report.repairDate),
              icon: Icons.calendar_today_outlined,
            ),
            _buildDetailTile(
              label: 'Duration',
              value: report.repairDuration ?? 'N/A',
              icon: Icons.timer_outlined,
            ),
          ],
        ),
        if (widget.request.reworkCount > 0) ...[
          SizedBox(height: isMobile ? 14 : 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AdminStyles.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminStyles.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.refresh_rounded, color: AdminStyles.warning, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Rework Count: ${widget.request.reworkCount}',
                  style: AdminStyles.headingStyle(fontSize: 13, color: AdminStyles.warning),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
    required bool isMobile,
    IconData? icon,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AdminStyles.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: AdminStyles.primary),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                title.toUpperCase(),
                style: AdminStyles.headingStyle(fontSize: 11, color: const Color(0xFF475569), letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailTile({
    required String label,
    required String value,
    IconData? icon,
    bool isCode = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 14, color: const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AdminStyles.headingStyle(fontSize: 11, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 3),
                isCode
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          value,
                          style: GoogleFonts.firaCode(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      )
                    : Text(
                        value,
                        style: AdminStyles.bodyStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationForm(bool isMobile) {
    if (_history.isEmpty) return _buildEmptyState();
    final report = _history[_selectedAttemptIndex];
    final isLatest = _selectedAttemptIndex == _history.length - 1;
    final isEvaluated = report.adminEvaluation != null;
    final isRequestorEvaluated = report.isRequestorEvaluated;
    final canEvaluate = isLatest && !isEvaluated && isRequestorEvaluated;

    return Column(
      children: [
        _buildAttemptTabs(),
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AdminStyles.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.fact_check_outlined, size: 18, color: AdminStyles.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Repair Submission Details',
                      style: AdminStyles.headingStyle(fontSize: isMobile ? 16 : 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildReadOnlyBlock('Work Performed', report.workPerformed),
              const SizedBox(height: 20),
              _buildReadOnlyBlock('Materials Used', report.materialsUsed?.isNotEmpty == true ? report.materialsUsed! : 'No materials recorded'),
              const SizedBox(height: 20),
              if (report.technicianNotes?.isNotEmpty == true) ...[
                _buildReadOnlyBlock('Technician Notes', report.technicianNotes!),
                const SizedBox(height: 20),
              ],
              if (report.photoAfter?.isNotEmpty == true) ...[
                _buildPhotoPreview(report.photoAfter!),
                const SizedBox(height: 20),
              ],
              _buildRequestorEvaluationSection(report, isMobile),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFF1F5F9)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.gavel_rounded, size: 18, color: Color(0xFF0F766E)),
                  ),
                  const SizedBox(width: 10),
                  Text('Evaluation Action', style: AdminStyles.headingStyle(fontSize: isMobile ? 16 : 18)),
                ],
              ),
              const SizedBox(height: 18),
              if (canEvaluate) ...[
                Text(
                  'The requestor has evaluated this repair (${report.isRequestorSatisfied ? "SATISFY" : "NOT SATISFY"}). Please make the final administrative decision below.',
                  style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary),
                ),
                const SizedBox(height: 18),
                _buildWebTextField(_reworkNotesController, 'Rework Instructions (Required only for rework)', 'Describe what is still missing or incorrect...', maxLines: 3),
                const SizedBox(height: 24),
                if (isMobile) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _markRework,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Send for Rework'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminStyles.error,
                        side: const BorderSide(color: AdminStyles.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _markCompleted,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Work Completed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminStyles.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AdminStyles.error,
                            side: const BorderSide(color: AdminStyles.error),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _markCompleted,
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text('Work Completed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminStyles.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
              ] else if (!isEvaluated && !isRequestorEvaluated) ...[
                Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: AdminStyles.textMuted, size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Decision Locked: Awaiting Requestor Review',
                              style: AdminStyles.headingStyle(fontSize: 14, color: AdminStyles.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'The buttons [ WORK COMPLETED ] and [ SEND FOR REWORK ] will become available once the original requestor submits their Satisfy / Not Satisfy evaluation.',
                              style: AdminStyles.bodyStyle(fontSize: 12.5, color: AdminStyles.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 20),
                  decoration: BoxDecoration(
                    color: report.adminEvaluation == 'satisfied' ? AdminStyles.success.withValues(alpha: 0.08) : AdminStyles.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: report.adminEvaluation == 'satisfied' ? AdminStyles.success.withValues(alpha: 0.25) : AdminStyles.error.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        report.adminEvaluation == 'satisfied' ? Icons.check_circle_rounded : Icons.replay_rounded,
                        color: report.adminEvaluation == 'satisfied' ? AdminStyles.success : AdminStyles.error,
                        size: 24,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.adminEvaluation == 'satisfied' ? 'Admin Decision: Work Approved & Completed' : 'Admin Decision: Rework Requested',
                              style: AdminStyles.headingStyle(
                                fontSize: 14,
                                color: report.adminEvaluation == 'satisfied' ? AdminStyles.success : AdminStyles.error,
                              ),
                            ),
                            if (report.adminEvaluationNotes?.isNotEmpty == true) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Notes: ${report.adminEvaluationNotes}',
                                style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textPrimary),
                              ),
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

  Widget _buildRequestorEvaluationSection(PostRepairReport report, bool isMobile) {
    final isEvaluated = report.isRequestorEvaluated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(color: Color(0xFFF1F5F9)),
        const SizedBox(height: 18),
        Row(
          children: [
            const Icon(Icons.rate_review_outlined, size: 18, color: AdminStyles.primary),
            const SizedBox(width: 8),
            Text('Requestor Evaluation', style: AdminStyles.headingStyle(fontSize: isMobile ? 15 : 17)),
            const Spacer(),
            if (isEvaluated)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: report.isRequestorSatisfied
                      ? AdminStyles.success.withValues(alpha: 0.12)
                      : AdminStyles.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: report.isRequestorSatisfied
                        ? AdminStyles.success.withValues(alpha: 0.3)
                        : AdminStyles.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      report.isRequestorSatisfied
                          ? Icons.thumb_up_alt_rounded
                          : Icons.thumb_down_alt_rounded,
                      size: 13,
                      color: report.isRequestorSatisfied
                          ? AdminStyles.success
                          : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      report.isRequestorSatisfied ? 'SATISFY' : 'NOT SATISFY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: report.isRequestorSatisfied
                            ? AdminStyles.success
                            : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (!isEvaluated)
          Container(
            padding: EdgeInsets.all(isMobile ? 14 : 18),
            decoration: BoxDecoration(
              color: AdminStyles.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminStyles.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.hourglass_top_rounded, color: AdminStyles.warning, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Awaiting Requestor Evaluation',
                        style: AdminStyles.headingStyle(fontSize: 14, color: const Color(0xFFB45309)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The original requestor (${widget.request.requestorName.isNotEmpty ? widget.request.requestorName : "Requestor"}) has not evaluated this repair yet. Campus Admin final decision is locked until the Requestor submits their review.',
                        style: AdminStyles.bodyStyle(fontSize: 12.5, color: AdminStyles.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: EdgeInsets.all(isMobile ? 14 : 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryLine('Decision', report.isRequestorSatisfied ? 'SATISFY (Satisfied with repair)' : 'NOT SATISFY (Unsatisfied with repair)'),
                const SizedBox(height: 10),
                _buildSummaryLine('Rating', report.requestorRating != null ? '${report.requestorRating} / 5 Stars' : 'Not rated'),
                const SizedBox(height: 10),
                _buildSummaryLine('Comment', report.requestorComment?.isNotEmpty == true ? report.requestorComment! : 'No comment provided'),
                const SizedBox(height: 10),
                _buildSummaryLine('Evaluated By', widget.request.requestorName.isNotEmpty ? widget.request.requestorName : 'Original Requestor'),
                if (report.requestorEvaluatedDate != null) ...[
                  const SizedBox(height: 10),
                  _buildSummaryLine('Evaluated Date', DateFormat('MMM dd, yyyy • hh:mm a').format(report.requestorEvaluatedDate!)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AdminStyles.bodyStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AdminStyles.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AdminStyles.bodyStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AdminStyles.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildAttemptTabs() {
    if (_history.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(4),
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? AdminStyles.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                          maxWidth: 340,
                          maxHeight: 240,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                height: 220,
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
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth < 420
                        ? 2
                        : constraints.maxWidth < 700
                            ? 3
                            : 4;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: urls.length,
                      itemBuilder: (context, index) {
                        final url = urls[index];
                        return Tooltip(
                          message: 'Click to enlarge photo',
                          child: InkWell(
                            onTap: () => showAttachmentZoomDialog(context, url),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    AppAttachmentImage(
                                      url: url,
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned(
                                      bottom: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.zoom_in_rounded, size: 13, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWebTextField(TextEditingController controller, String label, String hint, {int maxLines = 1, bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
        const SizedBox(height: 6),
        TextField(
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
        Text(label, style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            value,
            style: AdminStyles.bodyStyle(fontSize: 13.5, color: AdminStyles.textPrimary, height: 1.5),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.toUpperCase(),
            style: AdminStyles.headingStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // --- HELPERS ---

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.error));
  void _showWarning(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.warning));

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

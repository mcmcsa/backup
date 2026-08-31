import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/signature_pad_widget.dart';
import '../../admin/shared/admin_styles.dart';
import 'maintenance_accept_task_web.dart';
import '../../teacher/reports/teacher_official_form_web.dart';
import '../../../shared/models/pre_inspection_model.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/services/pre_inspection_service.dart';
import '../../../shared/services/post_repair_service.dart';

class MaintenanceTaskDetailsWeb extends StatefulWidget {
  final WorkRequest task;
  final VoidCallback? onBack;

  const MaintenanceTaskDetailsWeb({super.key, required this.task, this.onBack});

  @override
  State<MaintenanceTaskDetailsWeb> createState() => _MaintenanceTaskDetailsWebState();
}

class _MaintenanceTaskDetailsWebState extends State<MaintenanceTaskDetailsWeb>
    with SingleTickerProviderStateMixin {
  WorkRequest? _currentTask;
  List<ESignature> _signatures = [];
  PreInspectionReport? _preInspectionReport;
  List<PostRepairReport> _postRepairReports = [];
  final Map<String, String> _userNames = {};
  bool _isLoading = true;
  bool _isProcessing = false;
  
  // Confirmation form state
  final _noteController = TextEditingController();
  XFile? _evidenceImage;
  bool _isUploadingEvidence = false;

  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final task = await WorkRequestService.fetchById(widget.task.id);
      final sigs = await ESignatureService.fetchByWorkRequest(widget.task.id);
      final preInsp = await PreInspectionService.fetchLatestByWorkRequest(widget.task.id);
      final postRepairs = await PostRepairService.fetchByWorkRequest(widget.task.id);
      if (mounted) {
        setState(() {
          // Populate cache of user names from signatures to bypass RLS issues
          for (final sig in sigs) {
            if (sig.signerId.isNotEmpty && sig.signerName.isNotEmpty) {
              final isAdm = sig.signerRole.toLowerCase() == 'campadmin';
              _userNames[sig.signerId] = isAdm ? 'Campus Admin - ${sig.signerName}' : sig.signerName;
            }
          }
          _currentTask = task ?? widget.task;
          _signatures = sigs;
          _preInspectionReport = preInsp;
          _postRepairReports = postRepairs;
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        _animController.forward();
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // --- LOGIC PORTED FROM MOBILE ---

  bool get _isAssignedToMe {
    final user = context.read<AuthService>().currentUser;
    return _currentTask?.assignedToId == user?.id;
  }

  bool get _canStart {
    if (_currentTask == null) return false;
    final status = _currentTask!.status.toLowerCase();
    return _isAssignedToMe && 
           _currentTask!.acceptedDate == null && 
           (status == 'approved' || status == 'under_maintenance');
  }

  bool get _canComplete {
    if (_currentTask == null) return false;
    final status = _currentTask!.status.toLowerCase();
    return _isAssignedToMe && 
           _currentTask!.acceptedDate != null && 
           status != 'completed';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _evidenceImage = image);
    }
  }

  Future<String> _uploadWorkEvidenceImage({
    required String requestId,
    required XFile imageFile,
  }) async {
    final client = Supabase.instance.client;
    final bytes = await imageFile.readAsBytes();
    final extension = imageFile.name.contains('.')
        ? imageFile.name.split('.').last
        : 'jpg';
    final path =
        'work-evidence/$requestId/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await client.storage.from('work-evidence').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return client.storage.from('work-evidence').getPublicUrl(path);
  }

  Future<void> _handleCompletion(String signatureData) async {
    if (_evidenceImage == null && _currentTask?.workEvidence == null) {
      _showWarning('Please attach a work evidence image first.');
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null || _currentTask == null) return;

    setState(() => _isProcessing = true);

    try {
      String? evidenceUrl = _currentTask!.workEvidence;
      
      if (_evidenceImage != null) {
        setState(() => _isUploadingEvidence = true);
        try {
          evidenceUrl = await _uploadWorkEvidenceImage(
            requestId: _currentTask!.id,
            imageFile: _evidenceImage!,
          );
          await WorkRequestService.updateWorkEvidence(_currentTask!.id, evidenceUrl);
        } finally {
          if (mounted) setState(() => _isUploadingEvidence = false);
        }
      }

      if (_noteController.text.isNotEmpty) {
        await WorkRequestService.updateMaintenanceNote(_currentTask!.id, _noteController.text);
      }

      final signature = ESignature(
        id: '',
        workRequestId: _currentTask!.id,
        signerId: user.id,
        signerName: user.name,
        signerRole: 'maintenance',
        signatureType: 'completion',
        signatureData: signatureData,
        signedAt: DateTime.now(),
      );
      await ESignatureService.insert(signature);

      await WorkRequestService.updateStatus(_currentTask!.id, 'under_maintenance');
      await AppNotificationService.notifyCompletionSubmittedToAdmin(
        workRequestId: _currentTask!.id,
        maintenanceName: user.name,
        adminId: _currentTask!.approvedById,
      );

      _showSuccess('Work completion report submitted.');
      _loadData();
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- UI BUILDING ---

  Color get _statusColor {
    final status = _currentTask?.status.toLowerCase() ?? 'pending';
    switch (status) {
      case 'completed': return AdminStyles.success;
      case 'in_progress':
      case 'under_maintenance': return AdminStyles.info;
      case 'rework': return AdminStyles.error;
      case 'approved':
      case 'confirmed': return AdminStyles.primary;
      case 'pending': return AdminStyles.warning;
      case 'cancelled': return AdminStyles.error;
      default: return AdminStyles.textMuted;
    }
  }

  String get _statusLabel {
    final status = _currentTask?.status.toLowerCase() ?? 'pending';
    switch (status) {
      case 'in_progress': return 'IN PROGRESS';
      case 'under_maintenance': return 'UNDER MAINTENANCE';
      case 'cancelled': return 'CANCELLED';
      default: return status.toUpperCase();
    }
  }

  List<_TimelineStep> get _steps {
    if (_currentTask == null) return [];
    final task = _currentTask!;
    final steps = <_TimelineStep>[];

    // 1. Request Submitted
    steps.add(_TimelineStep(
      icon: Icons.assignment_turned_in_rounded,
      title: 'Request Submitted',
      desc: 'Initial request submitted by ${task.displayRequestorName}.',
      date: task.dateSubmitted,
      isCompleted: true,
      color: AdminStyles.primary,
    ));

    // 2. Admin Review & Approval
    final isApproved = ['assigned', 'confirmed', 'rework', 'completed', 'in progress', 'in_progress', 'declined'].contains(task.status.toLowerCase());
    final isDeclinedInitially = task.status.toLowerCase() == 'declined' && _preInspectionReport == null;
    steps.add(_TimelineStep(
      icon: Icons.admin_panel_settings_rounded,
      title: isDeclinedInitially ? 'Request Declined' : 'Admin Review & Approval',
      desc: isDeclinedInitially
          ? 'Request was declined and closed.'
          : (isApproved
              ? 'Request approved by ${task.approvedByName ?? "Admin"}.'
              : 'Waiting for admin approval.'),
      date: task.approvedDate,
      isCompleted: isApproved,
      color: isDeclinedInitially ? AdminStyles.error : AdminStyles.secondary,
    ));

    if (isDeclinedInitially) return steps;

    // 3. Maintenance Assignment & Acceptance
    final isAccepted = task.acceptedDate != null;
    steps.add(_TimelineStep(
      icon: Icons.engineering_rounded,
      title: 'Maintenance Assignment',
      desc: isAccepted
          ? 'Accepted by ${task.acceptedByName ?? "Technician"}.'
          : (task.assignedToId != null
              ? 'Assigned to ${task.acceptedByName ?? "Technician"}. Awaiting acceptance.'
              : 'Pending technician assignment.'),
      date: task.acceptedDate,
      isCompleted: isAccepted,
      color: AdminStyles.info,
    ));

    // 4. Pre-Inspection Report Submitted
    final hasPreInsp = _preInspectionReport != null;
    steps.add(_TimelineStep(
      icon: Icons.search_rounded,
      title: 'Pre-Inspection',
      desc: hasPreInsp
          ? 'Submitted by ${_preInspectionReport!.inspectorName}'
          : 'Awaiting pre-inspection.',
      date: _preInspectionReport?.inspectionDate,
      isCompleted: hasPreInsp,
      color: AdminStyles.warning,
    ));

    // 5. Pre-Inspection Review Decision
    if (hasPreInsp) {
      final isReviewed = _preInspectionReport!.status == 'Approved' || _preInspectionReport!.status == 'Declined';
      final isPreInspDeclined = _preInspectionReport!.status == 'Declined';
      final approvedByName = _preInspectionReport!.adminApprovedBy != null
          ? (_userNames[_preInspectionReport!.adminApprovedBy] ?? _preInspectionReport!.adminApprovedBy)
          : "Admin";
      
      steps.add(_TimelineStep(
        icon: isPreInspDeclined ? Icons.cancel_rounded : Icons.fact_check_rounded,
        title: isPreInspDeclined ? 'Pre-Inspection Declined' : 'Pre-Inspection Approved',
        desc: isReviewed
            ? '${_preInspectionReport!.status} by $approvedByName'
            : 'Awaiting pre-inspection review.',
        date: _preInspectionReport?.adminApprovedDate,
        isCompleted: isReviewed && !isPreInspDeclined,
        color: isPreInspDeclined ? AdminStyles.error : AdminStyles.success,
      ));

      if (isPreInspDeclined) return steps;
    }

    // 6. Post-Repair Attempts
    final sortedAttempts = List<PostRepairReport>.from(_postRepairReports)
      ..sort((a, b) {
        int cmp = a.repairDate.compareTo(b.repairDate);
        if (cmp != 0) return cmp;
        return a.attemptNumber.compareTo(b.attemptNumber);
      });

    for (int i = 0; i < sortedAttempts.length; i++) {
      final report = sortedAttempts[i];
      steps.add(_TimelineStep(
        icon: Icons.build_circle_rounded,
        title: 'Post-Repair Report Submitted',
        desc: 'Submitted by ${report.technicianName}',
        date: report.repairDate,
        isCompleted: true,
        color: AdminStyles.primary,
      ));

      final isEvaluated = report.adminEvaluation != null;
      final isRework = report.adminEvaluation == 'rework';
      final evaluatedByName = report.adminEvaluatedBy != null
          ? (_userNames[report.adminEvaluatedBy] ?? report.adminEvaluatedBy)
          : "Admin";
      
      final isLatestReport = i == sortedAttempts.length - 1;
      if (isEvaluated || isLatestReport) {
        steps.add(_TimelineStep(
          icon: isRework ? Icons.refresh_rounded : Icons.check_circle_rounded,
          title: isRework ? 'Post-Repair Evaluation Completed - Rework' : 'Post-Repair Evaluation',
          desc: isEvaluated
              ? (isRework
                  ? 'Rework required by $evaluatedByName'
                  : 'Approved by $evaluatedByName')
              : 'Awaiting evaluation.',
          date: report.adminEvaluatedDate,
          isCompleted: isEvaluated,
          color: isRework ? AdminStyles.warning : AdminStyles.success,
          customBadge: isRework ? 'Rework' : null,
        ));
      }
    }

    // If the latest evaluation was rework, append a pending Post-Repair Report step
    if (sortedAttempts.isNotEmpty && sortedAttempts.last.adminEvaluation == 'rework') {
      steps.add(const _TimelineStep(
        icon: Icons.build_circle_rounded,
        title: 'Post-Repair Report',
        desc: 'Awaiting post-repair report (Rework).',
        isCompleted: false,
        color: Colors.grey,
      ));
    }

    // 7. Final Completion
    final isCompleted = task.status.toLowerCase() == 'completed';
    steps.add(_TimelineStep(
      icon: Icons.verified_rounded,
      title: 'Completed & Verified',
      desc: isCompleted
          ? 'Work request fully verified and completed.'
          : 'Awaiting final verification and close out.',
      date: task.dateCompleted,
      isCompleted: isCompleted,
      color: AdminStyles.success,
      isLast: true,
    ));

    return steps;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 1100;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDFA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading || _isProcessing
                ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary, strokeWidth: 2))
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(isCompact ? 20 : 40),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1400),
                          child: Column(
                            children: [
                              _buildStatusHero(),
                              const SizedBox(height: 32),
                              isCompact
                                  ? Column(children: [
                                      _buildTimelineCard(),
                                      const SizedBox(height: 24),
                                      _buildInfoPanel(),
                                    ])
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 5, child: _buildTimelineCard()),
                                        const SizedBox(width: 28),
                                        Expanded(flex: 5, child: _buildInfoPanel()),
                                      ],
                                    ),
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

  // ─── Header Bar ──────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    if (_currentTask == null) return const SizedBox.shrink();
    final trackId = _currentTask!.id.length > 8
        ? _currentTask!.id.substring(0, 8).toUpperCase()
        : _currentTask!.id.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      height: 68,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: widget.onBack,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 20, color: AdminStyles.textPrimary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Request Progress', style: AdminStyles.headingStyle(fontSize: 20)),
                Text(
                  'Tracking ID: #$trackId',
                  style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => TeacherOfficialFormWeb(request: _currentTask!),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.assignment_rounded, size: 16),
            label: const Text('View Official Form', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 16),
          _buildStatusBadge(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(_statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _statusColor, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  // ─── Status Hero ─────────────────────────────────────────────────────────────
  Widget _buildStatusHero() {
    String title, desc;
    IconData icon;

    final status = _currentTask?.status.toLowerCase() ?? 'pending';
    switch (status) {
      case 'in_progress':
        title = 'Maintenance In Progress';
        desc = 'Work has been accepted and is currently in progress.';
        icon = Icons.construction_rounded;
        break;
      case 'confirmed':
        title = 'Pre-Inspection Approved';
        desc = 'The site pre-inspection has been approved. Please perform the repair work and submit the completion report.';
        icon = Icons.verified_rounded;
        break;
      case 'under_maintenance':
        title = 'Work Completed, Under Review';
        desc = 'Technician submitted completion files. Waiting for final verification sign-off.';
        icon = Icons.rate_review_rounded;
        break;
      case 'completed':
        title = 'Issue Resolved ✓';
        desc = 'This maintenance request has been completed and verified. Thank you!';
        icon = Icons.task_alt_rounded;
        break;
      case 'rework':
        title = 'Rework Requested';
        desc = 'The administrator or user requested modifications to the performed work.';
        icon = Icons.history_rounded;
        break;
      case 'cancelled':
        title = 'Request Cancelled';
        desc = 'This maintenance request has been cancelled.';
        icon = Icons.cancel_rounded;
        break;
      default:
        title = 'Awaiting Review';
        desc = 'Your request has been received and is pending admin review.';
        icon = Icons.pending_actions_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _statusColor.withValues(alpha: 0.12),
            _statusColor.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _statusColor.withValues(alpha: 0.25)),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: _statusColor.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(icon, color: _statusColor, size: 38),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AdminStyles.headingStyle(fontSize: 26, color: _statusColor)),
                const SizedBox(height: 8),
                Text(desc, style: AdminStyles.bodyStyle(fontSize: 15, color: AdminStyles.textSecondary, height: 1.5)),
                if (_currentTask?.maintenanceNotes != null && _currentTask!.maintenanceNotes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AdminStyles.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminStyles.info.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sticky_note_2_rounded, color: AdminStyles.info, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _currentTask!.maintenanceNotes!,
                            style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary, height: 1.4),
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
      ),
    );
  }

  // ─── Timeline Card ───────────────────────────────────────────────────────────
  Widget _buildTimelineCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminStyles.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timeline_rounded, color: AdminStyles.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Activity Timeline', style: AdminStyles.headingStyle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 32),
          ..._steps.map(_buildTimelineItem),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(_TimelineStep step) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: step.isCompleted
                        ? step.color.withValues(alpha: 0.12)
                        : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: step.isCompleted ? step.color : const Color(0xFFE2E8F0),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    step.isCompleted ? step.icon : Icons.radio_button_unchecked_rounded,
                    color: step.isCompleted ? step.color : const Color(0xFFCBD5E1),
                    size: 20,
                  ),
                ),
                if (!step.isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: step.isCompleted
                            ? LinearGradient(
                                colors: [step.color, step.color.withValues(alpha: 0.3)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                            : null,
                        color: step.isCompleted ? null : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: step.isLast ? 0 : 32, top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.title,
                          style: AdminStyles.headingStyle(
                            fontSize: 15,
                            color: step.isCompleted ? AdminStyles.textPrimary : AdminStyles.textMuted,
                            fontWeight: step.isCompleted ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (step.isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: step.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Done',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: step.color),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    step.desc,
                    style: AdminStyles.bodyStyle(
                      fontSize: 13,
                      color: step.isCompleted ? AdminStyles.textSecondary : AdminStyles.textMuted,
                      height: 1.5,
                    ),
                  ),
                  if (step.date != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 13, color: step.color.withValues(alpha: 0.7)),
                        const SizedBox(width: 5),
                        Text(
                          DateFormat('MMM dd, yyyy • hh:mm a').format(step.date!),
                          style: TextStyle(fontSize: 11, color: step.color.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Info/Action Panel ───────────────────────────────────────────────────────
  Widget _buildInfoPanel() {
    return Column(
      children: [
        if (!_isAssignedToMe && widget.task.status.toLowerCase() != 'pending') ...[
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              border: Border.all(color: const Color(0xFFFCD34D)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'View-Only Access',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This task is assigned to another maintenance technician. You cannot accept or complete it.',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF92400E).withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // Dynamic maintenance actions
        if (_canStart) ...[
          _buildStartActionCard(),
          const SizedBox(height: 24),
        ],
        if (_canComplete) ...[
          _buildCompletionActionCard(),
          const SizedBox(height: 24),
        ],
        
        _buildRequestInfoCard(),
        const SizedBox(height: 24),
        
        _buildReferenceDataCard(),
        if (_signatures.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSignaturesCard(),
        ],
      ],
    );
  }

  Widget _buildStartActionCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.not_started_rounded, color: AdminStyles.primary, size: 48),
          const SizedBox(height: 24),
          Text('Ready to Start?', style: AdminStyles.headingStyle(fontSize: 18)),
          const SizedBox(height: 12),
          Text('You are assigned to this task. Please acknowledge and sign to officially begin the maintenance work.', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => MaintenanceAcceptTaskWeb(task: _currentTask!)));
                if (result == true) _loadData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AdminStyles.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Go to Acceptance Page', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionActionCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Submit Completion Report', style: AdminStyles.headingStyle(fontSize: 18)),
          const SizedBox(height: 24),
          _buildEvidencePicker(),
          if (_isUploadingEvidence) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(color: AdminStyles.primary),
          ],
          const SizedBox(height: 24),
          _buildWebTextField(_noteController, 'Maintenance Notes', 'Describe findings or work performed...', maxLines: 4),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 32),
          SignaturePadWidget(
            title: 'Completion Signature',
            subtitle: 'Sign to confirm work is finished',
            onSignatureComplete: _handleCompletion,
          ),
        ],
      ),
    );
  }

  Widget _buildEvidencePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Work Evidence Photo (Mandatory)', style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_evidenceImage != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _evidenceImage!.path,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(top: 8, right: 8, child: IconButton(onPressed: () => setState(() => _evidenceImage = null), icon: const Icon(Icons.cancel_rounded, color: Colors.white))),
            ],
          )
        else
          InkWell(
            onTap: _pickImage,
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(color: AdminStyles.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminStyles.border, style: BorderStyle.solid)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_rounded, color: AdminStyles.primary),
                  const SizedBox(height: 8),
                  Text('Upload Evidence Image', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.primary)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRequestInfoCard() {
    final task = _currentTask!;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Problem Description', style: AdminStyles.headingStyle(fontSize: 18)),
              if (task.reworkCount > 0) 
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AdminStyles.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('${task.reworkCount} REWORK(S)', style: AdminStyles.headingStyle(fontSize: 11, color: AdminStyles.error)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AdminStyles.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminStyles.border),
            ),
            child: Text(
              task.description,
              style: AdminStyles.bodyStyle(fontSize: 14, height: 1.5, color: AdminStyles.textPrimary),
            ),
          ),
          const SizedBox(height: 24),
          Text('Location & Classification', style: AdminStyles.headingStyle(fontSize: 15)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildLocationChip(Icons.business_rounded, task.buildingName ?? 'Building'),
              _buildLocationChip(Icons.meeting_room_rounded, task.roomName ?? 'Room'),
              _buildLocationChip(Icons.category_rounded, task.typeOfRequest),
            ],
          ),
          if (task.workEvidence != null) ...[
            const SizedBox(height: 24),
            Text('Accomplished Work Evidence', style: AdminStyles.headingStyle(fontSize: 15)),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final urls = _parseEvidenceUrls(task.workEvidence);
                if (urls.isEmpty) return const SizedBox.shrink();
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 16 / 9,
                  ),
                  itemCount: urls.length,
                  itemBuilder: (context, idx) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        urls[idx],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                      ),
                    );
                  },
                );
              }
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AdminStyles.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminStyles.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AdminStyles.primary),
          const SizedBox(width: 8),
          Text(label, style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminStyles.primary)),
        ],
      ),
    );
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

  Widget _buildReferenceDataCard() {
    final task = _currentTask!;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reference Data', style: AdminStyles.headingStyle(fontSize: 15, color: AdminStyles.textSecondary)),
          const SizedBox(height: 20),
          _buildSummaryRow('Requestor', task.requestorName),
          _buildSummaryRow('Submitted', DateFormat('MMM dd, yyyy').format(task.dateSubmitted)),
          if (task.acceptedDate != null) _buildSummaryRow('Started', DateFormat('MMM dd, yyyy hh:mm a').format(task.acceptedDate!)),
          if (task.dateCompleted != null) _buildSummaryRow('Completed', DateFormat('MMM dd, yyyy hh:mm a').format(task.dateCompleted!)),
        ],
      ),
    );
  }

  Widget _buildSignaturesCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Process Signatures', style: AdminStyles.headingStyle(fontSize: 15)),
          const SizedBox(height: 20),
          ..._signatures.map((sig) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AdminStyles.success.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.verified_rounded, color: AdminStyles.success, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sig.signerName, style: AdminStyles.headingStyle(fontSize: 13)),
                          Text('${sig.signatureType.toUpperCase()} • ${DateFormat('MMM dd, yyyy • hh:mm a').format(sig.signedAt)}', style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildWebTextField(TextEditingController controller, String label, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminStyles.textPrimary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: AdminStyles.bodyStyle(fontSize: 14),
          decoration: InputDecoration(hintText: hint, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AdminStyles.border))),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AdminStyles.bodyStyle(fontSize: 13)),
          Text(value, style: AdminStyles.dataStyle(fontSize: 13)),
        ],
      ),
    );
  }

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.success));
  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.error));
  void _showWarning(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.warning));
}

class _TimelineStep {
  final IconData icon;
  final String title;
  final String desc;
  final DateTime? date;
  final bool isCompleted;
  final Color color;
  final bool isLast;
  final String? customBadge;

  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.desc,
    this.date,
    required this.isCompleted,
    required this.color,
    this.isLast = false,
    this.customBadge,
  });
}

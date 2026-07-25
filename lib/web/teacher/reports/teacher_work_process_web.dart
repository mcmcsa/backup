import 'package:flutter/material.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/e_signature_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../admin/shared/admin_styles.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'teacher_official_form_web.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/widgets/signature_pad_widget.dart';
import '../../../shared/services/work_request_service.dart';
import 'package:provider/provider.dart';

class TeacherWorkProcessWeb extends StatefulWidget {
  final WorkRequest request;
  final VoidCallback? onBack;

  const TeacherWorkProcessWeb({super.key, required this.request, this.onBack});

  @override
  State<TeacherWorkProcessWeb> createState() => _TeacherWorkProcessWebState();
}

class _TeacherWorkProcessWebState extends State<TeacherWorkProcessWeb>
    with SingleTickerProviderStateMixin {
  List<ESignature> _signatures = [];
  bool _isLoading = true;
  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

  late WorkRequest _currentRequest;

  WorkRequest get _req => _currentRequest;
  String get _status => _req.status.toLowerCase();

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
    _loadSignatures();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadSignatures() async {
    try {
      final sigs = await ESignatureService.fetchByWorkRequest(_req.id);
      if (mounted) {
        setState(() { _signatures = sigs; _isLoading = false; });
        _animController.forward();
      }
    } catch (_) {
      if (mounted) { setState(() => _isLoading = false); _animController.forward(); }
    }
  }

  // ─── Status Helpers ──────────────────────────────────────────────────────────
  Color get _statusColor {
    switch (_status) {
      case 'completed': return AdminStyles.success;
      case 'in_progress':
      case 'under_maintenance': return AdminStyles.info;
      case 'pending': return AdminStyles.warning;
      case 'cancelled': return AdminStyles.error;
      default: return AdminStyles.textMuted;
    }
  }

  String get _statusLabel {
    switch (_status) {
      case 'in_progress': return 'IN PROGRESS';
      case 'under_maintenance': return 'UNDER MAINTENANCE';
      case 'cancelled': return 'CANCELLED';
      default: return _status.toUpperCase();
    }
  }

  // Timeline step data
  List<_TimelineStep> get _steps {
    final submitted = _req.dateSubmitted;
    final approved = _req.approvedDate;
    final started = _req.maintenanceStartTime;
    final ended = _req.maintenanceEndTime ?? _req.dateCompleted;

    final isAssigned = _status != 'pending';
    final isInProgress = ['in_progress', 'under_maintenance', 'completed'].contains(_status);
    final isDone = _status == 'completed';

    return [
      _TimelineStep(
        icon: Icons.assignment_turned_in_rounded,
        title: 'Request Submitted',
        desc: 'You submitted a maintenance request for ${_req.roomName ?? 'a room'}.',
        date: submitted,
        isCompleted: true,
        color: AdminStyles.primary,
      ),
      _TimelineStep(
        icon: Icons.admin_panel_settings_rounded,
        title: 'Admin Review & Approval',
        desc: isAssigned
            ? (_req.approvedByName != null ? 'Approved by ${_req.approvedByName}.' : 'Request approved and assigned.')
            : 'Waiting for an admin to review your request.',
        date: approved,
        isCompleted: isAssigned,
        color: AdminStyles.secondary,
      ),
      _TimelineStep(
        icon: Icons.engineering_rounded,
        title: 'Maintenance In Progress',
        desc: isInProgress
            ? (_req.acceptedByName != null ? 'Assigned to ${_req.acceptedByName}.' : 'Maintenance staff is working on the issue.')
            : 'Pending assignment to a maintenance technician.',
        date: started,
        isCompleted: isInProgress,
        color: AdminStyles.info,
      ),
      _TimelineStep(
        icon: Icons.verified_rounded,
        title: 'Completed & Verified',
        desc: isDone
            ? 'The issue has been resolved. Thank you for your patience!'
            : 'Awaiting resolution and sign-off.',
        date: ended,
        isCompleted: isDone,
        color: AdminStyles.success,
        isLast: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 1000;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDFA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary, strokeWidth: 2))
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(isCompact ? 20 : 40),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
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
                                        Expanded(flex: 6, child: _buildTimelineCard()),
                                        const SizedBox(width: 28),
                                        Expanded(flex: 4, child: _buildInfoPanel()),
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
    final trackId = _req.id.length > 8
        ? _req.id.substring(0, 8).toUpperCase()
        : _req.id.toUpperCase();

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
            onTap: widget.onBack ?? () => context.pop(),
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
                builder: (context) => TeacherOfficialFormWeb(request: _req),
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

    switch (_status) {
      case 'in_progress':
      case 'under_maintenance':
        title = 'Maintenance In Progress';
        desc = 'Our technicians are currently working on resolving the issue.';
        icon = Icons.construction_rounded;
        break;
      case 'completed':
        title = 'Issue Resolved ✓';
        desc = 'This maintenance request has been completed and verified. Thank you!';
        icon = Icons.task_alt_rounded;
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
                if (_req.maintenanceNotes != null && _req.maintenanceNotes!.isNotEmpty) ...[
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
                            _req.maintenanceNotes!,
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
          // Line & Circle
          SizedBox(
            width: 48,
            child: Column(
              children: [
                // Circle
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
                // Connector
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
          // Content
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

  // ─── Info Panel ──────────────────────────────────────────────────────────────
  Widget _buildInfoPanel() {
    final hasAdminCompletion = _signatures.any((s) => s.signatureType == 'completion' && (s.signerRole == 'admin' || s.signerRole == 'approver'));
    final hasUserCompletion = _signatures.any((s) => s.signatureType == 'completion' && s.signerRole == 'teacher');

    return Column(
      children: [
        if (hasAdminCompletion) ...[
          _buildCompletionConfirmationCard(hasUserCompletion),
          const SizedBox(height: 20),
        ],
        _buildRequestInfoCard(),
        if (_signatures.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSignaturesCard(),
        ],
      ],
    );
  }

  Widget _buildCompletionConfirmationCard(bool hasUserCompletion) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: hasUserCompletion ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hasUserCompletion ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE)),
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
                  color: hasUserCompletion ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasUserCompletion ? Icons.verified_rounded : Icons.pending_actions_rounded,
                  color: hasUserCompletion ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                hasUserCompletion ? 'Work Completion Confirmed' : 'Confirm Work Request Completion',
                style: AdminStyles.headingStyle(
                  fontSize: 17,
                  color: hasUserCompletion ? const Color(0xFF166534) : const Color(0xFF1E40AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            hasUserCompletion
                ? 'You have verified and signed the completion confirmation form for this request.'
                : 'The maintenance work has been accomplished by the technician and signed by the Campus Admin. Please review the work and sign the confirmation to officially close this ticket.',
            style: AdminStyles.bodyStyle(
              fontSize: 13,
              color: hasUserCompletion ? const Color(0xFF166534) : const Color(0xFF1E40AF),
            ),
          ),
          if (!hasUserCompletion) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openConfirmSignatureDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.draw_rounded, size: 18),
              label: const Text('Sign Confirm Work Request Form', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  void _openConfirmSignatureDialog() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final signatureBase64 = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SignaturePadWidget(
                title: 'Confirm Completion Signature',
                subtitle: 'Please draw your signature below to verify completion.',
                onSignatureComplete: (base64) {
                  Navigator.of(context).pop(base64);
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );

    if (signatureBase64 != null) {
      setState(() => _isLoading = true);
      try {
        await ESignatureService.insert(
          ESignature(
            id: '',
            workRequestId: _req.id,
            signerId: user.id,
            signerName: user.name,
            signerRole: 'teacher',
            signatureType: 'completion',
            signatureData: signatureBase64,
            signedAt: DateTime.now(),
            notes: 'Requestor completion confirmation signature',
          ),
        );

        await WorkRequestService.completeRequest(_req.id);
        
        final updated = await WorkRequestService.fetchById(_req.id);
        if (updated != null && mounted) {
          setState(() {
            _currentRequest = updated;
          });
          await _loadSignatures();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing completion: $e'), backgroundColor: AdminStyles.error),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildRequestInfoCard() {
    // Only show priority if the admin has already reviewed/approved (status != 'pending').
    // While still pending, the admin has not yet assigned a priority level.
    final isPendingReview = _req.status.toLowerCase() == 'pending';
    final priorityDisplay = isPendingReview ? '--' : _req.priorityLabel;
    final priorityLower = _req.priority.toLowerCase();
    final priorityColor = isPendingReview
        ? AdminStyles.textMuted
        : priorityLower == 'high'
            ? AdminStyles.error
            : priorityLower == 'medium'
                ? AdminStyles.warning
                : priorityLower == 'low'
                    ? AdminStyles.success
                    : AdminStyles.textMuted;

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminStyles.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_rounded, color: AdminStyles.secondary, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Request Details', style: AdminStyles.headingStyle(fontSize: 17)),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailChip(Icons.location_on_rounded, 'Location', '${_req.buildingName ?? 'N/A'} — ${_req.roomName ?? 'N/A'}', AdminStyles.primary),
          _buildDetailChip(Icons.category_rounded, 'Category', _req.typeOfRequest.isNotEmpty ? _req.typeOfRequest : 'N/A', AdminStyles.secondary),
          _buildDetailChip(Icons.flag_rounded, 'Priority', priorityDisplay, priorityColor),
          _buildDetailChip(Icons.calendar_today_rounded, 'Submitted', DateFormat('MMM dd, yyyy').format(_req.dateSubmitted), AdminStyles.textSecondary),
          if (_req.requestorName.isNotEmpty)
            _buildDetailChip(Icons.person_rounded, 'Requested by', _req.requestorName, AdminStyles.textPrimary),
          const Divider(height: 32, color: Color(0xFFE2E8F0)),
          Row(
            children: [
              const Icon(Icons.description_rounded, size: 16, color: AdminStyles.textMuted),
              const SizedBox(width: 8),
              Text('Description', style: AdminStyles.headingStyle(fontSize: 13, color: AdminStyles.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              _req.description.isNotEmpty ? _req.description : 'No description provided.',
              style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary, height: 1.7),
            ),
          ),
          if (_req.attachmentUrls != null && _req.attachmentUrls!.isNotEmpty) ...[
            const Divider(height: 32, color: Color(0xFFE2E8F0)),
            Row(
              children: [
                const Icon(Icons.image_rounded, size: 16, color: AdminStyles.textMuted),
                const SizedBox(width: 8),
                Text('Attachments', style: AdminStyles.headingStyle(fontSize: 13, color: AdminStyles.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _req.attachmentUrls!.length,
                itemBuilder: (context, index) {
                  final url = _req.attachmentUrls![index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Image.network(url, fit: BoxFit.contain),
                                ),
                              ),
                            );
                          },
                          child: Image.network(url, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: AdminStyles.headingStyle(fontSize: 13, color: AdminStyles.textPrimary)),
              ],
            ),
          ),
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
        border: Border.all(color: AdminStyles.success.withValues(alpha: 0.3)),
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
                  color: AdminStyles.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_rounded, color: AdminStyles.success, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Verified Signatures', style: AdminStyles.headingStyle(fontSize: 17)),
            ],
          ),
          const SizedBox(height: 20),
          ..._signatures.map((s) => _buildSignatureItem(s)),
        ],
      ),
    );
  }

  Widget _buildSignatureItem(ESignature s) {
    final initials = s.signerName.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();
    Uint8List? signatureBytes;
    if (s.signatureData.isNotEmpty) {
      try {
        final cleanBase64 = s.signatureData.contains(',')
            ? s.signatureData.split(',').last
            : s.signatureData;
        signatureBytes = base64Decode(cleanBase64.trim());
      } catch (_) {
        // ignore decode errors
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AdminStyles.success.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminStyles.success.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AdminStyles.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(initials, style: const TextStyle(color: AdminStyles.success, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.signerName, style: AdminStyles.headingStyle(fontSize: 13)),
                  Text(s.signerRole.toUpperCase(), style: AdminStyles.bodyStyle(fontSize: 10, color: AdminStyles.textMuted)),
                  if (signatureBytes != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 50,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Image.memory(
                        signatureBytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.verified_rounded, color: AdminStyles.success, size: 18),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM dd').format(s.signedAt),
                  style: AdminStyles.bodyStyle(fontSize: 10, color: AdminStyles.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data class ──────────────────────────────────────────────────────────────
class _TimelineStep {
  final IconData icon;
  final String title;
  final String desc;
  final DateTime? date;
  final bool isCompleted;
  final bool isLast;
  final Color color;

  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.desc,
    this.date,
    required this.isCompleted,
    this.isLast = false,
    required this.color,
  });
}

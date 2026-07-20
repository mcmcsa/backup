import 'package:flutter/material.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/e_signature_service.dart';

import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../admin/shared/admin_styles.dart';

class TeacherWorkProcessWeb extends StatefulWidget {
  final WorkRequest request;

  const TeacherWorkProcessWeb({super.key, required this.request});

  @override
  State<TeacherWorkProcessWeb> createState() => _TeacherWorkProcessWebState();
}

class _TeacherWorkProcessWebState extends State<TeacherWorkProcessWeb> {
  List<ESignature> _signatures = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSignatures();
  }

  Future<void> _loadSignatures() async {
    try {
      final sigs = await ESignatureService.fetchByWorkRequest(widget.request.id);
      if (mounted) {
        setState(() {
          _signatures = sigs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminStyles.bg,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    children: [
                      _buildStatusHero(),
                      const SizedBox(height: 32),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: _buildTimelineSection()),
                          const SizedBox(width: 32),
                          Expanded(flex: 4, child: _buildRequestDetails()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: AdminStyles.surface,
        border: Border(bottom: BorderSide(color: AdminStyles.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Request Progress', style: AdminStyles.headingStyle(fontSize: 24)),
              Text('Tracking: ${widget.request.id.length > 8 ? widget.request.id.substring(0, 8).toUpperCase() : widget.request.id.toUpperCase()}', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
            ],
          ),
          const Spacer(),
          _buildStatusPill(widget.request.status),
        ],
      ),
    );
  }

  Widget _buildStatusHero() {
    final status = widget.request.status.toLowerCase();
    String title = 'Processing Request';
    String desc = 'Our maintenance team is reviewing your report.';
    IconData icon = Icons.hourglass_empty_rounded;
    Color color = AdminStyles.warning;

    if (status == 'in_progress' || status == 'under_maintenance') {
      title = 'Maintenance in Progress';
      desc = 'Maintenance staff is currently working on the issue.';
      icon = Icons.engineering_rounded;
      color = AdminStyles.info;
    } else if (status == 'completed') {
      title = 'Work Completed';
      desc = 'This issue has been resolved. Thank you for your patience.';
      icon = Icons.check_circle_rounded;
      color = AdminStyles.success;
    }

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.1), AdminStyles.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 40),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AdminStyles.headingStyle(fontSize: 28, color: color)),
                const SizedBox(height: 8),
                Text(desc, style: AdminStyles.bodyStyle(fontSize: 16, color: AdminStyles.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Timeline', style: AdminStyles.headingStyle(fontSize: 18)),
          const SizedBox(height: 32),
          _buildTimelineItem(
            'Request Submitted',
            'You reported an issue for ${widget.request.roomName ?? 'a room'}.',
            widget.request.dateSubmitted,
            isCompleted: true,
            isLast: false,
          ),
          _buildTimelineItem(
            'Maintenance Assigned',
            'The request has been queued for assignment.',
            null,
            isCompleted: widget.request.status != 'pending',
            isLast: false,
          ),
          _buildTimelineItem(
            'Work in Progress',
            'Maintenance staff is addressing the reported issue.',
            null,
            isCompleted: ['in_progress', 'under_maintenance', 'completed'].contains(widget.request.status.toLowerCase()),
            isLast: false,
          ),
          _buildTimelineItem(
            'Resolution & Verification',
            'Issue resolved and verified by the team.',
            null,
            isCompleted: widget.request.status.toLowerCase() == 'completed',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String title, String desc, DateTime? date, {required bool isCompleted, required bool isLast}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? AdminStyles.primary : AdminStyles.bg,
                shape: BoxShape.circle,
                border: Border.all(color: isCompleted ? AdminStyles.primary : AdminStyles.border, width: 2),
              ),
              child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
            ),
            if (!isLast)
              Container(width: 2, height: 60, color: isCompleted ? AdminStyles.primary : AdminStyles.border),
          ],
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AdminStyles.headingStyle(fontSize: 16, color: isCompleted ? AdminStyles.textPrimary : AdminStyles.textMuted)),
              const SizedBox(height: 4),
              Text(desc, style: AdminStyles.bodyStyle(fontSize: 14, color: AdminStyles.textSecondary)),
              if (date != null) ...[
                const SizedBox(height: 4),
                Text(DateFormat('MMM dd, yyyy • hh:mm a').format(date), style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequestDetails() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: AdminStyles.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Request Information', style: AdminStyles.headingStyle(fontSize: 18)),
              const SizedBox(height: 24),
              _buildDetailRow('Room', widget.request.roomName ?? 'N/A'),
              _buildDetailRow('Building', widget.request.buildingName ?? 'N/A'),
              _buildDetailRow('Category', widget.request.typeOfRequest),
              _buildDetailRow('Priority', widget.request.priority.toUpperCase()),
              const Divider(height: 40),
              Text('Description', style: AdminStyles.headingStyle(fontSize: 14)),
              const SizedBox(height: 12),
              Text(widget.request.description, style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, height: 1.6)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_signatures.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: AdminStyles.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verified Signatures', style: AdminStyles.headingStyle(fontSize: 18)),
                const SizedBox(height: 24),
                ..._signatures.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AdminStyles.bg, borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.verified_user_rounded, color: AdminStyles.primary, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.signerName, style: AdminStyles.headingStyle(fontSize: 14)),
                          Text(s.signerRole.toUpperCase(), style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textSecondary)),
                        ],
                      ),
                      const Spacer(),
                      Text(DateFormat('MMM dd').format(s.signedAt), style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
                    ],
                  ),
                )),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(label, style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: AdminStyles.headingStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: AdminStyles.pillDecoration(color: color, isSecondary: true),
      child: Text(status.toUpperCase().replaceAll('_', ' '), style: AdminStyles.headingStyle(fontSize: 12, color: color)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return AdminStyles.success;
      case 'in_progress':
      case 'under_maintenance': return AdminStyles.info;
      case 'pending': return AdminStyles.warning;
      default: return AdminStyles.textMuted;
    }
  }
}

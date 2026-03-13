import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/pre_inspection_model.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/pre_inspection_service.dart';
import '../../../shared/services/post_repair_service.dart';
import '../../../shared/widgets/workflow_status_badge.dart';
import 'admin_approval_signature_page.dart';
import 'admin_pre_inspection_review_page.dart';
import 'admin_post_repair_evaluation_page.dart';

/// Admin screen to view the full working process of a request:
/// timeline, working time, maintenance start/end, all stages
class AdminWorkProcessPage extends StatefulWidget {
  final WorkRequest request;

  const AdminWorkProcessPage({super.key, required this.request});

  @override
  State<AdminWorkProcessPage> createState() => _AdminWorkProcessPageState();
}

class _AdminWorkProcessPageState extends State<AdminWorkProcessPage> {
  WorkRequest? _request;
  PreInspectionReport? _preInspection;
  PostRepairReport? _postRepair;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _request = await WorkRequestService.fetchById(widget.request.id) ?? widget.request;
      _preInspection = await PreInspectionService.fetchLatestByWorkRequest(_request!.id);
      _postRepair = await PostRepairService.fetchLatestByWorkRequest(_request!.id);
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Work Process',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4169E1)),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4169E1)))
          : _request == null
              ? const Center(child: Text('Request not found'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Header
                      _buildHeaderCard(),
                      const SizedBox(height: 16),

                      // Working time card
                      _buildWorkingTimeCard(),
                      const SizedBox(height: 16),

                      // Workflow timeline
                      _buildWorkflowTimeline(),
                      const SizedBox(height: 16),

                      // Action buttons based on current status
                      _buildActionButtons(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4169E1), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_request!.id,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF4169E1))),
              WorkflowStatusBadge(status: _request!.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(_request!.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          const SizedBox(height: 4),
          Text('${_request!.buildingName} • ${_request!.officeRoom}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          if (_request!.acceptedByName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 14, color: Color(0xFF4169E1)),
                const SizedBox(width: 4),
                Text('Assigned to: ${_request!.acceptedByName}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4169E1))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkingTimeCard() {
    final start = _request!.maintenanceStartTime;
    final end = _request!.maintenanceEndTime;
    final fmt = DateFormat('MMM dd, yyyy HH:mm');

    String duration = 'N/A';
    if (start != null && end != null) {
      final diff = end.difference(start);
      if (diff.inHours > 0) {
        duration = '${diff.inHours}h ${diff.inMinutes % 60}m';
      } else {
        duration = '${diff.inMinutes}m';
      }
    } else if (start != null) {
      final diff = DateTime.now().difference(start);
      if (diff.inHours > 0) {
        duration = '${diff.inHours}h ${diff.inMinutes % 60}m (ongoing)';
      } else {
        duration = '${diff.inMinutes}m (ongoing)';
      }
    }

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
          Row(
            children: [
              const Icon(Icons.access_time, size: 18, color: Color(0xFF4169E1)),
              const SizedBox(width: 8),
              const Text('WORKING TIME',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          _buildTimeRow('Submitted', DateFormat('MMM dd, yyyy HH:mm').format(_request!.dateSubmitted)),
          if (_request!.approvedDate != null)
            _buildTimeRow('Approved', fmt.format(_request!.approvedDate!)),
          if (_request!.acceptedDate != null)
            _buildTimeRow('Accepted', fmt.format(_request!.acceptedDate!)),
          if (start != null)
            _buildTimeRow('Work Started', fmt.format(start)),
          if (end != null)
            _buildTimeRow('Work Completed', fmt.format(end)),
          const Divider(height: 16),
          _buildTimeRow('Total Duration', duration),
        ],
      ),
    );
  }

  Widget _buildTimeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
        ],
      ),
    );
  }

  Widget _buildWorkflowTimeline() {
    final steps = <_TimelineStep>[
      _TimelineStep(
        title: 'Report Submitted',
        subtitle: 'By ${_request!.requestorName}',
        time: DateFormat('MMM dd HH:mm').format(_request!.dateSubmitted),
        isCompleted: true,
        isActive: _request!.status == 'pending',
      ),
      _TimelineStep(
        title: 'Admin Approval',
        subtitle: _request!.approvedBy != null ? 'Signed by ${_request!.approvedBy}' : 'Awaiting admin e-signature',
        time: _request!.approvedDate != null ? DateFormat('MMM dd HH:mm').format(_request!.approvedDate!) : null,
        isCompleted: _request!.approvedDate != null,
        isActive: _request!.status == 'pending',
      ),
      _TimelineStep(
        title: 'Maintenance Acceptance',
        subtitle: _request!.acceptedByName != null ? 'Accepted by ${_request!.acceptedByName}' : 'Awaiting maintenance',
        time: _request!.acceptedDate != null ? DateFormat('MMM dd HH:mm').format(_request!.acceptedDate!) : null,
        isCompleted: _request!.acceptedDate != null,
        isActive: _request!.status == 'approved',
      ),
      _TimelineStep(
        title: 'Pre-Inspection',
        subtitle: _preInspection != null ? 'Report: ${_preInspection!.statusLabel}' : 'Pending inspection',
        time: _preInspection != null ? DateFormat('MMM dd HH:mm').format(_preInspection!.inspectionDate) : null,
        isCompleted: _preInspection?.status == 'approved',
        isActive: _request!.status == 'in_progress',
      ),
      _TimelineStep(
        title: 'Under Maintenance',
        subtitle: _request!.status == 'under_maintenance' || _request!.status == 'completed'
            ? 'Work in progress' : 'Waiting for pre-inspection approval',
        time: _request!.maintenanceStartTime != null
            ? DateFormat('MMM dd HH:mm').format(_request!.maintenanceStartTime!)
            : null,
        isCompleted: _request!.status == 'completed' || _postRepair != null,
        isActive: _request!.status == 'under_maintenance',
      ),
      _TimelineStep(
        title: 'Post-Repair Report',
        subtitle: _postRepair != null ? 'Status: ${_postRepair!.statusLabel}' : 'Awaiting completion',
        time: _postRepair != null ? DateFormat('MMM dd HH:mm').format(_postRepair!.repairDate) : null,
        isCompleted: _postRepair?.status == 'evaluated',
        isActive: _postRepair?.status == 'submitted',
      ),
      _TimelineStep(
        title: 'Completed',
        subtitle: _request!.status == 'completed' ? 'Work finished' : 'Not yet completed',
        time: _request!.dateCompleted != null ? DateFormat('MMM dd HH:mm').format(_request!.dateCompleted!) : null,
        isCompleted: _request!.status == 'completed',
        isActive: false,
      ),
    ];

    if (_request!.reworkCount > 0) {
      steps.insert(6, _TimelineStep(
        title: 'Rework (${_request!.reworkCount}x)',
        subtitle: _request!.reworkNotes ?? 'Rework requested',
        isCompleted: _request!.status != 'rework',
        isActive: _request!.status == 'rework',
      ));
    }

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
          const Text('WORKFLOW TIMELINE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            final i = entry.key;
            final step = entry.value;
            return _buildTimelineItem(step, isLast: i == steps.length - 1);
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(_TimelineStep step, {bool isLast = false}) {
    Color dotColor;
    if (step.isCompleted) {
      dotColor = const Color(0xFF059669);
    } else if (step.isActive) {
      dotColor = const Color(0xFF4169E1);
    } else {
      dotColor = const Color(0xFFD1D5DB);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline dot and line
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
              child: step.isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : step.isActive
                      ? Container(
                          margin: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                        )
                      : null,
            ),
            if (!isLast)
              Container(width: 2, height: 40, color: dotColor.withOpacity(0.3)),
          ],
        ),
        const SizedBox(width: 12),
        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(step.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: step.isCompleted || step.isActive
                              ? const Color(0xFF111827)
                              : const Color(0xFF9CA3AF),
                        )),
                    if (step.time != null)
                      Text(step.time!,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                  ],
                ),
                const SizedBox(height: 2),
                Text(step.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: step.isCompleted || step.isActive
                          ? const Color(0xFF6B7280)
                          : const Color(0xFFD1D5DB),
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final status = _request!.status;

    return Column(
      children: [
        // If pending → show "Approve" button
        if (status == 'pending')
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminApprovalSignaturePage(request: _request!),
                  ),
                );
                if (result == true) _loadData();
              },
              icon: const Icon(Icons.draw, size: 18),
              label: const Text('Approve with E-Signature'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4169E1),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

        // If pre-inspection submitted → show "Review Pre-Inspection"
        if (_preInspection != null && _preInspection!.status == 'submitted')
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminPreInspectionReviewPage(
                      request: _request!,
                    ),
                  ),
                );
                if (result == true) _loadData();
              },
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Review Pre-Inspection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

        // If post-repair submitted → show "Evaluate Post-Repair"
        if (_postRepair != null && _postRepair!.status == 'submitted')
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminPostRepairEvaluationPage(
                      request: _request!,
                    ),
                  ),
                );
                if (result != null) _loadData();
              },
              icon: const Icon(Icons.rate_review, size: 18),
              label: const Text('Evaluate Post-Repair'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
      ],
    );
  }
}

class _TimelineStep {
  final String title;
  final String subtitle;
  final String? time;
  final bool isCompleted;
  final bool isActive;

  _TimelineStep({
    required this.title,
    required this.subtitle,
    this.time,
    required this.isCompleted,
    required this.isActive,
  });
}

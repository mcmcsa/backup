import 'package:flutter/material.dart';

import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/work_request_service.dart';

class ApprovalQueuePageWeb extends StatefulWidget {
  const ApprovalQueuePageWeb({super.key});

  @override
  State<ApprovalQueuePageWeb> createState() => _ApprovalQueuePageWebState();
}

class _ApprovalQueuePageWebState extends State<ApprovalQueuePageWeb> {
  final TextEditingController _searchController = TextEditingController();

  List<WorkRequest> _pendingRequests = [];
  bool _isLoading = true;
  String _selectedPriority = 'All';

  static const _primaryBlue = Color(0xFF2563EB);
  static const _successGreen = Color(0xFF10B981);
  static const _warningOrange = Color(0xFFF59E0B);
  static const _dangerRed = Color(0xFFEF4444);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _cardBg = Color(0xFFFFFFFF);
  static const _pageBg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    try {
      final data = await WorkRequestService.fetchByStatus('Pending');
      if (!mounted) return;
      setState(() {
        _pendingRequests = data;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pendingRequests = [];
        _isLoading = false;
      });
    }
  }

  List<WorkRequest> get _filteredQueue {
    var queue = List<WorkRequest>.from(_pendingRequests);

    if (_selectedPriority != 'All') {
      queue = queue
          .where((item) => item.priority.toLowerCase() == _selectedPriority.toLowerCase())
          .toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      queue = queue.where((item) {
        final buildingName = (item.buildingName ?? '').toLowerCase();
        final officeRoom = (item.officeRoom ?? '').toLowerCase();
        return item.title.toLowerCase().contains(query) ||
            item.id.toLowerCase().contains(query) ||
            item.requestorName.toLowerCase().contains(query) ||
            buildingName.contains(query) ||
            officeRoom.contains(query);
      }).toList();
    }

    return queue;
  }

  int _priorityCount(String priority) {
    return _pendingRequests
        .where((item) => item.priority.toLowerCase() == priority.toLowerCase())
        .length;
  }

  Future<void> _approveRequest(WorkRequest request) async {
    await WorkRequestService.updateStatus(request.id, 'In Progress');
    await AppNotificationService.notifyApprovedToMaintenance(
      workRequestId: request.id,
      adminName: request.approvedByName ?? 'Admin',
      assignedMaintenanceId: request.assignedToId,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Request ${request.formattedId} approved'),
        backgroundColor: _successGreen,
      ),
    );
    _loadRequests();
  }

  Future<void> _rejectRequest(WorkRequest request) async {
    await WorkRequestService.updateStatus(request.id, 'Declined');

    final reporterId = request.requestorId;
    if (reporterId != null && reporterId.trim().isNotEmpty) {
      await AppNotificationService.createForUser(
        targetUserId: reporterId,
        title: 'Request Declined',
        message: 'Your request ${request.id} for ${request.officeRoom} was declined by admin.',
        type: 'work_request_declined',
        workRequestId: request.id,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Request ${request.formattedId} rejected'),
        backgroundColor: _dangerRed,
      ),
    );
    _loadRequests();
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return _dangerRed;
      case 'medium':
        return _warningOrange;
      case 'low':
        return _successGreen;
      default:
        return _textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredQueue;

    return Container(
      color: _pageBg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: _cardBg,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.pending_actions_rounded, color: _warningOrange),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Approval Queue',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search pending requests...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: _primaryBlue, width: 1.4),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedPriority,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Priorities')),
                    DropdownMenuItem(value: 'High', child: Text('High')),
                    DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'Low', child: Text('Low')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedPriority = value);
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StatCard(
                              title: 'Total Pending',
                              value: _pendingRequests.length.toString(),
                              color: _primaryBlue,
                            ),
                            const SizedBox(width: 12),
                            _StatCard(
                              title: 'High Priority',
                              value: _priorityCount('high').toString(),
                              color: _dangerRed,
                            ),
                            const SizedBox(width: 12),
                            _StatCard(
                              title: 'Medium Priority',
                              value: _priorityCount('medium').toString(),
                              color: _warningOrange,
                            ),
                            const SizedBox(width: 12),
                            _StatCard(
                              title: 'Low Priority',
                              value: _priorityCount('low').toString(),
                              color: _successGreen,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: filtered.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(48),
                                  child: Center(
                                    child: Text(
                                      'No pending requests found',
                                      style: TextStyle(color: _textSecondary),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  itemBuilder: (context, index) {
                                    final item = filtered[index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 150,
                                            child: Text(
                                              item.formattedId,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: _textPrimary,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              item.title,
                                              style: const TextStyle(color: _textPrimary),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              item.requestorName,
                                              style: const TextStyle(color: _textSecondary),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '${item.officeRoom ?? '-'}, ${item.buildingName ?? '-'}',
                                              style: const TextStyle(color: _textSecondary),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: _priorityColor(item.priority).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              item.priority.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: _priorityColor(item.priority),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          TextButton(
                                            onPressed: () => _approveRequest(item),
                                            child: const Text('Approve'),
                                          ),
                                          TextButton(
                                            onPressed: () => _rejectRequest(item),
                                            style: TextButton.styleFrom(foregroundColor: _dangerRed),
                                            child: const Text('Reject'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/signature_pad_widget.dart';
import '../../admin/shared/admin_styles.dart';
import '../teacher_nav_controller.dart';

class TeacherDeptHeadApprovalsWeb extends StatefulWidget {
  const TeacherDeptHeadApprovalsWeb({super.key});

  @override
  State<TeacherDeptHeadApprovalsWeb> createState() =>
      _TeacherDeptHeadApprovalsWebState();
}

class _TeacherDeptHeadApprovalsWebState
    extends State<TeacherDeptHeadApprovalsWeb>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<WorkRequest> _pendingRequests = [];
  List<WorkRequest> _evaluatedRequests = [];
  String _searchQuery = '';
  StreamSubscription<void>? _streamSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadRequests();

    _streamSub = WorkRequestService.onWorkRequestsChanged.listen((_) {
      if (mounted) _loadRequests();
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final pending = await WorkRequestService.fetchPendingForDeptHead(user.id);
      final evaluated =
          await WorkRequestService.fetchEvaluatedByDeptHead(user.id);

      if (mounted) {
        setState(() {
          _pendingRequests = pending;
          _evaluatedRequests = evaluated;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<WorkRequest> get _filteredPending {
    if (_searchQuery.trim().isEmpty) return _pendingRequests;
    final q = _searchQuery.toLowerCase();
    return _pendingRequests.where((r) {
      return r.title.toLowerCase().contains(q) ||
          r.requestorName.toLowerCase().contains(q) ||
          (r.roomName?.toLowerCase().contains(q) ?? false) ||
          (r.roomCode?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<WorkRequest> get _filteredEvaluated {
    if (_searchQuery.trim().isEmpty) return _evaluatedRequests;
    final q = _searchQuery.toLowerCase();
    return _evaluatedRequests.where((r) {
      return r.title.toLowerCase().contains(q) ||
          r.requestorName.toLowerCase().contains(q) ||
          (r.roomName?.toLowerCase().contains(q) ?? false) ||
          (r.roomCode?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          _buildHeader(),
          _buildSummaryStats(),
          _buildSearchAndTabs(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0F766E)),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRequestsList(_filteredPending, isPending: true),
                      _buildRequestsList(_filteredEvaluated, isPending: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.approval_rounded,
              color: Color(0xFF0F766E),
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Department Approvals',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Review, endorse, or decline faculty work requests before Campus Admin evaluation.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F766E)),
            tooltip: 'Refresh Requests',
            onPressed: _loadRequests,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStats() {
    final pendingCount = _pendingRequests.length;
    final approvedCount = _evaluatedRequests
        .where((r) => r.deptHeadStatus == 'approved')
        .length;
    final declinedCount = _evaluatedRequests
        .where((r) => r.deptHeadStatus == 'declined')
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 8),
      child: Row(
        children: [
          _buildStatCard(
            'Awaiting Evaluation',
            pendingCount.toString(),
            Icons.pending_actions_rounded,
            const Color(0xFFF59E0B),
            const Color(0xFFFEF3C7),
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Endorsed to Admin',
            approvedCount.toString(),
            Icons.check_circle_rounded,
            const Color(0xFF10B981),
            const Color(0xFFD1FAE5),
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Declined Requests',
            declinedCount.toString(),
            Icons.cancel_rounded,
            const Color(0xFFEF4444),
            const Color(0xFFFEE2E2),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color bg,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndTabs() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(3),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF64748B),
              indicator: BoxDecoration(
                color: const Color(0xFF0F766E),
                borderRadius: BorderRadius.circular(8),
              ),
              tabs: [
                Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Pending Requests',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (_pendingRequests.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_pendingRequests.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Evaluated History',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 280,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search requests, room, teacher...',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF0F766E)),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(
    List<WorkRequest> list, {
    required bool isPending,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending
                  ? Icons.check_circle_outline_rounded
                  : Icons.history_rounded,
              size: 56,
              color: const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 16),
            Text(
              isPending
                  ? 'All caught up! No requests pending evaluation.'
                  : 'No evaluated requests in history.',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final req = list[index];
        return _buildRequestCard(req, isPending: isPending);
      },
    );
  }

  Widget _buildRequestCard(WorkRequest req, {required bool isPending}) {
    final statusColor = _statusColor(req.deptHeadStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Code, Date, Status badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    req.formattedId,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _formatDate(req.dateSubmitted),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    req.deptHeadStatus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title & Description
            Text(
              req.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            if (req.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                req.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Metadata Chips: Requestor, Room, Department
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  Icons.person_rounded,
                  '${req.displayRequestorName} (${req.requestorPosition})',
                ),
                _buildInfoChip(
                  Icons.meeting_room_rounded,
                  req.officeRoom != null && req.officeRoom!.isNotEmpty
                      ? '${req.officeRoom} (${req.roomCode ?? ""})'
                      : (req.roomCode ?? 'Room N/A'),
                ),
                _buildInfoChip(
                  Icons.business_rounded,
                  req.departmentName ?? 'Department',
                ),
                if (req.attachmentUrls != null &&
                    req.attachmentUrls!.isNotEmpty)
                  _buildInfoChip(
                    Icons.photo_library_rounded,
                    '${req.attachmentUrls!.length} photo(s)',
                    color: const Color(0xFF0284C7),
                  ),
              ],
            ),

            if (req.deptHeadNotes != null &&
                req.deptHeadNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Your Notes: ${req.deptHeadNotes}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],

            // Action Buttons
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('View Full Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFF0F766E)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    // Navigate to TeacherReportsWeb details (index 3)
                    TeacherNavController.of(context)
                        ?.navigateTo(3, request: req);
                  },
                ),
                if (isPending) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Decline'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _showDeclineDialog(req),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve & Endorse'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _showApproveDialog(req),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {Color? color}) {
    final c = color ?? const Color(0xFF64748B);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c,
          ),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF10B981);
      case 'declined':
        return const Color(0xFFEF4444);
      case 'pending':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  void _showApproveDialog(WorkRequest req) {
    final notesController = TextEditingController();
    String? signatureBase64;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dContext) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Color(0xFF0F766E), size: 24),
              SizedBox(width: 10),
              Text('Approve & Endorse Request', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You are endorsing "${req.title}" to Campus Admin for maintenance review and assignment.',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Department Head Evaluation Notes (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add remarks, justifications, or special instructions...',
                      hintStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('E-Signature (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 6),
                  SignaturePadWidget(
                    title: 'Department Head E-Signature',
                    subtitle: 'Sign or upload your signature to endorse',
                    height: 160,
                    onSignatureComplete: (sig) {
                      signatureBase64 = sig;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(dContext);
                final user = context.read<AuthService>().currentUser;
                if (user == null) return;

                try {
                  await WorkRequestService.approveByDeptHead(
                    req.id,
                    user.id,
                    user.name,
                    notes: notesController.text.trim(),
                    signatureData: signatureBase64,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Request endorsed successfully and forwarded to Campus Admin.'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                    _loadRequests();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error approving request: $e'), backgroundColor: AdminStyles.error),
                    );
                  }
                }
              },
              child: const Text('Confirm Endorsement'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeclineDialog(WorkRequest req) {
    final reasonController = TextEditingController();
    String? signatureBase64;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dContext) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 24),
              SizedBox(width: 10),
              Text('Decline Work Request', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Declining this request terminates the workflow. The request will NOT proceed to Campus Admin.',
                    style: TextStyle(fontSize: 13, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  const Text('Reason for Declining (Required)*', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Explain why this request is declined...',
                      hintStyle: const TextStyle(fontSize: 13),
                      errorText: errorText,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('E-Signature (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 6),
                  SignaturePadWidget(
                    title: 'Department Head E-Signature',
                    subtitle: 'Sign or upload your signature',
                    height: 160,
                    onSignatureComplete: (sig) {
                      signatureBase64 = sig;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  setDState(() => errorText = 'Please provide a reason for declining.');
                  return;
                }

                Navigator.pop(dContext);
                final user = context.read<AuthService>().currentUser;
                if (user == null) return;

                try {
                  await WorkRequestService.declineByDeptHead(
                    req.id,
                    user.id,
                    user.name,
                    reason: reasonController.text.trim(),
                    signatureData: signatureBase64,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Request declined and closed.'),
                        backgroundColor: Color(0xFFEF4444),
                      ),
                    );
                    _loadRequests();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error declining request: $e'), backgroundColor: AdminStyles.error),
                    );
                  }
                }
              },
              child: const Text('Confirm Decline'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/login_activity_service.dart';
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
    extends State<TeacherDeptHeadApprovalsWeb> {
  bool _isLoading = true;
  bool _isGridView = false;
  List<WorkRequest> _pendingRequests = [];
  List<WorkRequest> _evaluatedRequests = [];
  String _searchQuery = '';
  // Filter: 'pending' | 'acknowledge' | 'approve'
  String _activeFilter = 'pending';
  StreamSubscription<void>? _streamSub;

  @override
  void initState() {
    super.initState();
    _loadRequests(showLoading: true);

    _streamSub = WorkRequestService.onWorkRequestsChanged.listen((_) {
      if (mounted) _loadRequests(showLoading: false);
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRequests({bool showLoading = false}) async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    if (showLoading || (_pendingRequests.isEmpty && _evaluatedRequests.isEmpty)) {
      setState(() => _isLoading = true);
    }
    try {
      final pending = await WorkRequestService.fetchPendingForDeptHead(user.id);
      final evaluated =
          await WorkRequestService.fetchEvaluatedByDeptHead(user.id);

      if (mounted) {
        setState(() {
          final remoteEvaluatedIds = evaluated.map((e) => e.id).toSet();
          final localUnsyncedEvaluated = _evaluatedRequests
              .where((r) => !remoteEvaluatedIds.contains(r.id))
              .toList();

          _evaluatedRequests = [...localUnsyncedEvaluated, ...evaluated];

          final allEvaluatedIds = _evaluatedRequests.map((e) => e.id).toSet();
          _pendingRequests =
              pending.where((p) => !allEvaluatedIds.contains(p.id)).toList();

          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<WorkRequest> get _activeList {
    List<WorkRequest> base;
    if (_activeFilter == 'pending') {
      base = _pendingRequests;
    } else if (_activeFilter == 'acknowledge') {
      base = _evaluatedRequests
          .where((r) => r.deptHeadStatus == 'acknowledged')
          .toList();
    } else {
      // 'approve'
      base = _evaluatedRequests
          .where((r) => r.deptHeadStatus == 'approved')
          .toList();
    }
    if (_searchQuery.trim().isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base.where((r) {
      return r.title.toLowerCase().contains(q) ||
          r.formattedId.toLowerCase().contains(q) ||
          r.id.toLowerCase().contains(q) ||
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
          _buildSearchAndFilters(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0F766E)),
                  )
                : _buildRequestsList(
                    _activeList,
                    isPending: _activeFilter == 'pending',
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
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
                  'Review, Approve, or Acknowledge faculty work requests before Campus Admin Evaluation.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F766E)),
            tooltip: 'Refresh Requests',
            onPressed: () => _loadRequests(showLoading: true),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final pendingCount = _pendingRequests.length;
    final acknowledgeCount =
        _evaluatedRequests.where((r) => r.deptHeadStatus == 'acknowledged').length;
    final approveCount =
        _evaluatedRequests.where((r) => r.deptHeadStatus == 'approved').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 12),
      child: Row(
        children: [
          // ── Filter Chips ────────────────────────────────────
          _buildFilterChip(
            label: 'Pending Request',
            count: pendingCount,
            filter: 'pending',
            activeColor: const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Acknowledge',
            count: acknowledgeCount,
            filter: 'acknowledge',
            activeColor: const Color(0xFF0F766E),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Approve',
            count: approveCount,
            filter: 'approve',
            activeColor: const Color(0xFF10B981),
          ),
          const Spacer(),
          // ── Search ──────────────────────────────────────────
          SizedBox(
            width: 260,
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
          const SizedBox(width: 10),
          // ── List / Grid toggle ───────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewToggle(
                  icon: Icons.view_list_rounded,
                  label: 'List',
                  isActive: !_isGridView,
                  onTap: () => setState(() => _isGridView = false),
                ),
                _buildViewToggle(
                  icon: Icons.grid_view_rounded,
                  label: 'Grid',
                  isActive: _isGridView,
                  onTap: () => setState(() => _isGridView = true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required String filter,
    required Color activeColor,
  }) {
    final isActive = _activeFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor : const Color(0xFFE2E8F0),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : const Color(0xFF64748B),
              ),
            ),
            if (count > 0 && filter == 'pending') ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.3)
                      : activeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : activeColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF0F766E).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? const Color(0xFF0F766E) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? const Color(0xFF0F766E) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList(
    List<WorkRequest> list, {
    required bool isPending,
  }) {
    if (list.isEmpty) {
      final emptyMsg = _activeFilter == 'pending'
          ? 'All caught up! No requests pending evaluation.'
          : _activeFilter == 'acknowledge'
              ? 'No acknowledged requests yet.'
              : 'No approved requests yet.';
      final emptyIcon = _activeFilter == 'pending'
          ? Icons.check_circle_outline_rounded
          : _activeFilter == 'acknowledge'
              ? Icons.handshake_outlined
              : Icons.verified_outlined;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 56, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            Text(
              emptyMsg,
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

    if (_isGridView) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 1200
              ? 3
              : (constraints.maxWidth > 750 ? 2 : 1);
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 310,
            ),
            itemCount: list.length,
            itemBuilder: (context, index) {
              return _buildRequestGridCard(list[index], isPending: isPending);
            },
          );
        },
      );
    }

    // Default: Compact List View
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _buildRequestListRow(list[index], isPending: isPending);
      },
    );
  }

  Widget _buildIdBadge(String formattedId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        formattedId,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F766E),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(
    WorkRequest req,
    bool isPending, {
    bool compact = false,
  }) {
    return [
      OutlinedButton.icon(
        icon: const Icon(Icons.open_in_new_rounded, size: 14),
        label: const Text('View Full Details'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0F766E),
          side: const BorderSide(color: Color(0xFF0F766E)),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 8 : 12,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: TextStyle(
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: () {
          TeacherNavController.of(context)?.navigateTo(3, request: req);
        },
      ),
      if (isPending) ...[
        const SizedBox(width: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.handshake_outlined, size: 14),
          label: const Text('Acknowledge'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F766E),
            side: const BorderSide(color: Color(0xFF0F766E)),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 8 : 12,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () => _showAcknowledgeDialog(req),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.check_rounded, size: 15),
          label: const Text('Approve'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 8 : 12,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: () => _showApproveDialog(req),
        ),
      ],
    ];
  }

  /// Compact List View Row — clean, highly scannable, eliminates excessive vertical length
  Widget _buildRequestListRow(WorkRequest req, {required bool isPending}) {
    final statusColor = _statusColor(req.deptHeadStatus);
    final displayTitle = req.title.trim().isNotEmpty
        ? req.title
        : (req.typeDisplay.isNotEmpty
            ? req.typeDisplay
            : 'Work Request #${req.formattedId}');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isVeryNarrow = constraints.maxWidth < 960;

            if (isVeryNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildIdBadge(req.formattedId),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(req.dateSubmitted),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                      const Spacer(),
                      _buildStatusPill(req.deptHeadStatus, statusColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _buildInfoChip(
                        Icons.person_rounded,
                        req.requestorPosition.trim().isNotEmpty
                            ? '${req.displayRequestorName} (${req.requestorPosition})'
                            : req.displayRequestorName,
                      ),
                      _buildInfoChip(
                        Icons.meeting_room_rounded,
                        req.officeRoom != null && req.officeRoom!.isNotEmpty
                            ? (req.roomCode != null && req.roomCode!.isNotEmpty
                                ? '${req.officeRoom} (${req.roomCode})'
                                : req.officeRoom!)
                            : (req.roomCode ?? 'Room N/A'),
                      ),
                      _buildInfoChip(
                        Icons.business_rounded,
                        req.departmentName ?? 'Department',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: _buildActionButtons(req, isPending, compact: true),
                  ),
                ],
              );
            }

            // Wide screen single-row layout
            return Row(
              children: [
                // 1. ID & Date column
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildIdBadge(req.formattedId),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(req.dateSubmitted),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // 2. Title & brief description
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (req.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          req.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // 3. Requestor & Room chips
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildInfoChip(
                        Icons.person_rounded,
                        req.requestorPosition.trim().isNotEmpty
                            ? '${req.displayRequestorName} (${req.requestorPosition})'
                            : req.displayRequestorName,
                      ),
                      const SizedBox(height: 4),
                      _buildInfoChip(
                        Icons.meeting_room_rounded,
                        req.officeRoom != null && req.officeRoom!.isNotEmpty
                            ? (req.roomCode != null && req.roomCode!.isNotEmpty
                                ? '${req.officeRoom} (${req.roomCode})'
                                : req.officeRoom!)
                            : (req.roomCode ?? 'Room N/A'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // 4. Status Badge
                SizedBox(
                  width: 100,
                  child: Center(
                    child: _buildStatusPill(req.deptHeadStatus, statusColor),
                  ),
                ),
                const SizedBox(width: 14),

                // 5. Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildActionButtons(req, isPending, compact: true),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Card representation for Grid View
  Widget _buildRequestGridCard(WorkRequest req, {required bool isPending}) {
    final statusColor = _statusColor(req.deptHeadStatus);
    final displayTitle = req.title.trim().isNotEmpty
        ? req.title
        : (req.typeDisplay.isNotEmpty
            ? req.typeDisplay
            : 'Work Request #${req.formattedId}');

    return Container(
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Code, Date, Status badge
            Row(
              children: [
                _buildIdBadge(req.formattedId),
                const SizedBox(width: 8),
                Text(
                  _formatDate(req.dateSubmitted),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const Spacer(),
                _buildStatusPill(req.deptHeadStatus, statusColor),
              ],
            ),
            const SizedBox(height: 12),

            // Title & Description
            Text(
              displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            if (req.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                req.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
            ],
            const Spacer(),

            // Metadata Chips
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildInfoChip(
                  Icons.person_rounded,
                  req.requestorPosition.trim().isNotEmpty
                      ? '${req.displayRequestorName} (${req.requestorPosition})'
                      : req.displayRequestorName,
                ),
                _buildInfoChip(
                  Icons.meeting_room_rounded,
                  req.officeRoom != null && req.officeRoom!.isNotEmpty
                      ? (req.roomCode != null && req.roomCode!.isNotEmpty
                          ? '${req.officeRoom} (${req.roomCode})'
                          : req.officeRoom!)
                      : (req.roomCode ?? 'Room N/A'),
                ),
              ],
            ),

            if (!isPending && req.deptHeadApprovedDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    size: 13,
                    color: Color(0xFF0F766E),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Evaluated: ${_formatDate(req.deptHeadApprovedDate!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 10),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _buildActionButtons(req, isPending, compact: true),
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
      case 'acknowledged':
        return const Color(0xFF0F766E);
      case 'cancelled':
        return const Color(0xFF64748B);
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
    bool isSubmitting = false;

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
              Text('Approve Work Request', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You are approving "${req.title}" for centralized Campus Maintenance. The request will proceed directly to Campus Admin.',
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
                  const Text('Department Head E-Signature (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 6),
                  SignaturePadWidget(
                    title: 'Department Head E-Signature',
                    subtitle: 'Sign or upload your signature to approve',
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
              onPressed: isSubmitting ? null : () => Navigator.pop(dContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final user = context.read<AuthService>().currentUser;
                      if (user == null) return;
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(dContext);

                      setDState(() => isSubmitting = true);

                      // 1. Optimistic state transition: Move immediately to Evaluated History
                      final updated = req.copyWith(
                        deptHeadStatus: 'approved',
                        status: 'Pending Campus Admin',
                        deptHeadApprovedDate: DateTime.now(),
                        deptHeadNotes: notesController.text.trim(),
                      );

                      if (mounted) {
                        setState(() {
                          _pendingRequests.removeWhere((r) => r.id == req.id);
                          _evaluatedRequests.removeWhere((r) => r.id == req.id);
                          _evaluatedRequests.insert(0, updated);
                          if (_pendingRequests.isEmpty) {
                            _activeFilter = 'approve';
                          }
                        });
                      }

                      // Instantly dismiss dialog and show immediate success confirmation
                      nav.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Request approved successfully and forwarded to Campus Admin.'),
                          backgroundColor: Color(0xFF10B981),
                          duration: Duration(seconds: 3),
                        ),
                      );

                      try {
                        await WorkRequestService.approveByDeptHead(
                          req.id,
                          user.id,
                          user.name,
                          notes: notesController.text.trim(),
                          signatureData: signatureBase64,
                        );

                        unawaited(LoginActivityService.recordAction(
                          user: user,
                          title: 'Department Head Approved Work Request',
                          details: 'Approved work request #${req.formattedId} (${req.title}) and forwarded to Campus Admin.',
                          workRequestId: req.id,
                        ));

                        if (mounted) {
                          _loadRequests(showLoading: false);
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Error approving request: $e'), backgroundColor: AdminStyles.error),
                          );
                          _loadRequests(showLoading: false);
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Confirm Approve'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAcknowledgeDialog(WorkRequest req) {
    final notesController = TextEditingController();
    String? signatureBase64;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dContext) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.handshake_rounded, color: Color(0xFF0F766E), size: 24),
              SizedBox(width: 10),
              Text('Acknowledge Work Request', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: Color(0xFF0F766E), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Acknowledging means the Department Head has received the issue and the department will handle it internally. This stops the centralized maintenance process and will NOT forward this request to Campus Admin.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF0F766E), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Internal Department Notes (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add remarks, internal assignment, or resolution notes...',
                      hintStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Department Head E-Signature (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 6),
                  SignaturePadWidget(
                    title: 'Department Head E-Signature',
                    subtitle: 'Sign or upload your signature to confirm acknowledgement',
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
              onPressed: isSubmitting ? null : () => Navigator.pop(dContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final user = context.read<AuthService>().currentUser;
                      if (user == null) return;
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(dContext);

                      setDState(() => isSubmitting = true);

                      // 1. Optimistic state transition: Move immediately to Evaluated History
                      final updated = req.copyWith(
                        deptHeadStatus: 'acknowledged',
                        status: 'Acknowledged',
                        deptHeadApprovedDate: DateTime.now(),
                        deptHeadNotes: notesController.text.trim(),
                      );

                      if (mounted) {
                        setState(() {
                          _pendingRequests.removeWhere((r) => r.id == req.id);
                          _evaluatedRequests.removeWhere((r) => r.id == req.id);
                          _evaluatedRequests.insert(0, updated);
                          if (_pendingRequests.isEmpty) {
                            _activeFilter = 'acknowledge';
                          }
                        });
                      }

                      // Instantly dismiss dialog and show immediate success confirmation
                      nav.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Request acknowledged. Department will handle internally.'),
                          backgroundColor: Color(0xFF10B981),
                          duration: Duration(seconds: 3),
                        ),
                      );

                      try {
                        await WorkRequestService.acknowledgeByDeptHead(
                          req.id,
                          user.id,
                          user.name,
                          notes: notesController.text.trim(),
                          signatureData: signatureBase64,
                        );

                        unawaited(LoginActivityService.recordAction(
                          user: user,
                          title: 'Department Head Acknowledged Work Request',
                          details: 'Acknowledged work request #${req.formattedId} (${req.title}) for internal department handling.',
                          workRequestId: req.id,
                        ));

                        if (mounted) {
                          _loadRequests(showLoading: false);
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Error acknowledging request: $e'), backgroundColor: AdminStyles.error),
                          );
                          _loadRequests(showLoading: false);
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Confirm Acknowledge'),
            ),
          ],
        ),
      ),
    );
  }
}

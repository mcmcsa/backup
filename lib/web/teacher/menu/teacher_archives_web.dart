import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../admin/shared/admin_styles.dart';
import '../teacher_nav_controller.dart';
import '../../../shared/widgets/room_comparison_dialog.dart';

class TeacherArchivesWeb extends StatefulWidget {
  const TeacherArchivesWeb({super.key});

  @override
  State<TeacherArchivesWeb> createState() => _TeacherArchivesWebState();
}

class _TeacherArchivesWebState extends State<TeacherArchivesWeb> {
  final TextEditingController _searchController = TextEditingController();
  List<WorkRequest> _archivedRequests = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  StreamSubscription<void>? _streamSub;

  @override
  void initState() {
    super.initState();
    _loadArchives();
    _streamSub = WorkRequestService.onWorkRequestsChanged.listen((_) {
      if (mounted) _loadArchives(silent: true);
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadArchives({bool silent = false}) async {
    try {
      final user = context.read<AuthService>().currentUser;
      if (user == null) return;
      if (!silent && mounted && _archivedRequests.isEmpty) {
        setState(() => _isLoading = true);
      }
      final data = await WorkRequestService.fetchHistoryForUser(user.id);
      if (mounted) {
        setState(() {
          _archivedRequests = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<WorkRequest> get _filteredArchives {
    return _archivedRequests.where((r) {
      final s = r.status.toLowerCase();
      final dhs = r.deptHeadStatus.toLowerCase();

      bool matchesFilter = false;
      if (_selectedFilter == 'All') {
        matchesFilter = true;
      } else if (_selectedFilter == 'Approved') {
        matchesFilter = dhs == 'approved' || s.contains('approved');
      } else if (_selectedFilter == 'Acknowledged') {
        matchesFilter = dhs == 'acknowledged' || s == 'acknowledged' || r.isAcknowledged;
      } else if (_selectedFilter == 'Completed') {
        matchesFilter = s == 'completed';
      } else if (_selectedFilter == 'Declined') {
        matchesFilter = (s == 'declined' || dhs == 'declined') && !r.isCancelled;
      } else if (_selectedFilter == 'Canceled') {
        matchesFilter = r.isCancelled || s == 'cancelled' || s == 'canceled';
      }

      final query = _searchController.text.toLowerCase().trim();
      if (query.isEmpty) return matchesFilter;

      final matchesSearch = r.title.toLowerCase().contains(query) ||
          (r.roomName?.toLowerCase().contains(query) ?? false) ||
          r.id.toLowerCase().contains(query) ||
          r.formattedId.toLowerCase().contains(query) ||
          r.requestorName.toLowerCase().contains(query);

      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminStyles.bg,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary))
              : _buildArchiveList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 650;

    return Container(
      padding: EdgeInsets.all(isNarrow ? 16 : 40),
      decoration: BoxDecoration(
        color: AdminStyles.surface,
        border: Border(bottom: BorderSide(color: AdminStyles.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('History', style: AdminStyles.headingStyle(fontSize: isNarrow ? 24 : 32)),
          const SizedBox(height: 8),
          Text(
            'Review your historical work requests, evaluations, approvals, and acknowledged requests.',
            style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontSize: isNarrow ? 14 : 16),
          ),
          SizedBox(height: isNarrow ? 20 : 32),
          if (isNarrow)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: AdminStyles.cardDecoration(hasShadow: false, borderColor: AdminStyles.border),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() {}),
                    decoration: AdminStyles.searchInputDecoration(
                      hintText: 'Search request history...',
                      prefixIcon: Icons.search_rounded,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Approved'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Acknowledged'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Completed'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Declined'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Canceled'),
                    ],
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: AdminStyles.cardDecoration(hasShadow: false, borderColor: AdminStyles.border),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() {}),
                      decoration: AdminStyles.searchInputDecoration(hintText: 'Search request history...', prefixIcon: Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('Approved'),
                const SizedBox(width: 8),
                _buildFilterChip('Acknowledged'),
                const SizedBox(width: 8),
                _buildFilterChip('Completed'),
                const SizedBox(width: 8),
                _buildFilterChip('Declined'),
                const SizedBox(width: 8),
                _buildFilterChip('Canceled'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 650;
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isNarrow ? 14 : 20, vertical: isNarrow ? 8 : 12),
        decoration: BoxDecoration(
          color: isSelected ? AdminStyles.primary : AdminStyles.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AdminStyles.primary : AdminStyles.border),
        ),
        child: Text(
          label,
          style: AdminStyles.bodyStyle(
            color: isSelected ? Colors.white : AdminStyles.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: isNarrow ? 12 : 14,
          ),
        ),
      ),
    );
  }

  Widget _buildArchiveList() {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 650;
    final archives = _filteredArchives;
    if (archives.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: AdminStyles.textMuted.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text('No request history found', style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(isNarrow ? 16 : 40),
      itemCount: archives.length,
      separatorBuilder: (context, index) => SizedBox(height: isNarrow ? 12 : 16),
      itemBuilder: (context, index) => _buildArchiveItem(archives[index]),
    );
  }

  Widget _buildArchiveItem(WorkRequest request) {
    final user = context.read<AuthService>().currentUser;
    final currentUserId = user?.id;
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 650;
    final color = _getItemColor(request);
    final icon = _getItemIcon(request);
    final isHeadEvaluated = currentUserId != null && request.deptHeadId == currentUserId;

    if (isNarrow) {
      return GestureDetector(
        onTap: () {
          TeacherNavController.of(context)?.navigateTo(3, request: request);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AdminStyles.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AdminStyles.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          request.formattedId.isNotEmpty
                              ? '#${request.formattedId}'
                              : (request.id.length > 8 ? '#${request.id.substring(0, 8)}' : '#${request.id}'),
                          style: AdminStyles.bodyStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AdminStyles.primary,
                          ),
                        ),
                      ),
                      if (isHeadEvaluated) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'DEPT HEAD EVAL',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF0F766E)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  _buildStatusPill(request, currentUserId),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          style: AdminStyles.headingStyle(fontSize: 15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on_outlined, size: 14, color: AdminStyles.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  request.roomName ?? 'N/A',
                                  style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
                                ),
                              ],
                            ),
                            if (request.requestorName.isNotEmpty && isHeadEvaluated)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_outline_rounded, size: 14, color: AdminStyles.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    request.requestorName,
                                    style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
                                  ),
                                ],
                              ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 13, color: AdminStyles.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(request.deptHeadApprovedDate ?? request.dateSubmitted),
                                  style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AdminStyles.border),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (request.roomId != null && request.roomId!.isNotEmpty) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => RoomComparisonDialog(roomId: request.roomId!),
                        );
                      },
                      icon: const Icon(Icons.difference_outlined, size: 14, color: Color(0xFF16A34A)),
                      label: Text(
                        'Compare',
                        style: AdminStyles.bodyStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: Color(0xFF86EFAC)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  TextButton.icon(
                    onPressed: () {
                      TeacherNavController.of(context)?.navigateTo(3, request: request);
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 15, color: AdminStyles.primary),
                    label: Text(
                      'View Details',
                      style: AdminStyles.bodyStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AdminStyles.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        TeacherNavController.of(context)?.navigateTo(3, request: request);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: AdminStyles.cardDecoration(),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          request.formattedId.isNotEmpty ? '#${request.formattedId}' : '',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AdminStyles.primary,
                          ),
                        ),
                        if (isHeadEvaluated) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.2)),
                            ),
                            child: const Text(
                              'EVALUATED AS DEPT HEAD',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0F766E)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.title,
                      style: AdminStyles.headingStyle(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_outlined, size: 14, color: AdminStyles.textSecondary),
                            const SizedBox(width: 4),
                            Container(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                request.roomName ?? 'N/A',
                                style: AdminStyles.bodyStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (request.requestorName.isNotEmpty && isHeadEvaluated)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_outline_rounded, size: 14, color: AdminStyles.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Requestor: ${request.requestorName}',
                                style: AdminStyles.bodyStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 14, color: AdminStyles.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM dd, yyyy').format(request.deptHeadApprovedDate ?? request.dateSubmitted),
                              style: AdminStyles.bodyStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildStatusPill(request, currentUserId),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (request.roomId != null && request.roomId!.isNotEmpty) ...[
                    Tooltip(
                      message: 'Compare Room Versions',
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => RoomComparisonDialog(roomId: request.roomId!),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Icon(Icons.difference_outlined, size: 16, color: Color(0xFF16A34A)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  PopupMenuButton<String>(
                    tooltip: 'Actions',
                    offset: const Offset(0, 38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: (val) {
                      if (val == 'view') {
                        TeacherNavController.of(context)?.navigateTo(3, request: request);
                      } else if (val == 'compare' && request.roomId != null && request.roomId!.isNotEmpty) {
                        showDialog(
                          context: context,
                          builder: (context) => RoomComparisonDialog(roomId: request.roomId!),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 16, color: AdminStyles.primary),
                            const SizedBox(width: 8),
                            Text('View Details', style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      if (request.roomId != null && request.roomId!.isNotEmpty)
                        PopupMenuItem(
                          value: 'compare',
                          child: Row(
                            children: [
                              const Icon(Icons.difference_outlined, size: 16, color: Color(0xFF16A34A)),
                              const SizedBox(width: 8),
                              Text('Compare Room', style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminStyles.border),
                      ),
                      child: const Icon(Icons.more_vert_rounded, size: 16, color: AdminStyles.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getItemColor(WorkRequest request) {
    final s = request.status.toLowerCase();
    final dhs = request.deptHeadStatus.toLowerCase();
    if (request.isCancelled || s == 'cancelled' || s == 'canceled') {
      return const Color(0xFFEF4444);
    }
    if (dhs == 'acknowledged' || s == 'acknowledged' || request.isAcknowledged) {
      return const Color(0xFF0F766E);
    }
    if (s == 'completed') {
      return AdminStyles.success;
    }
    if (dhs == 'approved') {
      return const Color(0xFF0284C7);
    }
    if (s == 'declined' || dhs == 'declined') {
      return AdminStyles.error;
    }
    return AdminStyles.primary;
  }

  IconData _getItemIcon(WorkRequest request) {
    final s = request.status.toLowerCase();
    final dhs = request.deptHeadStatus.toLowerCase();
    if (request.isCancelled || s == 'cancelled' || s == 'canceled') {
      return Icons.cancel_outlined;
    }
    if (dhs == 'acknowledged' || s == 'acknowledged' || request.isAcknowledged) {
      return Icons.handshake_rounded;
    }
    if (s == 'completed') {
      return Icons.check_circle_rounded;
    }
    if (dhs == 'approved') {
      return Icons.approval_rounded;
    }
    if (s == 'declined' || dhs == 'declined') {
      return Icons.cancel_rounded;
    }
    return Icons.history_rounded;
  }

  Widget _buildStatusPill(WorkRequest request, String? currentUserId) {
    final s = request.status.toLowerCase();
    final dhs = request.deptHeadStatus.toLowerCase();
    final isHeadEvaluated = currentUserId != null && request.deptHeadId == currentUserId;

    Color color;
    String displayStatus;

    if (request.isCancelled || s == 'cancelled' || s == 'canceled') {
      color = const Color(0xFFEF4444);
      displayStatus = 'CANCELED';
    } else if (dhs == 'acknowledged' || s == 'acknowledged' || request.isAcknowledged) {
      color = const Color(0xFF0F766E);
      displayStatus = isHeadEvaluated ? 'ACKNOWLEDGED BY YOU' : 'ACKNOWLEDGED';
    } else if (s == 'completed') {
      color = AdminStyles.success;
      displayStatus = 'COMPLETED';
    } else if (dhs == 'approved') {
      color = const Color(0xFF0284C7);
      displayStatus = isHeadEvaluated ? 'APPROVED BY YOU' : 'HEAD APPROVED';
    } else if (s == 'declined' || dhs == 'declined') {
      color = AdminStyles.error;
      displayStatus = 'DECLINED';
    } else {
      color = AdminStyles.primary;
      displayStatus = request.status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: AdminStyles.pillDecoration(color: color, isSecondary: true),
      child: Text(displayStatus, style: AdminStyles.headingStyle(fontSize: 10, color: color)),
    );
  }
}

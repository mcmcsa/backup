import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:psu_maintsystem/authentication/services/auth_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../maintenance_nav_controller.dart';
import '../../../shared/widgets/room_comparison_dialog.dart';

const Color _blue = Color(0xFF0EA5E9);
const Color _green = Color(0xFF10B981);
const Color _ink = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);
const Color _pageBg = Color(0xFFF1F5F9);
const Color _card = Colors.white;
const Color _border = Color(0xFFE2E8F0);

class MaintenanceHistoryWeb extends StatefulWidget {
  const MaintenanceHistoryWeb({super.key});

  @override
  State<MaintenanceHistoryWeb> createState() => _MaintenanceHistoryWebState();
}

class _MaintenanceHistoryWebState extends State<MaintenanceHistoryWeb> {
  List<WorkRequest> _history = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final user = context.read<AuthService>().currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final data = await WorkRequestService.fetchAssignedTo(user.id);
      final completed = data.where((r) {
        final st = r.status.toLowerCase();
        return st == 'completed' ||
            st == 'declined' ||
            st == 'cancelled' ||
            st == 'declined/cancelled';
      }).toList();
      if (mounted) setState(() { _history = completed; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = (_startDate != null && _endDate != null)
        ? DateTimeRange(start: _startDate!, end: _endDate!)
        : DateTimeRange(start: now.subtract(const Duration(days: 14)), end: now);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: initial,
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
            child: child,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  List<WorkRequest> get _filtered {
    final q = _searchController.text.toLowerCase().trim();
    return _history.where((r) {
      if (q.isNotEmpty) {
        final matches = r.id.toLowerCase().contains(q) ||
            (r.roomName?.toLowerCase().contains(q) ?? false) ||
            r.title.toLowerCase().contains(q);
        if (!matches) return false;
      }

      if (_startDate != null || _endDate != null) {
        final dt = r.dateCompleted ?? r.dateSubmitted;
        if (_startDate != null && dt.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day))) {
          return false;
        }
        if (_endDate != null && dt.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59))) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Groups requests by formatted date string
  Map<String, List<WorkRequest>> _groupByDate(List<WorkRequest> items) {
    final map = <String, List<WorkRequest>>{};
    for (final r in items) {
      final date = r.dateCompleted ?? r.dateSubmitted;
      String key;
      try {
        final dt = DateTime.parse(date.toString());
        final now = DateTime.now();
        if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          key = 'Today';
        } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
          key = 'Yesterday';
        } else {
          key = DateFormat('MMMM d, yyyy').format(dt);
        }
      } catch (_) {
        key = 'Unknown Date';
      }
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(color: _pageBg, child: const Center(child: CircularProgressIndicator(color: _blue)));
    }

    final isMobile = MediaQuery.of(context).size.width < 768;
    final filtered = _filtered;
    final grouped = _groupByDate(filtered);

    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            _buildHeader(filtered.length, isMobile),
            const SizedBox(height: 24),

            // ── Search ───────────────────────────────────────────────────
            _buildSearchBar(),
            const SizedBox(height: 28),

            // ── Grouped List ─────────────────────────────────────────────
            if (filtered.isEmpty)
              _buildEmpty()
            else
              ...grouped.entries.map((e) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateDivider(e.key),
                  const SizedBox(height: 12),
                  ...e.value.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HistoryCard(
                      request: r,
                      onTap: () {
                        MaintenanceNavController.of(context)?.navigateTo(3, request: r);
                      },
                    ),
                  )),
                  const SizedBox(height: 16),
                ],
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int count, bool isMobile) {
    final titleCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('Task History', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.5)),
        SizedBox(height: 6),
        Text('All completed work requests and resolved maintenance tasks.', style: TextStyle(fontSize: 14, color: _muted)),
      ],
    );

    final recordsIndicator = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _green.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 14, color: _green),
          const SizedBox(width: 6),
          Text('$count completed', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _green)),
        ],
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleCol,
          const SizedBox(height: 12),
          recordsIndicator,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: titleCol),
        const SizedBox(width: 16),
        recordsIndicator,
      ],
    );
  }

  Widget _buildSearchBar() {
    final hasDateFilter = _startDate != null || _endDate != null;
    final dateRangeText = hasDateFilter
        ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}'
        : 'Set Date Range';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;

        final searchInput = Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search by title, room, or tracking number...',
              hintStyle: TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: _muted, size: 20),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        );

        final dateButton = InkWell(
          onTap: _pickDateRange,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: hasDateFilter ? _blue.withValues(alpha: 0.1) : _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasDateFilter ? _blue : _border,
                width: hasDateFilter ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: hasDateFilter ? _blue : _muted,
                ),
                const SizedBox(width: 8),
                Text(
                  dateRangeText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: hasDateFilter ? FontWeight.w700 : FontWeight.w600,
                    color: hasDateFilter ? _blue : _ink,
                  ),
                ),
                if (hasDateFilter) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 14, color: _blue),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchInput,
              const SizedBox(height: 10),
              dateButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchInput),
            const SizedBox(width: 12),
            dateButton,
          ],
        );
      },
    );
  }

  Widget _buildDateDivider(String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: _ink.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 0.3)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: _border, height: 1)),
      ],
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 72),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: _green.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: const Icon(Icons.history_rounded, size: 36, color: _green),
          ),
          const SizedBox(height: 16),
          const Text('No completed tasks yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 6),
          const Text('Completed work requests will appear here.', style: TextStyle(fontSize: 13, color: _muted)),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  final WorkRequest request;
  final VoidCallback onTap;

  const _HistoryCard({required this.request, required this.onTap});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final date = widget.request.dateCompleted ?? widget.request.dateSubmitted;
    String displayDate = 'N/A';
    try {
      displayDate = DateFormat('h:mm a').format(DateTime.parse(date.toString()));
    } catch (_) {}

    final isCompleted = widget.request.status.toLowerCase() == 'completed';
    final statusColor = isCompleted ? _green : const Color(0xFFEF4444);
    final statusText = isCompleted ? 'COMPLETED' : 'DECLINED';
    final iconData = isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final ticketId = widget.request.id.length > 8 ? widget.request.id.substring(0, 8) : widget.request.id;

    if (isMobile) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$ticketId',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _blue,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          displayDate,
                          style: const TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
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
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(iconData, color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.request.title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          _InfoChip(Icons.room_rounded, widget.request.roomName ?? 'N/A'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: _border, height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.request.roomId != null && widget.request.roomId!.isNotEmpty) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => RoomComparisonDialog(roomId: widget.request.roomId!),
                          );
                        },
                        icon: const Icon(Icons.difference_outlined, size: 14, color: _green),
                        label: const Text(
                          'Compare',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _green),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: BorderSide(color: _green.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    TextButton.icon(
                      onPressed: widget.onTap,
                      icon: const Icon(Icons.visibility_outlined, size: 15, color: _blue),
                      label: const Text(
                        'View Details',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _blue),
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

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFF0FDF4) : _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? statusColor.withValues(alpha: 0.4) : _border,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: statusColor.withValues(alpha: 0.1), blurRadius: 14, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              // Completion indicator
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Icon(iconData, color: statusColor, size: 24),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.request.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 12,
                      children: [
                        _InfoChip(Icons.room_rounded, widget.request.roomName ?? 'N/A'),
                        _InfoChip(Icons.tag_rounded, ticketId),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Time & status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(statusText, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 0.5)),
                  ),
                  const SizedBox(height: 6),
                  Text(displayDate, style: const TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                tooltip: 'Actions',
                offset: const Offset(0, 38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onSelected: (val) {
                  if (val == 'view') {
                    widget.onTap();
                  } else if (val == 'compare' && widget.request.roomId != null && widget.request.roomId!.isNotEmpty) {
                    showDialog(
                      context: context,
                      builder: (context) => RoomComparisonDialog(roomId: widget.request.roomId!),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 16, color: _blue),
                        SizedBox(width: 8),
                        Text('View Task Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (widget.request.roomId != null && widget.request.roomId!.isNotEmpty)
                    const PopupMenuItem(
                      value: 'compare',
                      child: Row(
                        children: [
                          Icon(Icons.difference_outlined, size: 16, color: _green),
                          SizedBox(width: 8),
                          Text('Compare Room', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(Icons.more_vert_rounded, size: 16, color: _muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: _muted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

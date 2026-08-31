import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/providers/work_request_provider.dart';
import '../../../shared/providers/room_provider.dart';

import '../shared/admin_styles.dart';

// Mapping local colors to AdminStyles for compatibility and modularity
const Color _bg = AdminStyles.bg;
const Color _surface = AdminStyles.surface;
const Color _border = AdminStyles.border;
const Color _textPrimary = AdminStyles.textPrimary;
const Color _textMuted = AdminStyles.textMuted;
const Color _accentCyan = AdminStyles.primaryLight;
const Color _accentGreen = AdminStyles.success;
const Color _accentAmber = AdminStyles.warning;
const Color _accentRed = AdminStyles.error;

class DashboardPageWeb extends StatefulWidget {
  final VoidCallback? onViewAllWorkRequests;

  const DashboardPageWeb({super.key, this.onViewAllWorkRequests});

  @override
  State<DashboardPageWeb> createState() => _DashboardPageWebState();
}

class _DashboardPageWebState extends State<DashboardPageWeb> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<WorkRequestProvider>().refreshRequests();
        context.read<RoomProvider>().refreshRooms();
      }
    });
  }

  List<WorkRequest> get _allRequests {
    return Provider.of<WorkRequestProvider>(context).requests;
  }
  
  bool get _isLoading {
    return Provider.of<WorkRequestProvider>(context).isLoading;
  }
  
  String? get _error {
    return Provider.of<WorkRequestProvider>(context).error;
  }

  int _getCountByStatus(String status) {
    return _allRequests
        .where((r) => r.status.toLowerCase() == status.toLowerCase())
        .length;
  }

  int _getCountByPriority(String priority) {
    return _allRequests
        .where((r) => r.priority.toLowerCase() == priority.toLowerCase())
        .length;
  }

  int _getCountByActiveStatuses() {
    return _allRequests
        .where((r) {
          final status = r.status.toLowerCase();
          return status == 'in progress' ||
              status == 'in_progress' ||
              status == 'assigned' ||
              status == 'accepted by maintenance' ||
              status == 'pre-inspection submitted' ||
              status == 'confirmed' ||
              status == 'rework';
        })
        .length;
  }

  List<WorkRequest> _getLatestRequests({int limit = 6}) {
    final sorted = List<WorkRequest>.from(_allRequests)
      ..sort((left, right) => right.dateSubmitted.compareTo(left.dateSubmitted));
    return sorted.take(limit).toList();
  }

  List<WorkRequest> _getAgingTickets() {
    final now = DateTime.now();
    return _allRequests
        .where((r) =>
            r.status.toLowerCase() != 'completed' &&
            r.status.toLowerCase() != 'declined' &&
            now.difference(r.dateSubmitted).inDays > 3)
        .take(4)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text('Error loading dashboard: $_error', style: AdminStyles.bodyStyle(color: _accentRed)),
      );
    }
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AdminStyles.primary));
    }
    
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 1280;

    final pendingCount = _getCountByStatus('pending');
    final inProgressCount = _getCountByActiveStatuses();
    final completedCount = _getCountByStatus('completed');
    final roomsCount = Provider.of<RoomProvider>(context).rooms.length;

    return Container(
      decoration: const BoxDecoration(
        color: _bg,
      ),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: _accentCyan,
                strokeWidth: 3,
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: width < 900 ? 16 : 28,
                vertical: 22,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildStatCardsGrid(
                        pendingCount,
                        inProgressCount,
                        completedCount,
                        roomsCount,
                      ),
                      const SizedBox(height: 20),
                      if (isCompact)
                        Column(
                          children: [
                            _buildQuickInsightsCard(),
                            const SizedBox(height: 16),
                            _buildLatestRequestsCard(),
                            const SizedBox(height: 16),
                            _buildAgingTicketsCard(),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  _buildQuickInsightsCard(),
                                  const SizedBox(height: 16),
                                  _buildAgingTicketsCard(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(flex: 7, child: _buildLatestRequestsCard()),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminStyles.glassDecoration(
        color: Colors.white,
        opacity: 0.9,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AdminStyles.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AdminStyles.primary.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Maintenance Command Center',
                  style: AdminStyles.headingStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AdminStyles.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'System Online • Analytics Sync Active',
                      style: AdminStyles.bodyStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'SYSTEM TIME',
                style: AdminStyles.headingStyle(fontSize: 10, color: _textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                timestamp,
                style: AdminStyles.dataStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardsGrid(
    int pendingCount,
    int inProgressCount,
    int completedCount,
    int roomsCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth > 1024
            ? 4
            : constraints.maxWidth > 600
                ? 2
                : 1;
        final cardWidth = (constraints.maxWidth - ((perRow - 1) * 12)) / perRow;

        final cards = [
          _KpiCardData(
            title: 'Pending Review',
            value: pendingCount,
            color: _accentAmber,
            icon: Icons.access_time_filled_rounded,
          ),
          _KpiCardData(
            title: 'Active Repairs',
            value: inProgressCount,
            color: _accentCyan,
            icon: Icons.engineering_rounded,
          ),
          _KpiCardData(
            title: 'Completed',
            value: completedCount,
            color: _accentGreen,
            icon: Icons.check_circle_rounded,
          ),
          _KpiCardData(
            title: 'Rooms',
            value: roomsCount,
            color: Colors.purple,
            icon: Icons.meeting_room_rounded,
          ),
        ];

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((card) => SizedBox(
                    width: cardWidth,
                    child: _KpiCard(data: card),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildQuickInsightsCard() {
    final total = _allRequests.length;
    final completed = _getCountByStatus('completed');
    final highPriority = _getCountByPriority('high');
    final active = _getCountByActiveStatuses();

    final completionRate = total == 0 ? 0.0 : completed / total;
    final highPriorityRate = total == 0 ? 0.0 : highPriority / total;
    final activeRate = total == 0 ? 0.0 : active / total;

    return _SectionCard(
      title: 'Performance KPI',
      icon: Icons.analytics_rounded,
      action: Text(
        'Live',
        style: AdminStyles.headingStyle(
          color: _accentGreen,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Column(
        children: [
          _MiniProgress(
            label: 'Resolution Rate',
            value: '${(completionRate * 100).toStringAsFixed(1)}%',
            progress: completionRate.clamp(0.0, 1.0),
            color: _accentCyan,
          ),
          const SizedBox(height: 16),
          _MiniProgress(
            label: 'High Priority Share',
            value: '${(highPriorityRate * 100).toStringAsFixed(1)}%',
            progress: highPriorityRate.clamp(0.0, 1.0),
            color: _accentRed,
          ),
          const SizedBox(height: 16),
          _MiniProgress(
            label: 'Active Ticket Share',
            value: '${(activeRate * 100).toStringAsFixed(1)}%',
            progress: activeRate.clamp(0.0, 1.0),
            color: _accentAmber,
          ),
        ],
      ),
    );
  }

  Widget _buildAgingTicketsCard() {
    final agingTickets = _getAgingTickets();
    return _SectionCard(
      title: 'Aging Tickets',
      subtitle: '${agingTickets.length} overdue',
      icon: Icons.history_rounded,
      action: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _accentRed.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Priority',
          style: AdminStyles.headingStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _accentRed,
          ),
        ),
      ),
      child: agingTickets.isEmpty
          ? const _EmptyState(message: 'No aging tickets')
          : Column(
              children: agingTickets
                  .map((ticket) => _AgingTicketItem(ticket: ticket))
                  .toList(),
            ),
    );
  }

  Widget _buildLatestRequestsCard() {
    final latestRequests = _getLatestRequests(limit: 6);

    return _SectionCard(
      title: 'Recent Requests',
      icon: Icons.assignment_rounded,
      action: TextButton(
        onPressed: widget.onViewAllWorkRequests ?? () {},
        style: TextButton.styleFrom(
          foregroundColor: _accentCyan,
          minimumSize: const Size(44, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(
          'View All',
          style: AdminStyles.headingStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      contentPadding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: AdminStyles.bg,
              border: Border(
                bottom: BorderSide(color: AdminStyles.border),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    'TICKET',
                    style: AdminStyles.headingStyle(
                      color: AdminStyles.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'SUBJECT',
                    style: AdminStyles.headingStyle(
                      color: AdminStyles.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: Text(
                    'STATUS',
                    textAlign: TextAlign.center,
                    style: AdminStyles.headingStyle(
                      color: AdminStyles.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (latestRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: _EmptyState(message: 'No requests yet'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: latestRequests.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: _border),
              itemBuilder: (context, index) => _RequestTableRow(
                request: latestRequests[index],
              ),
            ),
        ],
      ),
    );
  }
}

class _KpiCardData {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  const _KpiCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiCardData data;

  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AdminStyles.cardDecoration(borderRadius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            data.value.toString(),
            style: AdminStyles.headingStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AdminStyles.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.title.toUpperCase(),
            style: AdminStyles.bodyStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AdminStyles.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;
  final Widget child;
  final EdgeInsets contentPadding;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.icon,
    this.action,
    required this.child,
    this.contentPadding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AdminStyles.cardDecoration(borderRadius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AdminStyles.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: AdminStyles.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AdminStyles.headingStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: AdminStyles.bodyStyle(
                            fontSize: 12,
                            color: _textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                ?action,
              ],
            ),
          ),
          Padding(
            padding: contentPadding,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  final String label;
  final String value;
  final double progress;
  final Color color;

  const _MiniProgress({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AdminStyles.bodyStyle(
                color: _textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: AdminStyles.headingStyle(
                color: _textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            backgroundColor: color.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.inbox_rounded,
          size: 40,
          color: Color(0xFF334155),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: AdminStyles.bodyStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textMuted,
          ),
        ),
      ],
    );
  }
}

class _RequestTableRow extends StatefulWidget {
  final WorkRequest request;

  const _RequestTableRow({required this.request});

  @override
  State<_RequestTableRow> createState() => _RequestTableRowState();
}

class _RequestTableRowState extends State<_RequestTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _isHovered ? AdminStyles.bg : Colors.white,
          border: Border(
            bottom: BorderSide(color: AdminStyles.border),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 130,
              child: Text(
                '#${widget.request.id.substring(0, 8).toUpperCase()}',
                style: AdminStyles.dataStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AdminStyles.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.request.title,
                    style: AdminStyles.bodyStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AdminStyles.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.request.officeRoom} • ${widget.request.buildingName}',
                    style: AdminStyles.bodyStyle(
                      fontSize: 11,
                      color: AdminStyles.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 130,
              child: Center(
                child: _StatusBadge(status: widget.request.status),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'pending':
      case 'pending assignment':
        color = _textMuted;
        label = 'Pending';
        break;
      case 'in progress':
      case 'in_progress':
      case 'assigned':
      case 'accepted by maintenance':
        color = _accentCyan;
        label = 'In Progress';
        break;
      case 'declined':
      case 'cancelled':
      case 'declined/cancelled':
        color = _accentRed;
        label = 'Declined';
        break;
      case 'confirmed':
      case 'pre-inspection approved':
      case 'under_maintenance':
        color = AdminStyles.primary;
        label = 'Confirmed';
        break;
      case 'rework':
      case 'for rework':
        color = _accentAmber;
        label = 'Rework';
        break;
      case 'completed':
        color = _accentGreen;
        label = 'Completed';
        break;
      default:
        color = _textMuted;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label.toUpperCase(),
        style: AdminStyles.headingStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _AgingTicketItem extends StatefulWidget {
  final WorkRequest ticket;

  const _AgingTicketItem({required this.ticket});

  @override
  State<_AgingTicketItem> createState() => _AgingTicketItemState();
}

class _AgingTicketItemState extends State<_AgingTicketItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final days = DateTime.now().difference(widget.ticket.dateSubmitted).inDays;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _isHovered ? AdminStyles.bg.withValues(alpha: 0.5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? AdminStyles.error.withValues(alpha: 0.4)
                : AdminStyles.border,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: AdminStyles.error.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.ticket.title,
                    style: AdminStyles.bodyStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AdminStyles.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.ticket.buildingName} • $days days ago',
                    style: AdminStyles.bodyStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AdminStyles.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}


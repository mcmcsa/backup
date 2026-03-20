import 'package:flutter/material.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';

class DashboardPageWeb extends StatefulWidget {
  const DashboardPageWeb({super.key});

  @override
  State<DashboardPageWeb> createState() => _DashboardPageWebState();
}

class _DashboardPageWebState extends State<DashboardPageWeb> {
  List<WorkRequest> _allRequests = [];
  bool _isLoading = true;

  // Clean color palette matching the design
  static const Color _primaryBlue = Color(0xFF3B82F6);
  static const Color _successGreen = Color(0xFF22C55E);
  static const Color _warningYellow = Color(0xFFFBBF24);
  static const Color _dangerRed = Color(0xFFEF4444);
  static const Color _darkText = Color(0xFF1E293B);
  static const Color _subtleText = Color(0xFF64748B);
  static const Color _cardBg = Colors.white;
  static const Color _pageBg = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final data = await WorkRequestService.fetchAll();
      if (mounted) {
        setState(() {
          _allRequests = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  List<WorkRequest> _getLatestRequests({int limit = 6}) {
    return _allRequests.take(limit).toList();
  }

  List<WorkRequest> _getAgingTickets() {
    final now = DateTime.now();
    return _allRequests
        .where((r) =>
            r.status.toLowerCase() != 'completed' &&
            now.difference(r.dateSubmitted).inDays > 3)
        .take(4)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _getCountByStatus('pending');
    final inProgressCount = _getCountByStatus('in_progress');
    final highPriorityCount = _getCountByPriority('high');
    final completedCount = _getCountByStatus('completed');

    return Container(
      color: _pageBg,
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primaryBlue),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stat Cards Row - 4 cards
                  _buildStatCardsRow(
                    pendingCount,
                    inProgressCount,
                    highPriorityCount,
                    completedCount,
                  ),
                  const SizedBox(height: 24),

                  // Main Content - Two columns
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column - Quick Insights + Aging Tickets
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            // Quick Insights Card
                            _buildQuickInsightsCard(),
                            const SizedBox(height: 20),
                            // Aging Tickets Card
                            _buildAgingTicketsCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Column - Latest Requests Table
                      Expanded(
                        flex: 6,
                        child: _buildLatestRequestsCard(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCardsRow(
    int pendingCount,
    int inProgressCount,
    int highPriorityCount,
    int completedCount,
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Pending Approvals',
            value: pendingCount,
            icon: Icons.hourglass_empty_rounded,
            iconColor: _warningYellow,
            trend: '+2%',
            trendUp: true,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _StatCard(
            title: 'Ongoing Repairs',
            value: inProgressCount,
            icon: Icons.build_rounded,
            iconColor: _primaryBlue,
            trend: '-5%',
            trendUp: false,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _StatCard(
            title: 'High Priority',
            value: highPriorityCount,
            icon: Icons.priority_high_rounded,
            iconColor: _dangerRed,
            trend: '+10%',
            trendUp: true,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _StatCard(
            title: 'Completed',
            value: completedCount,
            icon: Icons.check_circle_rounded,
            iconColor: _successGreen,
            trend: '+15%',
            trendUp: true,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickInsightsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: _primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Quick Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Avg Resolution Time
          _InsightMetric(
            label: 'Avg. Resolution Time',
            value: '4.2h',
            progress: 0.42,
            progressColor: _primaryBlue,
          ),
          const SizedBox(height: 20),

          // Equipment Health
          _InsightMetric(
            label: 'Equipment Health',
            value: '92%',
            progress: 0.92,
            progressColor: _successGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildAgingTicketsCard() {
    final agingTickets = _getAgingTickets();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _warningYellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Aging Tickets',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _darkText,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _dangerRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${agingTickets.length} pending',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _dangerRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Ticket list
          if (agingTickets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 48,
                      color: _successGreen.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'All caught up!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _subtleText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'No aging tickets',
                      style: TextStyle(
                        fontSize: 13,
                        color: _subtleText,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: agingTickets
                  .map((ticket) => _AgingTicketItem(ticket: ticket))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildLatestRequestsCard() {
    final latestRequests = _getLatestRequests(limit: 6);

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_rounded,
                    color: _primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Latest Requests',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _darkText,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: _primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    'TICKET #',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _subtleText,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'SUBJECT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _subtleText,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'STATUS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _subtleText,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Table Rows
          if (latestRequests.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 48,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No requests yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _subtleText,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: latestRequests.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Colors.grey.withValues(alpha: 0.1),
              ),
              itemBuilder: (context, index) {
                final request = latestRequests[index];
                return _RequestTableRow(request: request);
              },
            ),
        ],
      ),
    );
  }
}

// ==================== WIDGETS ====================

/// Stat Card matching the screenshot design
class _StatCard extends StatefulWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color iconColor;
  final String trend;
  final bool trendUp;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.trend,
    required this.trendUp,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(22),
        transform: Matrix4.identity()..translate(0.0, _isHovered ? -4.0 : 0.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? widget.iconColor.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: _isHovered ? 20 : 12,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                widget.icon,
                color: widget.iconColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 18),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Large number
                  Text(
                    widget.value.toString(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Title
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            // Trend badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: widget.trendUp
                    ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                    : const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.trendUp
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 14,
                    color: widget.trendUp
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.trend,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.trendUp
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Insight metric with progress bar
class _InsightMetric extends StatelessWidget {
  final String label;
  final String value;
  final double progress;
  final Color progressColor;

  const _InsightMetric({
    required this.label,
    required this.value,
    required this.progress,
    required this.progressColor,
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
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: progressColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Progress bar
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: progressColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: progressColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Aging ticket item with colored left border
class _AgingTicketItem extends StatefulWidget {
  final WorkRequest ticket;

  const _AgingTicketItem({required this.ticket});

  @override
  State<_AgingTicketItem> createState() => _AgingTicketItemState();
}

class _AgingTicketItemState extends State<_AgingTicketItem> {
  bool _isHovered = false;

  int get _daysAging {
    return DateTime.now().difference(widget.ticket.dateSubmitted).inDays;
  }

  Color get _borderColor {
    if (_daysAging > 14) return const Color(0xFFEF4444); // Red for > 14 days
    if (_daysAging > 7) return const Color(0xFFF97316); // Orange for > 7 days
    return const Color(0xFFFBBF24); // Yellow for others
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: _borderColor,
              width: 4,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ticket ID
                  Text(
                    '#${widget.ticket.id.length > 8 ? widget.ticket.id.substring(0, 8) : widget.ticket.id}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Location
                  Text(
                    '${widget.ticket.officeRoom}, ${widget.ticket.buildingName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Days aging
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _borderColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$_daysAging days',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _borderColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.ticket.requestorName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Request table row
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
        child: Row(
          children: [
            // Ticket ID
            SizedBox(
              width: 100,
              child: Text(
                '#${widget.request.id.length > 6 ? widget.request.id.substring(0, 6) : widget.request.id}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3B82F6),
                  fontFamily: 'monospace',
                ),
              ),
            ),
            // Subject
            Expanded(
              child: Text(
                widget.request.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Status Badge
            SizedBox(
              width: 100,
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

/// Status badge widget matching the screenshot
class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: config.textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  _StatusConfig _getStatusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return _StatusConfig(
          label: 'REVIEW',
          bgColor: const Color(0xFFFEF3C7),
          textColor: const Color(0xFFD97706),
        );
      case 'approved':
      case 'in_progress':
      case 'under_maintenance':
        return _StatusConfig(
          label: 'ACTIVE',
          bgColor: const Color(0xFFDBEAFE),
          textColor: const Color(0xFF2563EB),
        );
      case 'completed':
        return _StatusConfig(
          label: 'DONE',
          bgColor: const Color(0xFFDCFCE7),
          textColor: const Color(0xFF16A34A),
        );
      case 'rework':
        return _StatusConfig(
          label: 'REWORK',
          bgColor: const Color(0xFFFEE2E2),
          textColor: const Color(0xFFDC2626),
        );
      default:
        return _StatusConfig(
          label: status.toUpperCase(),
          bgColor: const Color(0xFFF1F5F9),
          textColor: const Color(0xFF64748B),
        );
    }
  }
}

class _StatusConfig {
  final String label;
  final Color bgColor;
  final Color textColor;

  _StatusConfig({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });
}

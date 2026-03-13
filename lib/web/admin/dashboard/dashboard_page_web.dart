import 'package:flutter/material.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/modern_dashboard_widgets.dart';

class DashboardPageWeb extends StatefulWidget {
  const DashboardPageWeb({super.key});

  @override
  State<DashboardPageWeb> createState() => _DashboardPageWebState();
}

class _DashboardPageWebState extends State<DashboardPageWeb> {
  List<WorkRequest> _allRequests = [];
  String _searchQuery = '';

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
        });
      }
    } catch (_) {
      // Handle error silently
    }
  }

  int _getCountByStatus(String status) {
    return _allRequests.where((r) => r.status.toLowerCase() == status.toLowerCase()).length;
  }

  int _getCountByPriority(String priority) {
    return _allRequests.where((r) => r.priority.toLowerCase() == priority.toLowerCase()).length;
  }

  List<WorkRequest> _getLatestRequests({int limit = 5}) {
    final filtered = _searchQuery.isEmpty
        ? _allRequests
        : _allRequests
            .where((r) => r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                r.description.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();
    return filtered.take(limit).toList();
  }

  List<WorkRequest> _getAgingTickets() {
    final now = DateTime.now();
    return _allRequests
        .where((r) =>
            r.status.toLowerCase() != 'completed' &&
            r.dateSubmitted.difference(now).inDays > 7)
        .take(10)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _getCountByStatus('pending');
    final inProgressCount = _getCountByStatus('in_progress');
    final highPriorityCount = _getCountByPriority('high');
    final completedCount = _getCountByStatus('completed');

    return Material(
      color: const Color(0xFFF5F7FA),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Search and Filter Bar
            _buildSearchBar(),
            const SizedBox(height: 32),

            // Stat Cards
            _buildStatCards(pendingCount, inProgressCount, highPriorityCount, completedCount),
            const SizedBox(height: 32),

            // Quick Insights Section
            _buildQuickInsights(),
            const SizedBox(height: 32),

            // Aging Tickets Section
            _buildAgingTickets(),
            const SizedBox(height: 32),

            // Latest Requests Section
            _buildLatestRequests(),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search requests...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF3B82F6)),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards(
    int pendingCount,
    int inProgressCount,
    int highPriorityCount,
    int completedCount,
  ) {
    return GridView.count(
      crossAxisCount: 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        MetricCard(
          title: 'Pending Approvals',
          value: '$pendingCount',
          icon: Icons.hourglass_empty_rounded,
          backgroundColor: const Color(0xFFFEF3C7),
          accentColor: const Color(0xFFD97706),
          showTrendUp: true,
          trendLabel: '+2%',
        ),
        MetricCard(
          title: 'Ongoing Repairs',
          value: '$inProgressCount',
          icon: Icons.build_rounded,
          backgroundColor: const Color(0xFFDEF7EC),
          accentColor: const Color(0xFF10B981),
          showTrendUp: false,
          trendLabel: '-8%',
        ),
        MetricCard(
          title: 'High Priority',
          value: '$highPriorityCount',
          icon: Icons.priority_high_rounded,
          backgroundColor: const Color(0xFFFECDD3),
          accentColor: const Color(0xFFDC2626),
          showTrendUp: true,
          trendLabel: '+10%',
        ),
        MetricCard(
          title: 'Completed',
          value: '$completedCount',
          icon: Icons.check_circle_rounded,
          backgroundColor: const Color(0xFFDEF7EC),
          accentColor: const Color(0xFF10B981),
          showTrendUp: true,
          trendLabel: '+15%',
        ),
      ],
    );
  }

  Widget _buildQuickInsights() {
    final avgResolutionTime = '4.2h';
    final equipmentHealth = '92%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'QUICK INSIGHTS',
          subtitle: 'Key metrics and performance indicators',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildInsightCard(
                title: 'Avg. Resolution Time',
                value: avgResolutionTime,
                icon: Icons.schedule_rounded,
                backgroundColor: const Color(0xFFEFF6FF),
                accentColor: const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInsightCard(
                title: 'Equipment Health',
                value: equipmentHealth,
                icon: Icons.favorite_rounded,
                backgroundColor: const Color(0xFFDEF7EC),
                accentColor: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String value,
    required IconData icon,
    required Color backgroundColor,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgingTickets() {
    final agingTickets = _getAgingTickets();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'AGING TICKETS',
          subtitle: 'Requests pending for more than 7 days',
        ),
        const SizedBox(height: 16),
        if (agingTickets.isEmpty)
          const EmptyStateWidget(
            icon: Icons.inbox_rounded,
            title: 'No Aging Tickets',
            description: 'All pending requests are being processed efficiently',
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.1),
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: agingTickets.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: Colors.grey.withValues(alpha: 0.1),
              ),
              itemBuilder: (context, index) {
                final ticket = agingTickets[index];
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Room: ${ticket.officeRoom} • ${ticket.buildingName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      PriorityIndicator(priority: ticket.priority),
                      const SizedBox(width: 16),
                      StatusBadge(
                        label: ticket.status.replaceAll('_', ' ').toUpperCase(),
                        backgroundColor: _getStatusColor(ticket.status),
                        foregroundColor: _getStatusTextColor(ticket.status),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildLatestRequests() {
    final latestRequests = _getLatestRequests(limit: 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'LATEST REQUESTS',
          subtitle: 'Most recent work requests',
        ),
        const SizedBox(height: 16),
        if (latestRequests.isEmpty)
          const EmptyStateWidget(
            icon: Icons.note_rounded,
            title: 'No Requests Found',
            description: 'No work requests match your search criteria',
          )
        else
          _buildRequestsTable(latestRequests),
      ],
    );
  }

  Widget _buildRequestsTable(List<WorkRequest> requests) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Subject',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Priority',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requests.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: Colors.grey.withValues(alpha: 0.1),
            ),
            itemBuilder: (context, index) {
              final request = requests[index];
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            request.requestorName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: StatusBadge(
                        label: request.status.replaceAll('_', ' ').toUpperCase(),
                        backgroundColor: _getStatusColor(request.status),
                        foregroundColor: _getStatusTextColor(request.status),
                      ),
                    ),
                    Expanded(
                      child: PriorityIndicator(priority: request.priority),
                    ),
                    Expanded(
                      child: Text(
                        '${request.officeRoom}, ${request.buildingName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFEF3C7);
      case 'approved':
        return const Color(0xFFDEF7EC);
      case 'in_progress':
      case 'under_maintenance':
        return const Color(0xFFEFF6FF);
      case 'completed':
        return const Color(0xFFDEF7EC);
      case 'rework':
        return const Color(0xFFFECDD3);
      case 'cancelled':
        return const Color(0xFFF3F4F6);
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFD97706);
      case 'approved':
        return const Color(0xFF10B981);
      case 'in_progress':
      case 'under_maintenance':
        return const Color(0xFF3B82F6);
      case 'completed':
        return const Color(0xFF10B981);
      case 'rework':
        return const Color(0xFFDC2626);
      case 'cancelled':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF64748B);
    }
  }
}

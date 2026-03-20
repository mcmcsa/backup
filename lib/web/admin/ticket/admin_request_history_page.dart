import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/workflow_status_badge.dart';

/// Admin screen showing full request history with stats filters
class AdminRequestHistoryPage extends StatefulWidget {
  final VoidCallback? openDrawer;

  const AdminRequestHistoryPage({super.key, this.openDrawer});

  @override
  State<AdminRequestHistoryPage> createState() => _AdminRequestHistoryPageState();
}

class _AdminRequestHistoryPageState extends State<AdminRequestHistoryPage> {
  List<WorkRequest> _allRequests = [];
  List<WorkRequest> _filteredRequests = [];
  bool _isLoading = true;
  String _selectedPeriod = 'Last 30 Days';
  String _selectedStatusFilter = 'all';

  final List<String> _periods = ['Last 30 Days', 'Quarterly', 'Yearly'];
  final List<String> _statusFilters = ['all', 'pending', 'approved', 'in_progress', 'under_maintenance', 'completed', 'rework'];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      _allRequests = await WorkRequestService.fetchAll();
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading requests: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _applyFilters() {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'Quarterly':
        startDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case 'Yearly':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default: // Last 30 Days
        startDate = now.subtract(const Duration(days: 30));
    }

    _filteredRequests = _allRequests.where((r) {
      final inRange = r.dateSubmitted.isAfter(startDate);
      final matchesStatus = _selectedStatusFilter == 'all' || r.status == _selectedStatusFilter;
      return inRange && matchesStatus;
    }).toList();

    _filteredRequests.sort((a, b) => b.dateSubmitted.compareTo(a.dateSubmitted));
  }

  // Stats for the selected period
  Map<String, int> get _stats {
    final counts = <String, int>{};
    for (final status in _statusFilters.where((s) => s != 'all')) {
      counts[status] = _filteredRequests.where((r) => r.status == status).length;
    }
    counts['total'] = _filteredRequests.length;
    return counts;
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
        title: const Text('Request History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4169E1)))
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Period selector
                  _buildPeriodSelector(),
                  const SizedBox(height: 16),

                  // Stats overview
                  _buildStatsGrid(),
                  const SizedBox(height: 16),

                  // Status filter chips
                  _buildStatusFilterChips(),
                  const SizedBox(height: 16),

                  // Results count
                  Text(
                    '${_filteredRequests.length} requests found',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 12),

                  // Request list
                  ..._filteredRequests.map((r) => _buildRequestCard(r)),

                  if (_filteredRequests.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      child: const Column(
                        children: [
                          Icon(Icons.history, size: 48, color: Color(0xFF9CA3AF)),
                          SizedBox(height: 16),
                          Text('No requests found for this period',
                              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: _periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPeriod = period;
                  _applyFilters();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF4169E1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    period,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = _stats;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _buildStatCard('Total', stats['total'] ?? 0, const Color(0xFF4169E1), Icons.assignment),
        _buildStatCard('Completed', stats['completed'] ?? 0, const Color(0xFF059669), Icons.check_circle),
        _buildStatCard('In Progress', stats['in_progress'] ?? 0, const Color(0xFF1D4ED8), Icons.build),
        _buildStatCard('Pending', stats['pending'] ?? 0, const Color(0xFFD97706), Icons.hourglass_empty),
        _buildStatCard('Under Maint.', stats['under_maintenance'] ?? 0, const Color(0xFFEA580C), Icons.engineering),
        _buildStatCard('Rework', stats['rework'] ?? 0, const Color(0xFFDC2626), Icons.refresh),
      ],
    );
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusFilters.map((status) {
          final isSelected = _selectedStatusFilter == status;
          final label = status == 'all'
              ? 'All'
              : status == 'in_progress'
                  ? 'In Progress'
                  : status == 'under_maintenance'
                      ? 'Under Maint.'
                      : status[0].toUpperCase() + status.substring(1);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87)),
              selectedColor: const Color(0xFF4169E1),
              backgroundColor: Colors.white,
              side: BorderSide(color: isSelected ? const Color(0xFF4169E1) : const Color(0xFFE5E7EB)),
              onSelected: (selected) {
                setState(() {
                  _selectedStatusFilter = status;
                  _applyFilters();
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRequestCard(WorkRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(request.id,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4169E1))),
              WorkflowStatusBadge(status: request.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(request.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          const SizedBox(height: 4),
          Text('${request.buildingName} • ${request.officeRoom}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Submitted: ${DateFormat('MMM dd, yyyy').format(request.dateSubmitted)}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
              if (request.dateCompleted != null)
                Text('Done: ${DateFormat('MMM dd, yyyy').format(request.dateCompleted!)}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF059669))),
            ],
          ),
          if (request.maintenanceStartTime != null || request.maintenanceEndTime != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time, size: 12, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                if (request.maintenanceStartTime != null)
                  Text('Start: ${DateFormat('MMM dd HH:mm').format(request.maintenanceStartTime!)}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                if (request.maintenanceEndTime != null) ...[
                  const Text(' → ', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                  Text('End: ${DateFormat('MMM dd HH:mm').format(request.maintenanceEndTime!)}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF059669))),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

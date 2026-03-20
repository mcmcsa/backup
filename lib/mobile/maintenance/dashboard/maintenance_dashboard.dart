import 'package:flutter/material.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../admin/shared/notifications_page.dart';
import '../task/task_details_page.dart';
import '../maintenance_navigation.dart';

class MaintenanceDashboardMobile extends StatefulWidget {
  const MaintenanceDashboardMobile({super.key});

  @override
  State<MaintenanceDashboardMobile> createState() =>
      _MaintenanceDashboardMobileState();
}

class _MaintenanceDashboardMobileState
    extends State<MaintenanceDashboardMobile> {
  List<WorkRequest> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final data = await WorkRequestService.fetchAll();
      final maintenanceQueue = data
          .where(
            (r) =>
                r.status == 'pending' ||
                r.status == 'approved' ||
                r.status == 'in_progress' ||
                r.status == 'under_maintenance' ||
                r.status == 'completed' ||
                r.status == 'done',
          )
          .toList();
      if (mounted) {
        setState(() {
          _requests = maintenanceQueue;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final assigned = _requests.where((r) => r.status == 'pending').length;
    final inspection = _requests
        .where(
          (r) =>
              r.status == 'ongoing' &&
              r.typeOfRequest.toLowerCase().contains('inspection'),
        )
        .length;
    final repair = _requests
        .where(
          (r) =>
              r.status == 'ongoing' &&
              !r.typeOfRequest.toLowerCase().contains('inspection'),
        )
        .length;
    final completed = _requests.where((r) => r.status == 'done').length;
    final activeRequests = _requests
        .where((r) => r.status == 'pending' || r.status == 'ongoing')
        .toList();
    final highPriority = _requests
        .where((r) => r.priority == 'high' && r.status != 'done')
        .toList();

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(
        roleText: 'Welcome Maintenance Staff',
        primaryColor: Color(0xFF4169E1),
        onNotificationPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotificationsPage()),
          );
          if (mounted) {
            setState(() {});
          }
        },
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Overview Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE UPDATES',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stats Grid
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'ASSIGNED',
                    '$assigned',
                    Icons.add_box_outlined,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'INSPECTION',
                    '$inspection',
                    Icons.remove_red_eye_outlined,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'REPAIR',
                    '$repair',
                    Icons.build_outlined,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'COMPLETED',
                    '$completed',
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Ticket Aging Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    const Text(
                      'Ticket Aging (FIFO)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PRIORITY REQUIRED',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Priority Tickets
            if (highPriority.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No priority tickets',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ),
              )
            else
              Row(
                children: [
                  ...highPriority
                      .take(2)
                      .map(
                        (r) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _buildPriorityTicket(
                              r.id.length > 5
                                  ? '#${r.id.substring(r.id.length - 4)}'
                                  : '#${r.id}',
                              r.title,
                              '${r.buildingName}, ${r.officeRoom}',
                              r.status == 'pending' ? 'Pending' : 'In Progress',
                              r.priority == 'high'
                                  ? 'HIGH ATTENTION'
                                  : 'JUST ASSIGNED',
                              r.priority == 'high' ? Colors.red : Colors.orange,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            const SizedBox(height: 24),

            // My Active Tasks Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Active Tasks',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const MaintenanceNavigation(initialIndex: 1),
                      ),
                    );
                  },
                  child: const Text(
                    'View All',
                    style: TextStyle(fontSize: 12, color: Color(0xFF4169E1)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Task Cards
            if (activeRequests.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No active tasks',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ),
              )
            else
              ...activeRequests.take(5).map((r) {
                final priorityLabel = r.priority == 'high'
                    ? 'HIGH PRIORITY'
                    : r.priority == 'medium'
                    ? 'MEDIUM'
                    : 'LOW PRIORITY';
                final priorityColor = r.priority == 'high'
                    ? Colors.red
                    : r.priority == 'medium'
                    ? Colors.orange
                    : Colors.blue.shade700;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TaskDetailsPage(
                            taskId: r.id,
                            title: r.title,
                            location: '${r.buildingName}, ${r.officeRoom}',
                          ),
                        ),
                      );
                    },
                    child: _buildTaskCard(
                      r.id,
                      r.title,
                      '${r.buildingName}, ${r.officeRoom}',
                      r.status == 'pending' ? 'Assigned' : 'In Progress',
                      priorityLabel,
                      priorityColor,
                    ),
                  ),
                );
              }),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityTicket(
    String id,
    String title,
    String location,
    String status,
    String badge,
    Color badgeColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: badgeColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            id,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            location,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
    String id,
    String title,
    String location,
    String status,
    String priority,
    Color priorityColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                id,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  priority,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: priorityColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: status == 'In Progress' ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF4169E1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: const Color(0xFF4169E1),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

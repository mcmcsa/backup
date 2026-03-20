import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../shared/notifications_page.dart';
import '../main_navigation.dart';

class DashboardPageMobile extends StatefulWidget {
  final VoidCallback openDrawer;

  const DashboardPageMobile({super.key, required this.openDrawer});

  @override
  State<DashboardPageMobile> createState() => _DashboardPageMobileState();
}

class _DashboardPageMobileState extends State<DashboardPageMobile> {
  List<WorkRequest> _requests = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  String _ticketCode(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return '#N/A';
    final end = trimmed.length < 4 ? trimmed.length : 4;
    return '#${trimmed.substring(0, end).toUpperCase()}';
  }

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      if (user == null) return;

      final count = await AppNotificationService.getUnreadCount(
        role: user.role.name,
        userId: user.id,
      );
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {}
  }

  Future<void> _loadRequests() async {
    try {
      final data = await WorkRequestService.fetchAll();
      if (mounted) setState(() { _requests = data; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: widget.openDrawer,
            child: const Icon(Icons.menu, color: Colors.black87, size: 28),
          ),
        ),
        title: Row(
          children: [
            SizedBox(
              height: 35,
              width: 35,
              child: Image.asset(
                'assets/images/PsuLogo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, _) => const Icon(
                  Icons.school,
                  color: Color(0xFF4169E1),
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PSU',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1,
                  ),
                ),
                Text(
                  'CAMPUS ADMINISTRATOR',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.black54,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.black87,
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsPage(),
                      ),
                    );
                    _loadUnreadCount();
                  },
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: 6,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search tickets, assets or staff...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF4169E1)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 20),

            // Stats Cards Grid
            Builder(
              builder: (context) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final pendingCount = _requests
                    .where((r) => r.status == 'pending')
                    .length;
                final ongoingCount = _requests
                    .where((r) => r.status == 'ongoing')
                    .length;
                final highPriorityCount = _requests
                    .where((r) => r.priority == 'high')
                    .length;
                final completedCount = _requests
                    .where((r) => r.status == 'done')
                    .length;

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                  children: [
                    _buildStatCard(
                      'Pending Approvals',
                      '$pendingCount',
                      Icons.pending_outlined,
                      Colors.orange,
                      Colors.orange.shade50,
                    ),
                    _buildStatCard(
                      'Ongoing Repairs',
                      '$ongoingCount',
                      Icons.build_outlined,
                      const Color(0xFF4169E1),
                      const Color(0xFFEEF2FF),
                    ),
                    _buildStatCard(
                      'High Priority',
                      '$highPriorityCount',
                      Icons.priority_high,
                      Colors.red,
                      Colors.red.shade50,
                    ),
                    _buildStatCard(
                      'Completed',
                      '$completedCount',
                      Icons.check_circle_outline,
                      Colors.green,
                      Colors.green.shade50,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Quick Insights Section
            Row(
              children: [
                Icon(Icons.insights, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  'QUICK INSIGHTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildInsightCard(
              'Avg. Resolution Time',
              _requests.where((r) => r.status == 'done' && r.dateCompleted != null).isEmpty
                  ? 'N/A'
                  : '${(_requests.where((r) => r.status == 'done' && r.dateCompleted != null).map((r) => r.dateCompleted!.difference(r.dateSubmitted).inHours).fold<int>(0, (a, b) => a + b) / _requests.where((r) => r.status == 'done' && r.dateCompleted != null).length).toStringAsFixed(1)}h',
              _requests.where((r) => r.status == 'done' && r.dateCompleted != null).isEmpty ? 0.0 : 0.5,
              Colors.blue,
              Icons.access_time,
            ),
            const SizedBox(height: 12),
            _buildInsightCard(
              'Resolution Rate',
              _requests.isEmpty
                  ? '0%'
                  : '${(_requests.where((r) => r.status == 'done').length * 100 / _requests.length).round()}%',
              _requests.isEmpty ? 0.0 : _requests.where((r) => r.status == 'done').length / _requests.length,
              Colors.green,
              Icons.shield_outlined,
            ),
            const SizedBox(height: 24),

            // Aging Tickets Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'AGING TICKETS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                TextButton(onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MainNavigation(initialIndex: 2),
                    ),
                  );
                }, child: const Text('View All')),
              ],
            ),
            const SizedBox(height: 8),

            _buildAgingTicketsSection(),
            const SizedBox(height: 24),

            // Latest Requests Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bookmark_outline,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LATEST REQUESTS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Latest Requests Table
            _buildLatestRequestsTable(),

            const SizedBox(height: 80), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          // Make the value/title area flexible so it can shrink/wrap
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(
    String title,
    String value,
    double progress,
    Color color,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgingTicket(String title, String subtitle, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(8),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestRow(
    String ticket,
    String subject,
    String status,
    Color statusColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              ticket,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              subject,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgingTicketsSection() {
    final agingRequests = _requests
        .where((r) => r.status == 'pending' || r.status == 'ongoing')
        .toList()
      ..sort((a, b) => a.dateSubmitted.compareTo(b.dateSubmitted));
    final top = agingRequests.take(3).toList();

    if (top.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('No aging tickets', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
      );
    }

    return Column(
      children: top.map((r) {
        final daysOpen = DateTime.now().difference(r.dateSubmitted).inDays;
        final color = daysOpen > 14 ? Colors.red : (daysOpen > 7 ? Colors.orange : Colors.blue);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildAgingTicket(
            '${_ticketCode(r.id)} - ${r.officeRoom}',
            '$daysOpen days open • ${r.requestorName}',
            color,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLatestRequestsTable() {
    final latest = List<WorkRequest>.from(_requests)
      ..sort((a, b) => b.dateSubmitted.compareTo(a.dateSubmitted));
    final top = latest.take(5).toList();

    if (top.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('No requests yet', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('TICKET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('SUBJECT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600), textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          ...top.map((r) {
            final statusColor = r.status == 'done'
                ? Colors.green
                : (r.status == 'ongoing' ? Colors.blue : Colors.orange);
            final statusLabel = r.status.toUpperCase();
            return _buildRequestRow(_ticketCode(r.id), r.title, statusLabel, statusColor);
          }),
        ],
      ),
    );
  }
}

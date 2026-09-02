import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../router/app_router.dart';
import 'package:intl/intl.dart';
import '../../admin/shared/notifications_page.dart';

class StudentTeacherDashboard extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const StudentTeacherDashboard({super.key, this.scaffoldKey});

  @override
  State<StudentTeacherDashboard> createState() => _StudentTeacherDashboardState();
}

class _StudentTeacherDashboardState extends State<StudentTeacherDashboard> {
  final TextEditingController _searchController = TextEditingController();
  List<WorkRequest> _requests = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadRequests();
    _setupRealtime();
  }

  void _setupRealtime() {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user == null || user.id.isEmpty) return;

    _realtimeChannel = WorkRequestService.listenToRequestorRequests(user.id, (data) {
      if (mounted) {
        setState(() {
          _requests = data;
        });
      }
    });
  }

  List<WorkRequest> get _filteredRequests {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _requests;
    return _requests.where((r) {
      return r.id.toLowerCase().contains(query) ||
             (r.officeRoom?.toLowerCase().contains(query) ?? false) ||
             r.title.toLowerCase().contains(query) ||
             (r.buildingName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> _loadRequests() async {
    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      List<WorkRequest> data;
      if (user != null && user.id.isNotEmpty) {
        data = await WorkRequestService.fetchByRequestor(user.id);
      } else {
        data = [];
      }
      if (mounted) setState(() { _requests = data; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: CommonAppBar(
        roleText: 'Teacher',
        primaryColor: themeProvider.primaryColor,
        onMenuPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
        onNotificationPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationsPage(),
            ),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              style: TextStyle(color: themeProvider.textColor),
              decoration: InputDecoration(
                hintText: 'Search my requests...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                  borderSide: BorderSide(color: Color(0xFF4169E1), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // My Request Summary
            Row(
              children: [
                Icon(Icons.insert_chart_outlined, size: 20, color: themeProvider.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'My Request Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
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
                    'TOTAL REPORTS',
                    '${_requests.length}',
                    const Color(0xFF00BFA5),
                    themeProvider,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'IN PROGRESS',
                    '${_requests.where((r) => r.status.toLowerCase() != 'completed' && r.status.toLowerCase() != 'declined' && r.status.toLowerCase() != 'cancelled' && r.status.toLowerCase() != 'declined/cancelled').length}',
                    Colors.orange,
                    themeProvider,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'RESOLVED',
                    '${_requests.where((r) => r.status.toLowerCase() == 'completed').length}',
                    Colors.green,
                    themeProvider,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'DECLINED',
                    '${_requests.where((r) => r.status.toLowerCase() == 'cancelled' || r.status.toLowerCase() == 'declined' || r.status.toLowerCase() == 'declined/cancelled' || r.status.toLowerCase() == 'pre-inspection declined').length}',
                    Colors.red,
                    themeProvider,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Report New Issue Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push('/work-request-form');
                },
                icon: const Icon(Icons.add_box_outlined, size: 22),
                label: const Text(
                  'Report New Issue',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Recent Reports
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.refresh, size: 20, color: themeProvider.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Reports',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    context.go(teacherReportsRoute);
                  },
                  child: Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Recent Reports List
            ..._filteredRequests.take(5).map((r) {
              Color statusColor;
              String statusLabel;
              switch (r.status.toLowerCase()) {
                case 'completed':
                  statusColor = Colors.green;
                  statusLabel = 'RESOLVED';
                  break;
                case 'in progress':
                case 'in_progress':
                case 'assigned':
                case 'accepted by maintenance':
                  statusColor = Colors.orange;
                  statusLabel = 'IN PROGRESS';
                  break;
                case 'declined':
                case 'cancelled':
                case 'declined/cancelled':
                case 'pre-inspection declined':
                  statusColor = Colors.red;
                  statusLabel = 'DECLINED';
                  break;
                case 'confirmed':
                case 'pre-inspection approved':
                case 'under_maintenance':
                  statusColor = Colors.blue;
                  statusLabel = 'CONFIRMED';
                  break;
                case 'rework':
                case 'for rework':
                  statusColor = Colors.deepOrange;
                  statusLabel = 'REWORK';
                  break;
                default:
                  statusColor = Colors.grey;
                  statusLabel = r.status.toUpperCase();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildReportCard(
                  icon: Icons.build_outlined,
                  iconColor: themeProvider.primaryColor,
                  iconBgColor: themeProvider.primaryColor.withValues(alpha: 0.1),
                  title: r.title,
                  location: '${r.officeRoom}, ${r.buildingName}',
                  date: DateFormat('MMM dd, yyyy • hh:mm a').format(r.dateSubmitted).toUpperCase(),
                  status: statusLabel,
                  statusColor: statusColor,
                  themeProvider: themeProvider,
                  onTap: () {
                    context.push(
                      '/request-details',
                      extra: {
                        'trackingNumber': r.id,
                        'status': statusLabel,
                      },
                    );
                  },
                ),
              );
            }),
            if (_filteredRequests.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: themeProvider.subtitleColor),
                      const SizedBox(height: 12),
                      Text(
                        _requests.isEmpty ? 'No reports yet' : 'No reports matching search',
                        style: TextStyle(color: themeProvider.subtitleColor),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 100), // Space for bottom navigation
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeProvider.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: themeProvider.subtitleColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 3,
            width: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String location,
    required String date,
    required String status,
    required Color statusColor,
    required ThemeProvider themeProvider,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: themeProvider.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: themeProvider.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location,
                    style: TextStyle(
                      fontSize: 12,
                      color: themeProvider.subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 11,
                      color: themeProvider.subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


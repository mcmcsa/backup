import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'task_details_page.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../shared/services/work_request_service.dart';
import 'package:psu_maintsystem/authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../admin/shared/notifications_page.dart';

class MaintenanceReportsPage extends StatefulWidget {
  const MaintenanceReportsPage({super.key});

  @override
  State<MaintenanceReportsPage> createState() => _MaintenanceReportsPageState();
}

class _MaintenanceReportsPageState extends State<MaintenanceReportsPage>
    with WidgetsBindingObserver {
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Pending',
    'In Progress',
    'Under Maintenance',
    'High Priority',
  ];

  bool _isHistorical(String status) {
    final s = status.toLowerCase();
    return s == 'completed' ||
        s == 'declined' ||
        s == 'cancelled' ||
        s == 'declined/cancelled' ||
        s == 'pre-inspection declined';
  }

  List<WorkRequest> _requests = [];
  bool _isLoading = true;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRequests();
    _startAutoRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRequests();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _loadRequests();
    });
  }

  Future<void> _loadRequests() async {
    try {
      final user = context.read<AuthService>().currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final data = await WorkRequestService.fetchAssignedTo(user.id);
      final maintenanceQueue = data
          .where((r) => r.status != 'Declined/Cancelled')
          .toList();

      if (mounted) {
        setState(() {
          _requests = maintenanceQueue;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<WorkRequest> get _filteredRequests {
    final active = _requests.where((r) => !_isHistorical(r.status)).toList();
    if (_selectedCategory == 'All') return active;
    if (_selectedCategory == 'Pending') {
      return active.where((r) => r.status == 'Assigned').toList();
    }
    if (_selectedCategory == 'In Progress') {
      return active
          .where((r) =>
            r.status == 'Accepted by Maintenance' ||
            r.status == 'Pre-Inspection Submitted' ||
            r.status == 'Pre-Inspection Approved' ||
            r.status == 'In Progress (Post-Repair)' ||
            r.status == 'Post-Repair Submitted' ||
            r.status == 'Under Evaluation' ||
            r.status == 'For Rework'
          )
          .toList();
    }
    if (_selectedCategory == 'Under Maintenance') {
      return active.where((r) => r.status == 'In Progress (Post-Repair)').toList();
    }
    if (_selectedCategory == 'High Priority') {
      return active.where((r) => r.priority.toLowerCase() == 'high').toList();
    }
    return active;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: CommonAppBar(
        roleText: 'Welcome Maintenance Staff',
        primaryColor: const Color(0xFF4169E1),
        showMenu: true,
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
      body: Column(
        children: [
          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Title
                Text(
                  'Maintenance Reports',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
                const SizedBox(height: 16),

                // Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: themeProvider.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: themeProvider.borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: themeProvider.subtitleColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Search tracking ID or location',
                          style: TextStyle(
                            fontSize: 13,
                            color: themeProvider.subtitleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Filter Chips
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          backgroundColor: themeProvider.cardColor,
                          selectedColor: const Color(0xFF4169E1),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : themeProvider.textColor,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF4169E1)
                                : themeProvider.borderColor,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Reports List
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_filteredRequests.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No reports found',
                            style: TextStyle(
                              fontSize: 14,
                              color: themeProvider.subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._filteredRequests.map((r) {
                    final statusLabel = r.statusLabel;
                    final statusColor = r.status == 'Completed'
                        ? Colors.green
                        : (r.status == 'Declined/Cancelled' || r.status == 'Pre-Inspection Declined')
                        ? Colors.red
                        : r.status == 'Assigned'
                        ? Colors.orange
                        : r.status == 'Pre-Inspection Submitted'
                        ? const Color(0xFF9C27B0)
                        : r.status == 'Pre-Inspection Approved'
                        ? const Color(0xFF00BFA5)
                        : r.status == 'Post-Repair Submitted'
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF2196F3);

                    IconData catIcon;
                    Color catColor;
                    switch (r.typeOfRequest.toLowerCase()) {
                      case 'electrical':
                        catIcon = Icons.electrical_services;
                        catColor = Colors.blue;
                        break;
                      case 'plumbing':
                        catIcon = Icons.plumbing;
                        catColor = Colors.orange;
                        break;
                      default:
                        catIcon = Icons.handyman;
                        catColor = const Color(0xFF00BFA5);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildReportCard(
                        id: r.id,
                        status: statusLabel,
                        statusColor: statusColor,
                        category: r.typeOfRequest,
                        categoryIcon: catIcon,
                        categoryColor: catColor,
                        location: '${r.buildingName}, ${r.officeRoom}',
                        assignedTo: r.requestorName,
                        themeProvider: themeProvider,
                      ),
                    );
                  }),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required String id,
    required String status,
    required Color statusColor,
    required String category,
    required IconData categoryIcon,
    required Color categoryColor,
    required String location,
    required String assignedTo,
    required ThemeProvider themeProvider,
  }) {
    final isDark = themeProvider.isDarkMode;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailsPage(
              taskId: id,
              title: category,
              location: location,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: themeProvider.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: themeProvider.borderColor),
          boxShadow: [
            BoxShadow(
              color: themeProvider.shadowColor,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: status == 'NEW'
                          ? statusColor
                          : status == 'PENDING'
                          ? Colors.orange
                          : status == 'ASSIGNED'
                          ? const Color(0xFF00BFA5)
                          : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${status.toUpperCase()} REQUEST',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.subtitleColor,
                        letterSpacing: 0.5,
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
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Request ID
            Text(
              id,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: themeProvider.textColor,
              ),
            ),
            const SizedBox(height: 12),

            // Category
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(categoryIcon, color: categoryColor, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Location
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: themeProvider.subtitleColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(fontSize: 11, color: themeProvider.subtitleColor),
                  ),
                ),
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: themeProvider.subtitleColor,
                ),
                const SizedBox(width: 4),
                Text(
                  assignedTo,
                  style: TextStyle(fontSize: 11, color: themeProvider.subtitleColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'task_details_page.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../shared/services/work_request_service.dart';
import 'package:psu_maintsystem/authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../admin/shared/notifications_page.dart';

class MaintenanceReportsPage extends StatefulWidget {
  final VoidCallback? openDrawer;

  const MaintenanceReportsPage({super.key, this.openDrawer});

  @override
  State<MaintenanceReportsPage> createState() => _MaintenanceReportsPageState();
}

class _MaintenanceReportsPageState extends State<MaintenanceReportsPage>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _statusFilters = [
    'All',
    'In Progress',
    'Confirmed',
    'Rework',
  ];
  final List<String> _priorityFilters = [
    'All',
    'Low',
    'Medium',
    'High',
  ];

  String _selectedStatusFilter = 'All';
  String _selectedPriorityFilter = 'All';

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
  RealtimeChannel? _realtimeChannel;
  StreamSubscription<void>? _changeSub;

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _changeSub?.cancel();
    try {
      _realtimeChannel?.unsubscribe();
    } catch (_) {}
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRequests();
    _setupRealtime();
    _startAutoRefresh();
  }

  void _setupRealtime() {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    try {
      _realtimeChannel =
          WorkRequestService.listenToMaintenanceRequests(user.id, (data) {
        if (mounted) {
          final maintenanceQueue = data
              .where((r) =>
                  r.status != 'Declined/Cancelled' &&
                  r.status.toLowerCase() != 'pending' &&
                  r.status.toLowerCase() != 'pending assignment')
              .toList();
          setState(() {
            _requests = maintenanceQueue;
            _isLoading = false;
          });
        }
      });
    } catch (_) {}

    _changeSub = WorkRequestService.onWorkRequestsChanged.listen((_) {
      _loadRequests();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRequests();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
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
          .where((r) =>
              r.status != 'Declined/Cancelled' &&
              r.status.toLowerCase() != 'pending' &&
              r.status.toLowerCase() != 'pending assignment')
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
    List<WorkRequest> list = _requests
        .where((r) =>
            !_isHistorical(r.status) &&
            r.status.toLowerCase() != 'pending' &&
            r.status.toLowerCase() != 'pending assignment')
        .toList();

    // Status filter (parity with web)
    if (_selectedStatusFilter == 'In Progress') {
      list = list.where((r) {
        final s = r.status.toLowerCase();
        return s == 'in progress' ||
            s == 'in_progress' ||
            s == 'assigned' ||
            s == 'accepted by maintenance' ||
            s == 'pre-inspection submitted' ||
            s == 'in progress (post-repair)' ||
            s == 'post-repair submitted' ||
            s == 'under evaluation';
      }).toList();
    } else if (_selectedStatusFilter == 'Confirmed') {
      list = list.where((r) {
        final s = r.status.toLowerCase();
        return s == 'confirmed' ||
            s == 'pre-inspection approved' ||
            s == 'under_maintenance';
      }).toList();
    } else if (_selectedStatusFilter == 'Rework') {
      list = list.where((r) {
        final s = r.status.toLowerCase();
        return s == 'rework' ||
            s == 'rework needed' ||
            s == 'for rework';
      }).toList();
    }

    // Priority filter (parity with web)
    if (_selectedPriorityFilter != 'All') {
      list = list.where((r) => r.priority.toLowerCase() == _selectedPriorityFilter.toLowerCase()).toList();
    }

    // Search query filter (tracking number, title, room/location, or description)
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) =>
        r.id.toLowerCase().contains(q) ||
        (r.roomName?.toLowerCase().contains(q) ?? false) ||
        (r.buildingName?.toLowerCase().contains(q) ?? false) ||
        (r.officeRoom?.toLowerCase().contains(q) ?? false) ||
        r.title.toLowerCase().contains(q) ||
        r.description.toLowerCase().contains(q)
      ).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: CommonAppBar(
        roleText: '',
        primaryColor: const Color(0xFF4169E1),
        showMenu: true,
        onMenuPressed: widget.openDrawer,
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
                // Header (Web Parity)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Work Reports',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: themeProvider.textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'All assigned work requests across campus.',
                          style: TextStyle(
                            fontSize: 12,
                            color: themeProvider.subtitleColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.assignment_rounded, size: 14, color: Color(0xFF0EA5E9)),
                          const SizedBox(width: 5),
                          Text(
                            '${_filteredRequests.length} records',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0EA5E9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar (Interactive with clear button)
                Container(
                  decoration: BoxDecoration(
                    color: themeProvider.cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: themeProvider.borderColor),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 14, color: themeProvider.textColor),
                    decoration: InputDecoration(
                      hintText: 'Search by tracking ID, title, room...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: themeProvider.subtitleColor,
                      ),
                      prefixIcon: Icon(Icons.search, color: themeProvider.subtitleColor, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              color: themeProvider.subtitleColor,
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Status Filter Chips (Full width, horizontal scroll)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusFilters.map((status) {
                      final isSelected = _selectedStatusFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedStatusFilter = status);
                            }
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
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Priority Filter Bar (On its own dedicated row)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.filter_list_rounded, size: 16, color: themeProvider.subtitleColor),
                        const SizedBox(width: 6),
                        Text(
                          'Priority Level:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.subtitleColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: themeProvider.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: themeProvider.borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPriorityFilter,
                          icon: Icon(Icons.arrow_drop_down, color: themeProvider.subtitleColor, size: 18),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.textColor,
                          ),
                          dropdownColor: themeProvider.cardColor,
                          items: _priorityFilters.map((p) {
                            return DropdownMenuItem<String>(
                              value: p,
                              child: Text(p == 'All' ? 'All Priorities' : '$p Priority'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedPriorityFilter = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
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
              id.length > 8 ? '#${id.substring(0, 8).toUpperCase()}' : '#${id.toUpperCase()}',
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

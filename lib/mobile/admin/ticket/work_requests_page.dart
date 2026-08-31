import 'dart:async';

import 'package:flutter/material.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/maintenance_account_service.dart';
import '../../../shared/services/work_request_service.dart';
import 'request_details_page.dart';
import 'admin_pre_inspection_review_page.dart';
import 'admin_post_repair_evaluation_page.dart';
import 'admin_request_history_page.dart';
import 'admin_work_process_page.dart';
import '../shared/notifications_page.dart';

class WorkRequestsPage extends StatefulWidget {
  final VoidCallback openDrawer;

  const WorkRequestsPage({super.key, required this.openDrawer});

  @override
  State<WorkRequestsPage> createState() => _WorkRequestsPageState();
}

class _WorkRequestsPageState extends State<WorkRequestsPage>
    with WidgetsBindingObserver {
  int _selectedFilter = 0;
  final TextEditingController _searchController = TextEditingController();
  final List<String> _filters = [
    'All',
    'Pending',
    'In Progress',
    'Declined',
    'Confirmed',
    'Rework',
    'Completed',
    'Duplicates',
  ];
  List<WorkRequest> _requests = [];
  Map<String, String> _maintenanceNamesById = {};
  Map<String, String> _maintenanceSpecializationsById = {};
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
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadRequests();
    });
  }

  Future<void> _loadRequests() async {
    try {
      final results = await Future.wait([
        WorkRequestService.fetchAll(),
        MaintenanceAccountService.fetchCreatedByCurrentAdmin(),
      ]);

      final data = results[0] as List<WorkRequest>;
      final maintenanceAccounts = results[1] as List<MaintenanceAccount>;
      final nameMap = {
        for (final account in maintenanceAccounts)
          account.userId: account.fullName,
      };
      final specializationMap = {
        for (final account in maintenanceAccounts)
          account.userId: (account.specialization ?? '').trim(),
      };

      if (mounted) {
        setState(() {
          _requests = data;
          _maintenanceNamesById = nameMap;
          _maintenanceSpecializationsById = specializationMap;
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

  String _assignedMaintenanceName(WorkRequest request) {
    final assignedToId = request.assignedToId?.trim();
    if (assignedToId == null || assignedToId.isEmpty) return 'Unassigned';

    final name = _maintenanceNamesById[assignedToId];
    if (name != null && name.trim().isNotEmpty) {
      final specialization =
          (_maintenanceSpecializationsById[assignedToId] ?? '').trim();
      if (specialization.isNotEmpty) {
        return '$name ($specialization)';
      }
      return name;
    }

    return 'Unassigned';
  }

  Future<void> _openLatestRequestDetails(WorkRequest request) async {
    try {
      final latest = await WorkRequestService.fetchById(request.id);
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RequestDetailsPage(request: latest ?? request),
        ),
      );
    } finally {
      if (mounted) {
        await _loadRequests();
      }
    }
  }

  List<WorkRequest> get _filteredRequests {
    final query = _searchController.text.toLowerCase();
    var requests = _requests;

    // Apply status filter
    if (_selectedFilter == 1) {
      requests = requests.where((r) => r.status.toLowerCase() == 'pending' || r.status.toLowerCase() == 'pending assignment').toList();
    } else if (_selectedFilter == 2) {
      requests = requests.where((r) => r.status.toLowerCase() == 'in progress' || r.status.toLowerCase() == 'in_progress' || r.status.toLowerCase() == 'assigned' || r.status.toLowerCase() == 'accepted by maintenance').toList();
    } else if (_selectedFilter == 3) {
      requests = requests.where((r) => r.status.toLowerCase() == 'declined' || r.status.toLowerCase() == 'cancelled' || r.status.toLowerCase() == 'declined/cancelled').toList();
    } else if (_selectedFilter == 4) {
      requests = requests.where((r) => r.status.toLowerCase() == 'confirmed' || r.status.toLowerCase() == 'pre-inspection approved' || r.status.toLowerCase() == 'under_maintenance').toList();
    } else if (_selectedFilter == 5) {
      requests = requests.where((r) => r.status.toLowerCase() == 'rework' || r.status.toLowerCase() == 'for rework').toList();
    } else if (_selectedFilter == 6) {
      requests = requests.where((r) => r.status.toLowerCase() == 'completed').toList();
    } else if (_selectedFilter == 7) {
      requests = requests.where((r) => r.duplicateOfId != null).toList();
    }

    // Apply search
    if (query.isNotEmpty) {
      requests = requests
          .where(
            (r) =>
                r.title.toLowerCase().contains(query) ||
                r.id.contains(query) ||
                (r.department ?? '').toLowerCase().contains(query),
          )
          .toList();
    }

    return requests;
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F4F6),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final totalCompleted = _requests
        .where((r) => r.status == 'Completed')
        .length;
    final readyCount = _requests.where((r) => r.status.toLowerCase() == 'pending' || r.status.toLowerCase() == 'pending assignment').length;
    final ongoingRequests = _requests
        .where((r) =>
          r.status.toLowerCase() != 'completed' &&
          r.status.toLowerCase() != 'declined' &&
          r.status.toLowerCase() != 'cancelled' &&
          r.status.toLowerCase() != 'declined/cancelled'
        )
        .toList();
    final ongoingRequest = ongoingRequests.isNotEmpty
        ? ongoingRequests.firstWhere(
            (r) => (r.officeRoom ?? '').contains('CLR'),
            orElse: () => ongoingRequests.first,
          )
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
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
                errorBuilder: (_, __, _) =>
                    const Icon(Icons.school, color: Colors.white, size: 18),
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
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsPage(),
                      ),
                    );
                  },
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar & Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search requests, rooms, or IDs...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(
                        Icons.search_rounded,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
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
                      borderSide: BorderSide(color: Color(0xFF4169E1)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_filters.length, (index) {
                      final isSelected = _selectedFilter == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedFilter = index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF4169E1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF4169E1)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              _filters[index],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // Request List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (ongoingRequest != null) ...[
                  _buildInProgressCard(ongoingRequest),
                  const SizedBox(height: 12),
                ],

                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackStats = constraints.maxWidth < 320;

                    if (stackStats) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStatCard(
                            'Total Completed',
                            '$totalCompleted',
                            '',
                            Colors.black87,
                          ),
                          const SizedBox(height: 12),
                          _buildStatCard(
                            'Pending',
                            '$readyCount',
                            '',
                            Colors.orange,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Completed',
                            '$totalCompleted',
                            '',
                            Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Pending',
                            '$readyCount',
                            '',
                            Colors.orange,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                ..._filteredRequests.map((request) => _buildRequestCard(request)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInProgressCard(WorkRequest? request) {
    if (request == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4169E1), Color(0xFF5B7FE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4169E1).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              const Text(
                'REQUEST BY',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'IN PROGRESS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            request.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.room, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                request.officeRoom ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackActions = constraints.maxWidth < 350;

              if (stackActions) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STARTED',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${request.dateSubmitted.hour > 12 ? request.dateSubmitted.hour - 12 : request.dateSubmitted.hour}:${request.dateSubmitted.minute.toString().padLeft(2, '0')} ${request.dateSubmitted.hour >= 12 ? 'PM' : 'AM'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AdminWorkProcessPage(request: request),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF4169E1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'View Progress',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'STARTED',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${request.dateSubmitted.hour > 12 ? request.dateSubmitted.hour - 12 : request.dateSubmitted.hour}:${request.dateSubmitted.minute.toString().padLeft(2, '0')} ${request.dateSubmitted.hour >= 12 ? 'PM' : 'AM'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AdminWorkProcessPage(request: request),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4169E1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'View Progress',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String percentage,
    Color valueColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                    height: 1,
                  ),
                ),
                if (percentage.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      percentage,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(WorkRequest request) {
    Color urgencyColor;
    Color urgencyBgColor;
    String urgencyLabel;

    switch (request.priority) {
      case 'high':
        urgencyColor = Colors.red;
        urgencyBgColor = const Color(0xFFFEE2E2);
        urgencyLabel = 'HIGH URGENCY';
        break;
      case 'medium':
        urgencyColor = Colors.orange;
        urgencyBgColor = const Color(0xFFFFF7ED);
        urgencyLabel = 'PENDING';
        break;
      case 'low':
        urgencyColor = const Color(0xFF4169E1);
        urgencyBgColor = const Color(0xFFEEF2FF);
        urgencyLabel = 'LOW URGENCY';
        break;
      default:
        urgencyColor = Colors.grey;
        urgencyBgColor = Colors.grey.shade100;
        urgencyLabel = 'NORMAL';
    }

    Color statusColor;
    String statusLabel = request.status.toUpperCase();

    switch (request.status.toLowerCase()) {
      case 'pending':
      case 'pending assignment':
        statusColor = Colors.grey;
        statusLabel = 'PENDING';
        break;
      case 'in progress':
      case 'in_progress':
      case 'assigned':
      case 'accepted by maintenance':
        statusColor = const Color(0xFF2196F3);
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
        statusColor = const Color(0xFF00BFA5);
        statusLabel = 'CONFIRMED';
        break;
      case 'rework':
      case 'for rework':
        statusColor = const Color(0xFFFF9800);
        statusLabel = 'REWORK';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusLabel = 'COMPLETED';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = request.status.toUpperCase();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: urgencyColor.withValues(alpha: 0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with urgency badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: urgencyBgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Request ID
                Text(
                  request.id,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),

                // Title
                Text(
                  request.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),

                // Details Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackDetails = constraints.maxWidth < 320;

                    if (stackDetails) {
                      return Column(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DEPARTMENT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                request.department ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ROOM',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                request.officeRoom ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DEPARTMENT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            request.department ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ROOM',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            request.officeRoom ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REQUESTED ON',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${request.dateSubmitted.month < 10 ? 'Oct' : 'Nov'} ${request.dateSubmitted.day}, ${request.dateSubmitted.year}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Assigned to
                Text(
                  'Assigned to: ${_assignedMaintenanceName(request)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),

                // Action Buttons
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wrapActions = constraints.maxWidth < 340;

                    if (wrapActions) {
                      return Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AdminPreInspectionReviewPage(
                                          request: request,
                                        ),
                                  ),
                                ).then((_) => _loadRequests());
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: const Text(
                                'Pre-Inspect',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AdminPostRepairEvaluationPage(
                                          request: request,
                                        ),
                                  ),
                                ).then((_) => _loadRequests());
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: const Text(
                                'Post-Repair',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _openLatestRequestDetails(request),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4169E1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'View Details',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AdminPreInspectionReviewPage(
                                        request: request,
                                      ),
                                ),
                              ).then((_) => _loadRequests());
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text(
                              'Pre-Inspect',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AdminPostRepairEvaluationPage(
                                        request: request,
                                      ),
                                ),
                              ).then((_) => _loadRequests());
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text(
                              'Post-Repair',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _openLatestRequestDetails(request),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4169E1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'View Details',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // View History button for low urgency
                if (request.priority == 'low') ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminRequestHistoryPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history, size: 14),
                      label: const Text(
                        'View History',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

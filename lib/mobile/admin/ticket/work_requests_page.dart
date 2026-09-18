import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/maintenance_account_service.dart';
import '../../../shared/services/work_request_service.dart';
import 'request_details_page.dart';
import 'admin_pre_inspection_review_page.dart';
import 'admin_post_repair_evaluation_page.dart';
import 'admin_room_verification_page.dart';
import '../shared/admin_app_bar.dart';

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
    'Confirmed',
    'Rework',
    'Duplicates',
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
    var requests = _requests.where((r) => !_isHistorical(r.status)).toList();

    final filter = _selectedFilter < _filters.length ? _filters[_selectedFilter] : 'All';

    // Apply status filter
    if (filter == 'Pending') {
      requests = requests.where((r) => r.status.toLowerCase() == 'pending' || r.status.toLowerCase() == 'pending assignment').toList();
    } else if (filter == 'In Progress') {
      requests = requests.where((r) => r.status.toLowerCase() == 'in progress' || r.status.toLowerCase() == 'in_progress' || r.status.toLowerCase() == 'assigned' || r.status.toLowerCase() == 'accepted by maintenance').toList();
    } else if (filter == 'Confirmed') {
      requests = requests.where((r) => r.status.toLowerCase() == 'confirmed' || r.status.toLowerCase() == 'pre-inspection approved' || r.status.toLowerCase() == 'under_maintenance').toList();
    } else if (filter == 'Rework') {
      requests = requests.where((r) => r.status.toLowerCase() == 'rework' || r.status.toLowerCase() == 'for rework').toList();
    } else if (filter == 'Duplicates') {
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
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AdminAppBar(
        openDrawer: widget.openDrawer,
      ),
      floatingActionButton: Container(
        height: 52,
        width: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4169E1), Color(0xFF6366F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4169E1).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminRoomVerificationPage(),
              ),
            ).then((_) => _loadRequests());
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
        ),
      ),
      body: Column(
        children: [
          // Search Bar & Filters
          Container(
            color: themeProvider.cardColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search requests, rooms, or IDs...',
                    hintStyle: TextStyle(
                      color: themeProvider.subtitleColor,
                      fontSize: 14,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(
                        Icons.search_rounded,
                        color: themeProvider.subtitleColor,
                        size: 20,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    filled: true,
                    fillColor: themeProvider.inputFillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: themeProvider.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: themeProvider.borderColor),
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
                                  : themeProvider.cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF4169E1)
                                    : themeProvider.borderColor,
                              ),
                            ),
                            child: Text(
                              _filters[index],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : themeProvider.textColor,
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
                ..._filteredRequests.map((request) => _buildRequestCard(request, themeProvider)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(WorkRequest request, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;

    Color urgencyColor;
    Color urgencyBgColor;
    switch (request.priority.toLowerCase()) {
      case 'high':
        urgencyColor = const Color(0xFFEF4444);
        urgencyBgColor = isDark ? const Color(0xFF451A1A) : const Color(0xFFFEE2E2);
        break;
      case 'medium':
        urgencyColor = const Color(0xFFF59E0B);
        urgencyBgColor = isDark ? const Color(0xFF452E10) : const Color(0xFFFFF7ED);
        break;
      case 'low':
        urgencyColor = const Color(0xFF3B82F6);
        urgencyBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
        break;
      default:
        urgencyColor = Colors.grey;
        urgencyBgColor = isDark ? const Color(0xFF262626) : Colors.grey.shade100;
    }

    Color statusColor;
    Color statusBgColor;
    String statusLabel = request.status.toUpperCase();

    switch (request.status.toLowerCase()) {
      case 'pending':
      case 'pending assignment':
        statusColor = const Color(0xFFF97316);
        statusBgColor = isDark ? const Color(0xFF431D08) : const Color(0xFFFFF7ED);
        statusLabel = 'PENDING';
        break;
      case 'in progress':
      case 'in_progress':
      case 'assigned':
      case 'accepted by maintenance':
        statusColor = const Color(0xFF3B82F6);
        statusBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
        statusLabel = 'IN PROGRESS';
        break;
      case 'declined':
      case 'cancelled':
      case 'declined/cancelled':
      case 'pre-inspection declined':
        statusColor = const Color(0xFFEF4444);
        statusBgColor = isDark ? const Color(0xFF451A1A) : const Color(0xFFFEE2E2);
        statusLabel = 'DECLINED';
        break;
      case 'confirmed':
      case 'pre-inspection approved':
      case 'under_maintenance':
        statusColor = const Color(0xFF14B8A6);
        statusBgColor = isDark ? const Color(0xFF113835) : const Color(0xFFF0FDFA);
        statusLabel = 'CONFIRMED';
        break;
      case 'rework':
      case 'for rework':
        statusColor = const Color(0xFFF59E0B);
        statusBgColor = isDark ? const Color(0xFF452E10) : const Color(0xFFFFFBEB);
        statusLabel = 'REWORK';
        break;
      case 'completed':
        statusColor = const Color(0xFF22C55E);
        statusBgColor = isDark ? const Color(0xFF14381C) : const Color(0xFFF0FDF4);
        statusLabel = 'COMPLETED';
        break;
      default:
        statusColor = const Color(0xFF64748B);
        statusBgColor = isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9);
        statusLabel = request.status.toUpperCase();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeProvider.borderColor),
        boxShadow: [
          BoxShadow(
            color: themeProvider.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Ticket ID + Date (Web-Style)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4169E1).withValues(alpha: isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${request.id.length > 8 ? request.id.substring(0, 8).toUpperCase() : request.id.toUpperCase()}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4169E1),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                DateFormat('MMM d, yyyy').format(request.dateSubmitted),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: themeProvider.subtitleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            request.title,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: themeProvider.textColor,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // Requestor Row (Web-Style)
          if (request.requestorName.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 14, color: themeProvider.subtitleColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    request.requestorName,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: themeProvider.subtitleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
          ],

          // Room & Department Row (Web-Style)
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: themeProvider.subtitleColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${request.officeRoom ?? 'N/A'}${request.department != null && request.department!.isNotEmpty ? ' • ${request.department}' : ''}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: themeProvider.subtitleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Assigned Technician Row (Web-Style)
          Row(
            children: [
              Icon(Icons.engineering_outlined, size: 14, color: themeProvider.subtitleColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Assigned to: ${_assignedMaintenanceName(request)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: themeProvider.subtitleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Badges Row: Status + Priority
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (request.priority.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: urgencyBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    request.priority.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: urgencyColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // 1-LINE HORIZONTAL ACTION BUTTONS (Pre-Inspect, Post-Repair, View Details)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminPreInspectionReviewPage(request: request),
                        ),
                      ).then((_) => _loadRequests());
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFCBD5E1),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFFF8FAFC),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Pre-Inspect',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminPostRepairEvaluationPage(request: request),
                        ),
                      ).then((_) => _loadRequests());
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFCBD5E1),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFFF8FAFC),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Post-Repair',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => _openLatestRequestDetails(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4169E1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

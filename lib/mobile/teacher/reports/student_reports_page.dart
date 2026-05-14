import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../authentication/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentReportsPage extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const StudentReportsPage({super.key, this.scaffoldKey});

  @override
  State<StudentReportsPage> createState() => _StudentReportsPageState();
}

class _StudentReportsPageState extends State<StudentReportsPage>
    with WidgetsBindingObserver {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  List<WorkRequest> _requests = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;
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

  void _setupRealtimeListener(String requestorId) {
    if (_realtimeChannel != null) return;
    _realtimeChannel = WorkRequestService.listenToRequestorRequests(
      requestorId,
      (updatedRequests) {
        if (mounted) {
          setState(() {
            _requests = updatedRequests;
          });
        }
      },
    );
  }

  Future<void> _loadRequests() async {
    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      List<WorkRequest> data;
      if (user != null && user.id.isNotEmpty) {
        data = await WorkRequestService.fetchByRequestor(user.id);
        _setupRealtimeListener(user.id);
      } else {
        data = [];
      }
      if (mounted)
        setState(() {
          _requests = data;
          _isLoading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  List<WorkRequest> get _filteredRequests {
    List<WorkRequest> filtered = _requests;
    if (_selectedFilter == 'Pending') {
      filtered = filtered.where((r) => r.status == 'pending').toList();
    } else if (_selectedFilter == 'In Progress') {
      filtered = filtered
          .where(
            (r) => r.status == 'in_progress' || r.status == 'under_maintenance',
          )
          .toList();
    } else if (_selectedFilter == 'Complete') {
      filtered = filtered.where((r) => r.status == 'completed').toList();
    }
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered
          .where(
            (r) =>
                r.id.toLowerCase().contains(query) ||
                (r.officeRoom?.toLowerCase().contains(query) ?? false) ||
                r.title.toLowerCase().contains(query),
          )
          .toList();
    }
    return filtered;
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    if (_realtimeChannel != null) {
      Supabase.instance.client.realtime.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Scaffold(
          backgroundColor: themeProvider.backgroundColor,
          appBar: CommonAppBar(
            roleText: 'Teacher',
            primaryColor: themeProvider.primaryColor,
            onMenuPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search tracking number or room...',
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
                      borderSide: BorderSide(
                        color: Color(0xFF4169E1),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              // My Reports Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 20,
                      color: themeProvider.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'My Reports',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Filter Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip('All', themeProvider),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending', themeProvider),
                    const SizedBox(width: 8),
                    _buildFilterChip('In Progress', themeProvider),
                    const SizedBox(width: 8),
                    _buildFilterChip('Complete', themeProvider),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Reports List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredRequests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No reports found',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredRequests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final r = _filteredRequests[index];
                          final statusLabel = r.status == 'completed'
                              ? 'COMPLETED'
                              : r.status == 'under_maintenance'
                              ? 'UNDER MAINTENANCE'
                              : r.status == 'in_progress'
                              ? 'IN PROGRESS'
                              : r.status == 'cancelled'
                              ? 'CANCELLED'
                              : 'PENDING';
                          final statusColor = r.status == 'completed'
                              ? const Color(0xFF4CAF50)
                              : r.status == 'under_maintenance'
                              ? const Color(0xFF9C27B0)
                              : r.status == 'in_progress'
                              ? const Color(0xFF2196F3)
                              : r.status == 'cancelled'
                              ? Colors.red
                              : const Color(0xFFFF9800);
                          return _buildReportCard(
                            trackingNumber: r.id,
                            title: '${r.officeRoom} - ${r.buildingName}',
                            category: r.typeOfRequest,
                            date: DateFormat(
                              'MMM dd, yyyy',
                            ).format(r.dateSubmitted),
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
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, ThemeProvider themeProvider) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? themeProvider.primaryColor
              : themeProvider.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? themeProvider.primaryColor
                : themeProvider.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : themeProvider.textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required String trackingNumber,
    required String title,
    required String category,
    required String date,
    required String status,
    required Color statusColor,
    required ThemeProvider themeProvider,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: themeProvider.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                themeProvider.isDarkMode ? 0.3 : 0.05,
              ),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tracking Number and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    trackingNumber,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.subtitleColor,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: themeProvider.textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            // Category and Date
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildMetaItem(
                  icon: Icons.build_circle_outlined,
                  text: category,
                  themeProvider: themeProvider,
                ),
                _buildMetaItem(
                  icon: Icons.calendar_today,
                  text: date,
                  themeProvider: themeProvider,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem({
    required IconData icon,
    required String text,
    required ThemeProvider themeProvider,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: themeProvider.subtitleColor),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: themeProvider.subtitleColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

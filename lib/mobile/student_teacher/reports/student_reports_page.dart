import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../authentication/services/auth_service.dart';
import 'package:intl/intl.dart';

class StudentReportsPage extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const StudentReportsPage({super.key, this.scaffoldKey});

  @override
  State<StudentReportsPage> createState() => _StudentReportsPageState();
}

class _StudentReportsPageState extends State<StudentReportsPage> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  List<WorkRequest> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
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

  List<WorkRequest> get _filteredRequests {
    List<WorkRequest> filtered = _requests;
    if (_selectedFilter == 'Pending') {
      filtered = filtered.where((r) => r.status == 'pending').toList();
    } else if (_selectedFilter == 'Ongoing') {
      filtered = filtered.where((r) => r.status == 'ongoing').toList();
    } else if (_selectedFilter == 'Complete') {
      filtered = filtered.where((r) => r.status == 'done').toList();
    }
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((r) =>
        r.id.toLowerCase().contains(query) ||
        r.officeRoom.toLowerCase().contains(query) ||
        r.title.toLowerCase().contains(query)
      ).toList();
    }
    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Scaffold(
          backgroundColor: themeProvider.backgroundColor,
          appBar: CommonAppBar(
            roleText: 'STUDENT/TEACHER',
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
                  decoration: InputDecoration(
                    hintText: 'Search tracking number or room...',
                    hintStyle: TextStyle(
                      color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(Icons.search, color: themeProvider.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400, size: 20),
                    filled: true,
                    fillColor: themeProvider.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: themeProvider.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: themeProvider.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: themeProvider.primaryColor, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              // My Reports Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.assignment_outlined, size: 20, color: themeProvider.primaryColor),
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
                    _buildFilterChip('Ongoing', themeProvider),
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
                            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No reports found', style: TextStyle(color: Colors.grey.shade400)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredRequests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final r = _filteredRequests[index];
                          final statusLabel = r.status == 'done' ? 'COMPLETED'
                              : r.status == 'ongoing' ? 'ONGOING'
                              : r.status == 'cancelled' ? 'CANCELLED'
                              : 'PENDING';
                          final statusColor = r.status == 'done' ? const Color(0xFF4CAF50)
                              : r.status == 'ongoing' ? const Color(0xFF2196F3)
                              : r.status == 'cancelled' ? Colors.red
                              : const Color(0xFFFF9800);
                          return _buildReportCard(
                            trackingNumber: r.id,
                            title: '${r.officeRoom} - ${r.buildingName}',
                            category: r.typeOfRequest,
                            date: DateFormat('MMM dd, yyyy').format(r.dateSubmitted),
                            status: statusLabel,
                            statusColor: statusColor,
                            themeProvider: themeProvider,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/request-details',
                                arguments: {
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
          color: isSelected ? themeProvider.primaryColor : themeProvider.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? themeProvider.primaryColor : themeProvider.borderColor,
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
              color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.3 : 0.05),
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
                Text(
                  trackingNumber,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.subtitleColor,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            ),
            const SizedBox(height: 12),
            // Category and Date
            Row(
              children: [
                Icon(
                  Icons.build_circle_outlined,
                  size: 16,
                  color: themeProvider.subtitleColor,
                ),
                const SizedBox(width: 6),
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 13,
                    color: themeProvider.subtitleColor,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: themeProvider.subtitleColor,
                ),
                const SizedBox(width: 6),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 13,
                    color: themeProvider.subtitleColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
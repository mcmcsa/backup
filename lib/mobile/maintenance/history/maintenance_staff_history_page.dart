import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../task/task_details_page.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/providers/theme_provider.dart';

class MaintenanceStaffHistoryPage extends StatefulWidget {
  const MaintenanceStaffHistoryPage({super.key});

  @override
  State<MaintenanceStaffHistoryPage> createState() => _MaintenanceStaffHistoryPageState();
}

class _MaintenanceStaffHistoryPageState extends State<MaintenanceStaffHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _sortAscending = false; // false = newest first, true = oldest first

  List<WorkRequest> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final user = context.read<AuthService>().currentUser;
      if (user != null) {
        final data = await WorkRequestService.fetchAssignedTo(user.id);
        if (mounted) {
          setState(() {
            _requests = data;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _requestToMap(WorkRequest r) {
    Color statusColor;
    String statusLabel;
    switch (r.status.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        statusLabel = 'COMPLETED';
        break;
      case 'in progress':
      case 'in_progress':
      case 'assigned':
      case 'accepted by maintenance':
        statusColor = Colors.blue;
        statusLabel = 'IN PROGRESS';
        break;
      case 'declined':
      case 'cancelled':
      case 'declined/cancelled':
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
        statusColor = Colors.orange;
        statusLabel = 'REWORK';
        break;
      case 'pending':
      case 'pending assignment':
        statusColor = Colors.grey;
        statusLabel = 'PENDING';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = r.status.toUpperCase();
    }

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
      case 'hvac':
        catIcon = Icons.ac_unit;
        catColor = Colors.cyan;
        break;
      default:
        catIcon = Icons.handyman;
        catColor = const Color(0xFF00BFA5);
    }

    return {
      'id': r.id,
      'title': r.title,
      'location': '${r.buildingName}, ${r.officeRoom}',
      'category': r.typeOfRequest,
      'categoryIcon': catIcon,
      'categoryColor': catColor,
      'status': statusLabel,
      'statusColor': statusColor,
      'date': r.dateSubmitted,
       'completedDate': r.status.toLowerCase() == 'completed' ? r.dateSubmitted : null,
      'priority': r.priority.isNotEmpty
          ? '${r.priority[0].toUpperCase()}${r.priority.substring(1)}'
          : 'Medium',
    };
  }

  List<Map<String, dynamic>> get _filteredItems {
    List<Map<String, dynamic>> filtered = _requests.map(_requestToMap).toList();

    // Filter by status
    if (_selectedFilter != 'All') {
      filtered = filtered.where((item) {
        String status = item['status'].toString().toUpperCase();
        String filter = _selectedFilter.toUpperCase();
        if (filter == 'IN PROGRESS') return status == 'IN PROGRESS';
        return status == filter;
      }).toList();
    }

    // Filter by search query
    String query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((item) {
        return item['id'].toString().toLowerCase().contains(query) ||
            item['title'].toString().toLowerCase().contains(query) ||
            item['location'].toString().toLowerCase().contains(query);
      }).toList();
    }

    // Filter by date range
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((item) {
        DateTime date = item['date'] as DateTime;
        return date.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
            date.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    // Sort by date
    filtered.sort((a, b) {
      DateTime dateA = a['date'] as DateTime;
      DateTime dateB = b['date'] as DateTime;
      if (_sortAscending) {
        return dateA.compareTo(dateB);
      } else {
        return dateB.compareTo(dateA);
      }
    });

    return filtered;
  }

  Future<void> _showDateRangePicker(bool isDark) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF4169E1),
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E1E2E),
                    onSurface: Colors.white,
                  ),
                )
              : Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF4169E1),
                    onPrimary: Colors.white,
                    onSurface: Colors.black87,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _toggleSortOrder() {
    setState(() {
      _sortAscending = !_sortAscending;
    });
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }

  String _formatRangeLabel() {
    if (_startDate == null || _endDate == null) {
      return 'Set Date Range';
    }
    return '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final filteredItems = _filteredItems;

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: const CommonAppBar(
        roleText: 'Welcome Maintenance Staff',
        primaryColor: Color(0xFF4169E1),
        showMenu: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Search Bar
          Container(
            color: themeProvider.cardColor,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {}),
              style: TextStyle(color: themeProvider.textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by ID, title or location...',
                hintStyle: TextStyle(
                  color: themeProvider.subtitleColor,
                  fontSize: 14,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(Icons.search_rounded, color: themeProvider.subtitleColor, size: 20),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade100,
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
          ),

          // Filter Tabs
          Container(
            color: themeProvider.cardColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', themeProvider),
                  const SizedBox(width: 8),
                  _buildFilterChip('Completed', themeProvider),
                  const SizedBox(width: 8),
                  _buildFilterChip('In Progress', themeProvider),
                  const SizedBox(width: 8),
                  _buildFilterChip('Cancelled', themeProvider),
                ],
              ),
            ),
          ),

          // Action Buttons
          Container(
            color: themeProvider.cardColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _startDate == null || _endDate == null
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showDateRangePicker(isDark),
                          icon: Icon(Icons.calendar_today, size: 16, color: themeProvider.textColor),
                          label: Text(
                            _formatRangeLabel(),
                            style: TextStyle(fontSize: 11, color: themeProvider.textColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: themeProvider.textColor,
                            side: BorderSide(color: themeProvider.borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _toggleSortOrder,
                          icon: Icon(
                            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 16,
                            color: themeProvider.textColor,
                          ),
                          label: Text(
                            _sortAscending ? 'Oldest' : 'Newest',
                            style: TextStyle(fontSize: 11, color: themeProvider.textColor),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: themeProvider.textColor,
                            side: BorderSide(color: themeProvider.borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Date Range:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: themeProvider.subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4169E1).withValues(alpha: isDark ? 0.2 : 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF4169E1),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'From',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: themeProvider.subtitleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(_startDate!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: themeProvider.textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: themeProvider.subtitleColor,
                              size: 16,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4169E1).withValues(alpha: isDark ? 0.2 : 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF4169E1),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'To',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: themeProvider.subtitleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(_endDate!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: themeProvider.textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _toggleSortOrder,
                              icon: Icon(
                                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                size: 14,
                                color: themeProvider.textColor,
                              ),
                              label: Text(
                                _sortAscending ? 'Oldest' : 'Newest',
                                style: TextStyle(fontSize: 11, color: themeProvider.textColor),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: themeProvider.textColor,
                                side: BorderSide(color: themeProvider.borderColor),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                              });
                            },
                            child: const Text('Clear', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          // History List
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No history records found',
                          style: TextStyle(
                            fontSize: 16,
                            color: themeProvider.textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters',
                          style: TextStyle(
                            fontSize: 13,
                            color: themeProvider.subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _buildHistoryCard(item, themeProvider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, ThemeProvider themeProvider) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
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
        color: isSelected ? const Color(0xFF4169E1) : themeProvider.borderColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailsPage(
                taskId: item['id'],
                title: item['title'],
                location: item['location'],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Category Badge
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (item['categoryColor'] as Color).withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      item['categoryIcon'] as IconData,
                      size: 20,
                      color: item['categoryColor'] as Color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['id'],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.subtitleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['title'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (item['statusColor'] as Color).withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item['status'],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: item['statusColor'] as Color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Location
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: themeProvider.subtitleColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item['location'],
                      style: TextStyle(
                        fontSize: 12,
                        color: themeProvider.subtitleColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Date Info
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: themeProvider.subtitleColor),
                  const SizedBox(width: 6),
                  Text(
                    'Started: ${_formatDate(item['date'] as DateTime)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: themeProvider.subtitleColor,
                    ),
                  ),
                  if (item['completedDate'] != null) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'Completed: ${_formatDate(item['completedDate'] as DateTime)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: themeProvider.subtitleColor,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Priority Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(item['priority']).withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag,
                          size: 12,
                          color: _getPriorityColor(item['priority']),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item['priority']} Priority',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getPriorityColor(item['priority']),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: themeProvider.subtitleColor,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}


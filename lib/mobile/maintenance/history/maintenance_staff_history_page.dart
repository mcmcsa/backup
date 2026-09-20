import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../task/task_details_page.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/room_comparison_dialog.dart';

class MaintenanceStaffHistoryPage extends StatefulWidget {
  final VoidCallback? openDrawer;

  const MaintenanceStaffHistoryPage({super.key, this.openDrawer});

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
        final completed = data.where((r) {
          final st = r.status.toLowerCase();
          return st == 'completed' ||
              st == 'declined' ||
              st == 'cancelled' ||
              st == 'declined/cancelled';
        }).toList();
        if (mounted) {
          setState(() {
            _requests = completed;
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'declined':
      case 'cancelled':
      case 'declined/cancelled':
        return const Color(0xFFEF4444);
      default:
        return Colors.blue;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'COMPLETED';
      case 'declined':
      case 'cancelled':
      case 'declined/cancelled':
        return 'DECLINED';
      default:
        return status.toUpperCase();
    }
  }

  List<WorkRequest> get _filteredItems {
    List<WorkRequest> filtered = List.from(_requests);

    // Filter by status
    if (_selectedFilter != 'All') {
      String filter = _selectedFilter.toUpperCase();
      filtered = filtered.where((item) {
        String status = item.status.toUpperCase();
        if (filter == 'CANCELLED') {
          return status == 'CANCELLED' || status == 'DECLINED' || status == 'DECLINED/CANCELLED';
        }
        return status == filter;
      }).toList();
    }

    // Filter by search query
    String query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((item) {
        return item.id.toLowerCase().contains(query) ||
            item.title.toLowerCase().contains(query) ||
            item.requestorName.toLowerCase().contains(query) ||
            (item.buildingName ?? '').toLowerCase().contains(query) ||
            (item.officeRoom ?? '').toLowerCase().contains(query);
      }).toList();
    }

    // Filter by date range
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((item) {
        return item.dateSubmitted.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
            item.dateSubmitted.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    // Sort by date
    filtered.sort((a, b) {
      if (_sortAscending) {
        return a.dateSubmitted.compareTo(b.dateSubmitted);
      } else {
        return b.dateSubmitted.compareTo(a.dateSubmitted);
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
      appBar: CommonAppBar(
        roleText: '',
        primaryColor: const Color(0xFF4169E1),
        showMenu: true,
        onMenuPressed: widget.openDrawer,
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
                  _buildFilterChip('Cancelled', themeProvider),
                ],
              ),
            ),
          ),

          // Action Buttons
          Container(
            color: themeProvider.cardColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _startDate == null || _endDate == null
                      ? OutlinedButton.icon(
                          onPressed: () => _showDateRangePicker(isDark),
                          icon: Icon(Icons.calendar_today, size: 15, color: themeProvider.textColor),
                          label: Text(
                            'Set Date Range',
                            style: TextStyle(fontSize: 12, color: themeProvider.textColor, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: themeProvider.textColor,
                            side: BorderSide(color: themeProvider.borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4169E1).withValues(alpha: isDark ? 0.2 : 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF4169E1), width: 1.5),
                          ),
                          child: InkWell(
                            onTap: () => _showDateRangePicker(isDark),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 14, color: Color(0xFF4169E1)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formatRangeLabel(),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4169E1)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _startDate = null;
                                      _endDate = null;
                                    });
                                  },
                                  child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF4169E1)),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _toggleSortOrder,
                  icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 15,
                    color: themeProvider.textColor,
                  ),
                  label: Text(
                    _sortAscending ? 'Oldest' : 'Newest',
                    style: TextStyle(fontSize: 12, color: themeProvider.textColor, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: themeProvider.textColor,
                    side: BorderSide(color: themeProvider.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
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

  Widget _buildHistoryCard(WorkRequest item, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    final statusColor = _getStatusColor(item.status);
    final statusLabel = _getStatusLabel(item.status);
    final shortId = item.id.length > 8 ? item.id.substring(0, 8).toUpperCase() : item.id.toUpperCase();
    final locationText = [item.buildingName, item.officeRoom].where((s) => s != null && s.isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TaskDetailsPage(
                  taskId: item.id,
                  title: item.title,
                  location: locationText,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with ID, Status, and Actions (Campus Admin style)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: themeProvider.borderColor.withValues(alpha: 0.6)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '#$shortId',
                      style: TextStyle(
                        color: themeProvider.subtitleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, size: 20, color: themeProvider.subtitleColor),
                          tooltip: 'Actions',
                          color: themeProvider.cardColor,
                          onSelected: (action) {
                            if (action == 'details') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TaskDetailsPage(
                                    taskId: item.id,
                                    title: item.title,
                                    location: locationText,
                                  ),
                                ),
                              );
                            } else if (action == 'compare') {
                              if (item.roomId != null && item.roomId!.isNotEmpty) {
                                showDialog(
                                  context: context,
                                  builder: (context) => RoomComparisonDialog(roomId: item.roomId!),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No room associated with this work request')),
                                );
                              }
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'details',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility_outlined, size: 18, color: themeProvider.textColor),
                                  const SizedBox(width: 8),
                                  Text('View Details', style: TextStyle(color: themeProvider.textColor)),
                                ],
                              ),
                            ),
                            if (item.roomId != null && item.roomId!.isNotEmpty)
                              PopupMenuItem(
                                value: 'compare',
                                child: Row(
                                  children: [
                                    const Icon(Icons.difference_outlined, size: 18, color: Color(0xFF0F766E)),
                                    const SizedBox(width: 8),
                                    Text('Compare Room', style: TextStyle(color: themeProvider.textColor)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
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
                    // Title
                    Text(
                      item.title,
                      style: TextStyle(
                        color: themeProvider.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Requestor / Instructor
                    if (item.requestorName.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 16, color: themeProvider.subtitleColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.requestorPosition.isNotEmpty
                                  ? '${item.requestorName} (${item.requestorPosition})'
                                  : item.requestorName,
                              style: TextStyle(
                                color: themeProvider.textColor,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Location
                    if (locationText.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 16, color: themeProvider.subtitleColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              locationText,
                              style: TextStyle(
                                color: themeProvider.subtitleColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Description
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: TextStyle(
                          color: themeProvider.subtitleColor,
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Dates (using Wrap to prevent any pixel overflow on narrow screens)
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 13, color: themeProvider.subtitleColor),
                            const SizedBox(width: 5),
                            Text(
                              'Requested: ${_formatDate(item.dateSubmitted)}',
                              style: TextStyle(
                                color: themeProvider.subtitleColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (item.dateCompleted != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 13, color: Color(0xFF10B981)),
                              const SizedBox(width: 5),
                              Text(
                                'Completed: ${_formatDate(item.dateCompleted!)}',
                                style: TextStyle(
                                  color: themeProvider.subtitleColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Divider(
                      height: 1,
                      thickness: 1,
                      color: themeProvider.borderColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),

                    // Priority Badge & Action Buttons (Wrap prevents overflow on all screen sizes)
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 10,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getPriorityColor(item.priority).withValues(alpha: isDark ? 0.18 : 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _getPriorityColor(item.priority).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.flag_rounded, size: 12, color: _getPriorityColor(item.priority)),
                              const SizedBox(width: 4),
                              Text(
                                '${item.priority.isNotEmpty ? item.priority[0].toUpperCase() + item.priority.substring(1).toLowerCase() : 'Medium'} Priority',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getPriorityColor(item.priority),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (item.roomId != null && item.roomId!.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => RoomComparisonDialog(roomId: item.roomId!),
                                  );
                                },
                                icon: Icon(
                                  Icons.difference_outlined,
                                  size: 14,
                                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                ),
                                label: Text(
                                  'Compare',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  side: BorderSide(
                                    color: (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)).withValues(alpha: 0.4),
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TaskDetailsPage(
                                      taskId: item.id,
                                      title: item.title,
                                      location: locationText,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.visibility_outlined, size: 14, color: Colors.white),
                              label: const Text(
                                'View Details',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
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



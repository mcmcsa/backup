import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/app_notification_model.dart';
import '../../../shared/services/app_notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'ALL';
  String _selectedTimeFilter = 'Today';
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _notifications = [];
            _isLoading = false;
          });
        }
        return;
      }

      final data = await AppNotificationService.fetchForUser(
        role: user.role.name,
        userId: user.id,
      );

      if (mounted) {
        setState(() {
          _notifications = data.map(_toNotificationItem).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _notifications = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<NotificationItem> get _filteredNotifications {
    List<NotificationItem> filtered = _notifications;

    // Filter by category
    if (_selectedCategory != 'ALL') {
      filtered = filtered
          .where((n) => n.category == _selectedCategory)
          .toList();
    }

    // Filter by time
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime weekStart = today.subtract(Duration(days: now.weekday - 1));

    if (_selectedTimeFilter == 'Today') {
      filtered = filtered
          .where((n) => n.date.isAfter(today.subtract(const Duration(days: 1))))
          .toList();
    } else if (_selectedTimeFilter == 'This Week') {
      filtered = filtered
          .where(
            (n) => n.date.isAfter(weekStart.subtract(const Duration(days: 1))),
          )
          .toList();
    }

    // Filter by search query
    String query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((n) {
        return n.title.toLowerCase().contains(query) ||
            n.description.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  Future<void> _markAllAsRead() async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user == null) return;

    await AppNotificationService.markAllAsRead(
      role: user.role.name,
      userId: user.id,
    );

    setState(() {
      for (final notification in _notifications) {
        notification.isRead = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  NotificationItem _toNotificationItem(AppNotification notification) {
    IconData icon;
    Color iconColor;
    NotificationType type;
    String category;

    switch (notification.type) {
      case 'work_request_submitted':
        icon = Icons.assignment_rounded;
        iconColor = const Color(0xFF4169E1);
        type = NotificationType.workOrder;
        category = 'WORK ORDERS';
        break;
      case 'work_request_approved':
        icon = Icons.check_circle_rounded;
        iconColor = const Color(0xFF059669);
        type = NotificationType.success;
        category = 'WORK ORDERS';
        break;
      default:
        icon = Icons.notifications_active_rounded;
        iconColor = const Color(0xFF6B7280);
        type = NotificationType.info;
        category = 'ALL';
        break;
    }

    return NotificationItem(
      id: notification.id,
      type: type,
      icon: icon,
      iconColor: iconColor,
      title: notification.title,
      description: notification.message,
      timestamp: _relativeTimestamp(notification.createdAt),
      date: notification.createdAt,
      isRead: notification.isRead,
      category: category,
    );
  }

  String _relativeTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  Map<String, List<NotificationItem>> _groupNotificationsByDate(
    List<NotificationItem> notifications,
  ) {
    Map<String, List<NotificationItem>> grouped = {
      'TODAY': [],
      'THIS WEEK': [],
      'LAST WEEK': [],
    };

    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime weekStart = today.subtract(Duration(days: now.weekday - 1));
    DateTime lastWeekStart = weekStart.subtract(const Duration(days: 7));

    for (var notification in notifications) {
      if (notification.date.isAfter(today.subtract(const Duration(days: 1)))) {
        grouped['TODAY']!.add(notification);
      } else if (notification.date.isAfter(
        weekStart.subtract(const Duration(days: 1)),
      )) {
        grouped['THIS WEEK']!.add(notification);
      } else if (notification.date.isAfter(
        lastWeekStart.subtract(const Duration(days: 1)),
      )) {
        grouped['LAST WEEK']!.add(notification);
      }
    }

    // Remove empty groups
    grouped.removeWhere((key, value) => value.isEmpty);

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotifications = _filteredNotifications;
    final groupedNotifications = _groupNotificationsByDate(
      filteredNotifications,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.black87),
            onPressed: _markAllAsRead,
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search notifications...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Category Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _buildCategoryChip('ALL'),
                const SizedBox(width: 8),
                _buildCategoryChip('URGENT'),
                const SizedBox(width: 8),
                _buildCategoryChip('WORK ORDERS'),
              ],
            ),
          ),

          // Time Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                _buildTimeFilterChip('Today'),
                const SizedBox(width: 8),
                _buildTimeFilterChip('This Week'),
                const SizedBox(width: 8),
                _buildTimeFilterChip('Earlier'),
              ],
            ),
          ),

          // Notifications List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredNotifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (var group in groupedNotifications.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, top: 8),
                          child: Text(
                            group.key,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ...group.value.map(
                          (notification) =>
                              _buildNotificationCard(notification),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    final isSelected = _selectedCategory == label;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = label;
        });
      },
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF4169E1),
      side: BorderSide(
        color: isSelected ? const Color(0xFF4169E1) : Colors.grey.shade300,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildTimeFilterChip(String label) {
    final isSelected = _selectedTimeFilter == label;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedTimeFilter = label;
        });
      },
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: Colors.grey.shade100,
      selectedColor: const Color(0xFF4169E1),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead
              ? Colors.grey.shade200
              : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          setState(() {
            notification.isRead = true;
          });
          await AppNotificationService.markAsRead(notification.id);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: notification.isRead
                    ? Colors.transparent
                    : notification.iconColor,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: notification.iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    notification.icon,
                    color: notification.iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            notification.timestamp,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum NotificationType { urgent, workOrder, info, success }

class NotificationItem {
  final String id;
  final NotificationType type;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String timestamp;
  final DateTime date;
  bool isRead;
  final String category;

  NotificationItem({
    required this.id,
    required this.type,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.date,
    this.isRead = false,
    required this.category,
  });
}

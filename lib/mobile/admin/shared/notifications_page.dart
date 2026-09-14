import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/app_notification_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/app_settings_service.dart';
import '../../../shared/services/chat_service.dart';
import '../../../shared/widgets/chat/chat_messages_panel.dart';
import '../../../shared/services/work_request_service.dart';
import '../../admin/ticket/request_details_page.dart' as admin_ticket;
import '../../../router/app_router.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedTimeFilter = 'All';
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  StreamSubscription<void>? _settingsSub;

  @override
  void initState() {
    super.initState();
    _settingsSub = AppSettingsService.changes.listen((_) {
      _loadNotifications();
    });
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

      final isEnabled = await AppSettingsService.isNotificationsEnabled(userId: user.id);
      if (!isEnabled) {
        if (mounted) {
          setState(() {
            _notificationsEnabled = false;
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
          _notificationsEnabled = true;
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
    _settingsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<NotificationItem> get _filteredNotifications {
    List<NotificationItem> filtered = _notifications;

    // Filter by category
    if (_selectedCategory == 'Message') {
      filtered = filtered.where((n) => n.category == 'Message').toList();
    } else if (_selectedCategory == 'Work Request') {
      filtered = filtered.where((n) => n.category == 'Work Request').toList();
    }

    // Filter by time
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));

    if (_selectedTimeFilter == 'Today') {
      filtered = filtered
          .where((n) => n.date.isAfter(today) || n.date.isAtSameMomentAs(today))
          .toList();
    } else if (_selectedTimeFilter == 'This Week') {
      filtered = filtered
          .where((n) => n.date.isAfter(weekStart) || n.date.isAtSameMomentAs(weekStart))
          .toList();
    } else if (_selectedTimeFilter == 'Earlier') {
      filtered = filtered
          .where((n) => n.date.isBefore(weekStart))
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

    if (mounted) {
      setState(() {
        for (final notification in _notifications) {
          notification.isRead = true;
        }
      });
    }
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
        category = 'Work Request';
        break;
      case 'work_request_approved':
        icon = Icons.check_circle_rounded;
        iconColor = const Color(0xFF059669);
        type = NotificationType.success;
        category = 'Work Request';
        break;
      case 'work_request_accepted':
        icon = Icons.handshake_rounded;
        iconColor = const Color(0xFF0D9488);
        type = NotificationType.success;
        category = 'Work Request';
        break;
      case 'work_request_completed':
        icon = Icons.task_alt_rounded;
        iconColor = const Color(0xFF059669);
        type = NotificationType.success;
        category = 'Work Request';
        break;
      case 'work_request_declined':
        icon = Icons.cancel_rounded;
        iconColor = const Color(0xFFDC2626);
        type = NotificationType.urgent;
        category = 'Work Request';
        break;
      case 'chat':
      case 'chat_message':
      case 'new_chat_message':
        icon = Icons.chat_bubble_rounded;
        iconColor = const Color(0xFF0F766E);
        type = NotificationType.info;
        category = 'Message';
        break;
      default:
        icon = Icons.notifications_active_rounded;
        iconColor = const Color(0xFF6B7280);
        type = NotificationType.info;
        category = 'Work Request';
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
      workRequestId: notification.workRequestId,
      chatRoomId: notification.chatRoomId,
      targetPage: notification.targetPage,
      rawType: notification.type,
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
                  borderSide: BorderSide(color: Color(0xFF4169E1)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),

          // Category Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip('All'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Message'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Work Request'),
                ],
              ),
            ),
          ),

          // Time Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTimeFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildTimeFilterChip('Today'),
                  const SizedBox(width: 8),
                  _buildTimeFilterChip('This Week'),
                  const SizedBox(width: 8),
                  _buildTimeFilterChip('Earlier'),
                ],
              ),
            ),
          ),

          // Notifications List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_notificationsEnabled
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.notifications_off_outlined,
                                size: 56,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Notifications are Disabled',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Turn on "Enable Notifications" in Settings to receive updates about requests and activity.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
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

  Future<void> _handleNotificationClick(NotificationItem notification) async {
    if (!notification.isRead) {
      setState(() {
        notification.isRead = true;
      });
      await AppNotificationService.markAsRead(notification.id);
    }

    if (!mounted) return;
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user == null) return;

    final isChat = notification.category == 'Message' ||
        notification.rawType == 'chat' ||
        notification.rawType == 'chat_message' ||
        notification.rawType == 'new_chat_message' ||
        (notification.chatRoomId != null && notification.chatRoomId!.isNotEmpty);

    // Case 1: Chat Notification
    if (isChat) {
      final roomId = notification.chatRoomId;
      if (roomId != null && roomId.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );

        try {
          final room = await ChatService.fetchRoom(roomId);
          if (mounted) Navigator.of(context).pop();

          if (room != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: Colors.white,
                  body: SafeArea(
                    top: false,
                    child: ChatMessagesPanel(
                      key: ValueKey(room.id),
                      room: room,
                      currentUserId: user.id,
                      currentUserName: user.name,
                      currentUserRole: user.role.name,
                      onBack: () => Navigator.pop(context),
                      onRoomDeleted: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            );
            return;
          }
        } catch (_) {
          if (mounted) Navigator.of(context).pop();
        }
      }

      if (!mounted) return;
      if (user.role.name == 'teacher') {
        context.push(teacherChatRoute);
      }
      return;
    }

    // Case 2: Work Request Notification
    if (notification.workRequestId != null && notification.workRequestId!.isNotEmpty) {
      final reqId = notification.workRequestId!;
      final userRoleStr = user.role.name.toLowerCase();

      if (userRoleStr == 'teacher') {
        context.push(
          '/request-details',
          extra: {
            'trackingNumber': reqId,
            'status': 'PENDING',
          },
        );
        return;
      } else if (userRoleStr == 'admin' || userRoleStr == 'campadmin') {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
        try {
          final req = await WorkRequestService.fetchById(reqId);
          if (mounted) Navigator.of(context).pop();
          if (req != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => admin_ticket.RequestDetailsPage(request: req),
              ),
            );
          }
        } catch (_) {
          if (mounted) Navigator.of(context).pop();
        }
        return;
      } else if (userRoleStr == 'maintenance') {
        context.push(
          '/request-details',
          extra: {
            'trackingNumber': reqId,
            'status': 'PENDING',
          },
        );
        return;
      }
    }
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
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _handleNotificationClick(notification),
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
                    color: notification.iconColor.withValues(alpha: 0.1),
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
  final String? workRequestId;
  final String? chatRoomId;
  final String? targetPage;
  final String rawType;

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
    this.workRequestId,
    this.chatRoomId,
    this.targetPage,
    this.rawType = '',
  });
}

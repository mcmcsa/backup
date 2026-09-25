import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/app_date_range_dialog.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/app_notification_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/app_settings_service.dart';
import '../../../shared/services/chat_service.dart';
import '../../../shared/widgets/chat/chat_messages_panel.dart';
import '../../../shared/services/work_request_service.dart';
import '../../admin/ticket/request_details_page.dart' as admin_ticket;
import '../../maintenance/task/task_details_page.dart';
import '../../../router/app_router.dart';
import '../../../shared/providers/theme_provider.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedTimeFilter = 'All';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  StreamSubscription<void>? _settingsSub;
  RealtimeChannel? _realtimeChannel;
  StreamSubscription<void>? _notifSub;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _settingsSub = AppSettingsService.changes.listen((_) {
      _loadNotifications(silent: true);
    });
    _notifSub = AppNotificationService.changes.listen((_) {
      if (mounted) _loadNotifications(silent: true);
    });

    try {
      _realtimeChannel = AppNotificationService.subscribeToNotifications(
        onUpdate: () {
          if (mounted) _loadNotifications(silent: true);
        },
      );
    } catch (_) {}

    // Auto-refresh (AJAX polling fallback) every 8 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _loadNotifications(silent: true);
    });

    _loadNotifications();
  }

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }
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
    _notifSub?.cancel();
    _realtimeChannel?.unsubscribe();
    _refreshTimer?.cancel();
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
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    if (_selectedTimeFilter == 'Today') {
      filtered = filtered
          .where((n) => n.date.isAfter(today) || n.date.isAtSameMomentAs(today))
          .toList();
    } else if (_selectedTimeFilter == 'This Week') {
      filtered = filtered
          .where((n) => n.date.isAfter(weekStart) || n.date.isAtSameMomentAs(weekStart))
          .toList();
    } else if (_selectedTimeFilter == 'This Month') {
      filtered = filtered
          .where((n) => n.date.isAfter(monthStart) || n.date.isAtSameMomentAs(monthStart))
          .toList();
    } else if (_selectedTimeFilter == 'This Year') {
      filtered = filtered
          .where((n) => n.date.isAfter(yearStart) || n.date.isAtSameMomentAs(yearStart))
          .toList();
    } else if (_selectedTimeFilter == 'Custom Range') {
      if (_customStartDate != null && _customEndDate != null) {
        final start = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
        final end = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59, 999);
        filtered = filtered.where((n) => !n.date.isBefore(start) && !n.date.isAfter(end)).toList();
      } else if (_customStartDate != null) {
        final start = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
        filtered = filtered.where((n) => !n.date.isBefore(start)).toList();
      } else if (_customEndDate != null) {
        final end = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59, 999);
        filtered = filtered.where((n) => !n.date.isAfter(end)).toList();
      }
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final filteredNotifications = _filteredNotifications;
    final groupedNotifications = _groupNotificationsByDate(
      filteredNotifications,
    );

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.done_all_rounded, color: themeProvider.textColor),
            onPressed: _markAllAsRead,
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: Column(
        children: [
          // Unified Search and Filter Header
          Container(
            color: themeProvider.cardColor,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() {}),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search notifications...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              size: 18,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: Color(0xFF00BFA5), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Category Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip('All', isDark, themeProvider),
                      const SizedBox(width: 8),
                      _buildCategoryChip('Message', isDark, themeProvider),
                      const SizedBox(width: 8),
                      _buildCategoryChip('Work Request', isDark, themeProvider),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Time Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTimeFilterChip('All', isDark, themeProvider),
                      const SizedBox(width: 8),
                      _buildTimeFilterChip('Today', isDark, themeProvider),
                      const SizedBox(width: 8),
                      _buildTimeFilterChip('This Week', isDark, themeProvider),
                      const SizedBox(width: 8),
                      _buildTimeFilterChip('This Month', isDark, themeProvider),
                      const SizedBox(width: 8),
                      _buildTimeFilterChip('This Year', isDark, themeProvider),
                      const SizedBox(width: 8),
                      _buildTimeFilterChip('Custom Range', isDark, themeProvider),
                    ],
                  ),
                ),
                if (_selectedTimeFilter == 'Custom Range') ...[
                  const SizedBox(height: 8),
                  _buildCustomDateRangeBar(isDark, themeProvider),
                ],
              ],
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
                            color: themeProvider.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: isDark ? Border.all(color: Colors.grey.shade800) : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 56,
                                color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Notifications are Disabled',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Turn on "Enable Notifications" in Settings to receive updates about requests and activity.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
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
                                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No notifications',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
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
                                  padding: const EdgeInsets.only(bottom: 10, top: 12),
                                  child: Text(
                                    group.key,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                ...group.value.map(
                                  (notification) =>
                                      _buildNotificationCard(notification, isDark, themeProvider),
                                ),
                              ],
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isDark, ThemeProvider themeProvider) {
    final isSelected = _selectedCategory == label;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: isSelected,
      checkmarkColor: Colors.white,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedCategory = label;
          });
        }
      },
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
      selectedColor: const Color(0xFF00BFA5),
      side: BorderSide(
        color: isSelected
            ? const Color(0xFF00BFA5)
            : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    );
  }

  Widget _buildTimeFilterChip(String label, bool isDark, ThemeProvider themeProvider) {
    final isSelected = _selectedTimeFilter == label;

    return ChoiceChip(
      avatar: label == 'Custom Range'
          ? Icon(
              Icons.date_range_rounded,
              size: 13,
              color: isSelected ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            )
          : null,
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (selected) async {
        if (selected) {
          setState(() {
            _selectedTimeFilter = label;
          });
          if (label == 'Custom Range' && (_customStartDate == null || _customEndDate == null)) {
            await _pickCustomDateRange(context);
          }
        }
      },
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      backgroundColor: isDark ? const Color(0xFF222222) : const Color(0xFFF1F5F9),
      selectedColor: isDark ? const Color(0xFF0F766E) : const Color(0xFF0D9488),
      side: BorderSide(
        color: isSelected
            ? (isDark ? const Color(0xFF0F766E) : const Color(0xFF0D9488))
            : (isDark ? Colors.grey.shade800 : Colors.transparent),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }

  Widget _buildCustomDateRangeBar(bool isDark, ThemeProvider themeProvider) {
    final startStr = _customStartDate != null
        ? DateFormat('MMM dd, yyyy').format(_customStartDate!)
        : 'Select';
    final endStr = _customEndDate != null
        ? DateFormat('MMM dd, yyyy').format(_customEndDate!)
        : 'Select';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222222) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _pickFromDate(context),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF00BFA5)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'From: $startStr',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => _pickToDate(context),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF00BFA5)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'To: $endStr',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customStartDate ?? now.subtract(const Duration(days: 7)),
      firstDate: DateTime(2020),
      lastDate: _customEndDate ?? DateTime(2035),
      helpText: 'Select From Date',
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked;
        if (_customEndDate != null && _customEndDate!.isBefore(picked)) {
          _customEndDate = picked;
        }
        _selectedTimeFilter = 'Custom Range';
      });
    }
  }

  Future<void> _pickToDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customEndDate ?? now,
      firstDate: _customStartDate ?? DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Select To Date',
    );
    if (picked != null) {
      setState(() {
        _customEndDate = picked;
        if (_customStartDate != null && _customStartDate!.isAfter(picked)) {
          _customStartDate = picked;
        }
        _selectedTimeFilter = 'Custom Range';
      });
    }
  }

  Future<void> _pickCustomDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialStartDate: _customStartDate ?? now.subtract(const Duration(days: 7)),
      initialEndDate: _customEndDate ?? now,
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedTimeFilter = 'Custom Range';
      });
    }
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
                builder: (_) => TaskDetailsPage(
                  taskId: req.id,
                  title: req.title,
                  location: '${req.buildingName} - ${req.officeRoom}',
                ),
              ),
            );
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Task not found or has been removed.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (_) {
          if (mounted) Navigator.of(context).pop();
        }
        return;
      }
    }
  }

  Widget _buildNotificationCard(
    NotificationItem notification,
    bool isDark,
    ThemeProvider themeProvider,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? (notification.isRead
                  ? Colors.grey.shade800
                  : const Color(0xFF00BFA5).withValues(alpha: 0.3))
              : (notification.isRead
                  ? Colors.grey.shade200
                  : const Color(0xFF00BFA5).withValues(alpha: 0.2)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 6,
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
                    color: notification.iconColor.withValues(alpha: isDark ? 0.18 : 0.1),
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
                                    : FontWeight.bold,
                                color: themeProvider.textColor,
                              ),
                            ),
                          ),
                          Text(
                            notification.timestamp,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
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

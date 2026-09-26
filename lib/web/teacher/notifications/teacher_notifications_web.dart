import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/app_notification_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/app_settings_service.dart';
import '../../../shared/services/chat_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../teacher_nav_controller.dart';
import '../../../shared/widgets/room_comparison_dialog.dart';
import '../../../shared/widgets/notification_filter_bar.dart';

class TeacherNotificationsWeb extends StatefulWidget {
  const TeacherNotificationsWeb({super.key});

  @override
  State<TeacherNotificationsWeb> createState() => _TeacherNotificationsWebState();
}

class _TeacherNotificationsWebState extends State<TeacherNotificationsWeb> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  bool _showAll = false;
  bool _notificationsEnabled = true;
  StreamSubscription<void>? _settingsSub;
  RealtimeChannel? _realtimeChannel;
  StreamSubscription<void>? _notifSub;
  Timer? _refreshTimer;
  NotificationTypeFilter _selectedType = NotificationTypeFilter.all;
  NotificationDateFilter _selectedDate = NotificationDateFilter.all;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  static const Color _primaryTeal = Color(0xFF00BFA5);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _subtleText = Color(0xFF64748B);
  static const Color _pageBg = Color(0xFFF1F5F9);
  static const Color _cardBg = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);

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

  @override
  void dispose() {
    _settingsSub?.cancel();
    _notifSub?.cancel();
    _realtimeChannel?.unsubscribe();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _notifications = [];
          _isLoading = false;
        });
        return;
      }

      final isEnabled = await AppSettingsService.isNotificationsEnabled(userId: user.id);
      if (!isEnabled) {
        if (!mounted) return;
        setState(() {
          _notificationsEnabled = false;
          _notifications = [];
          _isLoading = false;
        });
        return;
      }

      final data = await AppNotificationService.fetchForUser(
        role: user.role.name,
        userId: user.id,
      );

      if (!mounted) return;
      setState(() {
        _notificationsEnabled = true;
        _notifications = data;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notifications = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user == null) return;

    await AppNotificationService.markAllAsRead(
      role: user.role.name,
      userId: user.id,
    );

    if (!mounted) return;
    setState(() {
      _notifications = _notifications
          .map(
            (n) => AppNotification(
              id: n.id,
              title: n.title,
              message: n.message,
              type: n.type,
              targetRole: n.targetRole,
              targetUserId: n.targetUserId,
              workRequestId: n.workRequestId,
              isRead: true,
              createdAt: n.createdAt,
            ),
          )
          .toList();
    });
  }

  Future<void> _markOneAsRead(AppNotification notification) async {
    if (notification.isRead) return;
    await AppNotificationService.markAsRead(notification.id);
    await _loadNotifications();
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  IconData _iconForType(String type) {
    switch (type) {
      case 'work_request_submitted':
        return Icons.assignment_rounded;
      case 'work_request_approved':
        return Icons.check_circle_rounded;
      case 'work_request_accepted':
        return Icons.handshake_rounded;
      case 'work_request_completed':
        return Icons.task_alt_rounded;
      case 'work_request_declined':
        return Icons.cancel_rounded;
      case 'work_request_completion_submitted':
        return Icons.assignment_turned_in_rounded;
      case 'work_request_completion_ready_for_requestor':
        return Icons.fact_check_rounded;
      case 'chat':
      case 'chat_message':
      case 'new_chat_message':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'work_request_submitted':
        return const Color(0xFF4169E1);
      case 'work_request_approved':
      case 'work_request_accepted':
      case 'work_request_completed':
        return const Color(0xFF059669);
      case 'work_request_declined':
        return const Color(0xFFDC2626);
      case 'work_request_completion_submitted':
        return const Color(0xFF7C3AED);
      case 'work_request_completion_ready_for_requestor':
        return _primaryTeal;
      case 'chat':
      case 'chat_message':
      case 'new_chat_message':
        return const Color(0xFF0F766E);
      default:
        return _primaryTeal;
    }
  }

  String _relativeTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  List<AppNotification> get _filteredNotifications {
    return NotificationFilterHelper.filterNotifications(
      _notifications,
      typeFilter: _selectedType,
      dateFilter: _selectedDate,
      customStartDate: _customStartDate,
      customEndDate: _customEndDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotifications;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isNarrow = screenWidth < 650;

    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isNarrow ? 12 : 32,
          vertical: isNarrow ? 16 : 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(isNarrow),
            const SizedBox(height: 16),
            NotificationFilterBar(
              selectedType: _selectedType,
              onTypeChanged: (type) => setState(() => _selectedType = type),
              selectedDate: _selectedDate,
              onDateChanged: (date) => setState(() => _selectedDate = date),
              customStartDate: _customStartDate,
              customEndDate: _customEndDate,
              onCustomRangeChanged: (start, end) {
                setState(() {
                  _customStartDate = start;
                  _customEndDate = end;
                  _selectedDate = NotificationDateFilter.custom;
                });
              },
              primaryColor: _primaryTeal,
              unreadCount: _unreadCount,
              onMarkAllAsRead: _markAllAsRead,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: _primaryTeal),
              ))
            else if (!_notificationsEnabled)
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 540),
                  margin: EdgeInsets.symmetric(vertical: isNarrow ? 16 : 32),
                  padding: EdgeInsets.all(isNarrow ? 24 : 36),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isNarrow ? 56 : 72,
                        height: isNarrow ? 56 : 72,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications_off_outlined,
                          color: const Color(0xFF64748B),
                          size: isNarrow ? 28 : 36,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Notifications are Disabled',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isNarrow ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: _darkText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You have turned off notifications in your account settings. Turn on "Enable Notifications" in Settings to receive updates about requests and activity.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isNarrow ? 13 : 14,
                          color: _subtleText,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          TeacherNavController.of(context)?.navigateTo(9);
                        },
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        label: const Text('Go to Settings'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_notifications.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: isNarrow ? 36 : 60),
                  child: Column(
                    children: [
                      Container(
                        width: isNarrow ? 64 : 80,
                        height: isNarrow ? 64 : 80,
                        decoration: BoxDecoration(
                          color: _primaryTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.notifications_none_rounded, color: _primaryTeal, size: isNarrow ? 32 : 40),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No notifications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _darkText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "You're all caught up!",
                        style: TextStyle(fontSize: 13, color: _subtleText),
                      ),
                    ],
                  ),
                ),
              )
            else if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: isNarrow ? 32 : 48),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.filter_list_off_rounded, color: Colors.grey.shade500, size: 28),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No matching notifications',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _darkText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try changing your filter selection above.',
                        style: TextStyle(fontSize: 13, color: _subtleText),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedType = NotificationTypeFilter.all;
                            _selectedDate = NotificationDateFilter.all;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryTeal,
                          side: const BorderSide(color: _primaryTeal),
                        ),
                        child: const Text('Reset filters'),
                      ),
                    ],
                  ),
                ),
              )
            else
              _buildNotificationsList(isNarrow),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  if (isNarrow) ...[
                    InkWell(
                      onTap: () {
                        TeacherNavController.of(context)?.navigateTo(0);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _borderColor),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 18, color: _darkText),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: isNarrow ? 20 : 28,
                        fontWeight: FontWeight.w800,
                        color: _darkText,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (_unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _primaryTeal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _primaryTeal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$_unreadCount new',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Stay updated on your maintenance requests and activity.',
          style: TextStyle(
            fontSize: isNarrow ? 12.5 : 15,
            color: _subtleText.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsList(bool isNarrow) {
    final list = _filteredNotifications;
    final hasMoreThan20 = list.length > 20;
    final displayCount = _showAll ? list.length : (hasMoreThan20 ? 20 : list.length);

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayCount,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final notification = list[index];
            final color = _colorForType(notification.type);

            return GestureDetector(
              onTap: () async {
                if (!notification.isRead) {
                  await _markOneAsRead(notification);
                }
                if (notification.type == 'room_edit') {
                  final targetPage = notification.targetPage ?? '';
                  final roomId = targetPage.startsWith('room_id:') 
                      ? targetPage.replaceFirst('room_id:', '') 
                      : targetPage;
                  if (roomId.isNotEmpty && mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => RoomComparisonDialog(roomId: roomId),
                    );
                  }
                  return;
                }
                 final isChat = notification.type == 'chat' ||
                     notification.type == 'chat_message' ||
                     notification.type == 'new_chat_message';
                 if (isChat && notification.chatRoomId != null && notification.chatRoomId!.isNotEmpty) {
                  if (mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return const Center(child: CircularProgressIndicator());
                      },
                    );
                  }
                  try {
                    final room = await ChatService.fetchRoom(notification.chatRoomId!);
                    if (mounted) Navigator.of(context).pop();
                    if (room != null && mounted) {
                      TeacherNavController.of(context)?.navigateTo(4, chatRoom: room);
                    }
                  } catch (_) {
                    if (mounted) Navigator.of(context).pop();
                  }
                  return;
                }

                if (notification.workRequestId != null && notification.workRequestId!.isNotEmpty) {
                  if (mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return const Center(child: CircularProgressIndicator());
                      },
                    );
                  }
                  try {
                    final workRequest = await WorkRequestService.fetchById(notification.workRequestId!);
                    if (mounted) Navigator.of(context).pop();
                    if (workRequest != null && mounted) {
                      TeacherNavController.of(context)?.navigateTo(3, request: workRequest);
                    }
                  } catch (_) {
                    if (mounted) Navigator.of(context).pop();
                  }
                }
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  decoration: BoxDecoration(
                    color: notification.isRead ? _cardBg : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: notification.isRead ? _borderColor : color.withValues(alpha: 0.25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(isNarrow ? 12 : 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: isNarrow ? 38 : 44,
                        height: isNarrow ? 38 : 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(isNarrow ? 8 : 10),
                        ),
                        child: Icon(
                          _iconForType(notification.type),
                          color: color,
                          size: isNarrow ? 19 : 22,
                        ),
                      ),
                      SizedBox(width: isNarrow ? 10 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    style: TextStyle(
                                      fontSize: isNarrow ? 13.5 : 14.5,
                                      fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
                                      color: _darkText,
                                    ),
                                  ),
                                ),
                                if (!notification.isRead) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: _primaryTeal.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'NEW',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F766E),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.message,
                              style: TextStyle(
                                fontSize: isNarrow ? 12.5 : 13,
                                color: _subtleText,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _relativeTimestamp(notification.createdAt),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: _subtleText.withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (!notification.isRead)
                                  InkWell(
                                    onTap: () => _markOneAsRead(notification),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.done_rounded, size: 14, color: _primaryTeal),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Mark read',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: _primaryTeal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
          },
        ),
        if (hasMoreThan20 && !_showAll) ...[
          const SizedBox(height: 16),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _showAll = true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'View All Notifications',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF16A34A),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

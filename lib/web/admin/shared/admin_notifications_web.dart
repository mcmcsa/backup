import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/app_notification_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/app_settings_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../admin_main_navigation_web.dart';
import '../admin_nav_controller.dart';
import '../tickets/admin_work_process_web.dart';
import '../../../shared/services/chat_service.dart';
import '../../../shared/widgets/room_comparison_dialog.dart';
import '../../../shared/widgets/notification_filter_bar.dart';

class AdminNotificationsWeb extends StatefulWidget {
  const AdminNotificationsWeb({super.key});

  @override
  State<AdminNotificationsWeb> createState() => _AdminNotificationsWebState();
}

class _AdminNotificationsWebState extends State<AdminNotificationsWeb> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  bool _showAll = false;
  bool _notificationsEnabled = true;
  StreamSubscription<void>? _settingsSub;
  NotificationTypeFilter _selectedType = NotificationTypeFilter.all;
  NotificationDateFilter _selectedDate = NotificationDateFilter.all;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  static const Color _primaryBlue = Color(0xFF3B82F6);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _subtleText = Color(0xFF64748B);
  static const Color _pageBg = Color(0xFFF1F5F9);
  static const Color _cardBg = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _settingsSub = AppSettingsService.changes.listen((_) {
      _loadNotifications();
    });
    _loadNotifications();
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
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
            (notification) => AppNotification(
              id: notification.id,
              title: notification.title,
              message: notification.message,
              type: notification.type,
              targetRole: notification.targetRole,
              targetUserId: notification.targetUserId,
              workRequestId: notification.workRequestId,
              chatRoomId: notification.chatRoomId,
              targetPage: notification.targetPage,
              isRead: true,
              createdAt: notification.createdAt,
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

  int get _unreadCount => _notifications.where((notification) => !notification.isRead).length;

  IconData _iconForType(String type) {
    switch (type) {
      case 'room_edit':
        return Icons.edit_location_alt_rounded;
      case 'work_request_submitted':
        return Icons.assignment_rounded;
      case 'work_request_approved':
        return Icons.check_circle_rounded;
      case 'work_request_accepted':
        return Icons.handshake_rounded;
      case 'pre_inspection_submitted':
        return Icons.search_rounded;
      case 'post_repair_submitted':
        return Icons.build_circle_rounded;
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
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'room_edit':
        return const Color(0xFF8B5CF6);
      case 'work_request_submitted':
        return const Color(0xFF4169E1);
      case 'work_request_approved':
      case 'work_request_accepted':
      case 'work_request_completed':
        return const Color(0xFF059669);
      case 'pre_inspection_submitted':
        return const Color(0xFFF59E0B);
      case 'post_repair_submitted':
        return const Color(0xFF3B82F6);
      case 'work_request_declined':
        return const Color(0xFFDC2626);
      case 'work_request_completion_submitted':
        return const Color(0xFF7C3AED);
      case 'work_request_completion_ready_for_requestor':
        return const Color(0xFF0D9488);
      case 'chat':
      case 'chat_message':
      case 'new_chat_message':
        return const Color(0xFF0F766E);
      default:
        return const Color(0xFF6B7280);
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
    final isCompact = screenWidth < 700;

    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 16 : 32,
          vertical: isCompact ? 18 : 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
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
              primaryColor: _primaryBlue,
              unreadCount: _unreadCount,
              onMarkAllAsRead: _markAllAsRead,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: _primaryBlue))
            else if (!_notificationsEnabled)
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 540),
                  margin: const EdgeInsets.symmetric(vertical: 32),
                  padding: const EdgeInsets.all(36),
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
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_off_outlined,
                          color: Color(0xFF64748B),
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Notifications are Disabled',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _darkText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You have turned off notifications in your account settings. Turn on "Enable Notifications" in Settings to receive updates about requests and activity.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: _subtleText,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          AdminNavController.of(context)?.navigateTo(AdminMainNavigationWeb.settingsIndex);
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
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.notifications_none_rounded, color: _primaryBlue, size: 40),
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
                      const SizedBox(height: 8),
                      Text(
                        'You\'re all caught up!',
                        style: TextStyle(fontSize: 13, color: _subtleText),
                      ),
                    ],
                  ),
                ),
              )
            else if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.filter_list_off_rounded, color: Colors.grey.shade500, size: 32),
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedType = NotificationTypeFilter.all;
                            _selectedDate = NotificationDateFilter.all;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryBlue,
                          side: const BorderSide(color: _primaryBlue),
                        ),
                        child: const Text('Reset filters'),
                      ),
                    ],
                  ),
                ),
              )
            else
              _buildNotificationsList(isCompact: isCompact),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _darkText,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsList({bool isCompact = false}) {
    final list = _filteredNotifications;
    final hasMoreThan20 = list.length > 20;
    final displayCount = _showAll ? list.length : (hasMoreThan20 ? 20 : list.length);

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayCount,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                    if (room != null && mounted) {
                      final controller = AdminNavController.of(context);
                      if (controller != null) {
                        controller.navigateTo(20, chatRoom: room);
                      }
                    }
                  } catch (_) {
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
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
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                    if (workRequest != null && mounted) {
                      final controller = AdminNavController.of(context);
                      if (controller != null) {
                        controller.openWorkProcess(workRequest);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminWorkProcessWeb(request: workRequest),
                          ),
                        );
                      }
                    }
                  } catch (_) {
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                }
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  decoration: BoxDecoration(
                    color: notification.isRead ? _cardBg : const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: notification.isRead ? _borderColor : color.withValues(alpha: 0.2),
                    ),
                  ),
                  padding: EdgeInsets.all(isCompact ? 12 : 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: isCompact ? 38 : 44,
                        height: isCompact ? 38 : 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_iconForType(notification.type), color: color, size: isCompact ? 18 : 22),
                      ),
                      SizedBox(width: isCompact ? 10 : 16),
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
                                      fontSize: isCompact ? 13 : 14,
                                      fontWeight: FontWeight.w700,
                                      color: _darkText,
                                    ),
                                  ),
                                ),
                                if (!notification.isRead && !isCompact) ...[
                                  TextButton(
                                    onPressed: () => _markOneAsRead(notification),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: const Size(50, 28),
                                    ),
                                    child: const Text('Mark read', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.message,
                              style: TextStyle(fontSize: isCompact ? 12 : 13, color: _subtleText),
                              maxLines: isCompact ? 3 : 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _relativeTimestamp(notification.createdAt),
                                  style: TextStyle(fontSize: 11, color: _subtleText.withValues(alpha: 0.7)),
                                ),
                                if (!notification.isRead && isCompact)
                                  InkWell(
                                    onTap: () => _markOneAsRead(notification),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Text(
                                        'Mark read',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _primaryBlue,
                                        ),
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
                      color: Color(0xFF3B82F6),
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

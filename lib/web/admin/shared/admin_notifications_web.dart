import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/app_notification_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../admin_nav_controller.dart';
import '../tickets/admin_work_process_web.dart';
import '../../../shared/services/chat_service.dart';
import '../../../shared/widgets/room_comparison_dialog.dart';

class AdminNotificationsWeb extends StatefulWidget {
  const AdminNotificationsWeb({super.key});

  @override
  State<AdminNotificationsWeb> createState() => _AdminNotificationsWebState();
}

class _AdminNotificationsWebState extends State<AdminNotificationsWeb> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  bool _showAll = false;

  static const Color _primaryBlue = Color(0xFF3B82F6);
  static const Color _warningOrange = Color(0xFFF59E0B);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _subtleText = Color(0xFF64748B);
  static const Color _pageBg = Color(0xFFF1F5F9);
  static const Color _cardBg = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);

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
        if (!mounted) return;
        setState(() {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildActionBar(),
            const SizedBox(height: 32),
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: _primaryBlue))
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
            else
              _buildNotificationsList(),
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
        const SizedBox(height: 8),
        Text(
          'Live notifications from your database feed.',
          style: TextStyle(
            fontSize: 15,
            color: _subtleText.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _warningOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$_unreadCount unread',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _warningOrange,
              ),
            ),
          )
        else
          const SizedBox(),
        if (_unreadCount > 0)
          TextButton.icon(
            onPressed: _markAllAsRead,
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('Mark all as read'),
            style: TextButton.styleFrom(foregroundColor: _primaryBlue),
          )
        else
          const SizedBox(),
      ],
    );
  }

  Widget _buildNotificationsList() {
    final hasMoreThan20 = _notifications.length > 20;
    final displayCount = _showAll ? _notifications.length : (hasMoreThan20 ? 20 : _notifications.length);

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayCount,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final notification = _notifications[index];
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
                if ((notification.type == 'chat' || notification.type == 'chat_message') && notification.chatRoomId != null && notification.chatRoomId!.isNotEmpty) {
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
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_iconForType(notification.type), color: color, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _darkText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.message,
                              style: const TextStyle(fontSize: 13, color: _subtleText),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _relativeTimestamp(notification.createdAt),
                              style: TextStyle(fontSize: 12, color: _subtleText.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ),
                      if (!notification.isRead)
                        TextButton(
                          onPressed: () => _markOneAsRead(notification),
                          child: const Text('Mark read'),
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

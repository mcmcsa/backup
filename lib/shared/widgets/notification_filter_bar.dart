import 'package:flutter/material.dart';
import '../models/app_notification_model.dart';

enum NotificationTypeFilter {
  all,
  message,
  workRequest,
}

enum NotificationDateFilter {
  all,
  today,
  thisWeek,
  earlier,
}

class NotificationFilterHelper {
  static bool isMessage(AppNotification n) {
    final type = n.type.toLowerCase();
    return type == 'chat_message' ||
        type == 'new_chat_message' ||
        type == 'chat' ||
        (n.chatRoomId != null && n.chatRoomId!.isNotEmpty) ||
        (n.targetPage != null && n.targetPage!.toLowerCase().contains('chat'));
  }

  static bool isWorkRequest(AppNotification n) {
    if (isMessage(n)) return false;
    final type = n.type.toLowerCase();
    return (n.workRequestId != null && n.workRequestId!.isNotEmpty) ||
        type.contains('work') ||
        type.contains('request') ||
        type.contains('task') ||
        type.contains('repair') ||
        type.contains('inspection') ||
        type.contains('order');
  }

  static bool matchesType(AppNotification n, NotificationTypeFilter filter) {
    switch (filter) {
      case NotificationTypeFilter.all:
        return true;
      case NotificationTypeFilter.message:
        return isMessage(n);
      case NotificationTypeFilter.workRequest:
        // Everything not a chat message is treated as a work request / operations notification
        return isWorkRequest(n) || !isMessage(n);
    }
  }

  static bool matchesDate(DateTime dt, NotificationDateFilter filter) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));

    switch (filter) {
      case NotificationDateFilter.all:
        return true;
      case NotificationDateFilter.today:
        return dt.isAfter(startOfToday) || dt.isAtSameMomentAs(startOfToday);
      case NotificationDateFilter.thisWeek:
        return dt.isAfter(startOfWeek) || dt.isAtSameMomentAs(startOfWeek);
      case NotificationDateFilter.earlier:
        return dt.isBefore(startOfWeek);
    }
  }

  static List<AppNotification> filterNotifications(
    List<AppNotification> list, {
    required NotificationTypeFilter typeFilter,
    required NotificationDateFilter dateFilter,
    String? searchQuery,
  }) {
    return list.where((n) {
      if (!matchesType(n, typeFilter)) return false;
      if (!matchesDate(n.createdAt, dateFilter)) return false;
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchTitle = n.title.toLowerCase().contains(q);
        final matchBody = n.message.toLowerCase().contains(q);
        if (!matchTitle && !matchBody) return false;
      }
      return true;
    }).toList();
  }
}

class NotificationFilterBar extends StatelessWidget {
  final NotificationTypeFilter selectedType;
  final ValueChanged<NotificationTypeFilter> onTypeChanged;
  final NotificationDateFilter selectedDate;
  final ValueChanged<NotificationDateFilter> onDateChanged;
  final Color? primaryColor;
  final EdgeInsetsGeometry padding;
  final int? unreadCount;
  final VoidCallback? onMarkAllAsRead;

  const NotificationFilterBar({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
    required this.selectedDate,
    required this.onDateChanged,
    this.primaryColor,
    this.padding = EdgeInsets.zero,
    this.unreadCount,
    this.onMarkAllAsRead,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = primaryColor ?? Theme.of(context).primaryColor;

    return Padding(
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Section: Type Filters & Action Status
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 640;
                final typeSelector = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTypeChip(
                        label: 'All',
                        isSelected: selectedType == NotificationTypeFilter.all,
                        onTap: () => onTypeChanged(NotificationTypeFilter.all),
                        activeColor: activeColor,
                        icon: Icons.grid_view_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildTypeChip(
                        label: 'Message',
                        isSelected: selectedType == NotificationTypeFilter.message,
                        onTap: () => onTypeChanged(NotificationTypeFilter.message),
                        activeColor: activeColor,
                        icon: Icons.chat_bubble_outline_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildTypeChip(
                        label: 'Work Request',
                        isSelected: selectedType == NotificationTypeFilter.workRequest,
                        onTap: () => onTypeChanged(NotificationTypeFilter.workRequest),
                        activeColor: activeColor,
                        icon: Icons.assignment_outlined,
                      ),
                    ],
                  ),
                );

                Widget? actionsWidget;
                if (unreadCount != null) {
                  actionsWidget = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (unreadCount! > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFF97316).withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            '$unreadCount unread',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEA580C),
                            ),
                          ),
                        ),
                        if (onMarkAllAsRead != null) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: onMarkAllAsRead,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.done_all_rounded, size: 16, color: activeColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Mark all read',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: activeColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF059669)),
                              SizedBox(width: 4),
                              Text(
                                'All caught up',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                }

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: typeSelector),
                      if (actionsWidget != null) ...[
                        const SizedBox(width: 12),
                        actionsWidget,
                      ],
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    typeSelector,
                    if (actionsWidget != null) ...[
                      const SizedBox(height: 10),
                      actionsWidget,
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // Bottom Section: Date Timeline Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 15,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Time:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildDateChip(
                    label: 'All',
                    isSelected: selectedDate == NotificationDateFilter.all,
                    onTap: () => onDateChanged(NotificationDateFilter.all),
                    activeColor: activeColor,
                  ),
                  const SizedBox(width: 6),
                  _buildDateChip(
                    label: 'Today',
                    isSelected: selectedDate == NotificationDateFilter.today,
                    onTap: () => onDateChanged(NotificationDateFilter.today),
                    activeColor: activeColor,
                  ),
                  const SizedBox(width: 6),
                  _buildDateChip(
                    label: 'This Week',
                    isSelected: selectedDate == NotificationDateFilter.thisWeek,
                    onTap: () => onDateChanged(NotificationDateFilter.thisWeek),
                    activeColor: activeColor,
                  ),
                  const SizedBox(width: 6),
                  _buildDateChip(
                    label: 'Earlier',
                    isSelected: selectedDate == NotificationDateFilter.earlier,
                    onTap: () => onDateChanged(NotificationDateFilter.earlier),
                    activeColor: activeColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
    required IconData icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : const Color(0xFFCBD5E1),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? activeColor : const Color(0xFF64748B),
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/chat_model.dart';
import '../../providers/theme_provider.dart';

class ChatRoomTile extends StatelessWidget {
  final ChatRoom room;
  final String currentUserId;
  final bool isSelected;
  final bool isArchived;
  final VoidCallback onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onUnarchive;
  final VoidCallback? onDelete;

  const ChatRoomTile({
    super.key,
    required this.room,
    required this.currentUserId,
    required this.isSelected,
    this.isArchived = false,
    required this.onTap,
    this.onArchive,
    this.onUnarchive,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final name = room.displayName(currentUserId);
    final unread = room.unreadCount(currentUserId);
    final lastMsg = room.lastMessage ?? '';
    final time = room.lastMessageAt;
    final otherParticipant = room.participants
        .where((p) => p.userId != currentUserId)
        .firstOrNull;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? (themeProvider.isDarkMode
                ? themeProvider.primaryColor.withValues(alpha: 0.2)
                : const Color(0xFF0F766E).withValues(alpha: 0.12))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(
                color: themeProvider.isDarkMode
                    ? themeProvider.primaryColor.withValues(alpha: 0.5)
                    : const Color(0xFF0F766E).withValues(alpha: 0.3),
              )
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _buildAvatar(name, otherParticipant, themeProvider),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: themeProvider.isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF134E4A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (time != null)
                          Text(
                            _formatTime(time),
                            style: TextStyle(
                              fontSize: 11,
                              color: unread > 0
                                  ? (themeProvider.isDarkMode
                                      ? Colors.tealAccent.shade400
                                      : const Color(0xFF0F766E))
                                  : themeProvider.subtitleColor,
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMsg.isEmpty ? 'No messages yet' : lastMsg,
                            style: TextStyle(
                              fontSize: 12,
                              color: unread > 0
                                  ? (themeProvider.isDarkMode
                                      ? Colors.white70
                                      : const Color(0xFF134E4A))
                                  : themeProvider.subtitleColor,
                              fontWeight: unread > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: themeProvider.isDarkMode
                                  ? const Color(0xFF0D9488)
                                  : const Color(0xFF0F766E),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (room.workRequestId != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.link_rounded,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
                tooltip: 'Options',
                padding: EdgeInsets.zero,
                splashRadius: 18,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'archive') {
                    onArchive?.call();
                  } else if (value == 'unarchive') {
                    onUnarchive?.call();
                  } else if (value == 'delete') {
                    onDelete?.call();
                  }
                },
                itemBuilder: (context) => [
                  if (!isArchived)
                    const PopupMenuItem(
                      value: 'archive',
                      height: 38,
                      child: Row(
                        children: [
                          Icon(Icons.archive_outlined, size: 18, color: Color(0xFF0F766E)),
                          SizedBox(width: 10),
                          Text(
                            'Archive Chat',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  else
                    const PopupMenuItem(
                      value: 'unarchive',
                      height: 38,
                      child: Row(
                        children: [
                          Icon(Icons.unarchive_outlined, size: 18, color: Color(0xFF0F766E)),
                          SizedBox(width: 10),
                          Text(
                            'Unarchive Chat',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  const PopupMenuDivider(height: 1),
                  const PopupMenuItem(
                    value: 'delete',
                    height: 38,
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                        SizedBox(width: 10),
                        Text(
                          'Delete Conversation',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, ChatParticipant? participant, ThemeProvider themeProvider) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final profileImage = participant?.profileImage;

    return Stack(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: themeProvider.isDarkMode
              ? themeProvider.primaryColor.withValues(alpha: 0.25)
              : const Color(0xFF0F766E).withValues(alpha: 0.15),
          backgroundImage:
              profileImage != null ? NetworkImage(profileImage) : null,
          child: profileImage == null
              ? Text(
                  initials,
                  style: TextStyle(
                    color: themeProvider.isDarkMode
                        ? Colors.tealAccent.shade200
                        : const Color(0xFF0F766E),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                )
              : null,
        ),
        if (room.workRequestId != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF0369A1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.build_rounded,
                  size: 8, color: Colors.white),
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays == 0) return DateFormat('HH:mm').format(time);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEE').format(time);
    return DateFormat('MMM d').format(time);
  }
}

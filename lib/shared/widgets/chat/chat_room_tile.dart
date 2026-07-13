import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chat_model.dart';

class ChatRoomTile extends StatelessWidget {
  final ChatRoom room;
  final String currentUserId;
  final bool isSelected;
  final VoidCallback onTap;

  const ChatRoomTile({
    super.key,
    required this.room,
    required this.currentUserId,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
            ? const Color(0xFF0F766E).withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.3))
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _buildAvatar(name, otherParticipant),
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
                              color: const Color(0xFF134E4A),
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
                                  ? const Color(0xFF0F766E)
                                  : Colors.grey.shade500,
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
                                  ? const Color(0xFF134E4A)
                                  : Colors.grey.shade600,
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
                              color: const Color(0xFF0F766E),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, ChatParticipant? participant) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final profileImage = participant?.profileImage;

    return Stack(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
          backgroundImage:
              profileImage != null ? NetworkImage(profileImage) : null,
          child: profileImage == null
              ? Text(
                  initials,
                  style: const TextStyle(
                    color: Color(0xFF0F766E),
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

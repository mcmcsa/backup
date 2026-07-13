import 'package:flutter/foundation.dart';

enum MessageType { text, image, voice, file, system }
enum ChatRoomType { direct, group }

// ──────────────────────────────────────────────────────────────
// ChatRoom
// ──────────────────────────────────────────────────────────────
class ChatRoom {
  final String id;
  final String? name;
  final ChatRoomType type;
  final String? workRequestId;
  final String? createdBy;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Derived/joined fields
  final List<ChatParticipant> participants;

  const ChatRoom({
    required this.id,
    this.name,
    required this.type,
    this.workRequestId,
    this.createdBy,
    this.lastMessage,
    this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
    this.participants = const [],
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as String,
      name: json['name'] as String?,
      type: json['type'] == 'group' ? ChatRoomType.group : ChatRoomType.direct,
      workRequestId: json['work_request_id'] as String?,
      createdBy: json['created_by'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      participants: (json['chat_participants'] as List<dynamic>? ?? [])
          .map((p) => ChatParticipant.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Return the display name for this room from the perspective of [currentUserId].
  String displayName(String currentUserId) {
    if (name != null && name!.isNotEmpty) return name!;
    final other = participants.where((p) => p.userId != currentUserId).toList();
    if (other.isEmpty) return 'Unknown';
    return other.map((p) => p.userName ?? 'User').join(', ');
  }

  /// Unread count relative to current user
  int unreadCount(String currentUserId) {
    return participants
        .where((p) => p.userId == currentUserId)
        .map((p) => p.unreadCount)
        .fold(0, (a, b) => a + b);
  }
}

// ──────────────────────────────────────────────────────────────
// ChatParticipant
// ──────────────────────────────────────────────────────────────
class ChatParticipant {
  final String id;
  final String roomId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final DateTime? lastReadAt;
  final int unreadCount;

  // Joined from users table
  final String? userName;
  final String? userEmail;
  final String? profileImage;

  const ChatParticipant({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.lastReadAt,
    this.unreadCount = 0,
    this.userName,
    this.userEmail,
    this.profileImage,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'teacher',
      joinedAt: DateTime.parse(json['joined_at'] as String),
      lastReadAt: json['last_read_at'] != null
          ? DateTime.parse(json['last_read_at'] as String)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      userName: json['users']?['name'] as String?,
      userEmail: json['users']?['email'] as String?,
      profileImage: json['users']?['profile_image'] as String?,
    );
  }
}

// ──────────────────────────────────────────────────────────────
// ChatMessage
// ──────────────────────────────────────────────────────────────
class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String? content;
  final MessageType messageType;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? replyToId;
  final String? replyToContent;
  final String? replyToSenderName;
  final bool isForwarded;
  final bool isPinned;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    this.content,
    required this.messageType,
    this.attachmentUrl,
    this.attachmentName,
    this.replyToId,
    this.replyToContent,
    this.replyToSenderName,
    this.isForwarded = false,
    this.isPinned = false,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String? ?? 'Unknown',
      senderRole: json['sender_role'] as String? ?? 'teacher',
      content: json['content'] as String?,
      messageType: _parseType(json['message_type'] as String? ?? 'text'),
      attachmentUrl: json['attachment_url'] as String?,
      attachmentName: json['attachment_name'] as String?,
      replyToId: json['reply_to_id'] as String?,
      replyToContent: json['reply_to_content'] as String?,
      replyToSenderName: json['reply_to_sender_name'] as String?,
      isForwarded: json['is_forwarded'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static MessageType _parseType(String t) {
    switch (t) {
      case 'image':  return MessageType.image;
      case 'voice':  return MessageType.voice;
      case 'file':   return MessageType.file;
      case 'system': return MessageType.system;
      default:       return MessageType.text;
    }
  }

  String get typeString {
    switch (messageType) {
      case MessageType.image:  return 'image';
      case MessageType.voice:  return 'voice';
      case MessageType.file:   return 'file';
      case MessageType.system: return 'system';
      default:                 return 'text';
    }
  }

  String get previewText {
    if (isDeleted) return '🗑 Message deleted';
    switch (messageType) {
      case MessageType.image:  return '📷 Image';
      case MessageType.voice:  return '🎤 Voice message';
      case MessageType.file:   return '📎 ${attachmentName ?? 'File'}';
      case MessageType.system: return content ?? '';
      default:                 return content ?? '';
    }
  }

  ChatMessage copyWith({bool? isPinned, bool? isDeleted}) {
    return ChatMessage(
      id: id,
      roomId: roomId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      content: content,
      messageType: messageType,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      replyToId: replyToId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
      isForwarded: isForwarded,
      isPinned: isPinned ?? this.isPinned,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

// ──────────────────────────────────────────────────────────────
// TypingIndicator
// ──────────────────────────────────────────────────────────────
@immutable
class TypingIndicator {
  final String roomId;
  final String userId;
  final String userName;
  final bool isTyping;

  const TypingIndicator({
    required this.roomId,
    required this.userId,
    required this.userName,
    required this.isTyping,
  });

  factory TypingIndicator.fromJson(Map<String, dynamic> json) {
    return TypingIndicator(
      roomId: json['room_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? 'Someone',
      isTyping: json['is_typing'] as bool? ?? false,
    );
  }
}

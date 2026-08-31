class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final String targetRole;
  final String? targetUserId;
  final String? workRequestId;
  final String? chatRoomId;
  final String? targetPage;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.targetRole,
    this.targetUserId,
    this.workRequestId,
    this.chatRoomId,
    this.targetPage,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    final targetPageStr = map['target_page']?.toString();
    String? parsedChatRoomId;
    if (targetPageStr != null && targetPageStr.startsWith('chat_room_id:')) {
      parsedChatRoomId = targetPageStr.replaceFirst('chat_room_id:', '');
    }
    return AppNotification(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'info',
      targetRole: map['target_role'] ?? 'all',
      targetUserId: map['target_user_id']?.toString(),
      workRequestId: map['work_request_id']?.toString(),
      chatRoomId: parsedChatRoomId ?? map['chat_room_id']?.toString(),
      targetPage: targetPageStr,
      isRead: map['is_read'] ?? false,
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'target_role': targetRole,
      'target_user_id': targetUserId,
      'work_request_id': workRequestId,
      'chat_room_id': chatRoomId,
      'target_page': targetPage,
      'is_read': isRead,
    };
  }
}

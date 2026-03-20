class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final String targetRole;
  final String? targetUserId;
  final String? workRequestId;
  final String? statusSnapshot;
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
    this.statusSnapshot,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'info',
      targetRole: map['target_role'] ?? 'all',
      targetUserId: map['target_user_id']?.toString(),
      workRequestId: map['work_request_id']?.toString(),
      statusSnapshot: map['status_snapshot'],
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
      'status_snapshot': statusSnapshot,
      'is_read': isRead,
    };
  }
}

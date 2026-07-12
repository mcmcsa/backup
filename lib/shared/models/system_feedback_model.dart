class SystemFeedback {
  final String id;
  final String userId;
  final String userName;
  final String category; // 'Bug Report', 'Feature Request', 'General Feedback', 'Other'
  final String message;
  final String status; // 'pending', 'resolved'
  final String? adminReply;
  final DateTime createdAt;

  SystemFeedback({
    required this.id,
    required this.userId,
    required this.userName,
    required this.category,
    required this.message,
    required this.status,
    this.adminReply,
    required this.createdAt,
  });

  factory SystemFeedback.fromMap(Map<String, dynamic> map) {
    return SystemFeedback(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      userName: map['user_name'] ?? 'Unknown User',
      category: map['category'] ?? 'General Feedback',
      message: map['message'] ?? '',
      status: map['status'] ?? 'pending',
      adminReply: map['admin_reply'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'category': category,
      'message': message,
      'status': status,
      'admin_reply': adminReply,
      'created_at': createdAt.toIso8601String(),
    };
  }

  SystemFeedback copyWith({
    String? id,
    String? userId,
    String? userName,
    String? category,
    String? message,
    String? status,
    String? adminReply,
    DateTime? createdAt,
  }) {
    return SystemFeedback(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      category: category ?? this.category,
      message: message ?? this.message,
      status: status ?? this.status,
      adminReply: adminReply ?? this.adminReply,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SystemAnnouncement {
  final String id;
  final String title;
  final String content;
  final String priority; // 'low', 'normal', 'high', 'urgent'
  final String status; // 'draft', 'published', 'expired'
  final DateTime? scheduledFor;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  SystemAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    this.priority = 'normal',
    this.status = 'draft',
    this.scheduledFor,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory SystemAnnouncement.fromMap(Map<String, dynamic> map) {
    return SystemAnnouncement(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      priority: map['priority'] ?? 'normal',
      status: map['status'] ?? 'draft',
      scheduledFor: map['scheduled_for'] != null ? DateTime.parse(map['scheduled_for']) : null,
      expiresAt: map['expires_at'] != null ? DateTime.parse(map['expires_at']) : null,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
      createdBy: map['created_by'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'priority': priority,
      'status': status,
      'scheduled_for': scheduledFor?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  SystemAnnouncement copyWith({
    String? id,
    String? title,
    String? content,
    String? priority,
    String? status,
    DateTime? scheduledFor,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return SystemAnnouncement(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  bool get isPublished => status == 'published' && (scheduledFor == null || scheduledFor!.isBefore(DateTime.now()));
  bool get isExpired => status == 'expired' || (expiresAt != null && expiresAt!.isBefore(DateTime.now()));
  bool get isScheduled => status == 'published' && scheduledFor != null && scheduledFor!.isAfter(DateTime.now());
}

import 'dart:convert';

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
  final bool isPinned;
  final List<String> targetAudience; // e.g., ['faculty', 'maintenance', 'campus_admin', 'all']
  final String displayType; // 'banner', 'popup', 'notification'

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
    this.isPinned = false,
    this.targetAudience = const ['all'],
    this.displayType = 'notification',
  });

  /// Encodes UI metadata (isPinned, targetAudience, displayType) into content prefix
  /// so that tables without these specific columns can store and retrieve them seamlessly.
  static String encodeContent(
    String rawText, {
    bool isPinned = false,
    List<String> targetAudience = const ['all'],
    String displayType = 'notification',
  }) {
    final trimmed = rawText.trim();
    final bool isDefaultAudience = targetAudience.isEmpty ||
        (targetAudience.length == 1 && targetAudience.first.toLowerCase() == 'all');

    if (!isPinned && isDefaultAudience && displayType == 'notification') {
      return trimmed;
    }

    final meta = <String, dynamic>{};
    if (isPinned) meta['p'] = true;
    if (!isDefaultAudience) meta['a'] = targetAudience;
    if (displayType != 'notification') meta['t'] = displayType;

    return '<!--meta:${jsonEncode(meta)}-->\n$trimmed';
  }

  factory SystemAnnouncement.fromMap(Map<String, dynamic> map) {
    String content = (map['content'] ?? '').toString();
    bool parsedPinned = false;
    List<String> parsedAudience = const ['all'];
    String parsedDisplayType = 'notification';

    if (content.startsWith('<!--meta:') && content.contains('-->')) {
      try {
        final endIdx = content.indexOf('-->');
        final jsonStr = content.substring('<!--meta:'.length, endIdx);
        final meta = jsonDecode(jsonStr) as Map<String, dynamic>;
        content = content.substring(endIdx + 3).replaceFirst(RegExp(r'^\r?\n'), '');
        if (meta['p'] == true) parsedPinned = true;
        if (meta['a'] != null) parsedAudience = List<String>.from(meta['a']);
        if (meta['t'] != null) parsedDisplayType = meta['t'].toString();
      } catch (_) {}
    }

    return SystemAnnouncement(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? '',
      content: content,
      priority: map['priority'] ?? 'normal',
      status: map['status'] ?? 'draft',
      scheduledFor: map['scheduled_for'] != null ? DateTime.tryParse(map['scheduled_for'].toString()) : null,
      expiresAt: map['expires_at'] != null ? DateTime.tryParse(map['expires_at'].toString()) : null,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
      createdBy: map['created_by'] ?? '',
      isPinned: map['is_pinned'] == true || parsedPinned,
      targetAudience: map['target_audience'] != null
          ? List<String>.from(map['target_audience'])
          : parsedAudience,
      displayType: map['display_type'] ?? parsedDisplayType,
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
      'is_pinned': isPinned,
      'target_audience': targetAudience,
      'display_type': displayType,
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
    bool? isPinned,
    List<String>? targetAudience,
    String? displayType,
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
      isPinned: isPinned ?? this.isPinned,
      targetAudience: targetAudience ?? this.targetAudience,
      displayType: displayType ?? this.displayType,
    );
  }

  bool get isPublished => status == 'published' && (scheduledFor == null || scheduledFor!.isBefore(DateTime.now()));
  bool get isExpired => status == 'expired' || (expiresAt != null && expiresAt!.isBefore(DateTime.now()));
  bool get isScheduled => status == 'published' && scheduledFor != null && scheduledFor!.isAfter(DateTime.now());
}


class WorkRequestCollaborator {
  final String id;
  final String workRequestId;
  final String userId;
  final String role; // 'primary', 'secondary'
  final String status; // 'pending', 'accepted', 'rejected', 'removed'
  final DateTime invitedAt;
  final DateTime? respondedAt;
  
  // Joined fields
  final String? userName;
  final String? userSpecialization;

  WorkRequestCollaborator({
    required this.id,
    required this.workRequestId,
    required this.userId,
    required this.role,
    required this.status,
    required this.invitedAt,
    this.respondedAt,
    this.userName,
    this.userSpecialization,
  });

  factory WorkRequestCollaborator.fromJson(Map<String, dynamic> json) {
    return WorkRequestCollaborator(
      id: json['id'],
      workRequestId: json['work_request_id'],
      userId: json['user_id'],
      role: json['role'],
      status: json['status'],
      invitedAt: DateTime.parse(json['invited_at']),
      respondedAt: json['responded_at'] != null ? DateTime.parse(json['responded_at']) : null,
      userName: json['maintenance_users']?['users']?['name'] ?? json['users']?['name'],
      userSpecialization: json['maintenance_users']?['specialization'],
    );
  }
}

class WorkRequestTask {
  final String id;
  final String workRequestId;
  final String taskDescription;
  final bool isCompleted;
  final String? completedById;
  final String? createdById;
  final DateTime createdAt;
  final DateTime? completedAt;

  // Joined fields
  final String? completedByName;
  final String? createdByName;

  WorkRequestTask({
    required this.id,
    required this.workRequestId,
    required this.taskDescription,
    this.isCompleted = false,
    this.completedById,
    this.createdById,
    required this.createdAt,
    this.completedAt,
    this.completedByName,
    this.createdByName,
  });

  factory WorkRequestTask.fromJson(Map<String, dynamic> json) {
    return WorkRequestTask(
      id: json['id'],
      workRequestId: json['work_request_id'],
      taskDescription: json['task_description'],
      isCompleted: json['is_completed'] ?? false,
      completedById: json['completed_by'],
      createdById: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      completedByName: json['completed_by_user']?['name'],
      createdByName: json['created_by_user']?['name'],
    );
  }
}

class WorkRequestNote {
  final String id;
  final String workRequestId;
  final String authorId;
  final String content;
  final List<String> attachmentUrls;
  final List<String> voiceNotes;
  final DateTime createdAt;

  // Joined fields
  final String? authorName;

  WorkRequestNote({
    required this.id,
    required this.workRequestId,
    required this.authorId,
    required this.content,
    this.attachmentUrls = const [],
    this.voiceNotes = const [],
    required this.createdAt,
    this.authorName,
  });

  factory WorkRequestNote.fromJson(Map<String, dynamic> json) {
    return WorkRequestNote(
      id: json['id'],
      workRequestId: json['work_request_id'],
      authorId: json['author_id'],
      content: json['content'],
      attachmentUrls: List<String>.from(json['attachment_urls'] ?? []),
      voiceNotes: List<String>.from(json['voice_notes'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
      authorName: json['users']?['name'],
    );
  }
}

class WorkRequestActivity {
  final String id;
  final String workRequestId;
  final String? actorId;
  final String actionType;
  final String? details;
  final DateTime createdAt;

  // Joined fields
  final String? actorName;

  WorkRequestActivity({
    required this.id,
    required this.workRequestId,
    this.actorId,
    required this.actionType,
    this.details,
    required this.createdAt,
    this.actorName,
  });

  factory WorkRequestActivity.fromJson(Map<String, dynamic> json) {
    return WorkRequestActivity(
      id: json['id'],
      workRequestId: json['work_request_id'],
      actorId: json['actor_id'],
      actionType: json['action_type'],
      details: json['details'],
      createdAt: DateTime.parse(json['created_at']),
      actorName: json['users']?['name'],
    );
  }
}

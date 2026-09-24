class WorkRequestFollowUp {
  final String id;
  final String workRequestId;
  final String requestorId;
  final String? requestorName;
  final String message;
  final String targetStage; // 'dept_head' or 'campus_admin'
  final String? recipientUserId;
  final String status; // 'pending', 'acknowledged', 'replied'
  final String? adminResponse;
  final String? respondedBy;
  final String? responderName;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkRequestFollowUp({
    required this.id,
    required this.workRequestId,
    required this.requestorId,
    this.requestorName,
    required this.message,
    this.targetStage = 'dept_head',
    this.recipientUserId,
    this.status = 'pending',
    this.adminResponse,
    this.respondedBy,
    this.responderName,
    this.respondedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkRequestFollowUp.fromMap(Map<String, dynamic> map) {
    return WorkRequestFollowUp(
      id: map['id']?.toString() ?? '',
      workRequestId: map['work_request_id']?.toString() ?? '',
      requestorId: map['requestor_id']?.toString() ?? '',
      requestorName: map['requestor'] is Map ? map['requestor']['name']?.toString() : null,
      message: map['message']?.toString() ?? '',
      targetStage: map['target_stage']?.toString() ?? 'dept_head',
      recipientUserId: map['recipient_user_id']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      adminResponse: map['admin_response']?.toString(),
      respondedBy: map['responded_by']?.toString(),
      responderName: map['responder'] is Map ? map['responder']['name']?.toString() : null,
      respondedAt: map['responded_at'] != null ? DateTime.tryParse(map['responded_at'].toString()) : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'work_request_id': workRequestId,
      'requestor_id': requestorId,
      'message': message,
      'target_stage': targetStage,
      if (recipientUserId != null) 'recipient_user_id': recipientUserId,
      'status': status,
      if (adminResponse != null) 'admin_response': adminResponse,
      if (respondedBy != null) 'responded_by': respondedBy,
      if (respondedAt != null) 'responded_at': respondedAt?.toIso8601String(),
    };
  }

  String get targetStageLabel {
    switch (targetStage) {
      case 'dept_head':
        return 'Department Head';
      case 'campus_admin':
        return 'Campus Admin';
      default:
        return targetStage;
    }
  }

  bool get isReplied => status == 'replied' || (adminResponse != null && adminResponse!.isNotEmpty);

  String? get response => adminResponse;

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'PENDING';
      case 'acknowledged':
        return 'ACKNOWLEDGED';
      case 'replied':
        return 'REPLIED';
      default:
        return status.toUpperCase();
    }
  }
}

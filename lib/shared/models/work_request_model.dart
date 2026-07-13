class WorkRequest {
  final String id;
  final String title;
  final String description;
  final String
  status; // 'pending', 'approved', 'in_progress', 'under_maintenance', 'completed', 'rework', 'cancelled'
  final String priority; // 'low', 'medium', 'high'
  final String? buildingId;
  final String? buildingName;
  final String? departmentId;
  final String? departmentName;
  final String? roomId;
  final String? roomName;
  final String? requestTypeId;
  final String typeOfRequest;
  final DateTime dateSubmitted;
  final DateTime? dateCompleted;
  final DateTime? dateDue;
  final String requestorName;
  final String requestorPosition;
  final String? requestorId;
  final String? approvedById;
  final DateTime? approvedDate;
  final String? approvedByName;
  final String? reportedById;
  final String? reportedByName;
  final String? assignedToId;
  final String? workEvidence;
  final String? maintenanceNotes;
  final List<String>? attachmentUrls;
  final List<String>? voiceNotes;
  // New workflow fields
  final String? acceptedById;
  final String? acceptedByName;
  final DateTime? acceptedDate;
  final DateTime? maintenanceStartTime;
  final DateTime? maintenanceEndTime;
  final String? preInspectionId;
  final String? postRepairId;
  final int reworkCount;
  final String? reworkNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WorkRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.priority = 'medium',
    this.buildingId,
    this.buildingName,
    this.departmentId,
    this.departmentName,
    this.roomId,
    this.roomName,
    this.requestTypeId,
    required this.typeOfRequest,
    required this.dateSubmitted,
    this.dateCompleted,
    this.dateDue,
    required this.requestorName,
    required this.requestorPosition,
    this.requestorId,
    this.approvedById,
    this.approvedDate,
    this.approvedByName,
    this.reportedById,
    this.reportedByName,
    this.assignedToId,
    this.workEvidence,
    this.maintenanceNotes,
    this.attachmentUrls,
    this.voiceNotes,
    this.acceptedById,
    this.acceptedByName,
    this.acceptedDate,
    this.maintenanceStartTime,
    this.maintenanceEndTime,
    this.preInspectionId,
    this.postRepairId,
    this.reworkCount = 0,
    this.reworkNotes,
    this.createdAt,
    this.updatedAt,
  });

  factory WorkRequest.fromMap(Map<String, dynamic> map) {
    return WorkRequest(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      status: map['status'] ?? 'pending',
      priority: map['priority'] ?? 'medium',
      buildingId: map['building_id'],
      buildingName:
          map['building_name'] ?? _nestedText(map['building'], 'name'),
      departmentId: map['department_id'],
      departmentName:
          map['department_name'] ?? _nestedText(map['department'], 'name'),
      roomId: map['room_id'],
      roomName: map['room_name'] ?? _nestedText(map['room'], 'name'),
      requestTypeId: map['request_type_id']?.toString(),
      typeOfRequest:
        map['type_of_request'] ??
        _nestedText(map['request_type'], 'name') ??
        '',
      dateSubmitted: DateTime.parse(
        map['date_submitted'] ?? DateTime.now().toIso8601String(),
      ),
      dateCompleted: map['date_completed'] != null
          ? DateTime.parse(map['date_completed'])
          : null,
      dateDue: map['date_due'] != null ? DateTime.parse(map['date_due']) : null,
      requestorName:
          map['requestor_name'] ??
          _nestedText(map['requestor'], 'name') ??
          '',
      requestorPosition: map['requestor_position'] ?? '',
      requestorId: map['requestor_id'],
      approvedById: map['approved_by_id'],
      approvedDate: map['approved_date'] != null
          ? DateTime.parse(map['approved_date'])
          : null,
      approvedByName: map['approved_by_name'] ?? _nestedText(map['approver'], 'name'),
      reportedById: map['reported_by_id'] ?? map['requestor_id'],
      reportedByName:
          map['reported_by_name'] ?? _nestedText(map['requestor'], 'name') ?? map['requestor_name'] ?? '',
      assignedToId: map['assigned_to_id'],
      workEvidence: map['work_evidence'],
      maintenanceNotes: map['maintenance_notes'],
      attachmentUrls: map['attachment_urls'] != null 
          ? List<String>.from(map['attachment_urls'])
          : null,
      voiceNotes: map['voice_notes'] != null 
          ? List<String>.from(map['voice_notes'])
          : null,
      acceptedById:
          map['accepted_by_id'] ??
          ((map['accepted_date'] != null) ? map['assigned_to_id'] : null),
      acceptedByName:
          map['accepted_by_name'] ?? _nestedText(map['assignee'], 'name'),
      acceptedDate: map['accepted_date'] != null
          ? DateTime.parse(map['accepted_date'])
          : null,
      maintenanceStartTime: map['maintenance_start_time'] != null
          ? DateTime.parse(map['maintenance_start_time'])
          : null,
      maintenanceEndTime: map['maintenance_end_time'] != null
          ? DateTime.parse(map['maintenance_end_time'])
          : null,
      preInspectionId:
          map['pre_inspection_id'] ?? _firstNestedId(map['pre_reports']),
      postRepairId: map['post_repair_id'] ?? _firstNestedId(map['post_reports']),
      reworkCount: map['rework_count'] ?? 0,
      reworkNotes: map['rework_notes'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
        'type_of_request': typeOfRequest,
      'request_type_id':
          requestTypeId ??
          (_isLikelyUuid(typeOfRequest) ? typeOfRequest : null),
      'building_id': buildingId,
      'department_id': departmentId,
      'room_id': roomId,
      'date_submitted': dateSubmitted.toIso8601String(),
      'date_completed': dateCompleted?.toIso8601String(),
      'date_due': dateDue?.toIso8601String(),
      'requestor_name': requestorName,
      'requestor_position': requestorPosition,
      'requestor_id': requestorId,
      'approved_by_id': approvedById,
      'approved_date': approvedDate?.toIso8601String(),
      'assigned_to_id': assignedToId,
      'accepted_date': acceptedDate?.toIso8601String(),
      'maintenance_start_time': maintenanceStartTime?.toIso8601String(),
      'maintenance_end_time': maintenanceEndTime?.toIso8601String(),
      'attachment_urls': attachmentUrls,
      'rework_count': reworkCount,
      'rework_notes': reworkNotes,
      // Don't include created_at on INSERT - database provides default
    };
  }

  WorkRequest copyWith({
    String? id,
    String? title,
    String? description,
    String? status,
    String? priority,
    String? buildingId,
    String? buildingName,
    String? departmentId,
    String? departmentName,
    String? roomId,
    String? roomName,
    String? requestTypeId,
    String? typeOfRequest,
    DateTime? dateSubmitted,
    DateTime? dateCompleted,
    DateTime? dateDue,
    String? requestorName,
    String? requestorPosition,
    String? requestorId,
    String? approvedById,
    DateTime? approvedDate,
    String? approvedByName,
    String? reportedById,
    String? reportedByName,
    String? assignedToId,
    String? workEvidence,
    String? maintenanceNotes,
    List<String>? attachmentUrls,
    List<String>? voiceNotes,
    String? acceptedById,
    String? acceptedByName,
    DateTime? acceptedDate,
    DateTime? maintenanceStartTime,
    DateTime? maintenanceEndTime,
    String? preInspectionId,
    String? postRepairId,
    int? reworkCount,
    String? reworkNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkRequest(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      buildingId: buildingId ?? this.buildingId,
      buildingName: buildingName ?? this.buildingName,
      departmentId: departmentId ?? this.departmentId,
      departmentName: departmentName ?? this.departmentName,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      requestTypeId: requestTypeId ?? this.requestTypeId,
      typeOfRequest: typeOfRequest ?? this.typeOfRequest,
      dateSubmitted: dateSubmitted ?? this.dateSubmitted,
      dateCompleted: dateCompleted ?? this.dateCompleted,
      dateDue: dateDue ?? this.dateDue,
      requestorName: requestorName ?? this.requestorName,
      requestorPosition: requestorPosition ?? this.requestorPosition,
      requestorId: requestorId ?? this.requestorId,
      approvedById: approvedById ?? this.approvedById,
      approvedDate: approvedDate ?? this.approvedDate,
        approvedByName: approvedByName ?? this.approvedByName,
      reportedById: reportedById ?? this.reportedById,
        reportedByName: reportedByName ?? this.reportedByName,
      assignedToId: assignedToId ?? this.assignedToId,
      workEvidence: workEvidence ?? this.workEvidence,
      maintenanceNotes: maintenanceNotes ?? this.maintenanceNotes,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      voiceNotes: voiceNotes ?? this.voiceNotes,
      acceptedById: acceptedById ?? this.acceptedById,
      acceptedByName: acceptedByName ?? this.acceptedByName,
      acceptedDate: acceptedDate ?? this.acceptedDate,
      maintenanceStartTime: maintenanceStartTime ?? this.maintenanceStartTime,
      maintenanceEndTime: maintenanceEndTime ?? this.maintenanceEndTime,
      preInspectionId: preInspectionId ?? this.preInspectionId,
      postRepairId: postRepairId ?? this.postRepairId,
      reworkCount: reworkCount ?? this.reworkCount,
      reworkNotes: reworkNotes ?? this.reworkNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedId => '#${id.padLeft(3, '0')}';

  String? get department => departmentName;
  String? get officeRoom => roomName;
  String? get reportedBy => reportedByName;
  String? get approvedBy => approvedByName;

  static bool _isLikelyUuid(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return false;
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return uuid.hasMatch(normalized);
  }

  static String? _nestedText(dynamic value, String key) {
    if (value is Map<String, dynamic>) {
      return value[key]?.toString();
    }
    if (value is List && value.isNotEmpty && value.first is Map<String, dynamic>) {
      return (value.first as Map<String, dynamic>)[key]?.toString();
    }
    return null;
  }

  static String? _firstNestedId(dynamic value) {
    if (value is List && value.isNotEmpty && value.first is Map<String, dynamic>) {
      return (value.first as Map<String, dynamic>)['id']?.toString();
    }
    if (value is Map<String, dynamic>) {
      return value['id']?.toString();
    }
    return null;
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'PENDING';
      case 'approved':
        return 'APPROVED';
      case 'in_progress':
        return 'IN PROGRESS';
      case 'under_maintenance':
        return 'UNDER MAINTENANCE';
      case 'completed':
        return 'COMPLETED';
      case 'rework':
        return 'REWORK';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return status.toUpperCase();
    }
  }

  String get priorityLabel {
    switch (priority) {
      case 'high':
        return 'HIGH PRIORITY';
      case 'medium':
        return 'MEDIUM';
      case 'low':
        return 'LOW';
      default:
        return priority.toUpperCase();
    }
  }
}

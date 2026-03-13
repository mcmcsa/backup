class WorkRequest {
  final String id;
  final String title;
  final String description;
  final String status; // 'pending', 'approved', 'in_progress', 'under_maintenance', 'completed', 'rework', 'cancelled'
  final String priority; // 'low', 'medium', 'high'
  final String campus;
  final String buildingName;
  final String? buildingId;
  final String department;
  final String? departmentId;
  final String officeRoom;
  final String? roomId;
  final String typeOfRequest;
  final DateTime dateSubmitted;
  final DateTime? dateCompleted;
  final DateTime? dateDue;
  final String requestorName;
  final String requestorPosition;
  final String? requestorId;
  final String? approvedBy;
  final String? approvedById;
  final DateTime? approvedDate;
  final String reportedBy;
  final String? reportedById;
  final String? assignedToId;
  final String? workEvidence;
  final String? maintenanceNotes;
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

  WorkRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.priority = 'medium',
    required this.campus,
    required this.buildingName,
    this.buildingId,
    required this.department,
    this.departmentId,
    required this.officeRoom,
    this.roomId,
    required this.typeOfRequest,
    required this.dateSubmitted,
    this.dateCompleted,
    this.dateDue,
    required this.requestorName,
    required this.requestorPosition,
    this.requestorId,
    this.approvedBy,
    this.approvedById,
    this.approvedDate,
    required this.reportedBy,
    this.reportedById,
    this.assignedToId,
    this.workEvidence,
    this.maintenanceNotes,
    this.acceptedById,
    this.acceptedByName,
    this.acceptedDate,
    this.maintenanceStartTime,
    this.maintenanceEndTime,
    this.preInspectionId,
    this.postRepairId,
    this.reworkCount = 0,
    this.reworkNotes,
  });

  factory WorkRequest.fromMap(Map<String, dynamic> map) {
    return WorkRequest(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      status: map['status'] ?? 'pending',
      priority: map['priority'] ?? 'medium',
      campus: map['campus'] ?? '',
      buildingName: map['building_name'] ?? '',
      buildingId: map['building_id'],
      department: map['department'] ?? '',
      departmentId: map['department_id'],
      officeRoom: map['office_room'] ?? '',
      roomId: map['room_id'],
      typeOfRequest: map['type_of_request'] ?? '',
      dateSubmitted: DateTime.parse(map['date_submitted'] ?? DateTime.now().toIso8601String()),
      dateCompleted:
          map['date_completed'] != null ? DateTime.parse(map['date_completed']) : null,
      dateDue: map['date_due'] != null ? DateTime.parse(map['date_due']) : null,
      requestorName: map['requestor_name'] ?? '',
      requestorPosition: map['requestor_position'] ?? '',
      requestorId: map['requestor_id'],
      approvedBy: map['approved_by'],
      approvedById: map['approved_by_id'],
      approvedDate:
          map['approved_date'] != null ? DateTime.parse(map['approved_date']) : null,
      reportedBy: map['reported_by'] ?? '',
      reportedById: map['reported_by_id'],
      assignedToId: map['assigned_to_id'],
      workEvidence: map['work_evidence'],
      maintenanceNotes: map['maintenance_notes'],
      acceptedById: map['accepted_by_id'],
      acceptedByName: map['accepted_by_name'],
      acceptedDate: map['accepted_date'] != null ? DateTime.parse(map['accepted_date']) : null,
      maintenanceStartTime: map['maintenance_start_time'] != null ? DateTime.parse(map['maintenance_start_time']) : null,
      maintenanceEndTime: map['maintenance_end_time'] != null ? DateTime.parse(map['maintenance_end_time']) : null,
      preInspectionId: map['pre_inspection_id'],
      postRepairId: map['post_repair_id'],
      reworkCount: map['rework_count'] ?? 0,
      reworkNotes: map['rework_notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'campus': campus,
      'building_name': buildingName,
      'building_id': buildingId,
      'department': department,
      'department_id': departmentId,
      'office_room': officeRoom,
      'room_id': roomId,
      'type_of_request': typeOfRequest,
      'date_submitted': dateSubmitted.toIso8601String(),
      'date_completed': dateCompleted?.toIso8601String(),
      'date_due': dateDue?.toIso8601String(),
      'requestor_name': requestorName,
      'requestor_position': requestorPosition,
      'requestor_id': requestorId,
      'approved_by': approvedBy,
      'approved_by_id': approvedById,
      'approved_date': approvedDate?.toIso8601String(),
      'reported_by': reportedBy,
      'reported_by_id': reportedById,
      'assigned_to_id': assignedToId,
      'work_evidence': workEvidence,
      'maintenance_notes': maintenanceNotes,
      'accepted_by_id': acceptedById,
      'accepted_by_name': acceptedByName,
      'accepted_date': acceptedDate?.toIso8601String(),
      'maintenance_start_time': maintenanceStartTime?.toIso8601String(),
      'maintenance_end_time': maintenanceEndTime?.toIso8601String(),
      'pre_inspection_id': preInspectionId,
      'post_repair_id': postRepairId,
      'rework_count': reworkCount,
      'rework_notes': reworkNotes,
    };
  }

  WorkRequest copyWith({
    String? id,
    String? title,
    String? description,
    String? status,
    String? priority,
    String? campus,
    String? buildingName,
    String? buildingId,
    String? department,
    String? departmentId,
    String? officeRoom,
    String? roomId,
    String? typeOfRequest,
    DateTime? dateSubmitted,
    DateTime? dateCompleted,
    DateTime? dateDue,
    String? requestorName,
    String? requestorPosition,
    String? requestorId,
    String? approvedBy,
    String? approvedById,
    DateTime? approvedDate,
    String? reportedBy,
    String? reportedById,
    String? assignedToId,
    String? workEvidence,
    String? maintenanceNotes,
    String? acceptedById,
    String? acceptedByName,
    DateTime? acceptedDate,
    DateTime? maintenanceStartTime,
    DateTime? maintenanceEndTime,
    String? preInspectionId,
    String? postRepairId,
    int? reworkCount,
    String? reworkNotes,
  }) {
    return WorkRequest(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      campus: campus ?? this.campus,
      buildingName: buildingName ?? this.buildingName,
      buildingId: buildingId ?? this.buildingId,
      department: department ?? this.department,
      departmentId: departmentId ?? this.departmentId,
      officeRoom: officeRoom ?? this.officeRoom,
      roomId: roomId ?? this.roomId,
      typeOfRequest: typeOfRequest ?? this.typeOfRequest,
      dateSubmitted: dateSubmitted ?? this.dateSubmitted,
      dateCompleted: dateCompleted ?? this.dateCompleted,
      dateDue: dateDue ?? this.dateDue,
      requestorName: requestorName ?? this.requestorName,
      requestorPosition: requestorPosition ?? this.requestorPosition,
      requestorId: requestorId ?? this.requestorId,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedById: approvedById ?? this.approvedById,
      approvedDate: approvedDate ?? this.approvedDate,
      reportedBy: reportedBy ?? this.reportedBy,
      reportedById: reportedById ?? this.reportedById,
      assignedToId: assignedToId ?? this.assignedToId,
      workEvidence: workEvidence ?? this.workEvidence,
      maintenanceNotes: maintenanceNotes ?? this.maintenanceNotes,
      acceptedById: acceptedById ?? this.acceptedById,
      acceptedByName: acceptedByName ?? this.acceptedByName,
      acceptedDate: acceptedDate ?? this.acceptedDate,
      maintenanceStartTime: maintenanceStartTime ?? this.maintenanceStartTime,
      maintenanceEndTime: maintenanceEndTime ?? this.maintenanceEndTime,
      preInspectionId: preInspectionId ?? this.preInspectionId,
      postRepairId: postRepairId ?? this.postRepairId,
      reworkCount: reworkCount ?? this.reworkCount,
      reworkNotes: reworkNotes ?? this.reworkNotes,
    );
  }

  String get formattedId => '#${id.padLeft(3, '0')}';

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
      // Legacy statuses
      case 'ongoing':
        return 'IN PROGRESS';
      case 'done':
        return 'COMPLETED';
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


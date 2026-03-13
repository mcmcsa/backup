class PreInspectionReport {
  final String id;
  final String workRequestId;
  final String inspectorId;
  final String inspectorName;
  final DateTime inspectionDate;
  final String conditionFound;
  final String? description;
  final String? rootCause;
  final String severityLevel; // 'Minor', 'Moderate', 'Critical'
  final String? recommendedAction;
  final String? materialsNeeded; // JSON string array
  final String? estimatedTime;
  final String? photoEvidence; // JSON string array
  final bool adminApproved;
  final String? adminApprovedBy;
  final DateTime? adminApprovedDate;
  final String status; // 'submitted', 'approved', 'rejected'
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  PreInspectionReport({
    required this.id,
    required this.workRequestId,
    required this.inspectorId,
    required this.inspectorName,
    required this.inspectionDate,
    required this.conditionFound,
    this.description,
    this.rootCause,
    this.severityLevel = 'Minor',
    this.recommendedAction,
    this.materialsNeeded,
    this.estimatedTime,
    this.photoEvidence,
    this.adminApproved = false,
    this.adminApprovedBy,
    this.adminApprovedDate,
    this.status = 'submitted',
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory PreInspectionReport.fromMap(Map<String, dynamic> map) {
    return PreInspectionReport(
      id: map['id']?.toString() ?? '',
      workRequestId: map['work_request_id']?.toString() ?? '',
      inspectorId: map['inspector_id']?.toString() ?? '',
      inspectorName: map['inspector_name'] ?? '',
      inspectionDate: DateTime.parse(map['inspection_date'] ?? DateTime.now().toIso8601String()),
      conditionFound: map['condition_found'] ?? '',
      description: map['description'],
      rootCause: map['root_cause'],
      severityLevel: map['severity_level'] ?? 'Minor',
      recommendedAction: map['recommended_action'],
      materialsNeeded: map['materials_needed'],
      estimatedTime: map['estimated_time'],
      photoEvidence: map['photo_evidence'],
      adminApproved: map['admin_approved'] ?? false,
      adminApprovedBy: map['admin_approved_by']?.toString(),
      adminApprovedDate: map['admin_approved_date'] != null
          ? DateTime.parse(map['admin_approved_date'])
          : null,
      status: map['status'] ?? 'submitted',
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'work_request_id': workRequestId,
      'inspector_id': inspectorId,
      'inspector_name': inspectorName,
      'inspection_date': inspectionDate.toIso8601String(),
      'condition_found': conditionFound,
      'description': description,
      'root_cause': rootCause,
      'severity_level': severityLevel,
      'recommended_action': recommendedAction,
      'materials_needed': materialsNeeded,
      'estimated_time': estimatedTime,
      'photo_evidence': photoEvidence,
      'admin_approved': adminApproved,
      'admin_approved_by': adminApprovedBy,
      'admin_approved_date': adminApprovedDate?.toIso8601String(),
      'status': status,
      'notes': notes,
    };
  }

  PreInspectionReport copyWith({
    String? id,
    String? workRequestId,
    String? inspectorId,
    String? inspectorName,
    DateTime? inspectionDate,
    String? conditionFound,
    String? description,
    String? rootCause,
    String? severityLevel,
    String? recommendedAction,
    String? materialsNeeded,
    String? estimatedTime,
    String? photoEvidence,
    bool? adminApproved,
    String? adminApprovedBy,
    DateTime? adminApprovedDate,
    String? status,
    String? notes,
  }) {
    return PreInspectionReport(
      id: id ?? this.id,
      workRequestId: workRequestId ?? this.workRequestId,
      inspectorId: inspectorId ?? this.inspectorId,
      inspectorName: inspectorName ?? this.inspectorName,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      conditionFound: conditionFound ?? this.conditionFound,
      description: description ?? this.description,
      rootCause: rootCause ?? this.rootCause,
      severityLevel: severityLevel ?? this.severityLevel,
      recommendedAction: recommendedAction ?? this.recommendedAction,
      materialsNeeded: materialsNeeded ?? this.materialsNeeded,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      photoEvidence: photoEvidence ?? this.photoEvidence,
      adminApproved: adminApproved ?? this.adminApproved,
      adminApprovedBy: adminApprovedBy ?? this.adminApprovedBy,
      adminApprovedDate: adminApprovedDate ?? this.adminApprovedDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'submitted':
        return 'SUBMITTED';
      case 'approved':
        return 'APPROVED';
      case 'rejected':
        return 'REJECTED';
      default:
        return status.toUpperCase();
    }
  }
}

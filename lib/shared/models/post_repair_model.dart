class PostRepairReport {
  final String id;
  final String workRequestId;
  final int attemptNumber;
  final String technicianId;
  final String technicianName;
  final DateTime repairDate;
  final String workPerformed;
  final String? materialsUsed; // JSON string array
  final String? photoBefore; // JSON string array
  final String? photoAfter; // JSON string array
  final String? repairDuration;
  final String repairStatus; // 'completed', 'partial', 'needs_followup'
  final String? technicianNotes;
  final String? adminEvaluation; // 'satisfied', 'rework'
  final String? adminEvaluationNotes;
  final String? adminEvaluatedBy;
  final DateTime? adminEvaluatedDate;
  final String status; // 'Pending', 'Completed', 'Rework'
  final DateTime createdAt;
  final DateTime updatedAt;

  PostRepairReport({
    required this.id,
    required this.workRequestId,
    this.attemptNumber = 1,
    required this.technicianId,
    required this.technicianName,
    required this.repairDate,
    required this.workPerformed,
    this.materialsUsed,
    this.photoBefore,
    this.photoAfter,
    this.repairDuration,
    this.repairStatus = 'completed',
    this.technicianNotes,
    this.adminEvaluation,
    this.adminEvaluationNotes,
    this.adminEvaluatedBy,
    this.adminEvaluatedDate,
    this.status = 'Pending',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory PostRepairReport.fromMap(Map<String, dynamic> map) {
    return PostRepairReport(
      id: map['id']?.toString() ?? '',
      workRequestId: map['work_request_id']?.toString() ?? '',
      attemptNumber: map['attempt_number'] is int ? map['attempt_number'] : int.tryParse(map['attempt_number']?.toString() ?? '') ?? 1,
      technicianId: map['technician_id']?.toString() ?? '',
      technicianName: map['technician_name'] ?? '',
      repairDate: DateTime.parse(map['repair_date'] ?? DateTime.now().toIso8601String()),
      workPerformed: map['work_performed'] ?? '',
      materialsUsed: map['materials_used'],
      photoBefore: map['photo_before'],
      photoAfter: map['photo_after'],
      repairDuration: map['repair_duration'],
      repairStatus: map['repair_status'] ?? 'completed',
      technicianNotes: map['technician_notes'],
      adminEvaluation: map['admin_evaluation'],
      adminEvaluationNotes: map['admin_evaluation_notes'],
      adminEvaluatedBy: map['admin_evaluated_by']?.toString(),
      adminEvaluatedDate: map['admin_evaluated_date'] != null
          ? DateTime.parse(map['admin_evaluated_date'])
          : null,
      status: map['status'] ?? 'Pending',
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'work_request_id': workRequestId,
      'attempt_number': attemptNumber,
      'technician_id': technicianId,
      'technician_name': technicianName,
      'repair_date': repairDate.toIso8601String(),
      'work_performed': workPerformed,
      'materials_used': materialsUsed,
      'photo_before': photoBefore,
      'photo_after': photoAfter,
      'repair_duration': repairDuration,
      'repair_status': repairStatus,
      'technician_notes': technicianNotes,
      'admin_evaluation': adminEvaluation,
      'admin_evaluation_notes': adminEvaluationNotes,
      'admin_evaluated_by': adminEvaluatedBy,
      'admin_evaluated_date': adminEvaluatedDate?.toIso8601String(),
      'status': status,
    };
    // Only include 'id' when it's a real UUID (not empty) to allow DB auto-generation on insert
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }

  PostRepairReport copyWith({
    String? id,
    String? workRequestId,
    int? attemptNumber,
    String? technicianId,
    String? technicianName,
    DateTime? repairDate,
    String? workPerformed,
    String? materialsUsed,
    String? photoBefore,
    String? photoAfter,
    String? repairDuration,
    String? repairStatus,
    String? technicianNotes,
    String? adminEvaluation,
    String? adminEvaluationNotes,
    String? adminEvaluatedBy,
    DateTime? adminEvaluatedDate,
    String? status,
  }) {
    return PostRepairReport(
      id: id ?? this.id,
      workRequestId: workRequestId ?? this.workRequestId,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      repairDate: repairDate ?? this.repairDate,
      workPerformed: workPerformed ?? this.workPerformed,
      materialsUsed: materialsUsed ?? this.materialsUsed,
      photoBefore: photoBefore ?? this.photoBefore,
      photoAfter: photoAfter ?? this.photoAfter,
      repairDuration: repairDuration ?? this.repairDuration,
      repairStatus: repairStatus ?? this.repairStatus,
      technicianNotes: technicianNotes ?? this.technicianNotes,
      adminEvaluation: adminEvaluation ?? this.adminEvaluation,
      adminEvaluationNotes: adminEvaluationNotes ?? this.adminEvaluationNotes,
      adminEvaluatedBy: adminEvaluatedBy ?? this.adminEvaluatedBy,
      adminEvaluatedDate: adminEvaluatedDate ?? this.adminEvaluatedDate,
      status: status ?? this.status,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'Pending':
        return 'PENDING';
      case 'Completed':
        return 'COMPLETED';
      case 'Rework':
        return 'REWORK';
      default:
        return status.toUpperCase();
    }
  }

  String get repairStatusLabel {
    switch (repairStatus) {
      case 'completed':
        return 'Completed';
      case 'partial':
        return 'Partial';
      case 'needs_followup':
        return 'Needs Follow-up';
      default:
        return repairStatus;
    }
  }
}

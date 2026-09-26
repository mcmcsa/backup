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
  final String? requestorEvaluation; // 'satisfy', 'not_satisfy'
  final int? requestorRating; // 1 to 5 (optional)
  final String? requestorComment; // optional
  final String? requestorEvaluatedBy;
  final DateTime? requestorEvaluatedDate;
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
    this.requestorEvaluation,
    this.requestorRating,
    this.requestorComment,
    this.requestorEvaluatedBy,
    this.requestorEvaluatedDate,
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
      requestorEvaluation: map['requestor_evaluation'],
      requestorRating: map['requestor_rating'] is int
          ? map['requestor_rating']
          : int.tryParse(map['requestor_rating']?.toString() ?? ''),
      requestorComment: map['requestor_comment'],
      requestorEvaluatedBy: map['requestor_evaluated_by']?.toString(),
      requestorEvaluatedDate: map['requestor_evaluated_date'] != null
          ? DateTime.parse(map['requestor_evaluated_date'])
          : null,
      status: map['status'] ?? 'Pending',
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'work_request_id': workRequestId,
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
      'status': status,
    };
    if (attemptNumber > 0) map['attempt_number'] = attemptNumber;
    if (adminEvaluation != null) map['admin_evaluation'] = adminEvaluation;
    if (adminEvaluationNotes != null) map['admin_evaluation_notes'] = adminEvaluationNotes;
    if (adminEvaluatedBy != null) map['admin_evaluated_by'] = adminEvaluatedBy;
    if (adminEvaluatedDate != null) map['admin_evaluated_date'] = adminEvaluatedDate!.toIso8601String();
    if (requestorEvaluation != null) map['requestor_evaluation'] = requestorEvaluation;
    if (requestorRating != null) map['requestor_rating'] = requestorRating;
    if (requestorComment != null && requestorComment!.trim().isNotEmpty) {
      map['requestor_comment'] = requestorComment!.trim();
    }
    if (requestorEvaluatedBy != null) map['requestor_evaluated_by'] = requestorEvaluatedBy;
    if (requestorEvaluatedDate != null) {
      map['requestor_evaluated_date'] = requestorEvaluatedDate!.toIso8601String();
    }
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
    String? requestorEvaluation,
    int? requestorRating,
    String? requestorComment,
    String? requestorEvaluatedBy,
    DateTime? requestorEvaluatedDate,
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
      requestorEvaluation: requestorEvaluation ?? this.requestorEvaluation,
      requestorRating: requestorRating ?? this.requestorRating,
      requestorComment: requestorComment ?? this.requestorComment,
      requestorEvaluatedBy: requestorEvaluatedBy ?? this.requestorEvaluatedBy,
      requestorEvaluatedDate: requestorEvaluatedDate ?? this.requestorEvaluatedDate,
      status: status ?? this.status,
    );
  }

  /// Whether the requestor has submitted their review / evaluation
  bool get isRequestorEvaluated =>
      requestorEvaluation != null && requestorEvaluation!.trim().isNotEmpty;

  /// Whether the requestor selected SATISFY
  bool get isRequestorSatisfied => requestorEvaluation == 'satisfy';

  /// Whether the requestor selected NOT SATISFY
  bool get isRequestorNotSatisfied => requestorEvaluation == 'not_satisfy';

  /// User-friendly display label for the requestor evaluation
  String get requestorEvaluationLabel {
    if (isRequestorSatisfied) return 'Satisfied';
    if (isRequestorNotSatisfied) return 'Not Satisfied';
    return 'Pending Requestor Evaluation';
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

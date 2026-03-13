class ESignature {
  final String id;
  final String workRequestId;
  final String signerId;
  final String signerName;
  final String signerRole; // 'admin', 'maintenance', 'student_teacher'
  final String signatureType; // 'approval', 'acceptance', 'pre_inspection', 'post_repair', 'completion'
  final String signatureData; // Base64 encoded signature image
  final DateTime signedAt;
  final String? notes;
  final DateTime createdAt;

  ESignature({
    required this.id,
    required this.workRequestId,
    required this.signerId,
    required this.signerName,
    required this.signerRole,
    required this.signatureType,
    required this.signatureData,
    required this.signedAt,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ESignature.fromMap(Map<String, dynamic> map) {
    return ESignature(
      id: map['id']?.toString() ?? '',
      workRequestId: map['work_request_id']?.toString() ?? '',
      signerId: map['signer_id']?.toString() ?? '',
      signerName: map['signer_name'] ?? '',
      signerRole: map['signer_role'] ?? '',
      signatureType: map['signature_type'] ?? '',
      signatureData: map['signature_data'] ?? '',
      signedAt: DateTime.parse(map['signed_at'] ?? DateTime.now().toIso8601String()),
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'work_request_id': workRequestId,
      'signer_id': signerId,
      'signer_name': signerName,
      'signer_role': signerRole,
      'signature_type': signatureType,
      'signature_data': signatureData,
      'signed_at': signedAt.toIso8601String(),
      'notes': notes,
    };
  }

  Map<String, dynamic> toInsertMap() {
    final map = toMap();
    map.remove('id'); // Let DB generate UUID
    return map;
  }

  ESignature copyWith({
    String? id,
    String? workRequestId,
    String? signerId,
    String? signerName,
    String? signerRole,
    String? signatureType,
    String? signatureData,
    DateTime? signedAt,
    String? notes,
  }) {
    return ESignature(
      id: id ?? this.id,
      workRequestId: workRequestId ?? this.workRequestId,
      signerId: signerId ?? this.signerId,
      signerName: signerName ?? this.signerName,
      signerRole: signerRole ?? this.signerRole,
      signatureType: signatureType ?? this.signatureType,
      signatureData: signatureData ?? this.signatureData,
      signedAt: signedAt ?? this.signedAt,
      notes: notes ?? this.notes,
    );
  }

  String get signatureTypeLabel {
    switch (signatureType) {
      case 'approval':
        return 'Admin Approval';
      case 'acceptance':
        return 'Maintenance Acceptance';
      case 'pre_inspection':
        return 'Pre-Inspection';
      case 'post_repair':
        return 'Post-Repair';
      case 'completion':
        return 'Completion';
      default:
        return signatureType;
    }
  }
}

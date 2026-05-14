class QRCodeHistory {
  final String id;
  final String? roomId;
  final String qrCodeValue;
  final String? roomName;
  final String? building;
  final String? department;
  final String createdById;
  final DateTime createdAt;
  final int scannedCount;
  final DateTime? lastScanned;
  final bool isActive;

  QRCodeHistory({
    required this.id,
    this.roomId,
    required this.qrCodeValue,
    this.roomName,
    this.building,
    this.department,
    required this.createdById,
    required this.createdAt,
    this.scannedCount = 0,
    this.lastScanned,
    this.isActive = true,
  });

  static DateTime _parseToLocal(dynamic value) {
    if (value == null) return DateTime.now();
    return DateTime.parse(value.toString()).toLocal();
  }

  factory QRCodeHistory.fromMap(Map<String, dynamic> map) {
    return QRCodeHistory(
      id: map['id'] ?? '',
      roomId: map['room_id'],
      qrCodeValue: map['qr_code_value'] ?? '',
      roomName: map['room_name'],
      building: map['building'],
      department: map['department'],
      createdById: map['created_by_id'] ?? '',
      createdAt: _parseToLocal(map['created_at']),
      scannedCount: map['scanned_count'] ?? 0,
      lastScanned: map['last_scanned'] != null
          ? _parseToLocal(map['last_scanned'])
          : null,
      isActive: map['is_active'] ?? true,
    );
  }

  // Convert to JSON for storage/network
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'qr_code_value': qrCodeValue,
      'room_name': roomName,
      'building': building,
      'department': department,
      'created_by_id': createdById,
      'created_at': createdAt.toIso8601String(),
      'scanned_count': scannedCount,
      'last_scanned': lastScanned?.toIso8601String(),
      'is_active': isActive,
    };
  }

  Map<String, dynamic> toMap() {
    return toJson();
  }

  // Create from JSON
  factory QRCodeHistory.fromJson(Map<String, dynamic> json) {
    return QRCodeHistory.fromMap(json);
  }

  QRCodeHistory copyWith({
    String? id,
    String? roomId,
    String? qrCodeValue,
    String? roomName,
    String? building,
    String? department,
    String? createdById,
    DateTime? createdAt,
    int? scannedCount,
    DateTime? lastScanned,
    bool? isActive,
  }) {
    return QRCodeHistory(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      qrCodeValue: qrCodeValue ?? this.qrCodeValue,
      roomName: roomName ?? this.roomName,
      building: building ?? this.building,
      department: department ?? this.department,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      scannedCount: scannedCount ?? this.scannedCount,
      lastScanned: lastScanned ?? this.lastScanned,
      isActive: isActive ?? this.isActive,
    );
  }
}

class Room {
  final String id;
  final String code;
  final String name;
  final String buildingId;
  final String building; // display name from join
  final String floorId;
  final String floor;
  final int seats;
  final String departmentId;
  final String department; // display name from join
  final String roomTypeId;
  final String roomType; // 'Laboratory', 'Lecture Hall', 'Seminar Room'
  final String status; // 'available', 'reserved', 'maintenance'
  final String? imageUrl;
  final String? qrCodeData;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Room({
    required this.id,
    this.code = '',
    required this.name,
    this.buildingId = '',
    this.building = '',
    this.floorId = '',
    this.floor = '',
    required this.seats,
    this.departmentId = '',
    this.department = '',
    this.roomTypeId = '',
    this.roomType = '',
    required this.status,
    this.imageUrl,
    this.qrCodeData,
    this.createdAt,
    this.updatedAt,
  });

  Room copyWith({
    String? id,
    String? code,
    String? name,
    String? buildingId,
    String? building,
    String? floorId,
    String? floor,
    int? seats,
    String? departmentId,
    String? department,
    String? roomTypeId,
    String? roomType,
    String? status,
    String? imageUrl,
    String? qrCodeData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Room(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      buildingId: buildingId ?? this.buildingId,
      building: building ?? this.building,
      floorId: floorId ?? this.floorId,
      floor: floor ?? this.floor,
      seats: seats ?? this.seats,
      departmentId: departmentId ?? this.departmentId,
      department: department ?? this.department,
      roomTypeId: roomTypeId ?? this.roomTypeId,
      roomType: roomType ?? this.roomType,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Room.fromMap(Map<String, dynamic> map) {
    // Extract building name from joined data
    String buildingName = '';
    if (map['buildings'] is Map) {
      buildingName = map['buildings']['name'] ?? '';
    }
    // Extract department name from joined data
    String departmentName = '';
    if (map['departments'] is Map) {
      departmentName = map['departments']['name'] ?? '';
    }
    if (departmentName.isEmpty) {
      departmentName = map['department_name'] ?? map['department'] ?? '';
    }
    String roomTypeName = '';
    if (map['room_types'] is Map) {
      roomTypeName = map['room_types']['name'] ?? '';
    }
    if (roomTypeName.isEmpty) {
      roomTypeName = map['room_type'] ?? '';
    }

    String floorName = '';
    if (map['floors'] is Map) {
      floorName = map['floors']['name'] ?? '';
    }
    if (floorName.isEmpty && map['floor'] != null && map['floor'].toString().isNotEmpty) {
      floorName = map['floor'].toString();
    }
    if (floorName.isEmpty && map['floor_snapshot'] != null) {
      floorName = map['floor_snapshot'].toString();
    }

    int parseSeats(Map<String, dynamic> m) {
      final val = m['seats'] ??
          m['capacity'] ??
          m['capacity_seats'] ??
          m['seat_capacity'] ??
          m['capacity_seat'] ??
          m['seats_capacity'];

      if (val == null) return 0;
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is String) return int.tryParse(val.trim()) ?? 0;
      return 0;
    }

    return Room(
      id: map['id']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      name: map['name'] ?? '',
      buildingId: map['building_id']?.toString() ?? '',
      building: buildingName,
      floorId: map['floor_id']?.toString() ?? '',
      floor: floorName,
      seats: parseSeats(map),
      departmentId: map['department_id']?.toString() ?? '',
      department: departmentName,
      roomTypeId: map['room_type_id']?.toString() ?? '',
      roomType: roomTypeName.isNotEmpty ? roomTypeName : (map['room_type'] ?? ''),
      status: map['status'] ?? 'available',
      imageUrl: map['image_url'],
      qrCodeData: map['qr_code_data'],
      createdAt:
          map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt:
          map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'code': code.isNotEmpty ? code : id,
      'name': name,
      'building_id': buildingId,
      // Legacy schemas still require a non-null floor column.
      'floor': floor,
      if (floorId.isNotEmpty) 'floor_id': floorId,
      'seats': seats,
      if (roomTypeId.isNotEmpty) 'room_type_id': roomTypeId,
      'status': status,
      'image_url': imageUrl,
    };
    if (departmentId.isNotEmpty) {
      map['department_id'] = departmentId;
    }
    if (qrCodeData != null) {
      map['qr_code_data'] = qrCodeData;
    }
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

}


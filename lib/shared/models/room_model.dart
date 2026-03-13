class Room {
  final String id;
  final String name;
  final String buildingId;
  final String building; // display name from join
  final String floor;
  final int seats;
  final String departmentId;
  final String department; // display name from join
  final String roomType; // 'Laboratory', 'Lecture Hall', 'Seminar Room'
  final String status; // 'available', 'reserved', 'maintenance'
  final String? imageUrl;
  final String? description;
  final String? qrCodeData;

  Room({
    required this.id,
    required this.name,
    this.buildingId = '',
    this.building = '',
    this.floor = '1st Floor',
    required this.seats,
    this.departmentId = '',
    this.department = '',
    this.roomType = 'Laboratory',
    required this.status,
    this.imageUrl,
    this.description,
    this.qrCodeData,
  });

  Room copyWith({
    String? id,
    String? name,
    String? buildingId,
    String? building,
    String? floor,
    int? seats,
    String? departmentId,
    String? department,
    String? roomType,
    String? status,
    String? imageUrl,
    String? description,
    String? qrCodeData,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      buildingId: buildingId ?? this.buildingId,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      seats: seats ?? this.seats,
      departmentId: departmentId ?? this.departmentId,
      department: department ?? this.department,
      roomType: roomType ?? this.roomType,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      qrCodeData: qrCodeData ?? this.qrCodeData,
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

    return Room(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      buildingId: map['building_id']?.toString() ?? '',
      building: buildingName,
      floor: map['floor'] ?? '1st Floor',
      seats: map['seats'] ?? 0,
      departmentId: map['department_id']?.toString() ?? '',
      department: departmentName,
      roomType: map['room_type'] ?? 'Laboratory',
      status: map['status'] ?? 'available',
      imageUrl: map['image_url'],
      description: map['description'],
      qrCodeData: map['qr_code_data'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'building_id': buildingId,
      'floor': floor,
      'seats': seats,
      'room_type': roomType,
      'status': status,
      'image_url': imageUrl,
      'description': description,
    };
    if (departmentId.isNotEmpty) {
      map['department_id'] = departmentId;
    }
    if (qrCodeData != null) {
      map['qr_code_data'] = qrCodeData;
    }
    return map;
  }

}


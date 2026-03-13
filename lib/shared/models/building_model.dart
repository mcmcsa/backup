class Building {
  final String id;
  final String name;
  final String code;
  final String campus;
  final String? address;
  final int floors;
  final int totalRooms;
  final String? description;
  final String? buildingManager;
  final DateTime createdAt;
  final DateTime updatedAt;

  Building({
    required this.id,
    required this.name,
    required this.code,
    required this.campus,
    this.address,
    this.floors = 3,
    this.totalRooms = 0,
    this.description,
    this.buildingManager,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Building.fromMap(Map<String, dynamic> map) {
    return Building(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      campus: map['campus'] ?? '',
      address: map['address'],
      floors: map['floors'] ?? 3,
      totalRooms: map['total_rooms'] ?? 0,
      description: map['description'],
      buildingManager: map['building_manager'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'campus': campus,
      'address': address,
      'floors': floors,
      'total_rooms': totalRooms,
      'description': description,
      'building_manager': buildingManager,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Building copyWith({
    String? id,
    String? name,
    String? code,
    String? campus,
    String? address,
    int? floors,
    int? totalRooms,
    String? description,
    String? buildingManager,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Building(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      campus: campus ?? this.campus,
      address: address ?? this.address,
      floors: floors ?? this.floors,
      totalRooms: totalRooms ?? this.totalRooms,
      description: description ?? this.description,
      buildingManager: buildingManager ?? this.buildingManager,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

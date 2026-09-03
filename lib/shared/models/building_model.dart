class Building {
  final String id;
  final String name;
  final String code;
  final String departmentId;
  final String department;
  final int numberOfFloors;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Building({
    required this.id,
    required this.name,
    required this.code,
    this.departmentId = '',
    this.department = '',
    this.numberOfFloors = 1,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Building.fromMap(Map<String, dynamic> map) {
    String departmentName = '';
    if (map['departments'] is Map) {
      departmentName = map['departments']['name'] ?? '';
    }

    return Building(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      departmentId: map['department_id']?.toString() ?? '',
      department: departmentName,
      numberOfFloors: map['number_of_floors'] ?? 1,
      isActive: map['is_active'] ?? true,
      createdAt: DateTime.parse(
          map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      if (departmentId.isNotEmpty) 'department_id': departmentId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Building copyWith({
    String? id,
    String? name,
    String? code,
    String? departmentId,
    String? department,
    int? numberOfFloors,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Building(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      departmentId: departmentId ?? this.departmentId,
      department: department ?? this.department,
      numberOfFloors: numberOfFloors ?? this.numberOfFloors,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

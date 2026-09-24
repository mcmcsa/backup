class Department {
  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? headUserId;
  final String? headUserName;
  final String? buildingId;
  final String? buildingName;

  Department({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
    this.headUserId,
    this.headUserName,
    this.buildingId,
    this.buildingName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Department.fromMap(Map<String, dynamic> map) {
    String? headName;
    if (map['head_user'] is Map) {
      headName = map['head_user']['name']?.toString();
    } else if (map['head_name'] != null) {
      headName = map['head_name']?.toString();
    }

    String? buildingName;
    if (map['buildings'] is Map) {
      buildingName = map['buildings']['name']?.toString();
    } else if (map['building'] is Map) {
      buildingName = map['building']['name']?.toString();
    } else if (map['building_name'] != null) {
      buildingName = map['building_name']?.toString();
    }

    return Department(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description']?.toString(),
      isActive: map['is_active'] ?? true,
      headUserId: map['head_user_id']?.toString(),
      headUserName: headName,
      buildingId: map['building_id']?.toString(),
      buildingName: buildingName,
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
      if (headUserId != null) 'head_user_id': headUserId,
      if (buildingId != null && buildingId!.isNotEmpty) 'building_id': buildingId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Department copyWith({
    String? id,
    String? name,
    String? description,
    bool? isActive,
    String? headUserId,
    String? headUserName,
    String? buildingId,
    String? buildingName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Department(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      headUserId: headUserId ?? this.headUserId,
      headUserName: headUserName ?? this.headUserName,
      buildingId: buildingId ?? this.buildingId,
      buildingName: buildingName ?? this.buildingName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Department {
  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? headUserId;
  final String? headUserName;

  /// Many-to-Many building associations
  final List<String> buildingIds;
  final List<String> buildingNames;

  Department({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
    this.headUserId,
    this.headUserName,
    this.buildingIds = const [],
    this.buildingNames = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Backward-compatibility getters
  String? get buildingId => buildingIds.isNotEmpty ? buildingIds.first : null;
  String? get buildingName =>
      buildingNames.isNotEmpty ? buildingNames.join(', ') : null;

  factory Department.fromMap(Map<String, dynamic> map) {
    // 1. Resolve Department Head name
    String? headName;
    if (map['head_user'] is Map) {
      headName = map['head_user']['name']?.toString();
    } else if (map['head_name'] != null) {
      headName = map['head_name']?.toString();
    }

    // 2. Resolve Many-to-Many Buildings
    final List<String> bldgIds = [];
    final List<String> bldgNames = [];

    // From junction table relation: department_buildings(building_id, buildings(name))
    if (map['department_buildings'] is List) {
      for (final item in (map['department_buildings'] as List)) {
        if (item is Map) {
          final bId = item['building_id']?.toString();
          if (bId != null && bId.isNotEmpty && !bldgIds.contains(bId)) {
            bldgIds.add(bId);
          }
          if (item['buildings'] is Map && item['buildings']['name'] != null) {
            final bName = item['buildings']['name'].toString();
            if (bName.isNotEmpty && !bldgNames.contains(bName)) {
              bldgNames.add(bName);
            }
          } else if (item['building_name'] != null) {
            final bName = item['building_name'].toString();
            if (bName.isNotEmpty && !bldgNames.contains(bName)) {
              bldgNames.add(bName);
            }
          }
        }
      }
    }

    // From explicit building_ids / building_names lists
    if (map['building_ids'] is List) {
      for (final id in (map['building_ids'] as List)) {
        final str = id?.toString() ?? '';
        if (str.isNotEmpty && !bldgIds.contains(str)) {
          bldgIds.add(str);
        }
      }
    }
    if (map['building_names'] is List) {
      for (final name in (map['building_names'] as List)) {
        final str = name?.toString() ?? '';
        if (str.isNotEmpty && !bldgNames.contains(str)) {
          bldgNames.add(str);
        }
      }
    }

    // Fallbacks for legacy single building representations
    if (bldgIds.isEmpty && map['building_id'] != null && map['building_id'].toString().isNotEmpty) {
      bldgIds.add(map['building_id'].toString());
    }
    if (bldgNames.isEmpty) {
      if (map['buildings'] is Map && map['buildings']['name'] != null) {
        bldgNames.add(map['buildings']['name'].toString());
      } else if (map['building'] is Map && map['building']['name'] != null) {
        bldgNames.add(map['building']['name'].toString());
      } else if (map['building_name'] != null && map['building_name'].toString().isNotEmpty) {
        bldgNames.add(map['building_name'].toString());
      }
    }

    return Department(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description']?.toString(),
      isActive: map['is_active'] ?? true,
      headUserId: map['head_user_id']?.toString(),
      headUserName: headName,
      buildingIds: List.unmodifiable(bldgIds),
      buildingNames: List.unmodifiable(bldgNames),
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
    List<String>? buildingIds,
    List<String>? buildingNames,
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
      buildingIds: buildingIds ?? this.buildingIds,
      buildingNames: buildingNames ?? this.buildingNames,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

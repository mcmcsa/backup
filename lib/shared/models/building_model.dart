class Building {
  final String id;
  final String name;
  final String code;
  final int numberOfFloors;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Many-to-Many department associations
  final List<String> departmentIds;
  final List<String> departmentNames;

  Building({
    required this.id,
    required this.name,
    this.code = '',
    this.numberOfFloors = 1,
    this.isActive = true,
    List<String> departmentIds = const [],
    this.departmentNames = const [],
    String? departmentId,
    required this.createdAt,
    required this.updatedAt,
  }) : departmentIds = departmentIds.isNotEmpty
            ? departmentIds
            : (departmentId != null && departmentId.isNotEmpty ? [departmentId] : const []);

  /// Backward-compatibility getters
  String get departmentId => departmentIds.isNotEmpty ? departmentIds.first : '';
  String get department =>
      departmentNames.isNotEmpty ? departmentNames.join(', ') : '';

  factory Building.fromMap(Map<String, dynamic> map) {
    final List<String> deptIds = [];
    final List<String> deptNames = [];

    // From junction table relation: department_buildings(department_id, departments(name))
    if (map['department_buildings'] is List) {
      for (final item in (map['department_buildings'] as List)) {
        if (item is Map) {
          final dId = item['department_id']?.toString();
          if (dId != null && dId.isNotEmpty && !deptIds.contains(dId)) {
            deptIds.add(dId);
          }
          if (item['departments'] is Map && item['departments']['name'] != null) {
            final dName = item['departments']['name'].toString();
            if (dName.isNotEmpty && !deptNames.contains(dName)) {
              deptNames.add(dName);
            }
          } else if (item['department_name'] != null) {
            final dName = item['department_name'].toString();
            if (dName.isNotEmpty && !deptNames.contains(dName)) {
              deptNames.add(dName);
            }
          }
        }
      }
    }

    // From explicit department_ids / department_names lists
    if (map['department_ids'] is List) {
      for (final id in (map['department_ids'] as List)) {
        final str = id?.toString() ?? '';
        if (str.isNotEmpty && !deptIds.contains(str)) {
          deptIds.add(str);
        }
      }
    }
    if (map['department_names'] is List) {
      for (final name in (map['department_names'] as List)) {
        final str = name?.toString() ?? '';
        if (str.isNotEmpty && !deptNames.contains(str)) {
          deptNames.add(str);
        }
      }
    }

    // Fallbacks for legacy single department
    if (deptIds.isEmpty && map['department_id'] != null && map['department_id'].toString().isNotEmpty) {
      deptIds.add(map['department_id'].toString());
    }
    if (deptNames.isEmpty) {
      if (map['departments'] is Map && map['departments']['name'] != null) {
        deptNames.add(map['departments']['name'].toString());
      } else if (map['departments'] is List && (map['departments'] as List).isNotEmpty) {
        final first = (map['departments'] as List).first;
        if (first is Map && first['name'] != null) {
          deptNames.add(first['name'].toString());
        }
      } else if (map['department'] is Map && map['department']['name'] != null) {
        deptNames.add(map['department']['name'].toString());
      } else if (map['department_name'] != null && map['department_name'].toString().isNotEmpty) {
        deptNames.add(map['department_name'].toString());
      }
    }

    return Building(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      numberOfFloors: map['number_of_floors'] ?? 1,
      isActive: map['is_active'] ?? true,
      departmentIds: List.unmodifiable(deptIds),
      departmentNames: List.unmodifiable(deptNames),
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
      if (code.isNotEmpty) 'code': code,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Building copyWith({
    String? id,
    String? name,
    String? code,
    int? numberOfFloors,
    bool? isActive,
    List<String>? departmentIds,
    List<String>? departmentNames,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Building(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      numberOfFloors: numberOfFloors ?? this.numberOfFloors,
      isActive: isActive ?? this.isActive,
      departmentIds: departmentIds ?? this.departmentIds,
      departmentNames: departmentNames ?? this.departmentNames,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

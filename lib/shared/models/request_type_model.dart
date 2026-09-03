class RequestType {
  final String id;
  final String name;
  final String description;
  final String priority; // 'low', 'medium', 'high', 'critical'
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  RequestType({
    required this.id,
    required this.name,
    this.description = '',
    this.priority = 'medium',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RequestType.fromMap(Map<String, dynamic> map) {
    return RequestType(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      priority: map['priority'] ?? 'medium',
      isActive: map['is_active'] ?? true,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  RequestType copyWith({
    String? id,
    String? name,
    String? description,
    String? priority,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RequestType(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

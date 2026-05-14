class Floor {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  Floor({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Floor.fromMap(Map<String, dynamic> map) {
    return Floor(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
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

  Floor copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Floor(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

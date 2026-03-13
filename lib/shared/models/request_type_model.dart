class RequestType {
  final String id;
  final String name;
  final String code;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  RequestType({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.isActive = true,
    required this.createdAt,
  });

  factory RequestType.fromMap(Map<String, dynamic> map) {
    return RequestType(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      description: map['description'],
      isActive: map['is_active'] ?? true,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  RequestType copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return RequestType(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

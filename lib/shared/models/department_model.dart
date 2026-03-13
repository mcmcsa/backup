class Department {
  final String id;
  final String name;
  final String code;
  final String campus;
  final String? contactEmail;
  final String? contactPhone;
  final String? headName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Department({
    required this.id,
    required this.name,
    required this.code,
    required this.campus,
    this.contactEmail,
    this.contactPhone,
    this.headName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Department.fromMap(Map<String, dynamic> map) {
    return Department(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      campus: map['campus'] ?? '',
      contactEmail: map['contact_email'],
      contactPhone: map['contact_phone'],
      headName: map['head_name'],
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
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'head_name': headName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Department copyWith({
    String? id,
    String? name,
    String? code,
    String? campus,
    String? contactEmail,
    String? contactPhone,
    String? headName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Department(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      campus: campus ?? this.campus,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      headName: headName ?? this.headName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

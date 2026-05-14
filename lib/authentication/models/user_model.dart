enum UserRole { admin, teacher, maintenance }

class AppUser {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final bool isActive;
  final String? campus;
  final String? department;
  final String? position;
  final String? employeeId;
  final String? phone;
  final String? profileImage;
  final DateTime? createdAt;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    this.campus,
    this.department,
    this.position,
    this.employeeId,
    this.phone,
    this.profileImage,
    this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final teacherProfile = _asMap(map['teacher_users']);
    final maintenanceProfile = _asMap(map['maintenance_users']);
    final teacherDepartment = _asMap(teacherProfile['departments']);

    return AppUser(
      id: map['id']?.toString() ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: _parseRole(map['role']),
      isActive: map['is_active'] ?? true,
      campus: map['campus'],
      department:
          teacherProfile['department_name'] ??
          teacherDepartment['name'] ??
          map['department'] ??
          teacherProfile['department_id'] ??
          maintenanceProfile['department_id'],
      position:
          teacherProfile['position'] ?? maintenanceProfile['specialization'],
      employeeId:
          teacherProfile['employee_id'] ?? maintenanceProfile['employee_id'],
      phone: teacherProfile['phone'] ?? maintenanceProfile['phone'],
      profileImage:
          map['profile_image'] ??
          teacherProfile['profile_image'] ??
          maintenanceProfile['profile_image'],
      createdAt:
          map['created_at'] != null
              ? DateTime.tryParse(map['created_at'].toString())
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.name,
      'is_active': isActive,
    };
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is List && value.isNotEmpty && value.first is Map<String, dynamic>) {
      return value.first as Map<String, dynamic>;
    }
    return const <String, dynamic>{};
  }

  static UserRole _parseRole(dynamic roleValue) {
    if (roleValue == null) return UserRole.teacher;

    final roleString = roleValue.toString().toLowerCase();
    switch (roleString) {
      case 'admin':
        return UserRole.admin;
      case 'teacher':
        return UserRole.teacher;
      case 'maintenance':
        return UserRole.maintenance;
      default:
        return UserRole.teacher;
    }
  }

  String get roleLabel {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.maintenance:
        return 'Maintenance Staff';
    }
  }

  String get dashboardRoute {
    switch (role) {
      case UserRole.admin:
        return '/admin/dashboard';
      case UserRole.teacher:
        return '/teacher/dashboard';
      case UserRole.maintenance:
        return '/maintenance/dashboard';
    }
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    bool? isActive,
    String? campus,
    String? department,
    String? position,
    String? employeeId,
    String? phone,
    String? profileImage,
    bool clearProfileImage = false,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      campus: campus ?? this.campus,
      department: department ?? this.department,
      position: position ?? this.position,
      employeeId: employeeId ?? this.employeeId,
      phone: phone ?? this.phone,
      profileImage:
          clearProfileImage ? null : (profileImage ?? this.profileImage),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

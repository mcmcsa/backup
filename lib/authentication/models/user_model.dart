enum UserRole { admin, campadmin, teacher, maintenance }

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

  final bool mustChangePassword;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    this.mustChangePassword = false,
    this.campus,
    this.department,
    this.position,
    this.employeeId,
    this.phone,
    this.profileImage,
    this.createdAt,
  });

  factory AppUser.fromMap(
    Map<String, dynamic> map, {
    Map<String, String>? deptMap,
  }) {
    final teacherProfile = _asMap(map['teacher_users']);
    final maintenanceProfile = _asMap(map['maintenance_users']);
    final teacherDepartment = _asMap(teacherProfile['departments']);
    final userMetadata = _asMap(map['user_metadata']);

    final mustChange = map['must_change_password'] == true ||
        userMetadata['must_change_password'] == true;

    final deptId = teacherProfile['department_id']?.toString() ?? map['department_id']?.toString();
    final fallbackDeptName = (deptId != null && deptMap != null) ? deptMap[deptId] : null;

    return AppUser(
      id: map['id']?.toString() ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: _parseRole(map['role']),
      isActive: map['is_active'] ?? true,
      mustChangePassword: mustChange,
      campus: map['campus'],
      department: _nonEmptyString(teacherDepartment['name']) ??
          _nonEmptyString(teacherProfile['department_name']) ??
          _nonEmptyString(teacherProfile['department']) ??
          _nonEmptyString(fallbackDeptName) ??
          _nonEmptyString(map['department_name']) ??
          _nonEmptyString(map['department']),
      position: _nonEmptyString(teacherProfile['position']) ??
          _nonEmptyString(maintenanceProfile['specialization']) ??
          _nonEmptyString(map['position']),
      employeeId: _nonEmptyString(teacherProfile['employee_id']) ??
          _nonEmptyString(maintenanceProfile['employee_id']),
      phone: map['phone'],
      profileImage: map['profile_image'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  static String? _nonEmptyString(dynamic v) {
    if (v == null) return null;
    final str = v.toString().trim();
    return str.isNotEmpty ? str : null;
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
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return const <String, dynamic>{};
  }

  static UserRole _parseRole(dynamic roleValue) {
    if (roleValue == null) return UserRole.teacher;

    final roleString = roleValue.toString().toLowerCase();
    switch (roleString) {
      case 'admin':
        return UserRole.admin;
      case 'campadmin':
      case 'camp_admin':
      case 'campus_admin':
        return UserRole.campadmin;
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
        return 'System Administrator';
      case UserRole.campadmin:
        return 'Campus Administrator';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.maintenance:
        return 'Maintenance Staff';
    }
  }

  String get dashboardRoute {
    switch (role) {
      case UserRole.admin:
        return '/system-admin/dashboard';
      case UserRole.campadmin:
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

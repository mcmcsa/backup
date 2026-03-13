enum UserRole {
  admin,
  studentTeacher,
  maintenance,
}

class AppUser {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? campus;
  final String? department;
  final String? position;
  final String? profileImage;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.campus,
    this.department,
    this.position,
    this.profileImage,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id']?.toString() ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: _parseRole(map['role']),
      campus: map['campus'],
      department: map['department'],
      position: map['position'],
      profileImage: map['profile_image'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.name,
      'campus': campus,
      'department': department,
      'position': position,
      'profile_image': profileImage,
    };
  }

  static UserRole _parseRole(dynamic roleValue) {
    if (roleValue == null) return UserRole.studentTeacher;
    
    final roleString = roleValue.toString().toLowerCase();
    switch (roleString) {
      case 'admin':
        return UserRole.admin;
      case 'student_teacher':
      case 'studentteacher':
      case 'student':
      case 'teacher':
        return UserRole.studentTeacher;
      case 'maintenance':
        return UserRole.maintenance;
      default:
        return UserRole.studentTeacher;
    }
  }

  String get roleLabel {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.studentTeacher:
        return 'Student/Teacher';
      case UserRole.maintenance:
        return 'Maintenance Staff';
    }
  }

  String get dashboardRoute {
    switch (role) {
      case UserRole.admin:
        return '/admin/dashboard';
      case UserRole.studentTeacher:
        return '/student-teacher/dashboard';
      case UserRole.maintenance:
        return '/maintenance/dashboard';
    }
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    String? campus,
    String? department,
    String? position,
    String? profileImage,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      campus: campus ?? this.campus,
      department: department ?? this.department,
      position: position ?? this.position,
      profileImage: profileImage ?? this.profileImage,
    );
  }
}


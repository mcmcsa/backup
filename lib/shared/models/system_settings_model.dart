class SystemSettings {
  final String id;
  final String systemName;
  final String campusName;
  final String? schoolLogo;
  final String primaryColor;
  final String theme; // 'light', 'dark', 'system'
  final String timezone;
  final String academicYear;
  final String semester;
  final bool enforcePasswordPolicy;
  final int sessionTimeoutMinutes;
  final bool maintenanceMode;
  final DateTime updatedAt;

  SystemSettings({
    required this.id,
    this.systemName = 'Pangasinan State University Maintenance System',
    this.campusName = 'Main Campus',
    this.schoolLogo,
    this.primaryColor = '#0F172A',
    this.theme = 'light',
    this.timezone = 'Asia/Manila',
    this.academicYear = '2023-2024',
    this.semester = '1st Semester',
    this.enforcePasswordPolicy = true,
    this.sessionTimeoutMinutes = 60,
    this.maintenanceMode = false,
    required this.updatedAt,
  });

  factory SystemSettings.fromMap(Map<String, dynamic> map) {
    return SystemSettings(
      id: map['id']?.toString() ?? '1',
      systemName: map['system_name'] ?? 'PSU MMS',
      campusName: map['campus_name'] ?? 'Main Campus',
      schoolLogo: map['school_logo'],
      primaryColor: map['primary_color'] ?? '#0F172A',
      theme: map['theme'] ?? 'light',
      timezone: map['timezone'] ?? 'Asia/Manila',
      academicYear: map['academic_year'] ?? '2023-2024',
      semester: map['semester'] ?? '1st Semester',
      enforcePasswordPolicy: map['enforce_password_policy'] ?? true,
      sessionTimeoutMinutes: map['session_timeout_minutes'] ?? 60,
      maintenanceMode: map['maintenance_mode'] ?? false,
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'system_name': systemName,
      'campus_name': campusName,
      'school_logo': schoolLogo,
      'primary_color': primaryColor,
      'theme': theme,
      'timezone': timezone,
      'academic_year': academicYear,
      'semester': semester,
      'enforce_password_policy': enforcePasswordPolicy,
      'session_timeout_minutes': sessionTimeoutMinutes,
      'maintenance_mode': maintenanceMode,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SystemSettings copyWith({
    String? id,
    String? systemName,
    String? campusName,
    String? schoolLogo,
    String? primaryColor,
    String? theme,
    String? timezone,
    String? academicYear,
    String? semester,
    bool? enforcePasswordPolicy,
    int? sessionTimeoutMinutes,
    bool? maintenanceMode,
    DateTime? updatedAt,
  }) {
    return SystemSettings(
      id: id ?? this.id,
      systemName: systemName ?? this.systemName,
      campusName: campusName ?? this.campusName,
      schoolLogo: schoolLogo ?? this.schoolLogo,
      primaryColor: primaryColor ?? this.primaryColor,
      theme: theme ?? this.theme,
      timezone: timezone ?? this.timezone,
      academicYear: academicYear ?? this.academicYear,
      semester: semester ?? this.semester,
      enforcePasswordPolicy: enforcePasswordPolicy ?? this.enforcePasswordPolicy,
      sessionTimeoutMinutes: sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

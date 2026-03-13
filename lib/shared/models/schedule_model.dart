class RoomSchedule {
  final String id;
  final String roomId;
  final String subjectName;
  final String instructor;
  final DateTime scheduledDate;
  final String startTime;
  final String endTime;
  final bool isMaintenanceWindow;
  final String? notes;
  final String status; // 'scheduled', 'confirmed', 'cancelled'

  RoomSchedule({
    required this.id,
    required this.roomId,
    required this.subjectName,
    required this.instructor,
    required this.scheduledDate,
    required this.startTime,
    required this.endTime,
    this.isMaintenanceWindow = false,
    this.notes,
    this.status = 'scheduled',
  });

  factory RoomSchedule.fromMap(Map<String, dynamic> map) {
    return RoomSchedule(
      id: map['id']?.toString() ?? '',
      roomId: map['room_id']?.toString() ?? '',
      subjectName: map['subject_name'] ?? '',
      instructor: map['instructor'] ?? '',
      scheduledDate: DateTime.parse(map['scheduled_date']),
      startTime: map['start_time'] ?? '',
      endTime: map['end_time'] ?? '',
      isMaintenanceWindow: map['is_maintenance_window'] ?? false,
      notes: map['notes'],
      status: map['status'] ?? 'scheduled',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_id': roomId,
      'subject_name': subjectName,
      'instructor': instructor,
      'scheduled_date': scheduledDate.toString().split(' ')[0], // YYYY-MM-DD format
      'start_time': startTime,
      'end_time': endTime,
      'is_maintenance_window': isMaintenanceWindow,
      'notes': notes,
      'status': status,
    };
  }

  RoomSchedule copyWith({
    String? id,
    String? roomId,
    String? subjectName,
    String? instructor,
    DateTime? scheduledDate,
    String? startTime,
    String? endTime,
    bool? isMaintenanceWindow,
    String? notes,
    String? status,
  }) {
    return RoomSchedule(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      subjectName: subjectName ?? this.subjectName,
      instructor: instructor ?? this.instructor,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isMaintenanceWindow: isMaintenanceWindow ?? this.isMaintenanceWindow,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }

  String get formattedTimeSlot => '$startTime - $endTime';
}


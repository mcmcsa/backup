import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../authentication/models/user_model.dart';

class LoginActivity {
  final String userId;
  final String userName;
  final String role;
  final String eventType;
  final String title;
  final String? details;
  final String? workRequestId;
  final DateTime loggedInAt;

  const LoginActivity({
    required this.userId,
    required this.userName,
    required this.role,
    required this.eventType,
    required this.title,
    this.details,
    this.workRequestId,
    required this.loggedInAt,
  });

  factory LoginActivity.fromMap(Map<String, dynamic> map) {
    return LoginActivity(
      userId: map['user_id']?.toString() ?? '',
      userName: map['user_name']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      eventType: map['event_type']?.toString() ?? 'login',
      title: map['title']?.toString() ?? 'Admin Login',
      details: map['details']?.toString(),
      workRequestId: map['work_request_id']?.toString(),
      loggedInAt: DateTime.parse(
        map['logged_in_at']?.toString() ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'user_name': userName,
      'role': role,
      'event_type': eventType,
      'title': title,
      'details': details,
      'work_request_id': workRequestId,
      'logged_in_at': loggedInAt.toIso8601String(),
    };
  }
}

class LoginActivityService {
  static const String _storageKey = 'psu_login_activity_logs_v1';

  static Future<void> _append(Map<String, dynamic> entry) async {
    final prefs = await SharedPreferences.getInstance();
    final existingRaw = prefs.getString(_storageKey);

    final List<Map<String, dynamic>> decoded = existingRaw == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(existingRaw) as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();

    decoded.insert(0, entry);

    if (decoded.length > 500) {
      decoded.removeRange(500, decoded.length);
    }

    await prefs.setString(_storageKey, jsonEncode(decoded));
  }

  static Future<void> recordLogin(AppUser user) async {
    if (user.role != UserRole.admin) return;

    await _append({
      'user_id': user.id,
      'user_name': user.name,
      'role': user.role.name,
      'event_type': 'login',
      'title': 'Admin Login',
      'details': 'Logged in to the system',
      'logged_in_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> recordAdminAction({
    required AppUser user,
    required String title,
    String? details,
    String? workRequestId,
  }) async {
    if (user.role != UserRole.admin) return;

    await _append({
      'user_id': user.id,
      'user_name': user.name,
      'role': user.role.name,
      'event_type': 'action',
      'title': title,
      'details': details,
      'work_request_id': workRequestId,
      'logged_in_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<LoginActivity>> fetchAdminLogs({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return const <LoginActivity>[];

    final decoded = (jsonDecode(raw) as List)
        .map((item) => LoginActivity.fromMap(Map<String, dynamic>.from(item as Map)))
        .where((log) => log.role == UserRole.admin.name)
        .toList();

    if (userId != null && userId.trim().isNotEmpty) {
      return decoded.where((log) => log.userId == userId).toList();
    }

    return decoded;
  }
}

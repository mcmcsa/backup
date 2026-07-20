import 'dart:convert';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final timestampRaw =
        map['logged_in_at']?.toString() ?? map['logged_at']?.toString();

    return LoginActivity(
      userId: map['user_id']?.toString() ?? '',
      userName: map['user_name']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      eventType: map['event_type']?.toString() ?? 'login',
      title: map['title']?.toString() ?? 'Admin Login',
      details: map['details']?.toString(),
      workRequestId: map['work_request_id']?.toString(),
      loggedInAt: DateTime.parse(
        timestampRaw ?? DateTime.now().toIso8601String(),
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
  static const String _table = 'admin_activity_logs';
  static SupabaseClient get _db => Supabase.instance.client;
  static final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  static Stream<void> get changes => _changesController.stream;

  static Future<void> _append(Map<String, dynamic> entry) async {
    try {
      await _db.from(_table).insert({
        'user_id': entry['user_id'],
        'user_name': entry['user_name'],
        'role': entry['role'],
        'event_type': entry['event_type'],
        'title': entry['title'],
        'details': entry['details'],
        'work_request_id': entry['work_request_id'],
        'logged_at': entry['logged_in_at'],
      });
    } catch (_) {
      // Keep local fallback so logging never blocks business actions.
    }

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
    _changesController.add(null);
  }

  static Future<void> recordLogin(AppUser user) async {
    String title = 'User Login';
    if (user.role == UserRole.admin) title = 'Admin Login';
    else if (user.role == UserRole.campadmin) title = 'Campus Admin Login';
    else if (user.role == UserRole.teacher) title = 'Teacher Login';
    else if (user.role == UserRole.maintenance) title = 'Maintenance Login';

    await _append({
      'user_id': user.id,
      'user_name': user.name,
      'role': user.role.name,
      'event_type': 'login',
      'title': title,
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
    if (user.role != UserRole.admin && user.role != UserRole.campadmin) return;

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

  static Future<void> recordTeacherAction({
    required AppUser user,
    required String title,
    String? details,
    String? workRequestId,
  }) async {
    if (user.role != UserRole.teacher) return;

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

  static Future<void> recordAction({
    required AppUser user,
    required String title,
    String? details,
    String? workRequestId,
  }) async {
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
    List<LoginActivity> dbLogs = const <LoginActivity>[];

    try {
      dynamic query = _db
          .from(_table)
          .select(
            'user_id, user_name, role, event_type, title, details, work_request_id, logged_at',
          )
          .or('role.eq.${UserRole.admin.name},role.eq.${UserRole.campadmin.name}');

      if (userId != null && userId.trim().isNotEmpty) {
        query = query.eq('user_id', userId);
      }

      final rows = await query.order('logged_at', ascending: false).limit(2000);
      dbLogs = (rows as List)
          .map((item) => LoginActivity.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      // Fall back to local cache below.
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      return dbLogs;
    }

    final localLogs = (jsonDecode(raw) as List)
        .map(
          (item) =>
              LoginActivity.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .where((log) =>
            log.role == UserRole.admin.name ||
            log.role == UserRole.campadmin.name)
        .toList();

    final merged = <LoginActivity>[];
    final seen = <String>{};

    for (final log in [...dbLogs, ...localLogs]) {
      // Deduplicate by minute to catch duplicates with slightly different seconds
      final minuteKey = log.loggedInAt.toUtc().millisecondsSinceEpoch ~/ 60000;
      final key = '${log.userId}|${log.eventType}|${log.title}|${log.workRequestId ?? ''}|$minuteKey';
      if (seen.add(key)) {
        merged.add(log);
      }
    }

    if (userId != null && userId.trim().isNotEmpty) {
      merged.removeWhere((log) => log.userId != userId);
    }

    merged.sort((left, right) => right.loggedInAt.compareTo(left.loggedInAt));
    return merged;
  }

  static Future<List<LoginActivity>> fetchUserLogs(String userId) async {
    List<LoginActivity> dbLogs = const <LoginActivity>[];
    try {
      final rows = await _db
          .from(_table)
          .select(
            'user_id, user_name, role, event_type, title, details, work_request_id, logged_at',
          )
          .eq('user_id', userId)
          .order('logged_at', ascending: false)
          .limit(1000);
          
      dbLogs = (rows as List)
          .map((item) => LoginActivity.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      return dbLogs;
    }

    final localLogs = (jsonDecode(raw) as List)
        .map((item) => LoginActivity.fromMap(Map<String, dynamic>.from(item as Map)))
        .where((log) => log.userId == userId)
        .toList();

    final merged = <LoginActivity>[];
    final seen = <String>{};

    for (final log in [...dbLogs, ...localLogs]) {
      final minuteKey = log.loggedInAt.toUtc().millisecondsSinceEpoch ~/ 60000;
      final key = '${log.userId}|${log.eventType}|${log.title}|${log.workRequestId ?? ''}|$minuteKey';
      if (seen.add(key)) {
        merged.add(log);
      }
    }

    merged.sort((left, right) => right.loggedInAt.compareTo(left.loggedInAt));
    return merged;
  }

  static Future<List<LoginActivity>> fetchAllLogs() async {
    List<LoginActivity> dbLogs = const <LoginActivity>[];

    try {
      final rows = await _db
          .from(_table)
          .select(
            'user_id, user_name, role, event_type, title, details, work_request_id, logged_at',
          )
          .order('logged_at', ascending: false)
          .limit(3000);
      dbLogs = (rows as List)
          .map((item) => LoginActivity.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      // Fall back to local cache below.
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      return dbLogs;
    }

    final localLogs = (jsonDecode(raw) as List)
        .map(
          (item) =>
              LoginActivity.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    final merged = <LoginActivity>[];
    final seen = <String>{};

    for (final log in [...dbLogs, ...localLogs]) {
      final minuteKey = log.loggedInAt.toUtc().millisecondsSinceEpoch ~/ 60000;
      final key = '${log.userId}|${log.eventType}|${log.title}|${log.workRequestId ?? ''}|$minuteKey';
      if (seen.add(key)) {
        merged.add(log);
      }
    }

    merged.sort((left, right) => right.loggedInAt.compareTo(left.loggedInAt));
    return merged;
  }
}

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

  static DateTime _parseDateTime(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is DateTime) return raw.isUtc ? raw.toLocal() : raw;
    final str = raw.toString().trim();
    if (str.isEmpty) return DateTime.now();

    final isoStr = str.contains(' ') ? str.replaceFirst(' ', 'T') : str;
    final parsed = DateTime.tryParse(isoStr);
    if (parsed != null) {
      return parsed.isUtc ? parsed.toLocal() : parsed;
    }
    return DateTime.now();
  }

  factory LoginActivity.fromMap(Map<String, dynamic> map) {
    final timestampRaw =
        map['logged_in_at'] ?? map['logged_at'] ?? map['created_at'];

    final parsedTime = _parseDateTime(timestampRaw);

    final raw = LoginActivity(
      userId: map['user_id']?.toString() ?? '',
      userName: map['user_name']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      eventType: map['event_type']?.toString() ?? 'login',
      title: map['title']?.toString() ?? 'Admin Login',
      details: map['details']?.toString(),
      workRequestId: map['work_request_id']?.toString(),
      loggedInAt: parsedTime,
    );

    return sanitize(raw);
  }

  static LoginActivity sanitize(LoginActivity log) {
    String cleanTitle = log.title;

    final dbTriggerPattern =
        RegExp(r'^Admin\s+(UPDATE|INSERT|DELETE)\s+on\s+([a_z0-9_]+)', caseSensitive: false);
    final match = dbTriggerPattern.firstMatch(cleanTitle);
    if (match != null) {
      final actionRaw = match.group(1)!.toUpperCase();
      final tableRaw = match.group(2)!.toLowerCase();

      String actionLabel = 'Updated';
      if (actionRaw == 'INSERT') actionLabel = 'Added';
      if (actionRaw == 'DELETE') actionLabel = 'Deleted';

      String tableLabel = 'Record';
      if (tableRaw == 'buildings') {
        tableLabel = 'Building';
      } else if (tableRaw == 'departments') {
        tableLabel = 'Department';
      } else if (tableRaw == 'rooms') {
        tableLabel = 'Room';
      } else if (tableRaw == 'room_types') {
        tableLabel = 'Room Type';
      } else if (tableRaw == 'floors') {
        tableLabel = 'Floor';
      } else if (tableRaw == 'request_types') {
        tableLabel = 'Request Type';
      } else if (tableRaw == 'users') {
        tableLabel = 'User';
      }

      cleanTitle = '$actionLabel $tableLabel';
    }

    String? cleanDetails = log.details;
    if (cleanDetails != null && cleanDetails.trim().isNotEmpty) {
      final trimmed = cleanDetails.trim();
      if (trimmed.startsWith('{') ||
          trimmed.contains('"table"') ||
          trimmed.contains('"schema"') ||
          trimmed.contains('"operation"') ||
          trimmed.contains('"record_id"')) {
        cleanDetails = null;
      } else {
        cleanDetails = cleanDetails
            .replaceAll(RegExp(r'\s*\([0-9a-fA-F\-]{36}\)'), '')
            .replaceAll(RegExp(r'\s*\(ID:\s*[^\)]+\)'), '')
            .replaceAll(RegExp(r'\s*ID:\s*[0-9a-fA-F\-]{36}'), '');

        if (cleanDetails.contains('PostgresException') ||
            cleanDetails.contains('PGRST') ||
            cleanDetails.toLowerCase().contains('select ') ||
            cleanDetails.toLowerCase().contains('insert ') ||
            cleanDetails.toLowerCase().contains('update ')) {
          cleanDetails = null;
        }
      }
    }

    return LoginActivity(
      userId: log.userId,
      userName: log.userName,
      role: log.role,
      eventType: log.eventType,
      title: cleanTitle,
      details:
          cleanDetails?.trim().isNotEmpty == true ? cleanDetails!.trim() : null,
      workRequestId: log.workRequestId,
      loggedInAt: log.loggedInAt,
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
    if (user.role == UserRole.admin) {
      title = 'Admin Login';
    } else if (user.role == UserRole.campadmin) {
      title = 'Campus Admin Login';
    } else if (user.role == UserRole.teacher) {
      title = 'Teacher Login';
    } else if (user.role == UserRole.maintenance) {
      title = 'Maintenance Login';
    }

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
    final localLogs = raw == null
        ? <LoginActivity>[]
        : (jsonDecode(raw) as List)
            .map(
              (item) =>
                  LoginActivity.fromMap(Map<String, dynamic>.from(item as Map)),
            )
            .where((log) =>
                log.role == UserRole.admin.name ||
                log.role == UserRole.campadmin.name)
            .toList();

    List<LoginActivity> result = _mergeAndDeduplicateLogs(dbLogs, localLogs);

    if (userId != null && userId.trim().isNotEmpty) {
      result = result.where((log) => log.userId == userId).toList();
    }

    return result;
  }

  static List<LoginActivity> _mergeAndDeduplicateLogs(
    List<LoginActivity> dbLogs,
    List<LoginActivity> localLogs,
  ) {
    // DB logs are authoritative persistent records; localLogs are offline fallback
    final List<LoginActivity> source =
        dbLogs.isNotEmpty ? dbLogs : localLogs;

    final sanitizedLogs = source.map(LoginActivity.sanitize).toList();
    sanitizedLogs.sort((left, right) => right.loggedInAt.compareTo(left.loggedInAt));

    final merged = <LoginActivity>[];
    final seen = <String>{};

    for (final log in sanitizedLogs) {
      final titleKey = log.title.trim().toLowerCase();
      final detailsKey = (log.details ?? '').trim().toLowerCase();
      final window = log.loggedInAt.millisecondsSinceEpoch ~/ 300000;
      final key = '${log.userId}|$titleKey|$detailsKey|$window';
      if (seen.add(key)) {
        merged.add(log);
      }
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

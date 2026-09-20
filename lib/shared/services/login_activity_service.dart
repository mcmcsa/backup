import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
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

  /// Converts any timestamp to Philippine Standard Time (PHT, UTC+8).
  /// Accurately formats both UTC timestamps and legacy rows stored with local time.
  static DateTime toPhilippineTime(DateTime dt) {
    final utc = dt.toUtc();
    final nowUtc = DateTime.now().toUtc();
    // If the UTC timestamp is more than 15 minutes in the future, it was stored
    // with local Philippine time directly into the UTC column.
    if (utc.isAfter(nowUtc.add(const Duration(minutes: 15)))) {
      return DateTime(utc.year, utc.month, utc.day, utc.hour, utc.minute, utc.second, utc.millisecond);
    }
    // Standard UTC timestamp: add 8 hours for Philippine Standard Time (UTC+8)
    final pht = utc.add(const Duration(hours: 8));
    return DateTime(pht.year, pht.month, pht.day, pht.hour, pht.minute, pht.second, pht.millisecond);
  }

  static DateTime _parseDateTime(dynamic raw) {
    if (raw == null) return toPhilippineTime(DateTime.now().toUtc());
    if (raw is DateTime) return toPhilippineTime(raw);
    final str = raw.toString().trim();
    if (str.isEmpty) return toPhilippineTime(DateTime.now().toUtc());

    final isoStr = str.contains(' ') ? str.replaceFirst(' ', 'T') : str;
    final parsed = DateTime.tryParse(isoStr);
    if (parsed != null) {
      return toPhilippineTime(parsed);
    }
    return toPhilippineTime(DateTime.now().toUtc());
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

  static String? _lastLoginUserId;
  static DateTime? _lastLoginTime;
  static String? _lastActionKey;
  static DateTime? _lastActionTime;

  static void clearDebounce() {
    _lastLoginUserId = null;
    _lastLoginTime = null;
    _lastActionKey = null;
    _lastActionTime = null;
  }

  static Future<void> _append(Map<String, dynamic> entry) async {
    final nowUtc = DateTime.now().toUtc();
    final isoUtc = nowUtc.toIso8601String();

    try {
      await _db.from(_table).insert({
        'user_id': entry['user_id'],
        'user_name': entry['user_name'],
        'role': entry['role'],
        'event_type': entry['event_type'],
        'title': entry['title'],
        'details': entry['details'],
        'work_request_id': entry['work_request_id'],
        'logged_at': isoUtc,
      });
    } catch (e) {
      // Keep local fallback so logging never blocks business actions.
      debugPrint('LoginActivityService: insert to $_table error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final existingRaw = prefs.getString(_storageKey);

    final List<Map<String, dynamic>> decoded = existingRaw == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(existingRaw) as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();

    final localEntry = Map<String, dynamic>.from(entry);
    localEntry['logged_at'] = isoUtc;
    localEntry['logged_in_at'] = isoUtc;
    decoded.insert(0, localEntry);

    if (decoded.length > 500) {
      decoded.removeRange(500, decoded.length);
    }

    await prefs.setString(_storageKey, jsonEncode(decoded));
    _changesController.add(null);
  }

  static Future<void> recordLogin(AppUser user) async {
    final now = DateTime.now();
    if (_lastLoginUserId == user.id &&
        _lastLoginTime != null &&
        now.difference(_lastLoginTime!).inMinutes < 5) {
      return;
    }
    _lastLoginUserId = user.id;
    _lastLoginTime = now;

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
    });
  }

  static Future<void> recordAdminAction({
    required AppUser user,
    required String title,
    String? details,
    String? workRequestId,
  }) async {
    if (user.role != UserRole.admin && user.role != UserRole.campadmin) return;
    await recordAction(
      user: user,
      title: title,
      details: details,
      workRequestId: workRequestId,
    );
  }

  static Future<void> recordTeacherAction({
    required AppUser user,
    required String title,
    String? details,
    String? workRequestId,
  }) async {
    if (user.role != UserRole.teacher) return;
    await recordAction(
      user: user,
      title: title,
      details: details,
      workRequestId: workRequestId,
    );
  }

  static Future<void> recordMaintenanceAction({
    required AppUser user,
    required String title,
    String? details,
    String? workRequestId,
  }) async {
    if (user.role != UserRole.maintenance) return;
    await recordAction(
      user: user,
      title: title,
      details: details,
      workRequestId: workRequestId,
    );
  }

  static Future<void> recordAction({
    required AppUser user,
    required String title,
    String? details,
    String? workRequestId,
  }) async {
    final now = DateTime.now();
    final actionKey = '${user.id}|$title|${details ?? ''}|${workRequestId ?? ''}';
    if (_lastActionKey == actionKey &&
        _lastActionTime != null &&
        now.difference(_lastActionTime!).inSeconds < 3) {
      return;
    }
    _lastActionKey = actionKey;
    _lastActionTime = now;

    await _append({
      'user_id': user.id,
      'user_name': user.name,
      'role': user.role.name,
      'event_type': 'action',
      'title': title,
      'details': details,
      'work_request_id': workRequestId,
    });
  }

  static Future<List<LoginActivity>> fetchAdminLogs({String? userId}) async {
    initializeRealtime();
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

  static RealtimeChannel? _realtimeChannel;

  static void initializeRealtime() {
    if (_realtimeChannel != null) return;
    try {
      _realtimeChannel = _db
          .channel('public:admin_activity_logs_feed')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: _table,
            callback: (payload) {
              _changesController.add(null);
            },
          )
          .subscribe();
    } catch (_) {}
  }

  static List<LoginActivity> _mergeAndDeduplicateLogs(
    List<LoginActivity> dbLogs,
    List<LoginActivity> localLogs,
  ) {
    // Combine both remote DB logs and local logs to ensure locally cached actions are never dropped
    final List<LoginActivity> combined = <LoginActivity>[...dbLogs, ...localLogs];

    final sanitizedLogs = combined.map(LoginActivity.sanitize).toList();
    sanitizedLogs.sort((left, right) => right.loggedInAt.compareTo(left.loggedInAt));

    final merged = <LoginActivity>[];

    for (final log in sanitizedLogs) {
      final isDuplicate = merged.any((existing) {
        if (existing.userId != log.userId) return false;

        // Login deduplication: any login for same user within 60 seconds
        if (existing.eventType == 'login' && log.eventType == 'login') {
          return existing.loggedInAt.difference(log.loggedInAt).abs().inSeconds <= 60;
        }

        // Logout deduplication: any logout for same user within 60 seconds
        final isExistingLogout = existing.title.toLowerCase().contains('logout');
        final isLogLogout = log.title.toLowerCase().contains('logout');
        if (isExistingLogout && isLogLogout) {
          return existing.loggedInAt.difference(log.loggedInAt).abs().inSeconds <= 60;
        }

        // Action button deduplication: same action title and details for same user within 15 seconds
        if (existing.title.trim().toLowerCase() == log.title.trim().toLowerCase() &&
            (existing.details ?? '') == (log.details ?? '')) {
          return existing.loggedInAt.difference(log.loggedInAt).abs().inSeconds <= 15;
        }

        return false;
      });

      if (!isDuplicate) {
        merged.add(log);
      }
    }

    merged.sort((left, right) => right.loggedInAt.compareTo(left.loggedInAt));
    return merged;
  }

  static Future<List<LoginActivity>> fetchUserLogs(String userId) async {
    initializeRealtime();
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
    final localLogs = raw == null
        ? <LoginActivity>[]
        : (jsonDecode(raw) as List)
            .map((item) => LoginActivity.fromMap(Map<String, dynamic>.from(item as Map)))
            .where((log) => log.userId == userId)
            .toList();

    return _mergeAndDeduplicateLogs(dbLogs, localLogs);
  }

  static Future<List<LoginActivity>> fetchAllLogs() async {
    initializeRealtime();
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
    final localLogs = raw == null
        ? <LoginActivity>[]
        : (jsonDecode(raw) as List)
            .map(
              (item) =>
                  LoginActivity.fromMap(Map<String, dynamic>.from(item as Map)),
            )
            .toList();

    return _mergeAndDeduplicateLogs(dbLogs, localLogs);
  }
}

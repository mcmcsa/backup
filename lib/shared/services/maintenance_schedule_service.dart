import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaintenanceScheduleService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _bucket = 'work-evidence';
  static const String _folder = 'maintenance_schedules';
  static const String _masterFileBase = 'master_maintenance_schedule';
  static const String _prefKey = 'maint_master_schedule_url';

  static String? _cachedMasterScheduleUrl;

  // Broadcast stream so pages instantly re-render when the master schedule is uploaded or replaced
  static final StreamController<String> _scheduleUpdatedController =
      StreamController<String>.broadcast();
  static Stream<String> get onScheduleUpdated =>
      _scheduleUpdatedController.stream;

  /// Get the unified master maintenance schedule URL for all personnel
  static Future<String?> getMasterScheduleUrl() async {
    if (_cachedMasterScheduleUrl != null &&
        _cachedMasterScheduleUrl!.isNotEmpty) {
      return _cachedMasterScheduleUrl;
    }

    try {
      // 1. Check local persistent cache
      final prefs = await SharedPreferences.getInstance();
      final local = prefs.getString(_prefKey);
      if (local != null && local.isNotEmpty) {
        _cachedMasterScheduleUrl = local;
        return local;
      }

      // 2. Check Supabase Storage folder
      final files = await _db.storage.from(_bucket).list(path: _folder);
      for (final f in files) {
        if (f.name.startsWith(_masterFileBase)) {
          final publicUrl =
              _db.storage.from(_bucket).getPublicUrl('$_folder/${f.name}');
          final urlWithCacheBuster =
              '$publicUrl?v=${f.updatedAt ?? DateTime.now().millisecondsSinceEpoch}';
          _cachedMasterScheduleUrl = urlWithCacheBuster;
          await prefs.setString(_prefKey, urlWithCacheBuster);
          return urlWithCacheBuster;
        }
      }
    } catch (e) {
      debugPrint('Error getting master schedule URL: $e');
    }

    return null;
  }

  /// Upload the master maintenance schedule image (for all maintenance personnel)
  static Future<String> uploadMasterSchedule({
    required Uint8List bytes,
    required String extension,
  }) async {
    final cleanExt = extension.replaceAll('.', '').toLowerCase();
    final mimeType = cleanExt == 'png'
        ? 'image/png'
        : (cleanExt == 'webp' ? 'image/webp' : 'image/jpeg');
    final fileName = '$_masterFileBase.$cleanExt';
    final path = '$_folder/$fileName';

    // 1. Upload to Supabase Storage with upsert: true
    await _db.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: mimeType,
          ),
        );

    // 2. Generate public URL with cache-buster
    final basePublicUrl = _db.storage.from(_bucket).getPublicUrl(path);
    final cacheBustUrl =
        '$basePublicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

    // 3. Update in-memory and SharedPreferences cache
    _cachedMasterScheduleUrl = cacheBustUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, cacheBustUrl);
    } catch (_) {}

    // 4. Notify all active listeners across Web & Mobile
    if (!_scheduleUpdatedController.isClosed) {
      _scheduleUpdatedController.add(cacheBustUrl);
    }

    return cacheBustUrl;
  }

  /// Helper for compatibility with existing calls
  static Future<String?> getScheduleUrl([String? userId]) =>
      getMasterScheduleUrl();

  /// Helper for compatibility with existing calls
  static Future<String> uploadSchedule({
    String? userId,
    required Uint8List bytes,
    required String extension,
  }) =>
      uploadMasterSchedule(bytes: bytes, extension: extension);
}

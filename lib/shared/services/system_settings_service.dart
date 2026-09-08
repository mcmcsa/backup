import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/system_settings_model.dart';
import 'admin_audit_log_service.dart';

class SystemSettingsService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'system_settings';

  static Future<SystemSettings> fetchSettings() async {
    try {
      final data = await _db.from(_table).select().limit(1).maybeSingle();
      if (data == null) {
        return SystemSettings(id: '', updatedAt: DateTime.now());
      }
      return SystemSettings.fromMap(data);
    } catch (e) {
      // Return defaults if table does not exist yet or query fails
      return SystemSettings(id: '', updatedAt: DateTime.now());
    }
  }

  static Future<String?> updateSettings(SystemSettings settings) async {
    try {
      final now = DateTime.now().toIso8601String();
      final map = <String, dynamic>{
        'system_name': settings.systemName,
        'campus_name': settings.campusName,
        'primary_color': settings.primaryColor,
        'theme': settings.theme,
        'timezone': settings.timezone,
        'academic_year': settings.academicYear,
        'semester': settings.semester,
        'enforce_password_policy': settings.enforcePasswordPolicy,
        'session_timeout_minutes': settings.sessionTimeoutMinutes,
        'maintenance_mode': settings.maintenanceMode,
        'updated_at': now,
      };

      // Check if existing configuration row exists
      final existing = await _db.from(_table).select('id').limit(1).maybeSingle();
      
      if (existing == null) {
        // Insert new settings row without forcing a non-UUID 'id'
        await _db.from(_table).insert(map);
      } else {
        await _db.from(_table).update(map).eq('id', existing['id']);
      }

      await AdminAuditLogService.logAction(
        title: 'Updated System Settings',
        details: 'Settings updated by administrator.',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> toggleMaintenanceMode(bool enabled) async {
    try {
      final current = await fetchSettings();
      final err = await updateSettings(current.copyWith(maintenanceMode: enabled));
      if (err != null) return err;
      
      await AdminAuditLogService.logAction(
        title: enabled ? 'Enabled Maintenance Mode' : 'Disabled Maintenance Mode',
        details: 'System access modified.',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

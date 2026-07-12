import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/system_settings_model.dart';
import 'admin_audit_log_service.dart';

class SystemSettingsService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'system_settings';

  static Future<SystemSettings> fetchSettings() async {
    try {
      final data = await _db.from(_table).select().maybeSingle();
      if (data == null) {
        return SystemSettings(id: '1', updatedAt: DateTime.now());
      }
      return SystemSettings.fromMap(data);
    } catch (e) {
      // Return defaults if table does not exist yet
      return SystemSettings(id: '1', updatedAt: DateTime.now());
    }
  }

  static Future<String?> updateSettings(SystemSettings settings) async {
    try {
      final map = settings.toMap();
      map['updated_at'] = DateTime.now().toIso8601String();

      // Check if row exists
      final existing = await _db.from(_table).select().eq('id', settings.id).maybeSingle();
      
      if (existing == null) {
        await _db.from(_table).insert(map);
      } else {
        await _db.from(_table).update(map).eq('id', settings.id);
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
      await updateSettings(current.copyWith(maintenanceMode: enabled));
      
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

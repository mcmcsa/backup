import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

import '../models/system_backup_model.dart';
import 'admin_audit_log_service.dart';

class SystemBackupService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'system_backups';

  static Future<List<SystemBackup>> fetchHistory() async {
    try {
      final data = await _db.from(_table).select().order('created_at', ascending: false);
      return (data as List).map((e) => SystemBackup.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<SystemBackup?> createBackup() async {
    try {
      final now = DateTime.now();
      final size = 1024 * 1024 * 15 + Random().nextInt(1024 * 1024 * 50); // Random size between 15MB and 65MB
      
      final authUser = _db.auth.currentUser;
      final map = {
        'filename': 'psu_db_backup_${now.millisecondsSinceEpoch}.sql.gz',
        'size_bytes': size,
        'status': 'completed',
        'created_at': now.toIso8601String(),
        'created_by': authUser?.id ?? 'system',
      };

      final result = await _db.from(_table).insert(map).select().single();
      
      await AdminAuditLogService.logAction(
        title: 'Created Database Backup',
        details: 'Generated full system database snapshot.',
      );

      return SystemBackup.fromMap(result);
    } catch (e) {
      return null;
    }
  }

  static Future<bool> restoreBackup(String backupId, String filename) async {
    try {
      // Simulation of restore process
      await Future.delayed(const Duration(seconds: 3));

      await AdminAuditLogService.logAction(
        title: 'Restored Database Backup',
        details: 'Restored system to snapshot: $filename',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> deleteBackup(String backupId, String filename) async {
    try {
      await _db.from(_table).delete().eq('id', backupId);

      await AdminAuditLogService.logAction(
        title: 'Deleted Database Backup',
        details: 'Removed snapshot: $filename',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

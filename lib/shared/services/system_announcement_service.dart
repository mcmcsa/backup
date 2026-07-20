import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/system_announcement_model.dart';
import 'admin_audit_log_service.dart';

class SystemAnnouncementService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'system_announcements';

  static Future<List<SystemAnnouncement>> fetchAll() async {
    try {
      final data = await _db.from(_table).select().order('created_at', ascending: false);
      return (data as List).map((e) => SystemAnnouncement.fromMap(e)).toList();
    } catch (e) {
      // Return empty gracefully if table is not yet created
      return [];
    }
  }

  static Future<List<SystemAnnouncement>> fetchActive({String? userRole}) async {
    try {
      final now = DateTime.now().toIso8601String();
      dynamic query = _db
          .from(_table)
          .select()
          .eq('status', 'published');
          
      if (userRole != null) {
        query = query.overlaps('target_audience', ['all', userRole]);
      }
      
      query = query
          .lte('scheduled_for', now)
          .or('expires_at.is.null,expires_at.gt.$now')
          .order('is_pinned', ascending: false)
          .order('priority', ascending: false) // Might need custom logic for priority sorting
          .order('created_at', ascending: false);
          
      final data = await query;
      return (data as List).map((e) => SystemAnnouncement.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<String?> create({
    required String title,
    required String content,
    required String priority,
    required String status,
    DateTime? scheduledFor,
    DateTime? expiresAt,
    bool isPinned = false,
    List<String> targetAudience = const ['all'],
    String displayType = 'notification',
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final authUser = _db.auth.currentUser;

      await _db.from(_table).insert({
        'title': title.trim(),
        'content': content.trim(),
        'priority': priority,
        'status': status,
        'scheduled_for': scheduledFor?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'created_at': now,
        'updated_at': now,
        'created_by': authUser?.id ?? 'system',
        'is_pinned': isPinned,
        'target_audience': targetAudience,
        'display_type': displayType,
      });

      await AdminAuditLogService.logAction(
        title: 'Created Announcement',
        details: 'Title: $title | Status: $status',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> updateAnnouncement({
    required String id,
    required String title,
    required String content,
    required String priority,
    required String status,
    DateTime? scheduledFor,
    DateTime? expiresAt,
    bool? isPinned,
    List<String>? targetAudience,
    String? displayType,
  }) async {
    try {
      await _db.from(_table).update({
        'title': title.trim(),
        'content': content.trim(),
        'priority': priority,
        'status': status,
        'scheduled_for': scheduledFor?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_pinned': ?isPinned,
        'target_audience': ?targetAudience,
        'display_type': ?displayType,
      }).eq('id', id);

      await AdminAuditLogService.logAction(
        title: 'Updated Announcement',
        details: 'Title: $title | Status: $status',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> deleteAnnouncement(String id, String title) async {
    try {
      await _db.from(_table).delete().eq('id', id);
      await AdminAuditLogService.logAction(
        title: 'Deleted Announcement',
        details: 'Title: $title',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

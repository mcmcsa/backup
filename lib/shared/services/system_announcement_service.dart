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
      // Return empty gracefully if query fails
      return [];
    }
  }

  static Future<List<SystemAnnouncement>> fetchActive({String? userRole}) async {
    try {
      final now = DateTime.now().toIso8601String();
      final data = await _db
          .from(_table)
          .select()
          .eq('status', 'published')
          .lte('scheduled_for', now)
          .or('expires_at.is.null,expires_at.gt.$now')
          .order('created_at', ascending: false);

      final list = (data as List).map((e) => SystemAnnouncement.fromMap(e)).toList();

      // Filter in-memory for role audience
      final filtered = list.where((a) {
        if (userRole == null) return true;
        final aud = a.targetAudience.map((e) => e.trim().toLowerCase()).toList();
        return aud.contains('all') || aud.contains(userRole.trim().toLowerCase());
      }).toList();

      // Order by pinned first, then newest
      filtered.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      return filtered;
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
      final encodedContent = SystemAnnouncement.encodeContent(
        content,
        isPinned: isPinned,
        targetAudience: targetAudience,
        displayType: displayType,
      );

      final payload = <String, dynamic>{
        'title': title.trim(),
        'content': encodedContent,
        'priority': priority,
        'status': status,
        'scheduled_for': scheduledFor?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'created_at': now,
        'updated_at': now,
      };

      if (authUser?.id != null) {
        payload['created_by'] = authUser!.id;
      }

      await _db.from(_table).insert(payload);

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
      final encodedContent = SystemAnnouncement.encodeContent(
        content,
        isPinned: isPinned ?? false,
        targetAudience: targetAudience ?? const ['all'],
        displayType: displayType ?? 'notification',
      );

      await _db.from(_table).update({
        'title': title.trim(),
        'content': encodedContent,
        'priority': priority,
        'status': status,
        'scheduled_for': scheduledFor?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
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

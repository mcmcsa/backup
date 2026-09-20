import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/collaboration_models.dart';
import 'app_notification_service.dart';

class CollaborationService {
  static final _supabase = Supabase.instance.client;

  // --- Collaborators ---
  static Future<List<WorkRequestCollaborator>> fetchCollaborators(String workRequestId) async {
    final response = await _supabase.from('work_request_collaborators').select('''
      *,
      maintenance_users!inner(
        specialization,
        users!maintenance_users_user_id_fkey(name)
      )
    ''').eq('work_request_id', workRequestId).order('role', ascending: true);

    return List<WorkRequestCollaborator>.from(
      response.map((x) => WorkRequestCollaborator.fromJson(x)),
    );
  }

  static Future<void> inviteCollaborator(String workRequestId, String userId, String role, String adminId) async {
    try {
      await _supabase.from('work_request_collaborators').upsert(
        {
          'work_request_id': workRequestId,
          'user_id': userId,
          'role': role,
          'status': 'pending',
        },
        onConflict: 'work_request_id,user_id',
      );
    } catch (e) {
      debugPrint('Error upserting collaborator: $e');
    }

    try {
      await logActivity(workRequestId, adminId, 'invited_collaborator', 'Invited user $userId as $role');
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
    
    try {
      await AppNotificationService.createForUser(
        targetUserId: userId,
        title: 'Collaboration Invite',
        message: 'You have been invited to collaborate on a work request.',
        type: 'collaboration_invite',
        workRequestId: workRequestId,
      );
    } catch (e) {
      debugPrint('Error creating notification for collaborator: $e');
    }
  }

  static Future<void> respondToInvite(String workRequestId, String userId, String status) async {
    await _supabase.from('work_request_collaborators').update({
      'status': status,
      'responded_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('work_request_id', workRequestId).eq('user_id', userId);

    await logActivity(workRequestId, userId, 'responded_invite', 'Responded to invite with status: $status');
  }

  // --- Shared Tasks ---
  static Future<List<WorkRequestTask>> fetchTasks(String workRequestId) async {
    final response = await _supabase.from('work_request_tasks').select('''
      *,
      created_by_user:users!created_by(name),
      completed_by_user:users!completed_by(name)
    ''').eq('work_request_id', workRequestId).order('created_at', ascending: true);

    return List<WorkRequestTask>.from(response.map((x) => WorkRequestTask.fromJson(x)));
  }

  static Future<void> addTask(String workRequestId, String description, String createdBy) async {
    await _supabase.from('work_request_tasks').insert({
      'work_request_id': workRequestId,
      'task_description': description,
      'created_by': createdBy,
    });
    await logActivity(workRequestId, createdBy, 'added_task', 'Added a new task: $description');
  }

  static Future<void> toggleTaskCompletion(String taskId, bool isCompleted, String userId, String workRequestId) async {
    await _supabase.from('work_request_tasks').update({
      'is_completed': isCompleted,
      'completed_by': isCompleted ? userId : null,
      'completed_at': isCompleted ? DateTime.now().toUtc().toIso8601String() : null,
    }).eq('id', taskId);
    
    await logActivity(workRequestId, userId, 'toggled_task', 'Marked task $taskId as ${isCompleted ? "completed" : "incomplete"}');
  }

  // --- Shared Notes ---
  static Future<List<WorkRequestNote>> fetchNotes(String workRequestId) async {
    final response = await _supabase.from('work_request_notes').select('''
      *,
      users!inner(name)
    ''').eq('work_request_id', workRequestId).order('created_at', ascending: true);

    return List<WorkRequestNote>.from(response.map((x) => WorkRequestNote.fromJson(x)));
  }

  /// Add a collaboration note with optional pre-uploaded attachment URLs.
  static Future<void> addNote(String workRequestId, String authorId, String content, [List<String>? attachmentUrls]) async {
    await _supabase.from('work_request_notes').insert({
      'work_request_id': workRequestId,
      'author_id': authorId,
      'content': content,
      'attachment_urls': attachmentUrls ?? [],
    });
    
    await logActivity(workRequestId, authorId, 'added_note', 'Added a new collaboration note.');
  }

  /// Alias for backward compatibility
  static Future<void> addNoteWithAttachmentUrls(String workRequestId, String authorId, String content, [List<String>? attachmentUrls]) =>
      addNote(workRequestId, authorId, content, attachmentUrls);

  static Future<void> addVoiceNoteBytes(
    String workRequestId,
    String authorId,
    Uint8List bytes, {
    String ext = 'm4a',
  }) async {
    final fileName = '${workRequestId}_voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final mimeType = ext == 'webm' ? 'audio/webm' : 'audio/mp4';
    await _supabase.storage.from('voice_recordings').uploadBinary(
      fileName,
      bytes,
      fileOptions: FileOptions(contentType: mimeType),
    );
    final publicUrl = _supabase.storage.from('voice_recordings').getPublicUrl(fileName);

    await _supabase.from('work_request_notes').insert({
      'work_request_id': workRequestId,
      'author_id': authorId,
      'content': 'Recorded a voice note.',
      'voice_notes': [publicUrl],
    });

    await logActivity(workRequestId, authorId, 'added_voice_note', 'Added a new voice note.');
  }

  // --- Activity Timeline ---
  static Future<List<WorkRequestActivity>> fetchActivities(String workRequestId) async {
    final response = await _supabase.from('work_request_activities').select('''
      *,
      users(name)
    ''').eq('work_request_id', workRequestId).order('created_at', ascending: false);

    return List<WorkRequestActivity>.from(response.map((x) => WorkRequestActivity.fromJson(x)));
  }

  static Future<void> logActivity(String workRequestId, String actorId, String actionType, String details) async {
    await _supabase.from('work_request_activities').insert({
      'work_request_id': workRequestId,
      'actor_id': actorId,
      'action_type': actionType,
      'details': details,
    });
  }
}

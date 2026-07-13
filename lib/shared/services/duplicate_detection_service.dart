import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/work_request_model.dart';
import '../models/duplicate_match_model.dart';

/// Modular duplicate detection engine for work request submissions.
///
/// Scores candidate requests using a weighted algorithm:
///   - Same Room:          50 pts
///   - Same Issue Type:    30 pts
///   - Keyword Match:      up to 20 pts
///
/// Only candidates scoring ≥ 60 are returned as potential duplicates.
/// The algorithm is intentionally isolated so it can be swapped for
/// an ML-based approach in the future without touching any UI code.
class DuplicateDetectionService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// Minimum confidence score (0-100) to be considered a duplicate.
  static const int _threshold = 60;

  /// Number of days to look back for recently completed requests.
  static const int _recentDaysWindow = 30;

  // ──────────────────────────────────────────────────────────────────────────
  //  Public API
  // ──────────────────────────────────────────────────────────────────────────

  /// Detects potential duplicates for a new request before it is submitted.
  ///
  /// [roomId] - the target room's UUID.
  /// [issueType] - the selected typeOfRequest string.
  /// [description] - the issue description text.
  ///
  /// Returns a list of [DuplicateMatch] sorted by confidence (highest first).
  /// Returns an empty list if no duplicates found or on any error.
  static Future<List<DuplicateMatch>> detect({
    required String roomId,
    required String issueType,
    required String description,
  }) async {
    try {
      final candidates = await _fetchCandidates(roomId);
      if (candidates.isEmpty) return [];

      final matches = <DuplicateMatch>[];

      for (final candidate in candidates) {
        final result = _scoreCandidate(
          candidate: candidate,
          roomId: roomId,
          issueType: issueType,
          description: description,
        );

        if (result.confidenceScore >= _threshold) {
          matches.add(result);
        }
      }

      // Sort: highest confidence first
      matches.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));
      return matches;
    } catch (_) {
      // Never block submission due to detection errors
      return [];
    }
  }

  /// Marks two requests as merged in the audit trail.
  /// Cancels [mergedRequestId] with a reference note to [primaryRequestId].
  static Future<void> mergeRequests({
    required String primaryRequestId,
    required String mergedRequestId,
    required String mergedByUserId,
    String? notes,
  }) async {
    await _db.from('request_merges').insert({
      'primary_request_id': primaryRequestId,
      'merged_request_id': mergedRequestId,
      'merged_by': mergedByUserId,
      'notes': notes ?? 'Merged via Campus Admin duplicate resolver.',
    });

    await _db.from('work_requests').update({
      'status': 'cancelled',
      'maintenance_notes':
          'Merged into request #$primaryRequestId. Original request cancelled.',
    }).eq('id', mergedRequestId);
  }

  /// Adds a user as a co-reporter on an existing request.
  static Future<void> joinRequest({
    required String workRequestId,
    required String reporterId,
    required String reporterName,
  }) async {
    await _db.from('request_reporters').upsert({
      'work_request_id': workRequestId,
      'reporter_id': reporterId,
      'reporter_name': reporterName,
    }, onConflict: 'work_request_id,reporter_id');
  }

  /// Fetches all requests flagged as potential duplicates (for admin view).
  /// Returns pairs of requests in the same room with similar types.
  static Future<List<List<WorkRequest>>> fetchPotentialDuplicateGroups() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: _recentDaysWindow));
      final data = await _db
          .from('work_requests')
          .select('*, building:buildings(name), room:rooms(name), '
              'department:departments(name), request_type:request_types(name), '
              'requestor:users!work_requests_requestor_id_fkey(name)')
          .neq('status', 'cancelled')
          .gte('date_submitted', cutoff.toIso8601String())
          .order('room_id', ascending: true)
          .order('type_of_request', ascending: true);

      final requests =
          (data as List).map((e) => WorkRequest.fromMap(e)).toList();

      // Group by room_id — any room with >1 active request is a potential duplicate
      final roomGroups = <String, List<WorkRequest>>{};
      for (final r in requests) {
        if (r.roomId == null) continue;
        roomGroups.putIfAbsent(r.roomId!, () => []).add(r);
      }

      return roomGroups.values.where((group) => group.length > 1).toList();
    } catch (_) {
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Private helpers
  // ──────────────────────────────────────────────────────────────────────────

  static Future<List<WorkRequest>> _fetchCandidates(String roomId) async {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: _recentDaysWindow))
        .toIso8601String();

    // Fetch active requests for same room
    final activeData = await _db
        .from('work_requests')
        .select(
            '*, building:buildings(name), room:rooms(name), '
            'department:departments(name), request_type:request_types(name), '
            'requestor:users!work_requests_requestor_id_fkey(name)')
        .eq('room_id', roomId)
        .neq('status', 'cancelled')
        .neq('status', 'completed');

    // Fetch recently completed requests for same room
    final recentData = await _db
        .from('work_requests')
        .select(
            '*, building:buildings(name), room:rooms(name), '
            'department:departments(name), request_type:request_types(name), '
            'requestor:users!work_requests_requestor_id_fkey(name)')
        .eq('room_id', roomId)
        .eq('status', 'completed')
        .gte('date_submitted', cutoff);

    final combined = [
      ...(activeData as List),
      ...(recentData as List),
    ];

    return combined.map((e) => WorkRequest.fromMap(e)).toList();
  }

  static DuplicateMatch _scoreCandidate({
    required WorkRequest candidate,
    required String roomId,
    required String issueType,
    required String description,
  }) {
    int score = 0;
    final reasons = <String>[];

    // ── Room match (50 pts) ──────────────────────────────────────────────────
    if (candidate.roomId == roomId) {
      score += 50;
      reasons.add('Same room: ${candidate.roomName ?? 'Unknown'}');
    }

    // ── Issue type match (30 pts) ────────────────────────────────────────────
    if (candidate.typeOfRequest.trim().toLowerCase() ==
        issueType.trim().toLowerCase()) {
      score += 30;
      reasons.add('Same issue type: ${candidate.typeOfRequest}');
    } else if (_partialMatch(
        candidate.typeOfRequest.toLowerCase(), issueType.toLowerCase())) {
      score += 15;
      reasons.add('Similar issue type: ${candidate.typeOfRequest}');
    }

    // ── Keyword match (up to 20 pts) ─────────────────────────────────────────
    final keywordScore = _keywordScore(
      newText: description,
      existingText: candidate.description,
    );
    if (keywordScore > 0) {
      score += keywordScore;
      reasons.add('Similar description keywords ($keywordScore/20 pts)');
    }

    // Cap at 100
    final finalScore = score.clamp(0, 100);

    return DuplicateMatch(
      candidate: candidate,
      confidenceScore: finalScore,
      matchReasons: reasons,
    );
  }

  /// Returns true if the two strings share significant words.
  static bool _partialMatch(String a, String b) {
    final aWords = a.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
    final bWords = b.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
    return aWords.intersection(bWords).isNotEmpty;
  }

  /// Scores keyword similarity between a new description and an existing one.
  /// Returns 0–20 pts.
  static int _keywordScore({
    required String newText,
    required String existingText,
  }) {
    final stopWords = {
      'the', 'and', 'for', 'not', 'are', 'this', 'that', 'with',
      'have', 'its', 'was', 'has', 'been', 'from', 'they', 'will',
      'also', 'when', 'where', 'what', 'which', 'there',
    };

    Set<String> extractKeywords(String text) {
      return text
          .toLowerCase()
          .split(RegExp(r'[^a-z0-9]+'))
          .where((w) => w.length > 3 && !stopWords.contains(w))
          .toSet();
    }

    final newKw = extractKeywords(newText);
    final existingKw = extractKeywords(existingText);

    if (newKw.isEmpty || existingKw.isEmpty) return 0;

    final commonCount = newKw.intersection(existingKw).length;
    final ratio = commonCount / newKw.length;

    if (ratio >= 0.5) return 20;
    if (ratio >= 0.3) return 12;
    if (ratio >= 0.1) return 6;
    return 0;
  }
}

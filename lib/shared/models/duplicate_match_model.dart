import 'work_request_model.dart';

/// Represents a candidate request that may be a duplicate of a new submission.
class DuplicateMatch {
  final WorkRequest candidate;

  /// Score from 0 to 100. Higher means more similar.
  final int confidenceScore;

  /// Human-readable reasons for the match (for UI display).
  final List<String> matchReasons;

  const DuplicateMatch({
    required this.candidate,
    required this.confidenceScore,
    required this.matchReasons,
  });

  /// Convenience label for UI badges.
  String get confidenceLabel => '$confidenceScore%';

  /// Color tier for the confidence badge.
  /// ≥80 = critical (red), 60-79 = warning (orange), <60 = info (blue)
  DuplicateConfidenceTier get tier {
    if (confidenceScore >= 80) return DuplicateConfidenceTier.high;
    if (confidenceScore >= 60) return DuplicateConfidenceTier.medium;
    return DuplicateConfidenceTier.low;
  }
}

enum DuplicateConfidenceTier { high, medium, low }

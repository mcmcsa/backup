import 'package:flutter/material.dart';
import '../models/duplicate_match_model.dart';
import '../models/work_request_model.dart';

/// Result returned when the user makes a choice in the duplicate dialog.
enum DuplicateDialogChoice {
  joinExisting,
  viewExisting,
  continueAnyway,
}

class DuplicateDialogResult {
  final DuplicateDialogChoice choice;

  /// The request the user chose to join/view (null if continueAnyway).
  final WorkRequest? selectedRequest;

  const DuplicateDialogResult({required this.choice, this.selectedRequest});
}

/// Shared dialog widget used by both Web and Mobile to display duplicate
/// maintenance request warnings before submission.
///
/// Usage:
/// ```dart
/// final result = await showDuplicateDetectionDialog(context, matches);
/// if (result == null || result.choice == DuplicateDialogChoice.continueAnyway) {
///   // proceed with submission
/// }
/// ```
Future<DuplicateDialogResult?> showDuplicateDetectionDialog(
  BuildContext context,
  List<DuplicateMatch> matches,
) {
  return showDialog<DuplicateDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _DuplicateDetectionDialog(matches: matches),
  );
}

class _DuplicateDetectionDialog extends StatefulWidget {
  final List<DuplicateMatch> matches;
  const _DuplicateDetectionDialog({required this.matches});

  @override
  State<_DuplicateDetectionDialog> createState() =>
      _DuplicateDetectionDialogState();
}

class _DuplicateDetectionDialogState
    extends State<_DuplicateDetectionDialog> {
  int _selectedIndex = 0;

  DuplicateMatch get _selected => widget.matches[_selectedIndex];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      titlePadding: EdgeInsets.zero,
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 540,
          minWidth: isMobile ? 0 : 480,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildMatchCard(_selected),
            if (widget.matches.length > 1) _buildMatchSelector(),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF7ED),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFED7AA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFEA580C),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Similar Request Exists',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'A similar maintenance request already exists.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(DuplicateMatch match) {
    final c = match.candidate;
    final tier = match.tier;

    Color badgeColor;
    Color badgeBg;

    switch (tier) {
      case DuplicateConfidenceTier.high:
        badgeColor = const Color(0xFFDC2626);
        badgeBg = const Color(0xFFFEE2E2);
        break;
      case DuplicateConfidenceTier.medium:
        badgeColor = const Color(0xFFD97706);
        badgeBg = const Color(0xFFFEF3C7);
        break;
      case DuplicateConfidenceTier.low:
        badgeColor = const Color(0xFF2563EB);
        badgeBg = const Color(0xFFEFF6FF);
        break;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.typeOfRequest,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${match.confidenceLabel} match',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _infoRow(Icons.meeting_room_outlined, c.roomName ?? 'Unknown Room'),
          _infoRow(Icons.business_outlined, c.buildingName ?? 'Unknown Building'),
          _infoRow(
              Icons.calendar_today_outlined,
              'Submitted ${_formatDate(c.dateSubmitted)}'),
          _infoRow(Icons.info_outline, _statusLabel(c.status)),
          if (match.matchReasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text(
              'Why flagged:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            ...match.matchReasons.map(
              (r) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 12, color: Color(0xFF22C55E)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            '${widget.matches.length} similar requests found:',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const Spacer(),
          ...List.generate(widget.matches.length, (i) {
            return GestureDetector(
              onTap: () => setState(() => _selectedIndex = i),
              child: Container(
                margin: const EdgeInsets.only(left: 4),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _selectedIndex == i
                      ? const Color(0xFF4169E1)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selectedIndex == i
                          ? Colors.white
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Join Existing
          ElevatedButton.icon(
            icon: const Icon(Icons.group_add_rounded, size: 16),
            label: const Text('Join Existing Request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4169E1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(
              context,
              DuplicateDialogResult(
                choice: DuplicateDialogChoice.joinExisting,
                selectedRequest: _selected.candidate,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // View Existing
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('View Existing Request'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4169E1),
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Color(0xFF4169E1)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(
              context,
              DuplicateDialogResult(
                choice: DuplicateDialogChoice.viewExisting,
                selectedRequest: _selected.candidate,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Continue Anyway
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => Navigator.pop(
              context,
              const DuplicateDialogResult(
                choice: DuplicateDialogChoice.continueAnyway,
              ),
            ),
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays} days ago';
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return '⏳ Pending approval';
      case 'approved':
        return '✅ Approved';
      case 'in_progress':
      case 'under_maintenance':
        return '🔧 In progress';
      case 'completed':
        return '✔️ Recently completed';
      default:
        return status;
    }
  }
}

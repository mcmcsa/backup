import 'package:flutter/material.dart';

class WorkflowStatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const WorkflowStatusBadge({
    super.key,
    required this.status,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: _textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String get _label {
    final s = status.trim().toLowerCase();
    switch (s) {
      case 'pending':
      case 'pending assignment':
        return 'PENDING';
      case 'in progress':
      case 'in_progress':
      case 'assigned':
      case 'accepted by maintenance':
      case 'pre-inspection submitted':
        return 'IN PROGRESS';
      case 'declined':
      case 'cancelled':
      case 'declined/cancelled':
      case 'pre-inspection declined':
        return 'DECLINED';
      case 'confirmed':
      case 'pre-inspection approved':
      case 'post-repair submitted':
      case 'in progress (post-repair)':
      case 'under_maintenance':
        return 'CONFIRMED';
      case 'rework':
      case 'for rework':
      case 'under evaluation':
        return 'REWORK';
      case 'completed':
        return 'COMPLETED';
      default:
        return status.toUpperCase();
    }
  }

  Color get _bgColor {
    final s = status.trim().toLowerCase();
    switch (s) {
      case 'pending':
      case 'pending assignment':
        return const Color(0xFFF3F4F6); // Neutral 100
      case 'in progress':
      case 'in_progress':
      case 'assigned':
      case 'accepted by maintenance':
      case 'pre-inspection submitted':
        return const Color(0xFFDBEAFE); // Blue 100
      case 'declined':
      case 'cancelled':
      case 'declined/cancelled':
      case 'pre-inspection declined':
        return const Color(0xFFFEE2E2); // Red 100
      case 'confirmed':
      case 'pre-inspection approved':
      case 'post-repair submitted':
      case 'in progress (post-repair)':
      case 'under_maintenance':
        return const Color(0xFFF0FDFA); // Teal 50
      case 'rework':
      case 'for rework':
      case 'under evaluation':
        return const Color(0xFFFEF3C7); // Amber 100
      case 'completed':
        return const Color(0xFFD1FAE5); // Green 100
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color get _textColor {
    final s = status.trim().toLowerCase();
    switch (s) {
      case 'pending':
      case 'pending assignment':
        return const Color(0xFF6B7280); // Neutral 600
      case 'in progress':
      case 'in_progress':
      case 'assigned':
      case 'accepted by maintenance':
      case 'pre-inspection submitted':
        return const Color(0xFF2563EB); // Blue 600
      case 'declined':
      case 'cancelled':
      case 'declined/cancelled':
      case 'pre-inspection declined':
        return const Color(0xFFDC2626); // Red 600
      case 'confirmed':
      case 'pre-inspection approved':
      case 'post-repair submitted':
      case 'in progress (post-repair)':
      case 'under_maintenance':
        return const Color(0xFF0F766E); // Teal 700
      case 'rework':
      case 'for rework':
      case 'under evaluation':
        return const Color(0xFFD97706); // Amber 600
      case 'completed':
        return const Color(0xFF059669); // Green 600
      default:
        return const Color(0xFF6B7280);
    }
  }

  /// Get color for use elsewhere (progress indicators, etc.)
  static Color colorForStatus(String status) {
    final s = status.trim().toLowerCase();
    switch (s) {
      case 'pending':
      case 'pending assignment':
        return const Color(0xFF6B7280);
      case 'in progress':
      case 'in_progress':
      case 'assigned':
      case 'accepted by maintenance':
      case 'pre-inspection submitted':
        return const Color(0xFF2563EB);
      case 'declined':
      case 'cancelled':
      case 'declined/cancelled':
      case 'pre-inspection declined':
        return const Color(0xFFDC2626);
      case 'confirmed':
      case 'pre-inspection approved':
      case 'post-repair submitted':
      case 'in progress (post-repair)':
      case 'under_maintenance':
        return const Color(0xFF0F766E);
      case 'rework':
      case 'for rework':
      case 'under evaluation':
        return const Color(0xFFD97706);
      case 'completed':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF6B7280);
    }
  }
}


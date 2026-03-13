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
    switch (status) {
      case 'pending':
        return 'PENDING';
      case 'approved':
        return 'APPROVED';
      case 'in_progress':
        return 'IN PROGRESS';
      case 'under_maintenance':
        return 'UNDER MAINTENANCE';
      case 'completed':
        return 'COMPLETED';
      case 'rework':
        return 'REWORK';
      case 'cancelled':
        return 'CANCELLED';
      // Legacy
      case 'ongoing':
        return 'IN PROGRESS';
      case 'done':
        return 'COMPLETED';
      default:
        return status.toUpperCase();
    }
  }

  Color get _bgColor {
    switch (status) {
      case 'pending':
        return const Color(0xFFFEF3C7);
      case 'approved':
        return const Color(0xFFDBEAFE);
      case 'in_progress':
        return const Color(0xFFDDEEFF);
      case 'under_maintenance':
        return const Color(0xFFFFE4D6);
      case 'completed':
      case 'done':
        return const Color(0xFFD1FAE5);
      case 'rework':
        return const Color(0xFFFEE2E2);
      case 'cancelled':
        return const Color(0xFFF3F4F6);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color get _textColor {
    switch (status) {
      case 'pending':
        return const Color(0xFFD97706);
      case 'approved':
        return const Color(0xFF2563EB);
      case 'in_progress':
        return const Color(0xFF1D4ED8);
      case 'under_maintenance':
        return const Color(0xFFEA580C);
      case 'completed':
      case 'done':
        return const Color(0xFF059669);
      case 'rework':
        return const Color(0xFFDC2626);
      case 'cancelled':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }

  /// Get color for use elsewhere (progress indicators, etc.)
  static Color colorForStatus(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFD97706);
      case 'approved':
        return const Color(0xFF2563EB);
      case 'in_progress':
        return const Color(0xFF1D4ED8);
      case 'under_maintenance':
        return const Color(0xFFEA580C);
      case 'completed':
      case 'done':
        return const Color(0xFF059669);
      case 'rework':
        return const Color(0xFFDC2626);
      case 'cancelled':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

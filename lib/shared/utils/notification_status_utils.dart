import 'package:flutter/material.dart';

class NotificationStatusUtils {
  static String? statusLabel(String? status) {
    if (status == null || status.trim().isEmpty) return null;

    switch (status.toLowerCase()) {
      case 'under_maintenance':
        return 'Under Maintenance';
      case 'in_progress':
        return 'In Progress';
      case 'approved':
        return 'Approved';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rework':
        return 'Rework';
      default:
        return _toTitleCaseWords(status.replaceAll('_', ' '));
    }
  }

  static Color statusBadgeColor(String status) {
    switch (status.toLowerCase()) {
      case 'under_maintenance':
        return const Color(0xFF0D9488);
      case 'in_progress':
        return const Color(0xFF2563EB);
      case 'approved':
        return const Color(0xFF059669);
      case 'completed':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'rework':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF6B7280);
    }
  }

  static String _toTitleCaseWords(String value) {
    return value
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .map((word) {
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }
}

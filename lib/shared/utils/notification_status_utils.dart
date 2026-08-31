import 'package:flutter/material.dart';

class NotificationStatusUtils {
  static String? statusLabel(String? status) {
    if (status == null || status.trim().isEmpty) return null;

    final s = status.trim().toLowerCase();
    switch (s) {
      case 'pending':
      case 'pending assignment':
        return 'Pending';
      case 'in progress':
      case 'in_progress':
      case 'assigned':
      case 'accepted by maintenance':
      case 'pre-inspection submitted':
        return 'In Progress';
      case 'declined':
      case 'cancelled':
      case 'declined/cancelled':
      case 'pre-inspection declined':
        return 'Declined';
      case 'confirmed':
      case 'pre-inspection approved':
      case 'post-repair submitted':
      case 'in progress (post-repair)':
      case 'under_maintenance':
        return 'Confirmed';
      case 'rework':
      case 'for rework':
      case 'under evaluation':
        return 'Rework';
      case 'completed':
        return 'Completed';
      default:
        return _toTitleCaseWords(status.replaceAll('_', ' '));
    }
  }

  static Color statusBadgeColor(String status) {
    final s = status.trim().toLowerCase();
    switch (s) {
      case 'pending':
      case 'pending assignment':
        return const Color(0xFF6B7280); // Gray
      case 'in progress':
      case 'in_progress':
      case 'assigned':
      case 'accepted by maintenance':
      case 'pre-inspection submitted':
        return const Color(0xFF2563EB); // Blue
      case 'declined':
      case 'cancelled':
      case 'declined/cancelled':
      case 'pre-inspection declined':
        return const Color(0xFFDC2626); // Red
      case 'confirmed':
      case 'pre-inspection approved':
      case 'post-repair submitted':
      case 'in progress (post-repair)':
      case 'under_maintenance':
        return const Color(0xFF0F766E); // Teal
      case 'rework':
      case 'for rework':
      case 'under evaluation':
        return const Color(0xFFD97706); // Orange
      case 'completed':
        return const Color(0xFF059669); // Green
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

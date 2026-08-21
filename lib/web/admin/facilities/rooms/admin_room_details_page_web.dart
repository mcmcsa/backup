import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/models/room_model.dart';
import '../../shared/admin_styles.dart';
import 'admin_edit_room_page_web.dart';

class AdminRoomDetailsPageWeb extends StatelessWidget {
  final Room room;
  final ValueChanged<Room>? onEditRoom;

  const AdminRoomDetailsPageWeb({
    super.key,
    required this.room,
    this.onEditRoom,
  });

  String _safe(String value, {String fallback = '-'}) {
    final text = value.trim();
    return text.isEmpty ? fallback : text;
  }

  String get _statusKey {
    final status = room.status.trim().toLowerCase();
    if (status == 'available') return 'available';
    if (status == 'reserved') return 'reserved';
    return 'maintenance';
  }

  String get _statusLabel {
    switch (_statusKey) {
      case 'available':
        return 'AVAILABLE';
      case 'reserved':
        return 'RESERVED';
      default:
        return 'UNAVAILABLE';
    }
  }

  Color get _statusColor {
    switch (_statusKey) {
      case 'available':
        return AdminStyles.success;
      case 'reserved':
        return AdminStyles.warning;
      default:
        return AdminStyles.error;
    }
  }

  IconData get _statusIcon {
    switch (_statusKey) {
      case 'available':
        return Icons.check_circle_rounded;
      case 'reserved':
        return Icons.event_busy_rounded;
      default:
        return Icons.build_circle_rounded;
    }
  }

  void _openEdit(BuildContext context) {
    if (onEditRoom != null) {
      onEditRoom!(room);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AdminEditRoomPageWeb(room: room)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomCode = room.code.isNotEmpty ? room.code : room.id;

    return Scaffold(
      backgroundColor: AdminStyles.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: AdminStyles.cardDecoration(borderRadius: 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 760;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: AdminStyles.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AdminStyles.primary.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.meeting_room_rounded,
                                    color: AdminStyles.primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'OPERATIONS CONTROL',
                                        style: AdminStyles.bodyStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AdminStyles.textMuted,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Room Profile',
                                        style: AdminStyles.pageTitleStyle(),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Detailed room information for operations, scheduling, and maintenance execution.',
                                        style: AdminStyles.bodyStyle(
                                          fontSize: 14,
                                          color: AdminStyles.textSecondary,
                                          height: 1.55,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (compact)
                              Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: Semantics(
                                      button: true,
                                      label: 'Go back',
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          if (Navigator.canPop(context)) {
                                            Navigator.pop(context);
                                          } else {
                                            context.go('/admin/facilities');
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.arrow_back_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Back'),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size.fromHeight(46),
                                          foregroundColor: AdminStyles.textSecondary,
                                          side: BorderSide(
                                            color: AdminStyles.border,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: Semantics(
                                      button: true,
                                      label: 'Edit room details',
                                      child: ElevatedButton.icon(
                                        onPressed: () => _openEdit(context),
                                        icon: const Icon(
                                          Icons.edit_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Edit Room'),
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size.fromHeight(46),
                                          backgroundColor: AdminStyles.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _buildStatusBadge(),
                                  ),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  Semantics(
                                    button: true,
                                    label: 'Go back',
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        if (Navigator.canPop(context)) {
                                          Navigator.pop(context);
                                        } else {
                                          context.go('/admin/facilities');
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.arrow_back_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Back'),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(116, 46),
                                        foregroundColor: AdminStyles.textSecondary,
                                        side: BorderSide(
                                          color: AdminStyles.border,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Semantics(
                                    button: true,
                                    label: 'Edit room details',
                                    child: ElevatedButton.icon(
                                      onPressed: () => _openEdit(context),
                                      icon: const Icon(
                                        Icons.edit_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Edit Room'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(134, 46),
                                        backgroundColor: AdminStyles.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  _buildStatusBadge(),
                                ],
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Content grid without redundant metrics row
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stack = constraints.maxWidth < 980;

                      if (stack) {
                        return Column(
                          children: [
                            _buildMainDetailsCard(roomCode),
                            const SizedBox(height: 24),
                            _buildSideSummaryCard(),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _buildMainDetailsCard(roomCode),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 4,
                            child: _buildSideSummaryCard(),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Semantics(
      label: 'Current room status: $_statusLabel',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _statusColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_statusIcon, size: 14, color: _statusColor),
            const SizedBox(width: 6),
            Text(
              _statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _statusColor,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainDetailsCard(String roomCode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminStyles.cardDecoration(borderRadius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Room Intelligence',
            style: AdminStyles.headingStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Primary attributes used across scheduling, ticketing, and operational oversight.',
            style: AdminStyles.bodyStyle(
              fontSize: 13,
              color: AdminStyles.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.2,
            children: [
              _InfoCard(
                label: 'Room Name',
                value: _safe(room.name),
                icon: Icons.meeting_room_rounded,
              ),
              _InfoCard(
                label: 'Room Code',
                value: roomCode,
                icon: Icons.qr_code_rounded,
              ),
              _InfoCard(
                label: 'Room Type',
                value: _safe(room.roomType),
                icon: Icons.category_rounded,
              ),
              _InfoCard(
                label: 'Seats Capacity',
                value: '${room.seats} Seats',
                icon: Icons.chair_alt_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSideSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminStyles.cardDecoration(borderRadius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location & Status',
            style: AdminStyles.headingStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Physical location details and current operational status of the room.',
            style: AdminStyles.bodyStyle(
              fontSize: 13,
              color: AdminStyles.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          _SummaryRow(
            icon: Icons.corporate_fare_rounded,
            label: 'Building Location',
            value: _safe(room.building),
          ),
          const Divider(height: 24, thickness: 1, color: AdminStyles.border),
          _SummaryRow(
            icon: Icons.layers_rounded,
            label: 'Floor Assignment',
            value: _safe(room.floor),
          ),
          const Divider(height: 24, thickness: 1, color: AdminStyles.border),
          _SummaryRow(
            icon: Icons.apartment_rounded,
            label: 'Managing Department',
            value: _safe(room.department),
          ),
          const Divider(height: 24, thickness: 1, color: AdminStyles.border),
          _SummaryRow(
            icon: _statusIcon,
            label: 'Operational Status',
            value: _statusLabel,
            valueColor: _statusColor,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AdminStyles.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AdminStyles.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AdminStyles.bodyStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AdminStyles.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminStyles.headingStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AdminStyles.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AdminStyles.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: valueColor ?? AdminStyles.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AdminStyles.bodyStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AdminStyles.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AdminStyles.headingStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AdminStyles.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

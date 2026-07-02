import 'package:flutter/material.dart';

import '../../../../shared/models/room_model.dart';
import '../../shared/admin_styles.dart';
import 'admin_edit_room_page_web.dart';

class AdminRoomDetailsPageWeb extends StatelessWidget {
  final Room room;
  final ValueChanged<Room>? onEditRoom;

  static const Color _pageBackground = Color(0xFFF4F7FB);
  static const Color _panelBackground = Color(0xFFFFFFFF);
  static const Color _borderColor = Color(0xFFDDE5F0);
  static const Color _titleColor = Color(0xFF0B1A33);
  static const Color _bodyColor = Color(0xFF45556E);
  static const Color _accentColor = Color(0xFF1D4ED8);

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
        return const Color(0xFF10B981);
      case 'reserved':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFF91A16);
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
      backgroundColor: _pageBackground,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x3D60A5FA), Color(0x0060A5FA)],
                ),
              ),
            ),
          ),
          Positioned(
            left: -90,
            top: 260,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x296B7280), Color(0x006B7280)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF9FBFF), Color(0xFFF3F8FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFD6E4FF)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF0B1A33,
                              ).withValues(alpha: 0.06),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
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
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFD6E4FF),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.apartment_rounded,
                                        color: _accentColor,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Operations Control',
                                            style: AdminStyles.bodyStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF51607A),
                                              letterSpacing: 0.35,
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
                                              color: _bodyColor,
                                              height: 1.55,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
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
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.arrow_back_rounded,
                                              size: 18,
                                            ),
                                            label: const Text('Back'),
                                            style: OutlinedButton.styleFrom(
                                              minimumSize:
                                                  const Size.fromHeight(46),
                                              foregroundColor: const Color(
                                                0xFF334155,
                                              ),
                                              side: const BorderSide(
                                                color: Color(0xFFCBD5E1),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
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
                                              minimumSize:
                                                  const Size.fromHeight(46),
                                              backgroundColor: _accentColor,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
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
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.arrow_back_rounded,
                                            size: 18,
                                          ),
                                          label: const Text('Back'),
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size(116, 46),
                                            foregroundColor: const Color(
                                              0xFF334155,
                                            ),
                                            side: const BorderSide(
                                              color: Color(0xFFCBD5E1),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                            backgroundColor: _accentColor,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 620;
                          final tileWidth = compact
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 12) / 2;

                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _MetricTile(
                                width: tileWidth,
                                label: 'ROOM CODE',
                                value: roomCode,
                                icon: Icons.badge_rounded,
                                accent: _accentColor,
                              ),
                              _MetricTile(
                                width: tileWidth,
                                label: 'CAPACITY',
                                value: '${room.seats}',
                                icon: Icons.chair_alt_rounded,
                                accent: const Color(0xFF0369A1),
                              ),
                              _MetricTile(
                                width: tileWidth,
                                label: 'ROOM TYPE',
                                value: _safe(room.roomType),
                                icon: Icons.category_rounded,
                                accent: const Color(0xFF0F766E),
                              ),
                              _MetricTile(
                                width: tileWidth,
                                label: 'FLOOR',
                                value: _safe(room.floor),
                                icon: Icons.layers_rounded,
                                accent: const Color(0xFF334155),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stack = constraints.maxWidth < 980;

                          if (stack) {
                            return Column(
                              children: [
                                _buildMainDetailsCard(roomCode),
                                const SizedBox(height: 14),
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
                              const SizedBox(width: 14),
                              Expanded(flex: 4, child: _buildSideSummaryCard()),
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
        ],
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
      padding: const EdgeInsets.all(22),
      decoration: AdminStyles.cardDecoration(borderRadius: 20).copyWith(
        color: _panelBackground,
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Room Intelligence',
            style: AdminStyles.headingStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Primary attributes used across scheduling, ticketing, and operational oversight.',
            style: AdminStyles.bodyStyle(
              fontSize: 14,
              color: _bodyColor,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InfoCard(
                label: 'Room Name',
                value: _safe(room.name),
                width: 248,
              ),
              _InfoCard(label: 'Room Code', value: roomCode, width: 248),
              _InfoCard(
                label: 'Department',
                value: _safe(room.department),
                width: 248,
              ),
              _InfoCard(
                label: 'Building',
                value: _safe(room.building),
                width: 248,
              ),
              _InfoCard(label: 'Floor', value: _safe(room.floor), width: 248),
              _InfoCard(
                label: 'Room Type',
                value: _safe(room.roomType),
                width: 248,
              ),
              _InfoCard(
                label: 'Seats',
                value: room.seats.toString(),
                width: 248,
              ),
              _InfoCard(label: 'Status', value: _statusLabel, width: 248),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSideSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminStyles.cardDecoration(borderRadius: 20).copyWith(
        color: _panelBackground,
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operational Summary',
            style: AdminStyles.headingStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Current assignment and maintenance context for this room.',
            style: AdminStyles.bodyStyle(
              fontSize: 13,
              color: _bodyColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            icon: Icons.corporate_fare_rounded,
            label: 'Building',
            value: _safe(room.building),
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.apartment_rounded,
            label: 'Department',
            value: _safe(room.department),
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.layers_rounded,
            label: 'Floor',
            value: _safe(room.floor),
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.chair_alt_rounded,
            label: 'Capacity',
            value: '${room.seats} seats',
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: _statusIcon,
            label: 'Current Status',
            value: _statusLabel,
            valueColor: _statusColor,
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _MetricTile({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDEE7F2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.45,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
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

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final double width;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE7F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              height: 1.4,
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
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF475569)),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

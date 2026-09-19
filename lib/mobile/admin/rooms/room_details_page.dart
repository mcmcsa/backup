import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/providers/theme_provider.dart';
import '../../../../shared/models/room_model.dart';
import '../../../../shared/services/room_service.dart';
import '../../../../shared/services/work_request_service.dart';
import '../../../../shared/widgets/attachment_image_widget.dart';

class RoomDetailsPage extends StatefulWidget {
  final Room room;

  const RoomDetailsPage({super.key, required this.room});

  @override
  State<RoomDetailsPage> createState() => _RoomDetailsPageState();
}

class _RoomDetailsPageState extends State<RoomDetailsPage> {
  late Room _room;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _fetchFreshRoom();
  }

  Future<void> _fetchFreshRoom() async {
    try {
      if (widget.room.id.isEmpty) return;
      await WorkRequestService.updateRoomStatusFromRequests(widget.room.id);
      final fresh = await RoomService.fetchById(widget.room.id);
      if (fresh != null && mounted) {
        setState(() {
          _room = fresh;
        });
      }
    } catch (_) {}
  }

  String _safe(String value, {String fallback = '-'}) {
    final text = value.trim();
    return text.isEmpty ? fallback : text;
  }

  bool get _isAvailable {
    final status = _room.status.trim().toLowerCase();
    return status == 'available';
  }

  String get _statusLabel => _isAvailable ? 'AVAILABLE' : 'UNAVAILABLE';
  Color get _statusColor => _isAvailable ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
  IconData get _statusIcon => _isAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final roomCode = _room.code.isNotEmpty ? _room.code : _room.id;
    final statusBgColor = _isAvailable
        ? (isDark ? const Color(0xFF14381C) : const Color(0xFFDCFCE7))
        : (isDark ? const Color(0xFF451A1A) : const Color(0xFFFEE2E2));

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.appBarColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: themeProvider.shadowColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: themeProvider.appBarIconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Room Details',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: themeProvider.appBarTextColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: themeProvider.appBarIconColor),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchFreshRoom().then((_) {
                if (mounted) setState(() => _isLoading = false);
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: themeProvider.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: themeProvider.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: themeProvider.shadowColor,
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Room Image (if any)
                        if (_room.imageUrl != null && _room.imageUrl!.trim().isNotEmpty) ...[
                          GestureDetector(
                            onTap: () => showAttachmentZoomDialog(context, _room.imageUrl!.trim()),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: double.infinity,
                                height: 190,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    AppAttachmentImage(
                                      url: _room.imageUrl!.trim(),
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                                            SizedBox(width: 4),
                                            Text('Tap to zoom', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4169E1).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.meeting_room_rounded,
                                color: Color(0xFF4169E1),
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _safe(_room.name),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: themeProvider.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: themeProvider.chipColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      roomCode,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF4169E1),
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        Divider(color: themeProvider.dividerColor, height: 1),
                        const SizedBox(height: 14),

                        // Status Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'OPERATIONAL STATUS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: themeProvider.subtitleColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_statusIcon, size: 13, color: _statusColor),
                                  const SizedBox(width: 5),
                                  Text(
                                    _statusLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _statusColor,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Room Information Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: themeProvider.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: themeProvider.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: themeProvider.shadowColor,
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF4169E1)),
                            const SizedBox(width: 8),
                            Text(
                              'Room Information',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailTile(
                          icon: Icons.meeting_room_rounded,
                          label: 'Room Name',
                          value: _safe(_room.name),
                          themeProvider: themeProvider,
                        ),
                        Divider(height: 20, color: themeProvider.dividerColor),
                        _buildDetailTile(
                          icon: Icons.qr_code_rounded,
                          label: 'Room Code',
                          value: roomCode,
                          themeProvider: themeProvider,
                        ),
                        Divider(height: 20, color: themeProvider.dividerColor),
                        _buildDetailTile(
                          icon: Icons.category_rounded,
                          label: 'Room Type',
                          value: _safe(_room.roomType),
                          themeProvider: themeProvider,
                        ),
                        Divider(height: 20, color: themeProvider.dividerColor),
                        _buildDetailTile(
                          icon: Icons.chair_alt_rounded,
                          label: 'Seating Capacity',
                          value: '${_room.seats} Seats',
                          themeProvider: themeProvider,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Location & Assignment Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: themeProvider.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: themeProvider.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: themeProvider.shadowColor,
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_city_rounded, size: 18, color: Color(0xFF4169E1)),
                            const SizedBox(width: 8),
                            Text(
                              'Location & Management',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailTile(
                          icon: Icons.corporate_fare_rounded,
                          label: 'Building Location',
                          value: _safe(_room.building),
                          themeProvider: themeProvider,
                        ),
                        Divider(height: 20, color: themeProvider.dividerColor),
                        _buildDetailTile(
                          icon: Icons.layers_rounded,
                          label: 'Floor Assignment',
                          value: _safe(_room.floor),
                          themeProvider: themeProvider,
                        ),
                        Divider(height: 20, color: themeProvider.dividerColor),
                        _buildDetailTile(
                          icon: Icons.apartment_rounded,
                          label: 'Managing Department',
                          value: _safe(_room.department),
                          themeProvider: themeProvider,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
    required ThemeProvider themeProvider,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: themeProvider.chipColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: themeProvider.borderColor),
          ),
          child: Icon(icon, size: 18, color: themeProvider.subtitleColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: themeProvider.subtitleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

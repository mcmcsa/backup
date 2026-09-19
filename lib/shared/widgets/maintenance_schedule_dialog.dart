import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/maintenance_schedule_service.dart';

/// Shows an interactive master maintenance schedule viewer dialog.
/// Supports zooming, panning, and in-place updating of the schedule image.
Future<void> showMaintenanceScheduleDialog(
  BuildContext context, {
  String title = 'Maintenance Schedule',
  String subtitle = 'Campus Master Schedule • All Maintenance Staff',
  String? scheduleUrl,
  VoidCallback? onScheduleChanged,
  String? userId,
  String? technicianName,
  String? specialization,
  String? availabilityStatus,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _MaintenanceScheduleDialogContent(
      title: title,
      subtitle: subtitle,
      initialScheduleUrl: scheduleUrl,
      onScheduleChanged: onScheduleChanged,
    ),
  );
}

class _MaintenanceScheduleDialogContent extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? initialScheduleUrl;
  final VoidCallback? onScheduleChanged;

  const _MaintenanceScheduleDialogContent({
    required this.title,
    required this.subtitle,
    this.initialScheduleUrl,
    this.onScheduleChanged,
  });

  @override
  State<_MaintenanceScheduleDialogContent> createState() =>
      _MaintenanceScheduleDialogContentState();
}

class _MaintenanceScheduleDialogContentState
    extends State<_MaintenanceScheduleDialogContent> {
  String? _currentScheduleUrl;
  bool _isUploading = false;
  bool _isLoadingUrl = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentScheduleUrl = widget.initialScheduleUrl;
    if (_currentScheduleUrl == null || _currentScheduleUrl!.isEmpty) {
      _loadScheduleUrl();
    }
  }

  Future<void> _loadScheduleUrl() async {
    setState(() => _isLoadingUrl = true);
    try {
      final url = await MaintenanceScheduleService.getMasterScheduleUrl();
      if (mounted) {
        setState(() {
          _currentScheduleUrl = url;
          _isLoadingUrl = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingUrl = false);
    }
  }

  Future<void> _pickAndUploadSchedule() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (picked == null) return;

      setState(() => _isUploading = true);

      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last;

      final uploadedUrl =
          await MaintenanceScheduleService.uploadMasterSchedule(
        bytes: bytes,
        extension: ext,
      );

      if (mounted) {
        setState(() {
          _currentScheduleUrl = uploadedUrl;
          _isUploading = false;
        });
        widget.onScheduleChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maintenance schedule image attached successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload schedule image: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 600;
    final dialogWidth = isCompact ? size.width * 0.94 : 660.0;
    final dialogMaxHeight = size.height * 0.86;

    final hasImage = _currentScheduleUrl != null &&
        _currentScheduleUrl!.trim().isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: dialogMaxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Dialog Header ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFF0F766E),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF64748B),
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Main Content Area ───────────────────────────────────────────
            Flexible(
              child: _isLoadingUrl || _isUploading
                  ? Container(
                      height: 280,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: Color(0xFF0F766E),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isUploading
                                ? 'Uploading schedule image...'
                                : 'Loading schedule...',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : hasImage
                      ? Container(
                          color: const Color(0xFF0F172A),
                          constraints: BoxConstraints(
                            maxHeight: isCompact ? 380 : 500,
                            minHeight: 240,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              InteractiveViewer(
                                minScale: 0.8,
                                maxScale: 4.5,
                                child: Center(
                                  child: Image.network(
                                    _currentScheduleUrl!,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (c, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      );
                                    },
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.broken_image_rounded,
                                            color: Colors.white54,
                                            size: 48,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Failed to load schedule image.',
                                            style: TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.pinch_rounded,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Pinch or scroll to zoom',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 36,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.event_busy_rounded,
                                  size: 34,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No Schedule Image Attached',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'No master maintenance schedule image has been attached yet. Click below to attach the weekly or monthly schedule photo for all maintenance personnel.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _pickAndUploadSchedule,
                                icon: const Icon(
                                  Icons.add_photo_alternate_rounded,
                                  size: 18,
                                ),
                                label: const Text('Attach Schedule Image'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F766E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),

            // ── Dialog Footer ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (hasImage)
                    OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickAndUploadSchedule,
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: Text(
                        isCompact ? 'Replace' : 'Update / Replace Image',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F766E),
                        side: const BorderSide(color: Color(0xFF0F766E)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

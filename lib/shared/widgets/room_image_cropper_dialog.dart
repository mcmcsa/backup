import 'dart:math';
import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

/// Shows a pop-up dialog to crop a room image to 16:9 aspect ratio.
/// Returns the cropped [Uint8List] or null if cancelled.
Future<Uint8List?> showRoomImageCropperDialog(
  BuildContext context,
  Uint8List imageBytes,
) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _RoomImageCropperDialog(imageBytes: imageBytes),
  );
}

class _RoomImageCropperDialog extends StatefulWidget {
  final Uint8List imageBytes;
  const _RoomImageCropperDialog({required this.imageBytes});

  @override
  State<_RoomImageCropperDialog> createState() => _RoomImageCropperDialogState();
}

class _RoomImageCropperDialogState extends State<_RoomImageCropperDialog> {
  final CropController _controller = CropController();
  bool _isCropping = false;

  void _doCrop() {
    if (_isCropping) return;
    setState(() => _isCropping = true);
    _controller.crop();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = min(screenSize.width * 0.92, 740.0);
    final dialogHeight = min(screenSize.height * 0.88, 560.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // ─── Header ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.crop_rounded, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crop Room Photo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'I-drag ang puting rectangle para piliin ang parteng ipapakita (16:9)',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isCropping ? null : () => Navigator.pop(context, null),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    tooltip: 'Cancel',
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            // ─── Crop Canvas ───────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Crop(
                    image: widget.imageBytes,
                    controller: _controller,
                    onCropped: (result) {
                      if (!mounted) return;
                      switch (result) {
                        case CropSuccess(:final croppedImage):
                          Navigator.pop(context, croppedImage);
                        case CropFailure(:final cause):
                          debugPrint('Crop failed: $cause');
                          setState(() => _isCropping = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to crop image. Please try again.')),
                          );
                      }
                    },
                    aspectRatio: 16 / 9,
                    initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                      size: 0.85,
                      aspectRatio: 16 / 9,
                    ),
                    withCircleUi: false,
                    baseColor: const Color(0xFF0F172A),
                    maskColor: Colors.black.withValues(alpha: 0.65),
                    cornerDotBuilder: (size, edgeAlignment) => const DotControl(
                      color: Colors.white,
                    ),
                    interactive: false,
                  ),
                ),
              ),
            ),

            // ─── Hint Text ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 13, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 5),
                  Text(
                    'I-drag ang corners o loob ng rectangle para i-adjust ang crop frame.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),

            // ─── Action Bar ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isCropping ? null : () => Navigator.pop(context, null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _isCropping ? null : _doCrop,
                    icon: _isCropping
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(_isCropping ? 'Applying...' : 'Use This Crop'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E), // Teal brand
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
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

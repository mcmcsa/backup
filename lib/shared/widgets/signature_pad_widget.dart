import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// A reusable signature pad widget that captures hand-drawn signatures
/// or accepts uploaded image signatures, and returns them as Base64-encoded
/// PNG image data. Uploaded images are analyzed for clarity before acceptance.
class SignaturePadWidget extends StatefulWidget {
  final Function(String base64Signature) onSignatureComplete;
  final String title;
  final String subtitle;
  final double height;

  const SignaturePadWidget({
    super.key,
    required this.onSignatureComplete,
    this.title = 'E-Signature',
    this.subtitle = 'Sign below to confirm',
    this.height = 200,
  });

  @override
  State<SignaturePadWidget> createState() => _SignaturePadWidgetState();
}

enum _SignatureMode { draw, upload }

class _SignaturePadWidgetState extends State<SignaturePadWidget> {
  // â”€â”€ Draw mode state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  bool _hasSigned = false;

  // â”€â”€ Upload mode state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  _SignatureMode _mode = _SignatureMode.draw;
  Uint8List? _uploadedBytes;
  String? _uploadError;
  bool _isAnalyzing = false;
  bool _isConfirmed = false;

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
      _hasSigned = false;
      _uploadedBytes = null;
      _uploadError = null;
      _isConfirmed = false;
    });
  }

  // â”€â”€ Clamp points inside canvas â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Offset _clamp(Offset point, Size canvasSize) {
    return Offset(
      point.dx.clamp(0, canvasSize.width),
      point.dy.clamp(0, canvasSize.height),
    );
  }

  // â”€â”€ Draw mode: save signature â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _saveDrawnSignature() async {
    if (!_hasSigned) return;

    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final size = (context.findRenderObject() as RenderBox).size;
    final width = size.width * pixelRatio;
    final height = widget.height * pixelRatio;

    final confirmed = await _showConfirmDialog();
    if (!confirmed) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, widget.height),
      Paint()..color = Colors.white,
    );

    for (final stroke in _strokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke[0].dx, stroke[0].dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final base64 = base64Encode(byteData.buffer.asUint8List());
      setState(() => _isConfirmed = true);
      widget.onSignatureComplete(base64);
    }
  }

  // â”€â”€ Upload mode: pick image â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _pickSignatureImage() async {
    setState(() {
      _uploadError = null;
      _isAnalyzing = false;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _isAnalyzing = true;
      _uploadedBytes = null;
      _uploadError = null;
    });

    final clarityResult = await _analyzeImageClarity(file.bytes!);

    setState(() {
      _isAnalyzing = false;
    });

    if (!clarityResult.isAcceptable) {
      setState(() {
        _uploadError = clarityResult.reason;
      });
      return;
    }

    setState(() {
      _uploadedBytes = file.bytes;
      _uploadError = null;
    });
  }

  // â”€â”€ Upload mode: analyze clarity â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<_ClarityResult> _analyzeImageClarity(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final w = image.width;
      final h = image.height;

      if (w < 100 || h < 50) {
        return _ClarityResult(
          false,
          'Image too small (${w}x$h px). Please upload a larger, clearer signature.',
        );
      }

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        return _ClarityResult(false, 'Could not read image data. Please try another file.');
      }

      final pixels = byteData.buffer.asUint8List();
      final totalPixels = w * h;

      // Pixel statistics
      int brightPixels = 0;   // pure white/transparent background
      int midTonePixels = 0;  // shading/grays

      // Foreground analysis (only for non-background pixels)
      int foregroundPixels = 0;
      int redOrGreenPixels = 0; // Signatures should be Black or Blue ink only
      int minX = w, minY = h, maxX = 0, maxY = 0;

      double sumLuminance = 0;
      double sumSqLuminance = 0;

      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          final r = pixels[i].toDouble();
          final g = pixels[i + 1].toDouble();
          final b = pixels[i + 2].toDouble();
          final a = pixels[i + 3].toDouble();

          // Background (transparent)
          if (a < 50) {
            brightPixels++;
            continue;
          }

          final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
          sumLuminance += luminance;
          sumSqLuminance += luminance * luminance;

          if (luminance > 235) {
            brightPixels++;
          } else {
            // Foreground pixel (Ink or Shading)
            foregroundPixels++;
            if (luminance < 80) {
              // dark ink pixel (no specific counter needed anymore)
            } else {
              midTonePixels++;
            }

            // Track bounding box of the ink
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;

            // Check if ink is NOT black or blue (e.g. red, green, yellow, orange)
            // If R or G is significantly higher than B, it's a warm color
            if (r > b + 25 || g > b + 25) {
              redOrGreenPixels++;
            }
          }
        }
      }

      final brightRatio = brightPixels / totalPixels;
      final midToneRatio = midTonePixels / totalPixels;
      final meanLuminance = sumLuminance / totalPixels;
      final variance = (sumSqLuminance / totalPixels) - (meanLuminance * meanLuminance);
      final stdDev = math.sqrt(variance);

      // Ink density and aspect ratio within its bounding box
      int inkWidth = maxX >= minX ? (maxX - minX + 1) : 0;
      int inkHeight = maxY >= minY ? (maxY - minY + 1) : 0;
      double inkDensity = 0;
      double aspectRatio = 0;
      if (inkWidth > 0 && inkHeight > 0) {
        inkDensity = foregroundPixels / (inkWidth * inkHeight);
        aspectRatio = inkWidth / inkHeight;
      }
      
      final redGreenRatio = foregroundPixels > 0 ? (redOrGreenPixels / foregroundPixels) : 0;

      // ── Signature Detection ───────────────────────────────────────────────

      // Check 1: Empty or blank
      if (foregroundPixels == 0 || inkWidth < 10 || inkHeight < 10) {
        return _ClarityResult(false, 'No signature detected. The image appears blank.');
      }

      // Check 2: Background ratio
      if (brightRatio < 0.65) {
        return _ClarityResult(
          false,
          'This does not appear to be a signature (background is not clear/white enough).\n\nPlease upload a clear photo of your handwritten signature on plain white paper.',
        );
      }

      // Check 3: Mid-tones / Shading
      if (midToneRatio > 0.10) {
        return _ClarityResult(
          false,
          'Image rejected. This appears to be a drawing, photo, or clipart (too much shading/gray).\n\nPlease upload a clean signature (solid ink lines).',
        );
      }

      // Check 4: Colored Ink (Red/Green/Yellow) — strict 2% limit
      if (redGreenRatio > 0.02) {
        return _ClarityResult(
          false,
          'Colored image detected. Signatures must be in Black or Blue ink only.\n\nPlease upload a valid signature.',
        );
      }

      // Check 5: Aspect Ratio — signatures are typically wide. Cliparts are often square or tall.
      if (aspectRatio < 1.1) {
        return _ClarityResult(
          false,
          'Image rejected. The drawn object is too square or tall to be a signature. Signatures are typically wide.\n\nPlease upload a normal handwritten signature.',
        );
      }

      // Check 6: Ink Density — signatures are thin lines, not solid blocks
      if (inkDensity > 0.35) {
        return _ClarityResult(
          false,
          'Image rejected. The drawn object is too dense or solid to be a signature.\n\nPlease upload a normal handwritten signature.',
        );
      }

      // Check 7: Sharpness
      if (stdDev < 20) {
        return _ClarityResult(
          false,
          'The signature image is too blurry or low-contrast. Please upload a clearer, sharper signature.',
        );
      }

      // ── Clarity / Sharpness Check ─────────────────────────────────────────
      if (stdDev < 20) {
        return _ClarityResult(
          false,
          'The signature image is too blurry or low-contrast. Please upload a clearer, sharper signature.',
        );
      }

      return _ClarityResult(true, 'Signature detected and accepted.');
    } catch (e) {
      return _ClarityResult(false, 'Could not process the image. Please try a different file.');
    }
  }


  // â”€â”€ Upload mode: confirm and submit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _saveUploadedSignature() async {
    if (_uploadedBytes == null) return;

    final confirmed = await _showConfirmDialog();
    if (!confirmed) return;

    final base64 = base64Encode(_uploadedBytes!);
    setState(() => _isConfirmed = true);
    widget.onSignatureComplete(base64);
  }

  // â”€â”€ Shared: confirmation dialog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<bool> _showConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.draw_rounded, color: Color(0xFF4169E1)),
            SizedBox(width: 10),
            Text(
              'Confirm Signature',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to save and confirm this signature for your request?',
          style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'No',
              style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4169E1),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return result == true;
  }

  bool get _canConfirm =>
      (_mode == _SignatureMode.draw && _hasSigned) ||
      (_mode == _SignatureMode.upload && _uploadedBytes != null);

  Future<void> _handleConfirm() async {
    if (_mode == _SignatureMode.draw) {
      await _saveDrawnSignature();
    } else {
      await _saveUploadedSignature();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_hasSigned || _uploadedBytes != null)
                  TextButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      textStyle: const TextStyle(fontSize: 12),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),

          // Tab switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _TabButton(
                  label: 'Draw',
                  icon: Icons.draw_outlined,
                  selected: _mode == _SignatureMode.draw,
                  onTap: () {
                    if (_isConfirmed) return;
                    setState(() {
                      _mode = _SignatureMode.draw;
                      _uploadedBytes = null;
                      _uploadError = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _TabButton(
                  label: 'Upload',
                  icon: Icons.upload_file_outlined,
                  selected: _mode == _SignatureMode.upload,
                  onTap: () {
                    if (_isConfirmed) return;
                    setState(() {
                      _mode = _SignatureMode.upload;
                      _strokes.clear();
                      _currentStroke = [];
                      _hasSigned = false;
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Canvas or Upload area
          if (_mode == _SignatureMode.draw) _buildDrawCanvas(),
          if (_mode == _SignatureMode.upload) _buildUploadArea(),

          // Hint text for draw mode
          if (_mode == _SignatureMode.draw && !_hasSigned)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.draw_outlined, size: 16, color: Color(0xFF9CA3AF)),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Draw your signature above',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Confirm button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_canConfirm && !_isConfirmed) ? _handleConfirm : null,
                icon: Icon(_isConfirmed ? Icons.check_circle : Icons.check_circle_outline, size: 18),
                label: Text(
                  _isConfirmed ? 'Signature Confirmed' : 'Confirm Signature',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isConfirmed ? const Color(0xFF10B981) : const Color(0xFF4169E1),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _isConfirmed ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
                  disabledForegroundColor: _isConfirmed ? Colors.white : const Color(0xFF9CA3AF),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Draw canvas â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildDrawCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasWidth = constraints.maxWidth - 32;
        final canvasHeight = widget.height;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: canvasHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hasSigned
                  ? const Color(0xFF4169E1).withValues(alpha: 0.3)
                  : const Color(0xFFE5E7EB),
              width: _hasSigned ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: GestureDetector(
              onPanStart: (details) {
                if (_isConfirmed) return;
                final clamped = _clamp(
                  details.localPosition,
                  Size(canvasWidth, canvasHeight),
                );
                setState(() {
                  _currentStroke = [clamped];
                  _hasSigned = true;
                });
              },
              onPanUpdate: (details) {
                final clamped = _clamp(
                  details.localPosition,
                  Size(canvasWidth, canvasHeight),
                );
                setState(() {
                  _currentStroke.add(clamped);
                });
              },
              onPanEnd: (details) {
                setState(() {
                  _strokes.add(List.from(_currentStroke));
                  _currentStroke = [];
                });
              },
              child: CustomPaint(
                painter: _SignaturePainter(
                  strokes: _strokes,
                  currentStroke: _currentStroke,
                ),
                size: Size(canvasWidth, canvasHeight),
              ),
            ),
          ),
        );
      },
    );
  }

  // â”€â”€ Upload area â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildUploadArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: (_isAnalyzing || _isConfirmed) ? null : _pickSignatureImage,
        child: Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _uploadError != null
                  ? const Color(0xFFEF4444)
                  : _uploadedBytes != null
                      ? const Color(0xFF4169E1).withValues(alpha: 0.4)
                      : const Color(0xFFD1D5DB),
              width: _uploadedBytes != null || _uploadError != null ? 2 : 1,
            ),
          ),
          child: _isAnalyzing
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFF4169E1),
                        strokeWidth: 2.5,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Verifying signature...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4169E1),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Checking if image is a valid signature',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                )
              : _uploadedBytes != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.memory(
                            _uploadedBytes!,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Clear',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                          _uploadError != null
                              ? Icons.warning_rounded
                              : Icons.upload_file_outlined,
                          size: 40,
                          color: _uploadError != null
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            _uploadError ?? 'Click to upload your signature',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: _uploadError != null
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF6B7280),
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (_uploadError != null) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _pickSignatureImage,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Try Again'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4169E1),
                              side: const BorderSide(color: Color(0xFF4169E1)),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 6),
                          const Text(
                            'PNG, JPG accepted â€¢ Must be clear and legible',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ),
        ),
      ),
    );
  }
}

// â”€â”€ Tab button helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4169E1)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Clarity result â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ClarityResult {
  final bool isAcceptable;
  final String reason;
  const _ClarityResult(this.isAcceptable, this.reason);
}

// â”€â”€ Signature painter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  _SignaturePainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Clip strictly to canvas bounds to prevent stroke overflow
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke[0].dx, stroke[0].dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    if (currentStroke.length >= 2) {
      final path = Path();
      path.moveTo(currentStroke[0].dx, currentStroke[0].dy);
      for (int i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

/// A dialog that shows the signature pad and returns the base64 signature
class SignatureDialog extends StatelessWidget {
  final String title;
  final String subtitle;

  const SignatureDialog({
    super.key,
    this.title = 'E-Signature Required',
    this.subtitle = 'Sign below to confirm your approval',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SignaturePadWidget(
              title: title,
              subtitle: subtitle,
              onSignatureComplete: (base64) {
                Navigator.pop(context, base64);
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show the signature dialog and return the base64 signature or null
  static Future<String?> show(
    BuildContext context, {
    String? title,
    String? subtitle,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SignatureDialog(
        title: title ?? 'E-Signature Required',
        subtitle: subtitle ?? 'Sign below to confirm your approval',
      ),
    );
  }
}


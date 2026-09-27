import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../utils/signature_image_helper.dart';

/// A reusable signature pad widget that captures hand-drawn signatures
/// or accepts uploaded image signatures, and returns them as Base64-encoded
/// PNG image data. Uploaded images are analyzed for clarity before acceptance.
class SignaturePadWidget extends StatefulWidget {
  final Function(String base64Signature) onSignatureComplete;
  final VoidCallback? onSignatureCleared;
  final String title;
  final String subtitle;
  final double height;
  final bool showConfirmButton;
  final bool showTitle;
  final bool enableFullscreen;

  const SignaturePadWidget({
    super.key,
    required this.onSignatureComplete,
    this.onSignatureCleared,
    this.title = 'E-Signature',
    this.subtitle = 'Sign below to confirm',
    this.height = 200,
    this.showConfirmButton = true,
    this.showTitle = true,
    this.enableFullscreen = true,
  });

  @override
  State<SignaturePadWidget> createState() => _SignaturePadWidgetState();
}

enum _SignatureMode { draw, upload }

class _SignaturePadWidgetState extends State<SignaturePadWidget> {
  // â”€â”€ Draw mode state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final GlobalKey _canvasKey = GlobalKey();
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
    widget.onSignatureCleared?.call();
    widget.onSignatureComplete('');
  }

  // â”€â”€ Clamp points inside canvas â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Offset _clamp(Offset point, Size canvasSize) {
    return Offset(
      point.dx.clamp(0, canvasSize.width),
      point.dy.clamp(0, canvasSize.height),
    );
  }

  // ── Draw mode: export signature ──────────────────────────────────────────
  Future<void> _exportDrawnSignature({bool markConfirmed = false}) async {
    if (!_hasSigned || _strokes.isEmpty) return;

    try {
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final RenderBox? canvasBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      final canvasWidth = canvasBox?.size.width ?? (MediaQuery.of(context).size.width - 48);
      final canvasHeight = canvasBox?.size.height ?? widget.height;
      final width = (canvasWidth * pixelRatio).toInt().clamp(1, 4096);
      final height = (canvasHeight * pixelRatio).toInt().clamp(1, 4096);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(pixelRatio);

      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

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
      final img = await picture.toImage(width, height);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null && mounted) {
        final base64 = base64Encode(byteData.buffer.asUint8List());
        if (markConfirmed) {
          setState(() => _isConfirmed = true);
          widget.onSignatureComplete(base64);
        } else if (!widget.showConfirmButton) {
          widget.onSignatureComplete(base64);
        }
      }
    } catch (_) {}
  }

  // ── Draw mode: save signature (confirm) ───────────────────────────────────
  Future<void> _saveDrawnSignature() async {
    await _exportDrawnSignature(markConfirmed: true);
  }

  // ── Fullscreen signature pad ──────────────────────────────────────────────
  Future<void> _openFullscreenPad() async {
    final RenderBox? canvasBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final currentWidth = canvasBox?.size.width ?? (MediaQuery.of(context).size.width - 48);
    final currentHeight = canvasBox?.size.height ?? widget.height;

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => _FullscreenSignatureDialog(
          initialStrokes: _strokes,
          sourceWidth: currentWidth,
          sourceHeight: currentHeight,
          isDark: Theme.of(context).brightness == Brightness.dark,
          primaryCol: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF00BFA5)
              : const Color(0xFF0F766E),
        ),
      ),
    );

    if (result != null && mounted) {
      final List<List<Offset>> returnedStrokes = result['strokes'] as List<List<Offset>>? ?? [];
      final String? returnedBase64 = result['base64'] as String?;

      setState(() {
        _strokes.clear();
        for (final s in returnedStrokes) {
          _strokes.add(List.from(s));
        }
        _hasSigned = _strokes.isNotEmpty;
        _isConfirmed = false;
        _uploadedBytes = null;
        _uploadError = null;
        _mode = _SignatureMode.draw;
      });

      if (returnedBase64 != null && returnedBase64.isNotEmpty) {
        widget.onSignatureComplete(returnedBase64);
      } else if (_hasSigned) {
        await _exportDrawnSignature(markConfirmed: false);
      } else {
        _clear();
      }
    }
  }

  // ── Upload mode: pick image ───────────────────────────────────────────────
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
    Uint8List? fileBytes = file.bytes;
    if (fileBytes == null && file.path != null) {
      try {
        fileBytes = await File(file.path!).readAsBytes();
      } catch (_) {}
    }
    if (fileBytes == null) return;

    setState(() {
      _isAnalyzing = true;
      _uploadedBytes = null;
      _uploadError = null;
    });

    final clarityResult = await _analyzeImageClarity(fileBytes);

    if (!clarityResult.isAcceptable) {
      setState(() {
        _isAnalyzing = false;
        _uploadError = clarityResult.reason;
      });
      return;
    }

    // Automatically remove paper/photo background and extract signature ink
    final transparentBytes = await SignatureImageHelper.removeBackground(fileBytes);

    setState(() {
      _isAnalyzing = false;
      _uploadedBytes = transparentBytes;
      _uploadError = null;
    });

    if (!widget.showConfirmButton) {
      final base64 = base64Encode(transparentBytes);
      widget.onSignatureComplete(base64);
    }
  }

  // ── Upload mode: analyze clarity ───────────────────────────────────────────
  Future<_ClarityResult> _analyzeImageClarity(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final w = image.width;
      final h = image.height;

      if (w < 40 || h < 20) {
        return _ClarityResult(
          false,
          'Image too small (${w}x$h px). Please upload a clearer, larger signature image.',
        );
      }

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        return _ClarityResult(false, 'Could not read image data. Please try another file.');
      }

      final pixels = byteData.buffer.asUint8List();
      final totalPixels = w * h;

      int transparentPixels = 0;
      double minLum = 255;
      double maxLum = 0;

      // Sample evenly to evaluate contrast and transparency quickly
      final sampleStep = math.max(1, (totalPixels / 20000).toInt());
      for (int i = 0; i < pixels.length; i += 4 * sampleStep) {
        final a = pixels[i + 3];
        if (a < 50) {
          transparentPixels++;
          continue;
        }
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        final lum = 0.299 * r + 0.587 * g + 0.114 * b;
        if (lum > maxLum) maxLum = lum;
        if (lum < minLum) minLum = lum;
      }

      final totalSampled = (pixels.length / (4 * sampleStep)).floor();
      final hasExistingTransparency = transparentPixels > (totalSampled * 0.15);

      int minX = w, minY = h, maxX = 0, maxY = 0;
      int inkPixelCount = 0;

      if (hasExistingTransparency) {
        // Transparent PNG / digital signature
        for (int y = 0; y < h; y += 2) {
          for (int x = 0; x < w; x += 2) {
            final idx = (y * w + x) * 4;
            if (pixels[idx + 3] > 40) {
              inkPixelCount++;
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }

        if (inkPixelCount < 15) {
          return _ClarityResult(false, 'No signature detected. The image appears blank.');
        }

        return _ClarityResult(true, 'Signature detected and accepted.');
      }

      // Opaque image (photo of paper or scan)
      final contrast = maxLum - minLum;
      if (contrast < 22) {
        return _ClarityResult(
          false,
          'The image appears blank or has very low contrast. Please upload a clear signature on paper.',
        );
      }

      final inkLumThreshold = maxLum - (contrast * 0.28);
      for (int y = 0; y < h; y += 2) {
        for (int x = 0; x < w; x += 2) {
          final idx = (y * w + x) * 4;
          final r = pixels[idx];
          final g = pixels[idx + 1];
          final b = pixels[idx + 2];
          final lum = 0.299 * r + 0.587 * g + 0.114 * b;

          if (lum <= inkLumThreshold) {
            inkPixelCount++;
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }

      final totalChecked = (w / 2).ceil() * (h / 2).ceil();
      final inkRatio = inkPixelCount / totalChecked;

      if (inkPixelCount < 15 || (maxX - minX) < 8 || (maxY - minY) < 6) {
        return _ClarityResult(
          false,
          'No signature detected. Please upload a clear photo of your handwritten signature.',
        );
      }

      if (inkRatio > 0.85) {
        return _ClarityResult(
          false,
          'The image appears too dark or solid. Please upload a clear photo of your signature on white/light paper.',
        );
      }

      return _ClarityResult(true, 'Signature detected and accepted.');
    } catch (e) {
      return _ClarityResult(false, 'Could not process the image. Please try a different file.');
    }
  }

  // ── Upload mode: confirm and submit ───────────────────────────────────────
  Future<void> _saveUploadedSignature() async {
    if (_uploadedBytes == null) return;

    // _uploadedBytes is already processed with pure black ink and transparent background
    final base64 = base64Encode(_uploadedBytes!);
    setState(() => _isConfirmed = true);
    widget.onSignatureComplete(base64);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryCol = isDark ? const Color(0xFF00BFA5) : const Color(0xFF0F766E);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (widget.showTitle)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                        if (widget.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_hasSigned || _uploadedBytes != null)
                    TextButton.icon(
                      onPressed: _clear,
                      icon: const Icon(Icons.refresh_rounded, size: 15),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(
                        foregroundColor: subtitleColor,
                        textStyle: const TextStyle(fontSize: 12),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  if (widget.enableFullscreen)
                    IconButton(
                      icon: const Icon(Icons.open_in_full_rounded, size: 17),
                      color: subtitleColor,
                      tooltip: 'Sign in Fullscreen',
                      splashRadius: 18,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: _openFullscreenPad,
                    ),
                ],
              ),
            ),

          // Tab switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                const Spacer(),
                if (!widget.showConfirmButton && (_hasSigned || _uploadedBytes != null))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF10B981)),
                        SizedBox(width: 4),
                        Text(
                          'Ready',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.draw_outlined, size: 15, color: subtitleColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Draw your signature in the box above',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Confirm button
          if (widget.showConfirmButton)
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_canConfirm && !_isConfirmed) ? _handleConfirm : null,
                  icon: Icon(_isConfirmed ? Icons.check_circle : Icons.check_circle_outline, size: 18),
                  label: Text(
                    _isConfirmed ? 'Successfully Signed' : 'Confirm Signature',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isConfirmed ? const Color(0xFF10B981) : primaryCol,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _isConfirmed
                        ? const Color(0xFF10B981)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
                    disabledForegroundColor: _isConfirmed
                        ? Colors.white
                        : (isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF)),
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Draw canvas ───────────────────────────────────────────────────────────
  Widget _buildDrawCanvas() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryCol = isDark ? const Color(0xFF00BFA5) : const Color(0xFF0F766E);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final canvasBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB);

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasWidth = constraints.maxWidth - 24;
        final canvasHeight = widget.height;
        return Container(
          key: _canvasKey,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          height: canvasHeight,
          decoration: BoxDecoration(
            color: canvasBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hasSigned
                  ? primaryCol.withValues(alpha: 0.5)
                  : borderColor,
              width: _hasSigned ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: RawGestureDetector(
              gestures: <Type, GestureRecognizerFactory>{
                EagerGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                  (EagerGestureRecognizer instance) {},
                ),
              },
              behavior: HitTestBehavior.opaque,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  if (_isConfirmed) return;
                  final clamped = _clamp(
                    event.localPosition,
                    Size(canvasWidth, canvasHeight),
                  );
                  setState(() {
                    _currentStroke = [clamped];
                    _hasSigned = true;
                  });
                },
                onPointerMove: (event) {
                  if (_isConfirmed) return;
                  final clamped = _clamp(
                    event.localPosition,
                    Size(canvasWidth, canvasHeight),
                  );
                  setState(() {
                    _currentStroke.add(clamped);
                  });
                },
                onPointerUp: (event) {
                  if (_isConfirmed) return;
                  setState(() {
                    _strokes.add(List.from(_currentStroke));
                    _currentStroke = [];
                  });
                  if (!widget.showConfirmButton) {
                    _exportDrawnSignature(markConfirmed: false);
                  }
                },
                onPointerCancel: (event) {
                  if (_isConfirmed) return;
                  setState(() {
                    if (_currentStroke.isNotEmpty) {
                      _strokes.add(List.from(_currentStroke));
                    }
                    _currentStroke = [];
                  });
                  if (!widget.showConfirmButton) {
                    _exportDrawnSignature(markConfirmed: false);
                  }
                },
                child: CustomPaint(
                  painter: _SignaturePainter(
                    strokes: _strokes,
                    currentStroke: _currentStroke,
                    color: isDark ? const Color(0xFF2DD4BF) : Colors.black,
                  ),
                  size: Size(canvasWidth, canvasHeight),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Upload area ───────────────────────────────────────────────────────────
  Widget _buildUploadArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryCol = isDark ? const Color(0xFF00BFA5) : const Color(0xFF0F766E);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFD1D5DB);
    final canvasBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: (_isAnalyzing || _isConfirmed) ? null : _pickSignatureImage,
        child: Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: canvasBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _uploadError != null
                  ? const Color(0xFFEF4444)
                  : _uploadedBytes != null
                      ? primaryCol.withValues(alpha: 0.5)
                      : borderColor,
              width: _uploadedBytes != null || _uploadError != null ? 2 : 1,
            ),
          ),
          child: _isAnalyzing
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: primaryCol,
                        strokeWidth: 2.5,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Verifying signature...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryCol,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Checking if image is a valid signature',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF9CA3AF),
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
                                  'Signature Ready',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? const Color(0xFF00BFA5) : const Color(0xFF0F766E);
    final inactiveBg = isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6);
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : inactiveColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Clarity result ───────────────────────────────────────────────────────────
class _ClarityResult {
  final bool isAcceptable;
  final String reason;
  const _ClarityResult(this.isAcceptable, this.reason);
}

// ── Signature painter ────────────────────────────────────────────────────────
class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color color;

  _SignaturePainter({
    required this.strokes,
    required this.currentStroke,
    this.color = Colors.black,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
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

/// Fullscreen signature dialog offering maximum drawing area
class _FullscreenSignatureDialog extends StatefulWidget {
  final List<List<Offset>> initialStrokes;
  final double sourceWidth;
  final double sourceHeight;
  final bool isDark;
  final Color primaryCol;

  const _FullscreenSignatureDialog({
    required this.initialStrokes,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.isDark,
    required this.primaryCol,
  });

  @override
  State<_FullscreenSignatureDialog> createState() =>
      _FullscreenSignatureDialogState();
}

class _FullscreenSignatureDialogState
    extends State<_FullscreenSignatureDialog> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    for (final s in widget.initialStrokes) {
      _strokes.add(List.from(s));
    }
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
    });
  }

  Future<void> _done() async {
    if (_strokes.isEmpty) {
      Navigator.pop(context, {'strokes': <List<Offset>>[], 'base64': ''});
      return;
    }

    try {
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final RenderBox? canvasBox =
          _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      final canvasWidth = canvasBox?.size.width ?? MediaQuery.of(context).size.width;
      final canvasHeight = canvasBox?.size.height ?? 300.0;
      final width = (canvasWidth * pixelRatio).toInt().clamp(1, 4096);
      final height = (canvasHeight * pixelRatio).toInt().clamp(1, 4096);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(pixelRatio);

      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

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
      final img = await picture.toImage(width, height);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final base64 = byteData != null ? base64Encode(byteData.buffer.asUint8List()) : '';

      // Scale strokes to match source pad dimensions
      final scaleX = widget.sourceWidth > 0 && canvasWidth > 0 ? (widget.sourceWidth / canvasWidth) : 1.0;
      final scaleY = widget.sourceHeight > 0 && canvasHeight > 0 ? (widget.sourceHeight / canvasHeight) : 1.0;
      final scaledStrokes = _strokes.map((s) => s.map((pt) => Offset(pt.dx * scaleX, pt.dy * scaleY)).toList()).toList();

      if (mounted) {
        Navigator.pop(context, {'strokes': scaledStrokes, 'base64': base64});
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context, {'strokes': _strokes, 'base64': ''});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = widget.isDark ? const Color(0xFF1E293B) : Colors.white;
    final textCol = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final borderCol = widget.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0.5,
        title: Text(
          'Draw Signature',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textCol),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          color: textCol,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_strokes.isNotEmpty)
            TextButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                foregroundColor: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _done,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Done'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryCol,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  key: _canvasKey,
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF020617) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: RawGestureDetector(
                      gestures: <Type, GestureRecognizerFactory>{
                        EagerGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                          (EagerGestureRecognizer instance) {},
                        ),
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (event) {
                          setState(() {
                            _currentStroke = [event.localPosition];
                          });
                        },
                        onPointerMove: (event) {
                          setState(() {
                            _currentStroke.add(event.localPosition);
                          });
                        },
                        onPointerUp: (event) {
                          setState(() {
                            _strokes.add(List.from(_currentStroke));
                            _currentStroke = [];
                          });
                        },
                        onPointerCancel: (event) {
                          setState(() {
                            if (_currentStroke.isNotEmpty) {
                              _strokes.add(List.from(_currentStroke));
                            }
                            _currentStroke = [];
                          });
                        },
                        child: CustomPaint(
                          painter: _SignaturePainter(
                            strokes: _strokes,
                            currentStroke: _currentStroke,
                            color: widget.isDark ? const Color(0xFF2DD4BF) : Colors.black,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_outlined, size: 16, color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Draw signature freely across the screen, then tap Done',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}



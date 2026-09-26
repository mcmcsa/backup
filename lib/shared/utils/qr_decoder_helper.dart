import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zxing2/qrcode.dart';

class QrDecodeResult {
  final String? code;
  final Uint8List? imageBytes;
  final String? imagePath;

  const QrDecodeResult({
    this.code,
    this.imageBytes,
    this.imagePath,
  });

  bool get hasCode => code != null && code!.trim().isNotEmpty;
}

class QrDecoderHelper {
  /// Picks an image from gallery/files and decodes any QR code present.
  /// Returns a [QrDecodeResult] containing the decoded code, image bytes, and path.
  static Future<QrDecodeResult?> pickAndDecodeQr() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null) return null;

      final bytes = await image.readAsBytes();

      // 1. Try Pure Dart ZXing2 engine first (works everywhere: Web, Mobile, Desktop)
      String? decoded = decodeImageBytes(bytes);

      // 2. If not decoded and on Mobile, try mobile_scanner native engine fallback
      if ((decoded == null || decoded.isEmpty) && !kIsWeb) {
        try {
          final controller = MobileScannerController();
          final capture = await controller.analyzeImage(image.path);
          await controller.dispose();
          if (capture != null && capture.barcodes.isNotEmpty) {
            final code = capture.barcodes.first.rawValue?.trim();
            if (code != null && code.isNotEmpty) {
              decoded = code;
            }
          }
        } catch (_) {}
      }

      return QrDecodeResult(
        code: decoded?.trim(),
        imageBytes: bytes,
        imagePath: image.path,
      );
    } catch (e) {
      debugPrint('Error picking and decoding QR from image: $e');
      return null;
    }
  }

  /// Backward-compatible method that returns the decoded text directly.
  static Future<String?> pickAndDecodeQrCode() async {
    final result = await pickAndDecodeQr();
    return result?.code;
  }

  /// Pure Dart QR Decoder using zxing2 and package:image
  static String? decodeImageBytes(Uint8List bytes) {
    try {
      final rawImage = img.decodeImage(bytes);
      if (rawImage == null) return null;

      // Try with original resolution
      String? result = _tryDecodeZxing(rawImage);
      if (result != null) return result;

      // If failed and image is large, resize down to improve QR finder pattern detection
      if (rawImage.width > 800 || rawImage.height > 800) {
        final resized = img.copyResize(rawImage, width: 800);
        result = _tryDecodeZxing(resized);
        if (result != null) return result;
      }

      // If failed and image is small, resize up
      if (rawImage.width < 300 && rawImage.height < 300) {
        final upscaled = img.copyResize(rawImage, width: 600);
        result = _tryDecodeZxing(upscaled);
        if (result != null) return result;
      }
    } catch (e) {
      debugPrint('Error in decodeImageBytes: $e');
    }
    return null;
  }

  static String? _tryDecodeZxing(img.Image image) {
    final int width = image.width;
    final int height = image.height;
    final Int32List pixels = Int32List(width * height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final a = pixel.a.toInt();
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();

        // Blend transparent background with white
        if (a < 128) {
          r = 255;
          g = 255;
          b = 255;
        }

        pixels[y * width + x] = (255 << 24) | (r << 16) | (g << 8) | b;
      }
    }

    // Attempt 1: HybridBinarizer standard
    try {
      final source = RGBLuminanceSource(width, height, pixels);
      final bitmap = BinaryBitmap(HybridBinarizer(source));
      final result = QRCodeReader().decode(bitmap);
      if (result.text.trim().isNotEmpty) return result.text.trim();
    } catch (_) {}

    // Attempt 2: HybridBinarizer inverted (for dark mode QR or inverted codes)
    try {
      final source = RGBLuminanceSource(width, height, pixels);
      final bitmap = BinaryBitmap(HybridBinarizer(source.invert()));
      final result = QRCodeReader().decode(bitmap);
      if (result.text.trim().isNotEmpty) return result.text.trim();
    } catch (_) {}

    // Attempt 3: GlobalHistogramBinarizer
    try {
      final source = RGBLuminanceSource(width, height, pixels);
      final bitmap = BinaryBitmap(GlobalHistogramBinarizer(source));
      final result = QRCodeReader().decode(bitmap);
      if (result.text.trim().isNotEmpty) return result.text.trim();
    } catch (_) {}

    // Attempt 4: GlobalHistogramBinarizer inverted
    try {
      final source = RGBLuminanceSource(width, height, pixels);
      final bitmap = BinaryBitmap(GlobalHistogramBinarizer(source.invert()));
      final result = QRCodeReader().decode(bitmap);
      if (result.text.trim().isNotEmpty) return result.text.trim();
    } catch (_) {}

    return null;
  }
}

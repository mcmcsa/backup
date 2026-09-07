import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Helper utility to process signature images:
/// Automatically removes paper/white backgrounds, turns them into transparent PNGs,
/// cleans up ink contrast, and crops away excessive empty margins.
class SignatureImageHelper {
  /// Removes background from a Base64 signature string and returns a transparent Base64 PNG string.
  static Future<String> removeBackgroundFromBase64(String base64Str) async {
    try {
      final cleanBase64 = base64Str.contains(',')
          ? base64Str.split(',').last.trim()
          : base64Str.trim();
      final bytes = base64Decode(cleanBase64);
      final processedBytes = await removeBackground(bytes);
      return base64Encode(processedBytes);
    } catch (_) {
      return base64Str;
    }
  }

  /// Removes background from raw image bytes and returns transparent PNG bytes.
  static Future<Uint8List> removeBackground(Uint8List inputBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(inputBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final w = image.width;
      final h = image.height;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return inputBytes;

      final pixels = Uint8List.fromList(byteData.buffer.asUint8List());

      // Sample border pixels to estimate paper/background luminance
      double borderLumSum = 0;
      int borderCount = 0;

      void sample(int x, int y) {
        if (x < 0 || x >= w || y < 0 || y >= h) return;
        final idx = (y * w + x) * 4;
        final r = pixels[idx];
        final g = pixels[idx + 1];
        final b = pixels[idx + 2];
        final a = pixels[idx + 3];
        if (a > 50) {
          final lum = 0.299 * r + 0.587 * g + 0.114 * b;
          borderLumSum += lum;
          borderCount++;
        }
      }

      // Sample edges (top, bottom, left, right)
      for (int x = 0; x < w; x += 4) {
        sample(x, 0);
        sample(x, 1);
        sample(x, h - 2);
        sample(x, h - 1);
      }
      for (int y = 0; y < h; y += 4) {
        sample(0, y);
        sample(1, y);
        sample(w - 2, y);
        sample(w - 1, y);
      }

      final bgLum = borderCount > 0 ? (borderLumSum / borderCount) : 245.0;
      // Thresholds for paper removal and ink retention
      final threshold = (bgLum * 0.88).clamp(170.0, 245.0);
      final darkThreshold = (threshold * 0.65).clamp(80.0, 150.0);

      int minX = w, minY = h, maxX = 0, maxY = 0;
      bool foundInk = false;

      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          final r = pixels[i].toDouble();
          final g = pixels[i + 1].toDouble();
          final b = pixels[i + 2].toDouble();
          final a = pixels[i + 3].toDouble();

          // Already transparent
          if (a < 10) {
            pixels[i + 3] = 0;
            continue;
          }

          final lum = 0.299 * r + 0.587 * g + 0.114 * b;

          if (lum >= threshold) {
            // Paper background -> transparent
            pixels[i + 3] = 0;
          } else if (lum <= darkThreshold) {
            // Definite ink -> full opacity and crisp ink
            pixels[i + 3] = 255;
            if (b > r + 20 && b > g + 20) {
              // Dark blue ink -> preserve dark blue
              pixels[i] = (r * 0.5).toInt().clamp(0, 40);
              pixels[i + 1] = (g * 0.5).toInt().clamp(0, 50);
              pixels[i + 2] = (b * 0.85).toInt().clamp(110, 200);
            } else {
              // Black ink
              final v = (lum * 0.35).toInt().clamp(0, 30);
              pixels[i] = v;
              pixels[i + 1] = v;
              pixels[i + 2] = v;
            }
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
            foundInk = true;
          } else {
            // Smooth anti-aliased edge
            final factor = (threshold - lum) / (threshold - darkThreshold);
            final newAlpha = (255 * factor).toInt().clamp(0, 255);
            pixels[i + 3] = newAlpha;
            if (newAlpha > 40) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
              foundInk = true;
            }
          }
        }
      }

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        w,
        h,
        ui.PixelFormat.rgba8888,
        (img) => completer.complete(img),
      );
      final processedImg = await completer.future;

      if (!foundInk || maxX <= minX || maxY <= minY) {
        final pngData = await processedImg.toByteData(format: ui.ImageByteFormat.png);
        return pngData != null ? pngData.buffer.asUint8List() : inputBytes;
      }

      // Crop to ink bounding box with a small margin (padding)
      const pad = 12;
      final cropX = (minX - pad).clamp(0, w);
      final cropY = (minY - pad).clamp(0, h);
      final cropW = (maxX + pad).clamp(0, w) - cropX;
      final cropH = (maxY + pad).clamp(0, h) - cropY;

      if (cropW <= 0 || cropH <= 0) {
        final pngData = await processedImg.toByteData(format: ui.ImageByteFormat.png);
        return pngData != null ? pngData.buffer.asUint8List() : inputBytes;
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final srcRect = Rect.fromLTWH(cropX.toDouble(), cropY.toDouble(), cropW.toDouble(), cropH.toDouble());
      final dstRect = Rect.fromLTWH(0, 0, cropW.toDouble(), cropH.toDouble());
      canvas.drawImageRect(processedImg, srcRect, dstRect, Paint());
      final croppedPicture = recorder.endRecording();
      final croppedImg = await croppedPicture.toImage(cropW, cropH);

      final byteDataCropped = await croppedImg.toByteData(format: ui.ImageByteFormat.png);
      if (byteDataCropped != null) {
        return byteDataCropped.buffer.asUint8List();
      }

      final pngData = await processedImg.toByteData(format: ui.ImageByteFormat.png);
      return pngData != null ? pngData.buffer.asUint8List() : inputBytes;
    } catch (e) {
      debugPrint('Signature background removal error: $e');
      return inputBytes;
    }
  }
}

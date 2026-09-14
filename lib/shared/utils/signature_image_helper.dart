import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Helper utility to process signature images:
/// Automatically removes paper/white backgrounds, turns them into transparent PNGs,
/// cleans up ink contrast, converts strokes to crisp pure black, and crops away
/// excessive empty margins.
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

  /// Removes background from raw image bytes and returns transparent PNG bytes
  /// with pure black ink and smooth anti-aliased edges.
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
      final totalPixels = w * h;

      // ── Step 1: Detect existing transparency & sample background ──────────
      int transparentPixels = 0;
      double borderLumSum = 0;
      int borderCount = 0;
      double maxLum = 0;
      double minLum = 255;

      void sampleBorder(int x, int y) {
        if (x < 0 || x >= w || y < 0 || y >= h) return;
        final idx = (y * w + x) * 4;
        final a = pixels[idx + 3];
        if (a > 50) {
          final r = pixels[idx];
          final g = pixels[idx + 1];
          final b = pixels[idx + 2];
          final lum = 0.299 * r + 0.587 * g + 0.114 * b;
          borderLumSum += lum;
          borderCount++;
        }
      }

      // Sample image borders (top, bottom, left, right edges)
      for (int x = 0; x < w; x += 2) {
        sampleBorder(x, 0);
        sampleBorder(x, 1);
        sampleBorder(x, h - 2);
        sampleBorder(x, h - 1);
      }
      for (int y = 0; y < h; y += 2) {
        sampleBorder(0, y);
        sampleBorder(1, y);
        sampleBorder(w - 2, y);
        sampleBorder(w - 1, y);
      }

      // Sample global min/max luminance and check transparency
      final step = math.max(1, (totalPixels / 10000).toInt());
      for (int i = 0; i < pixels.length; i += 4 * step) {
        final a = pixels[i + 3];
        if (a < 50) {
          transparentPixels++;
        } else {
          final lum = 0.299 * pixels[i] + 0.587 * pixels[i + 1] + 0.114 * pixels[i + 2];
          if (lum > maxLum) maxLum = lum;
          if (lum < minLum) minLum = lum;
        }
      }

      final isAlreadyTransparent = (transparentPixels / (totalPixels / step)) > 0.20 || borderCount == 0;

      int minX = w, minY = h, maxX = 0, maxY = 0;
      bool foundInk = false;

      // ── Step 2: Extract Ink & Remove Background ───────────────────────────
      if (isAlreadyTransparent) {
        // Image is already transparent: convert all non-transparent ink to pure black
        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            final i = (y * w + x) * 4;
            final a = pixels[i + 3];

            if (a < 20) {
              pixels[i + 3] = 0;
            } else {
              // Convert ink to crisp black with enhanced visibility
              pixels[i] = 0;
              pixels[i + 1] = 0;
              pixels[i + 2] = 0;
              pixels[i + 3] = math.min(255, (a * 1.15).toInt());

              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
              foundInk = true;
            }
          }
        }
      } else {
        // Opaque paper/photo image: calculate adaptive thresholds for paper vs ink
        final bgLum = borderCount > 0 ? (borderLumSum / borderCount) : maxLum;
        final contrast = (bgLum - minLum).clamp(20.0, 255.0);

        // Anything within 18% of paper background is treated as white/paper background
        final paperThreshold = bgLum - (contrast * 0.18);
        // Definite ink is the darkest 45% of the contrast range
        final solidInkThreshold = minLum + (contrast * 0.40);

        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            final i = (y * w + x) * 4;
            final r = pixels[i].toDouble();
            final g = pixels[i + 1].toDouble();
            final b = pixels[i + 2].toDouble();
            final a = pixels[i + 3];

            if (a < 20) {
              pixels[i + 3] = 0;
              continue;
            }

            final lum = 0.299 * r + 0.587 * g + 0.114 * b;

            if (lum >= paperThreshold) {
              // Paper background -> 100% transparent
              pixels[i + 3] = 0;
            } else if (lum <= solidInkThreshold) {
              // Definite ink -> 100% pure black (#000000)
              pixels[i] = 0;
              pixels[i + 1] = 0;
              pixels[i + 2] = 0;
              pixels[i + 3] = 255;

              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
              foundInk = true;
            } else {
              // Anti-aliased ink edge -> smooth graduated alpha with pure black RGB
              // Setting RGB to 0,0,0 ensures there is ZERO white/gray halo around the ink!
              final factor = (paperThreshold - lum) / (paperThreshold - solidInkThreshold);
              final newAlpha = (255 * factor).toInt().clamp(0, 255);

              pixels[i] = 0;
              pixels[i + 1] = 0;
              pixels[i + 2] = 0;
              pixels[i + 3] = newAlpha;

              if (newAlpha > 30) {
                if (x < minX) minX = x;
                if (x > maxX) maxX = x;
                if (y < minY) minY = y;
                if (y > maxY) maxY = y;
                foundInk = true;
              }
            }
          }
        }
      }

      // ── Step 3: Reconstruct Image ─────────────────────────────────────────
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

      // ── Step 4: Auto-Crop to Signature Bounding Box with Padding ───────────
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

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psu_maintsystem/shared/utils/signature_image_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SignatureImageHelper removes white background and makes ink black', () async {
    // Create a 100x100 white image with a dark stroke in the center
    const width = 100;
    const height = 100;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw white paper background
    final bgPaint = Paint()..color = const Color(0xFFEEEEEE); // slightly off-white paper
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), bgPaint);

    // Draw dark blue/black signature stroke in the center
    final inkPaint = Paint()
      ..color = const Color(0xFF1E3A8A) // blue ink
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(30, 50), const Offset(70, 50), inkPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    expect(byteData, isNotNull);

    final inputBytes = byteData!.buffer.asUint8List();

    // Process with removeBackground
    final processedBytes = await SignatureImageHelper.removeBackground(inputBytes);
    expect(processedBytes, isNotNull);
    expect(processedBytes.isNotEmpty, isTrue);

    // Decode processed image
    final codec = await ui.instantiateImageCodec(processedBytes);
    final frame = await codec.getNextFrame();
    final processedImg = frame.image;

    // Verify it was cropped to around the stroke (width should be less than 100)
    expect(processedImg.width, lessThan(width));

    final rawData = await processedImg.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(rawData, isNotNull);
    final pixels = rawData!.buffer.asUint8List();

    // Find non-transparent ink pixel and verify it is pure black (R=0, G=0, B=0)
    int foundBlackInkCount = 0;
    int transparentPixelCount = 0;

    for (int i = 0; i < pixels.length; i += 4) {
      final r = pixels[i];
      final g = pixels[i + 1];
      final b = pixels[i + 2];
      final a = pixels[i + 3];

      if (a < 20) {
        transparentPixelCount++;
      } else if (a > 100) {
        // Must be pure black
        if (r == 0 && g == 0 && b == 0) {
          foundBlackInkCount++;
        }
      }
    }

    expect(foundBlackInkCount, greaterThan(0), reason: 'Ink should be converted to pure black (RGB: 0,0,0)');
    expect(transparentPixelCount, greaterThan(0), reason: 'Paper background should be transparent');
  });

  test('SignatureImageHelper processes base64 string', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 50, 50), Paint()..color = Colors.white);
    canvas.drawLine(const Offset(10, 25), const Offset(40, 25), Paint()..color = Colors.black..strokeWidth = 3);
    final picture = recorder.endRecording();
    final img = await picture.toImage(50, 50);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final b64 = base64Encode(byteData!.buffer.asUint8List());

    final cleanB64 = await SignatureImageHelper.removeBackgroundFromBase64(b64);
    expect(cleanB64, isNotEmpty);
    expect(cleanB64, isNot(equals(b64)));
  });

  test('SignatureImageHelper handles already transparent images and turns ink black', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Draw without background (fully transparent)
    final redPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(10, 20), const Offset(40, 20), redPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(60, 40);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final inputBytes = byteData!.buffer.asUint8List();

    final processedBytes = await SignatureImageHelper.removeBackground(inputBytes);
    final codec = await ui.instantiateImageCodec(processedBytes);
    final frame = await codec.getNextFrame();
    final processedImg = frame.image;

    final rawData = await processedImg.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixels = rawData!.buffer.asUint8List();

    bool hasBlackInk = false;
    for (int i = 0; i < pixels.length; i += 4) {
      final r = pixels[i];
      final g = pixels[i + 1];
      final b = pixels[i + 2];
      final a = pixels[i + 3];

      if (a > 100) {
        expect(r, equals(0));
        expect(g, equals(0));
        expect(b, equals(0));
        hasBlackInk = true;
      }
    }
    expect(hasBlackInk, isTrue);
  });
}

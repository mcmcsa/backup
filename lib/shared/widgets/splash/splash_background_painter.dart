import 'dart:math';
import 'package:flutter/material.dart';

class SplashBackgroundPainter extends CustomPainter {
  final double animationValue;

  SplashBackgroundPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawParticles(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    const double gridSize = 40.0;
    
    // Animate grid offset
    final double offsetX = (animationValue * gridSize) % gridSize;
    final double offsetY = (animationValue * gridSize) % gridSize;

    for (double i = -gridSize + offsetX; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double j = -gridSize + offsetY; j < size.height; j += gridSize) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), paint);
    }
  }

  void _drawParticles(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF06B6D4).withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    // Use a fixed random seed so particles don't jitter on repaint
    final random = Random(42);
    
    for (int i = 0; i < 15; i++) {
      final double baseX = random.nextDouble() * size.width;
      final double baseY = random.nextDouble() * size.height;
      final double speedMultiplier = random.nextDouble() * 50 + 20;
      
      // Particles move slowly upwards
      double movingY = baseY - (animationValue * speedMultiplier);
      // Wrap around
      if (movingY < -20) {
        movingY = size.height + 20 + (movingY % size.height);
      }
      
      final double radius = random.nextDouble() * 3 + 1;
      canvas.drawCircle(Offset(baseX, movingY), radius, paint);
    }
  }

  @override
  bool shouldRepaint(SplashBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

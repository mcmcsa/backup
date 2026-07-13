import 'package:flutter/material.dart';

class QRScanAnimator extends StatefulWidget {
  const QRScanAnimator({super.key});

  @override
  State<QRScanAnimator> createState() => _QRScanAnimatorState();
}

class _QRScanAnimatorState extends State<QRScanAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Simulated QR Grid (Faint)
          Icon(
            Icons.qr_code_2,
            size: 80,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          
          // Corner Markers
          _buildCorner(Alignment.topLeft),
          _buildCorner(Alignment.topRight),
          _buildCorner(Alignment.bottomLeft),
          _buildCorner(Alignment.bottomRight),

          // Animated Scan Line
          AnimatedBuilder(
            animation: _scanController,
            builder: (context, child) {
              return Positioned(
                top: 10 + (_scanController.value * 96), // 120 height - 10 padding - ~4 line height = ~100 range
                left: 10,
                right: 10,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.8),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          border: _getCornerBorder(alignment),
        ),
      ),
    );
  }

  Border _getCornerBorder(Alignment alignment) {
    const BorderSide side = BorderSide(color: Color(0xFF3B82F6), width: 2);
    if (alignment == Alignment.topLeft) {
      return const Border(top: side, left: side);
    } else if (alignment == Alignment.topRight) {
      return const Border(top: side, right: side);
    } else if (alignment == Alignment.bottomLeft) {
      return const Border(bottom: side, left: side);
    } else {
      return const Border(bottom: side, right: side);
    }
  }
}

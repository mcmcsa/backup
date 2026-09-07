import 'dart:convert';
import 'package:flutter/material.dart';

class AppAttachmentImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const AppAttachmentImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (url.startsWith('data:image') || url.startsWith('data:')) {
      try {
        final commaIdx = url.indexOf(',');
        if (commaIdx != -1) {
          final b64 = url.substring(commaIdx + 1);
          final bytes = base64Decode(b64);
          imageWidget = Image.memory(
            bytes,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, __, ___) => _buildError(),
          );
        } else {
          imageWidget = _buildError();
        }
      } catch (_) {
        imageWidget = _buildError();
      }
    } else {
      imageWidget = Image.network(
        url,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _buildError(),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }
    return imageWidget;
  }

  Widget _buildError() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 28),
      ),
    );
  }
}

void showAttachmentZoomDialog(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              maxScale: 4.0,
              child: Center(
                child: AppAttachmentImage(
                  url: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Material(
                color: Colors.black.withValues(alpha: 0.6),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

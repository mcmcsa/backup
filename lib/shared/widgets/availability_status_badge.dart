import 'package:flutter/material.dart';
import '../services/maintenance_status_service.dart';

enum BadgeSize { small, medium, large }

class AvailabilityStatusBadge extends StatelessWidget {
  final String status;
  final BadgeSize size;
  final bool showLabel;
  final bool isInteractive;
  final VoidCallback? onTap;

  const AvailabilityStatusBadge({
    super.key,
    required this.status,
    this.size = BadgeSize.medium,
    this.showLabel = true,
    this.isInteractive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MaintenanceStatusService.getStatusColor(status);
    final fgColor = Color(colors['color']);
    final bgColor = Color(colors['bg']);

    final padding = _getPadding();
    final fontSize = _getFontSize();
    final dotSize = _getDotSize();

    String displayLabel = status.replaceAll('_', ' ');
    displayLabel = displayLabel.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '').join(' ');

    Widget badge = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fgColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: fgColor,
              shape: BoxShape.circle,
            ),
          ),
          if (showLabel) ...[
            SizedBox(width: size == BadgeSize.small ? 4 : 6),
            Text(
              displayLabel,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: fgColor,
                height: 1.1,
              ),
            ),
          ],
          if (isInteractive) ...[
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: fontSize + 4, color: fgColor),
          ]
        ],
      ),
    );

    if (isInteractive && onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: badge,
      );
    }

    return badge;
  }

  EdgeInsets _getPadding() {
    if (!showLabel) return EdgeInsets.all(_getDotSize() / 2);
    switch (size) {
      case BadgeSize.small:
        return const EdgeInsets.symmetric(horizontal: 6, vertical: 2);
      case BadgeSize.medium:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      case BadgeSize.large:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    }
  }

  double _getFontSize() {
    switch (size) {
      case BadgeSize.small:
        return 10;
      case BadgeSize.medium:
        return 12;
      case BadgeSize.large:
        return 14;
    }
  }

  double _getDotSize() {
    switch (size) {
      case BadgeSize.small:
        return 6;
      case BadgeSize.medium:
        return 8;
      case BadgeSize.large:
        return 10;
    }
  }
}

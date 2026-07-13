import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../../web/admin/shared/admin_styles.dart';

class OfflineBannerWidget extends StatelessWidget {
  final Widget child;

  const OfflineBannerWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService().isConnected,
      builder: (context, isConnected, _) {
        if (isConnected) return child;

        return Column(
          children: [
            _buildBanner(),
            Expanded(child: child),
          ],
        );
      },
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      color: AdminStyles.warning, // Using warning color for offline
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.black87, size: 18),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'You are currently offline. Changes will be saved locally.',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

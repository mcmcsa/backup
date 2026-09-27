import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

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
            _buildBanner(context),
            Expanded(child: child),
          ],
        );
      },
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFDC2626), // Strong, distinct warning red
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'No internet connection. Offline actions will sync once reconnected.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<bool>(
              valueListenable: ConnectivityService().isCheckingConnection,
              builder: (context, isChecking, _) {
                if (isChecking) {
                  return const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  );
                }

                return InkWell(
                  onTap: () async {
                    final hasInternet = await ConnectivityService().checkRealConnection();
                    if (context.mounted) {
                      if (hasInternet) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.wifi_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Internet connection restored!'),
                              ],
                            ),
                            backgroundColor: Color(0xFF10B981),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Still offline. Please check your network connection.'),
                              ],
                            ),
                            backgroundColor: Color(0xFFB91C1C),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Retry',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

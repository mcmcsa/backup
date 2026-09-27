import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

/// Helper to detect, sanitize, and display human-friendly messages
/// for network and connectivity errors, preventing raw technical exceptions
/// (like SocketException, ClientException, errno = 103) from leaking to users.
class NetworkErrorHelper {
  /// Checks if an error or exception is network/connectivity related.
  static bool isNetworkError(dynamic error) {
    if (error == null) return false;

    if (!kIsWeb) {
      if (error is SocketException ||
          error is TimeoutException ||
          error is HttpException) {
        return true;
      }
    }

    final str = error.toString();
    return isNetworkErrorMessage(str);
  }

  /// Checks if a string message describes a network failure.
  static bool isNetworkErrorMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('connection abort') ||
        lower.contains('software caused connection abort') ||
        lower.contains('connection reset') ||
        lower.contains('connection refused') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('errno = 103') ||
        lower.contains('errno = 101') ||
        lower.contains('errno = 111') ||
        lower.contains('handshakeexception') ||
        lower.contains('network error') ||
        lower.contains('timed out') ||
        lower.contains('timeout') ||
        lower.contains('authretryablefetchexception') ||
        lower.contains('no internet') ||
        lower.contains('failed to connect') ||
        lower.contains('semaphore timeout') ||
        lower.contains('network_error');
  }

  /// Converts any technical or raw error into a clean, human-friendly message.
  static String sanitizeErrorMessage(
    dynamic error, {
    String fallback = 'An unexpected error occurred. Please try again.',
  }) {
    if (error == null) return fallback;

    if (isNetworkError(error)) {
      return 'No internet connection. Please check your network and try again.';
    }

    final str = error.toString().trim();
    final lower = str.toLowerCase();

    // Invalid credentials
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid email or password')) {
      return 'Invalid email or password. Please try again.';
    }

    // Email not confirmed
    if (lower.contains('email not confirmed')) {
      return 'Please verify your institutional email before logging in.';
    }

    // Account inactive
    if (lower.contains('inactive')) {
      return 'Your account is inactive. Please contact the administrator.';
    }

    // Never leak raw URLs, hostnames, ports or OS exceptions to UI
    if (lower.contains('supabase.co') ||
        lower.contains('os error') ||
        lower.contains('uri=') ||
        lower.contains('errno =')) {
      return 'Unable to connect to the server. Please check your connection and try again.';
    }

    // Strip Dart prefixes if present
    var clean = str;
    if (clean.startsWith('Exception: ')) {
      clean = clean.substring('Exception: '.length);
    }
    if (clean.startsWith('AuthException(message: ')) {
      clean = clean
          .replaceFirst('AuthException(message: ', '')
          .replaceAll(')', '');
    }

    return clean.isNotEmpty ? clean : fallback;
  }

  /// Displays an aesthetic, modern modal dialog alerting the user about no connection,
  /// with a Retry action.
  static Future<void> showNoInternetDialog({
    required BuildContext context,
    required Future<void> Function() onRetry,
    String? title,
    String? message,
  }) async {
    if (!context.mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        bool isRetrying = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 10,
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2), // soft red-50
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFCA5A5).withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.wifi_off_rounded,
                          color: Color(0xFFEF4444), // red-500
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title ?? 'No Internet Connection',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message ??
                          'Unable to reach PSU E-Ayos servers. Please verify your Wi-Fi or mobile data connection and try again.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isRetrying ? null : () => Navigator.of(dialogCtx).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isRetrying
                                ? null
                                : () async {
                                    setDialogState(() => isRetrying = true);
                                    try {
                                      await ConnectivityService().checkRealConnection();
                                      if (dialogCtx.mounted) {
                                        Navigator.of(dialogCtx).pop();
                                      }
                                      await onRetry();
                                    } catch (_) {
                                      if (dialogCtx.mounted) {
                                        setDialogState(() => isRetrying = false);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E), // PSU Teal
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: isRetrying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.refresh_rounded, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'Retry',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Shows a clean, modern floating SnackBar with an optional Retry button.
  static void showCleanSnackBar({
    required BuildContext context,
    required dynamic error,
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;

    final isNet = isNetworkError(error);
    final cleanMsg = sanitizeErrorMessage(error);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1E293B), // Modern Dark Slate
        elevation: 6,
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isNet
                    ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                    : Colors.white12,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNet ? Icons.wifi_off_rounded : Icons.info_outline_rounded,
                color: isNet ? const Color(0xFFF87171) : Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cleanMsg,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: const Color(0xFF38BDF8), // Bright Sky Blue
                onPressed: onRetry,
              )
            : SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white70,
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
        duration: Duration(seconds: isNet ? 6 : 4),
      ),
    );
  }
}

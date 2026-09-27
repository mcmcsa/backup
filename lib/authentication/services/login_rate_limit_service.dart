import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of evaluating or recording a login attempt for rate limiting.
class LoginRateLimitResult {
  final bool isLockedOut;
  final int remainingSeconds;
  final int failedAttempts;
  final bool shouldTriggerForgotPassword;
  final String message;

  const LoginRateLimitResult({
    required this.isLockedOut,
    required this.remainingSeconds,
    required this.failedAttempts,
    required this.shouldTriggerForgotPassword,
    required this.message,
  });

  String get formattedRemainingTime {
    final minutes = (remainingSeconds / 60).floor();
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Service that handles progressive lockout upon repeated failed login attempts:
/// - 1st & 2nd fail: Warning with attempt count (e.g. Attempt 1 of 3)
/// - 3rd fail: 1 minute lockout
/// - 4th fail: 3 minutes lockout
/// - 5th fail: 5 minutes lockout
/// - 6th fail: 10 minutes lockout
/// - 7th fail / max daily: Automatic Forgot Password dialog prompt
class LoginRateLimitService {
  static const String _prefixAttempts = 'auth_failed_attempts_';
  static const String _prefixLockoutUntil = 'auth_lockout_until_';
  static const String _prefixDailyDate = 'auth_daily_date_';

  /// Standard lockout durations based on failed attempt count (1-indexed)
  static int _getLockoutDurationSeconds(int attempts) {
    switch (attempts) {
      case 3:
        return 60; // 1 minute
      case 4:
        return 180; // 3 minutes
      case 5:
        return 300; // 5 minutes
      case 6:
        return 600; // 10 minutes
      default:
        if (attempts >= 7) {
          return 600; // 10 minutes + trigger forgot password
        }
        return 0;
    }
  }

  static String _cleanKey(String email) {
    final clean = email.trim().toLowerCase();
    return clean.isEmpty ? 'unknown_user' : clean;
  }

  /// Checks if the given email is currently under cooldown/lockout.
  static Future<LoginRateLimitResult> checkLockout(String email) async {
    final key = _cleanKey(email);
    final prefs = await SharedPreferences.getInstance();

    final lockoutUntilMs = prefs.getInt('$_prefixLockoutUntil$key') ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final failedAttempts = prefs.getInt('$_prefixAttempts$key') ?? 0;

    if (lockoutUntilMs > nowMs) {
      final remainingSec = ((lockoutUntilMs - nowMs) / 1000).ceil();
      final minutes = (remainingSec / 60).ceil();
      final isMaxReached = failedAttempts >= 7;

      return LoginRateLimitResult(
        isLockedOut: true,
        remainingSeconds: remainingSec,
        failedAttempts: failedAttempts,
        shouldTriggerForgotPassword: isMaxReached,
        message: isMaxReached
            ? 'Account temporarily locked due to multiple failed attempts. Please reset your password or wait for the cooldown.'
            : 'Too many failed login attempts. Please wait $minutes minute${minutes > 1 ? 's' : ''} before trying again.',
      );
    }

    return LoginRateLimitResult(
      isLockedOut: false,
      remainingSeconds: 0,
      failedAttempts: failedAttempts,
      shouldTriggerForgotPassword: false,
      message: '',
    );
  }

  /// Records a failed login attempt for the given email and returns the new lockout state.
  static Future<LoginRateLimitResult> recordFailedAttempt(String email) async {
    final key = _cleanKey(email);
    final prefs = await SharedPreferences.getInstance();

    // Reset daily attempts if it is a new calendar day
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString('$_prefixDailyDate$key');
    int failedAttempts = prefs.getInt('$_prefixAttempts$key') ?? 0;

    if (savedDate != todayStr) {
      failedAttempts = 0;
      await prefs.setString('$_prefixDailyDate$key', todayStr);
    }

    failedAttempts++;
    await prefs.setInt('$_prefixAttempts$key', failedAttempts);

    final durationSec = _getLockoutDurationSeconds(failedAttempts);
    final shouldTriggerForgot = failedAttempts >= 7;

    if (durationSec > 0) {
      final lockoutUntilMs = DateTime.now().millisecondsSinceEpoch + (durationSec * 1000);
      await prefs.setInt('$_prefixLockoutUntil$key', lockoutUntilMs);

      final minutes = (durationSec / 60).ceil();
      final message = shouldTriggerForgot
          ? 'You have reached the maximum failed login attempts for today. Please reset your password.'
          : 'Too many failed login attempts. Please try again in $minutes minute${minutes > 1 ? 's' : ''}.';

      return LoginRateLimitResult(
        isLockedOut: true,
        remainingSeconds: durationSec,
        failedAttempts: failedAttempts,
        shouldTriggerForgotPassword: shouldTriggerForgot,
        message: message,
      );
    }

    // 1st or 2nd fail
    final remainingAttemptsBeforeLock = 3 - failedAttempts;
    final message = remainingAttemptsBeforeLock > 0
        ? 'Invalid email or password. ($failedAttempts/3 attempts before 1-min cooldown)'
        : 'Invalid email or password.';

    return LoginRateLimitResult(
      isLockedOut: false,
      remainingSeconds: 0,
      failedAttempts: failedAttempts,
      shouldTriggerForgotPassword: false,
      message: message,
    );
  }

  /// Clears failed attempts when user successfully logs in.
  static Future<void> resetAttempts(String email) async {
    final key = _cleanKey(email);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefixAttempts$key');
    await prefs.remove('$_prefixLockoutUntil$key');
    await prefs.remove('$_prefixDailyDate$key');
  }
}

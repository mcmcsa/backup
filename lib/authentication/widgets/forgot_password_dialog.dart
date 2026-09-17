import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

enum _ResetStep {
  email,
  otp,
  newPassword,
  success,
}

class ForgotPasswordDialog extends StatefulWidget {
  final String? initialEmail;
  final ValueChanged<String>? onPasswordResetSuccess;

  const ForgotPasswordDialog({
    super.key,
    this.initialEmail,
    this.onPasswordResetSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialEmail,
    ValueChanged<String>? onPasswordResetSuccess,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ForgotPasswordDialog(
        initialEmail: initialEmail,
        onPasswordResetSuccess: onPasswordResetSuccess,
      ),
    );
  }

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  // --- Styling Constants ---
  static const Color _primary = Color(0xFF1E40AF); // PSU Blue
  static const Color _accent = Color(0xFF0F766E); // Deep Teal
  static const Color _navy = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _bgInput = Color(0xFFF8FAFC);
  static const Color _success = Color(0xFF16A34A);
  static const Color _error = Color(0xFFDC2626);

  _ResetStep _step = _ResetStep.email;

  // Controllers
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  final _formKeyEmail = GlobalKey<FormState>();
  final _formKeyOtp = GlobalKey<FormState>();
  final _formKeyNewPass = GlobalKey<FormState>();

  bool _loading = false;
  String? _errorMessage;
  String? _infoMessage;

  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  // 30-second resend countdown timer
  static const int _kResendSeconds = 30;
  int _resendSecondsLeft = 0;
  Timer? _countdownTimer;

  AuthService? _authService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthService>().beginPasswordReset();
      }
    });
    if (widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty) {
      _emailCtrl.text = widget.initialEmail!.trim();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authService = context.read<AuthService>();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    if (_step != _ResetStep.success) {
      try {
        _authService?.cancelPasswordReset();
      } catch (_) {}
    }
    super.dispose();
  }

  void _startResendTimer() {
    _countdownTimer?.cancel();
    setState(() => _resendSecondsLeft = _kResendSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsLeft > 1) {
        setState(() => _resendSecondsLeft--);
      } else {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      }
    });
  }

  // ── Step 1: Send OTP to Email ──────────────────────────────────────────────
  Future<void> _handleSendOtp() async {
    if (!_formKeyEmail.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final email = _emailCtrl.text.trim();
    final auth = context.read<AuthService>();
    final error = await auth.sendPasswordResetOtp(email);

    if (!mounted) return;

    if (error == null) {
      setState(() {
        _loading = false;
        _step = _ResetStep.otp;
        _otpCtrl.clear();
        _infoMessage = 'A verification code was sent to $email.';
      });
      _startResendTimer();
    } else {
      setState(() {
        _loading = false;
        _errorMessage = error;
      });
    }
  }

  // ── Resend OTP Button Handler ─────────────────────────────────────────────
  Future<void> _handleResendOtp() async {
    if (_resendSecondsLeft > 0 || _loading) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final email = _emailCtrl.text.trim();
    final auth = context.read<AuthService>();
    final error = await auth.sendPasswordResetOtp(email);

    if (!mounted) return;

    if (error == null) {
      setState(() {
        _loading = false;
        _infoMessage = 'A new verification code has been sent!';
      });
      _startResendTimer();
    } else {
      setState(() {
        _loading = false;
        _errorMessage = error;
      });
    }
  }

  // ── Step 2: Verify OTP Code ────────────────────────────────────────────────
  Future<void> _handleVerifyOtp() async {
    if (!_formKeyOtp.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final email = _emailCtrl.text.trim();
    final token = _otpCtrl.text.trim();
    final auth = context.read<AuthService>();
    final error = await auth.verifyPasswordResetOtp(email: email, token: token);

    if (!mounted) return;

    if (error == null) {
      _countdownTimer?.cancel();
      setState(() {
        _loading = false;
        _step = _ResetStep.newPassword;
        _errorMessage = null;
        _infoMessage = null;
      });
    } else {
      setState(() {
        _loading = false;
        _errorMessage = error;
      });
    }
  }

  // ── Step 3: Complete Password Reset ────────────────────────────────────────
  Future<void> _handleCompleteReset() async {
    if (!_formKeyNewPass.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final newPass = _newPassCtrl.text.trim();
    final auth = context.read<AuthService>();
    final error = await auth.completePasswordReset(newPassword: newPass);

    if (!mounted) return;

    if (error == null) {
      setState(() {
        _loading = false;
        _step = _ResetStep.success;
      });
      widget.onPasswordResetSuccess?.call(_emailCtrl.text.trim());
    } else {
      setState(() {
        _loading = false;
        _errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
            border: Border.all(color: _border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  if (_errorMessage != null) _buildAlert(_errorMessage!, isError: true),
                  if (_infoMessage != null) _buildAlert(_infoMessage!, isError: false),
                  _buildCurrentStepContent(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header Component ───────────────────────────────────────────────────────
  Widget _buildHeader() {
    IconData icon;
    Color iconColor;
    Color iconBg;
    String title;
    String subtitle;

    switch (_step) {
      case _ResetStep.email:
        icon = Icons.lock_reset_rounded;
        iconColor = _primary;
        iconBg = _primary.withValues(alpha: 0.1);
        title = 'Forgot Password';
        subtitle = 'Enter your registered email address and we will send you a 6-digit verification code.';
        break;
      case _ResetStep.otp:
        icon = Icons.mark_email_read_outlined;
        iconColor = _accent;
        iconBg = _accent.withValues(alpha: 0.1);
        title = 'Enter Verification Code';
        subtitle = 'We sent a 6-digit code to ${_emailCtrl.text.trim()}.';
        break;
      case _ResetStep.newPassword:
        icon = Icons.key_rounded;
        iconColor = _primary;
        iconBg = _primary.withValues(alpha: 0.1);
        title = 'Set New Password';
        subtitle = 'Your email has been verified. Enter your new password below.';
        break;
      case _ResetStep.success:
        icon = Icons.check_circle_rounded;
        iconColor = _success;
        iconBg = _success.withValues(alpha: 0.1);
        title = 'Password Reset Complete!';
        subtitle = 'Your password has been successfully changed. You can now log in.';
        break;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 32), // Balance close button
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: _textMuted, size: 22),
              tooltip: 'Close',
              splashRadius: 20,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _navy,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: _textMuted,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  // ── Alert Box ─────────────────────────────────────────────────────────────
  Widget _buildAlert(String message, {required bool isError}) {
    final bg = isError ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7);
    final border = isError ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC);
    final fg = isError ? const Color(0xFFB91C1C) : const Color(0xFF15803D);
    final icon = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step Content Router ───────────────────────────────────────────────────
  Widget _buildCurrentStepContent() {
    switch (_step) {
      case _ResetStep.email:
        return _buildEmailStep();
      case _ResetStep.otp:
        return _buildOtpStep();
      case _ResetStep.newPassword:
        return _buildNewPasswordStep();
      case _ResetStep.success:
        return _buildSuccessStep();
    }
  }

  // ── Step 1: Email Input ───────────────────────────────────────────────────
  Widget _buildEmailStep() {
    return Form(
      key: _formKeyEmail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Email Address',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            textInputAction: TextInputAction.go,
            onFieldSubmitted: (_) => _handleSendOtp(),
            validator: (v) {
              final text = v?.trim() ?? '';
              if (text.isEmpty) return 'Please enter your email address.';
              if (!text.contains('@') || !text.contains('.')) {
                return 'Please enter a valid email address.';
              }
              return null;
            },
            decoration: _inputDecoration(
              hint: 'e.g. name@psu.edu.ph',
              prefixIcon: Icons.mail_outline_rounded,
            ),
          ),
          const SizedBox(height: 24),
          _buildPrimaryButton(
            label: 'Send Verification Code',
            onPressed: _loading ? null : _handleSendOtp,
            loading: _loading,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Sign In', style: TextStyle(color: _textMuted, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── Step 2: OTP Verification & 30s Countdown ──────────────────────────────
  Widget _buildOtpStep() {
    return Form(
      key: _formKeyOtp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Verification Code',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy),
              ),
              InkWell(
                onTap: _loading
                    ? null
                    : () {
                        setState(() {
                          _step = _ResetStep.email;
                          _errorMessage = null;
                          _infoMessage = null;
                        });
                      },
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Change Email',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            style: const TextStyle(
              fontSize: 22,
              letterSpacing: 6,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              color: _navy,
            ),
            onFieldSubmitted: (_) => _handleVerifyOtp(),
            validator: (v) {
              final text = v?.trim() ?? '';
              if (text.isEmpty) return 'Please enter the verification code.';
              if (text.length < 6 || text.length > 8) {
                return 'The code must be 6 to 8 digits.';
              }
              return null;
            },
            decoration: _inputDecoration(
              hint: 'Enter code',
              prefixIcon: Icons.pin_outlined,
            ),
          ),
          const SizedBox(height: 16),

          // ── 30-Second Countdown & Resend Section ──────────────────────────
          Center(
            child: _resendSecondsLeft > 0
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: _textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'Resend code in ${_resendSecondsLeft}s',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textMuted,
                        ),
                      ),
                    ],
                  )
                : TextButton.icon(
                    onPressed: _loading ? null : _handleResendOtp,
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: _primary),
                    label: const Text(
                      'Resend Code',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
          ),
          const SizedBox(height: 20),

          _buildPrimaryButton(
            label: 'Verify Code',
            onPressed: _loading ? null : _handleVerifyOtp,
            loading: _loading,
          ),
        ],
      ),
    );
  }

  // ── Step 3: New Password Input ────────────────────────────────────────────
  Widget _buildNewPasswordStep() {
    return Form(
      key: _formKeyNewPass,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'New Password',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _newPassCtrl,
            obscureText: _obscureNewPass,
            autofocus: true,
            textInputAction: TextInputAction.next,
            validator: (v) {
              final text = v?.trim() ?? '';
              if (text.isEmpty) return 'Please enter a new password.';
              if (text.length < 6) return 'Password must be at least 6 characters.';
              return null;
            },
            decoration: _inputDecoration(
              hint: 'At least 6 characters',
              prefixIcon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                  color: _textMuted,
                ),
                onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Confirm New Password',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmPassCtrl,
            obscureText: _obscureConfirmPass,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleCompleteReset(),
            validator: (v) {
              final text = v?.trim() ?? '';
              if (text.isEmpty) return 'Please confirm your new password.';
              if (text != _newPassCtrl.text.trim()) {
                return 'Passwords do not match.';
              }
              return null;
            },
            decoration: _inputDecoration(
              hint: 'Re-enter new password',
              prefixIcon: Icons.lock_reset_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                  color: _textMuted,
                ),
                onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildPrimaryButton(
            label: 'Reset Password',
            onPressed: _loading ? null : _handleCompleteReset,
            loading: _loading,
          ),
        ],
      ),
    );
  }

  // ── Step 4: Success Message ───────────────────────────────────────────────
  Widget _buildSuccessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        _buildPrimaryButton(
          label: 'Proceed to Sign In',
          onPressed: () => Navigator.of(context).pop(),
          loading: false,
        ),
      ],
    );
  }

  // ── Primary Action Button ─────────────────────────────────────────────────
  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    required bool loading,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  // ── Input Decoration Helper ───────────────────────────────────────────────
  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(prefixIcon, size: 20, color: _textMuted),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _bgInput,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _error, width: 1.5),
      ),
    );
  }
}

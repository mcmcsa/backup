import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../../shared/providers/theme_provider.dart';

class ForceChangePasswordScreen extends StatefulWidget {
  const ForceChangePasswordScreen({super.key});

  @override
  State<ForceChangePasswordScreen> createState() =>
      _ForceChangePasswordScreenState();
}

class _ForceChangePasswordScreenState
    extends State<ForceChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();
    final error = await authService.forceChangePassword(
      newPassword: _passCtrl.text.trim(),
    );

    if (!mounted) return;

    setState(() => _submitting = false);

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      final user = authService.currentUser;
      if (user != null && mounted) {
        context.go(user.dashboardRoute);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // Dynamic colors based on theme
    const accentColor = Color(0xFF0F766E);
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2D2D45) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);
    final labelColor = isDark ? Colors.grey.shade300 : const Color(0xFF334155);
    final fieldFillColor = isDark ? const Color(0xFF252535) : const Color(0xFFF8FAFC);
    final fieldBorderColor = isDark ? const Color(0xFF3D3D55) : const Color(0xFFE2E8F0);
    final iconColor = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);
    final inputTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final hintColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0D0D1A)
            : Colors.black.withValues(alpha: 0.55),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.25),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                  border: Border.all(color: cardBorder),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lock Icon
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            color: accentColor,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title
                      Center(
                        child: Text(
                          'Update Password',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        'Your account for ${user?.email ?? 'this account'} was created by a System Administrator. Please update your temporary password before continuing.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: subtitleColor,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.red.shade900.withValues(alpha: 0.4)
                                : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? Colors.red.shade700
                                  : const Color(0xFFFCA5A5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: isDark
                                    ? Colors.red.shade300
                                    : const Color(0xFFDC2626),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.red.shade300
                                        : const Color(0xFFB91C1C),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // New Password label
                      Text(
                        'New Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscurePass,
                        style: TextStyle(color: inputTextColor, fontSize: 14),
                        cursorColor: accentColor,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter a new password.';
                          }
                          if (v.trim().length < 6) {
                            return 'Password must be at least 6 characters.';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter new password',
                          hintStyle: TextStyle(color: hintColor, fontSize: 14),
                          prefixIcon: Icon(Icons.key_rounded,
                              size: 20, color: iconColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: iconColor,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                          ),
                          filled: true,
                          fillColor: fieldFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: fieldBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: fieldBorderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: accentColor, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? Colors.red.shade400 : Colors.red,
                            ),
                          ),
                          errorStyle: TextStyle(
                            color: isDark ? Colors.red.shade300 : Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password label
                      Text(
                        'Confirm New Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _obscureConfirm,
                        style: TextStyle(color: inputTextColor, fontSize: 14),
                        cursorColor: accentColor,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please confirm your password.';
                          }
                          if (v.trim() != _passCtrl.text.trim()) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Re-enter new password',
                          hintStyle: TextStyle(color: hintColor, fontSize: 14),
                          prefixIcon: Icon(Icons.lock_outline_rounded,
                              size: 20, color: iconColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: iconColor,
                            ),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                          filled: true,
                          fillColor: fieldFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: fieldBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: fieldBorderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: accentColor, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? Colors.red.shade400 : Colors.red,
                            ),
                          ),
                          errorStyle: TextStyle(
                            color: isDark ? Colors.red.shade300 : Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                accentColor.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Update Password & Continue',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

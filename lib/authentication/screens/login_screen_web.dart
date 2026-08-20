import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

class LoginScreenWeb extends StatefulWidget {
  const LoginScreenWeb({super.key});

  @override
  State<LoginScreenWeb> createState() => _LoginScreenWebState();
}

class _LoginScreenWebState extends State<LoginScreenWeb>
  with TickerProviderStateMixin {
  // --- Professional Color Palette ---
  static const Color _brandNavy = Color(0xFF0F172A);
  static const Color _brandAmber = Color(0xFFFBBF24);
  static const Color _brandBlue = Color(0xFF1E40AF); // Changed from 0xFF4D8CFF to a deeper dark blue
  static const Color _bgSlate = Color(0xFFF8FAFC);
  static const Color _textPrimary = Color(0xFF161E2E); // Darker primary text for better contrast
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _inputBorder = Color(0xFFBFDBFE); // New light blue border color (blue-200)

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeHeader;
  late final Animation<double> _fadeForm;
  late final Animation<Offset> _slideForm;
  late final AnimationController _floatController;
  late final Animation<double> _floatOffset;
  late final Animation<double> _floatScale;
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;



  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeHeader = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );

    _fadeForm = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.3, 0.8, curve: Curves.easeOut)),
    );

    _slideForm = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic)),
    );

    _animController.forward();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _floatOffset = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _floatScale = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulse = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final user = await authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (user == null) {
        final errorMsg = authService.loginError ?? 'Invalid email or password';
        _showLoginError(_friendlyLoginError(errorMsg));
        return;
      }

      final String statusText;

      switch (user.role.name) {
        case 'admin':
          statusText = 'Loading System Admin Console...';
          break;
        case 'campadmin':
          statusText = 'Loading Admin Dashboard...';
          break;
        case 'teacher':
          statusText = 'Loading Teacher Dashboard...';
          break;
        case 'maintenance':
          statusText = 'Loading Maintenance Dashboard...';
          break;
        default:
          statusText = 'Synchronizing Interface...';
      }

      if (!mounted) return;
      authService.showInitializingScreen(
        context,
        user.dashboardRoute,
        statusText: statusText,
      );
    } catch (e) {
      if (!mounted) return;
      _showLoginError(_friendlyLoginError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLoginError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Verification Failed: $message'),
        backgroundColor: const Color(0xFFE11D48),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  String _friendlyLoginError(Object error) {
    final rawMessage = error.toString();
    final normalized = rawMessage.toLowerCase();

    if (normalized.contains('database error querying schema') ||
        normalized.contains('unexpected_failure')) {
      return 'The authentication database needs repair. Please apply the latest Supabase migration and try again.';
    }

    return rawMessage
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^AuthException:\s*'), '');
  }

  @override
  Widget build(BuildContext context) {
    // Quick fix to ensure HTML splash screen is hidden during hot reload
    try {
      final loadingDiv = html.document.getElementById('loading');
      if (loadingDiv != null) {
        loadingDiv.remove();
      }
    } catch (_) {}

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 768 && size.width < 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8FF),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.9, -0.8),
                  radius: 1.1,
                  colors: [
                    Colors.white.withValues(alpha: 0.92),
                    _bgSlate,
                    const Color(0xFFEAF2FF),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFCBD5E1).withValues(alpha: 0.28), width: 24),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFDBEAFE).withValues(alpha: 0.35),
              ),
            ),
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 958 : 375, // Reduced by 10% (1116 -> 1004, 468 -> 421)
                maxHeight: isDesktop ? 670 : size.height - 48,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 42,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(34),
                child: Stack(
                  children: [
                    // Base Layer: Row of Content
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Column (Login Form)
                        Expanded(
                          flex: 1,
                          child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isDesktop ? 64 : (isTablet ? 44 : 24),
                                  vertical: 22,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildBrandHeader(),
                                    const SizedBox(height: 24),
                                    _buildFormBody(size),
                                    const SizedBox(height: 18),
                                    _buildFooter(),
                                  ],
                                ),
                            ),
                          ),
                        
                        // Right Column (Value Panel)
                        if (isDesktop)
                          Expanded(
                            flex: 1,
                            child: _buildValuePanel(),
                          ),
                      ],
                    ),
                    // Floating Back Button
                    Positioned(
                      top: 20,
                      left: 20,
                      child: Tooltip(
                        message: 'Back to Landing Page',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => context.go('/'),
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: _brandNavy,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),


                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Center(
          child: Image.asset(
            'assets/images/psu_logo_v3.png',
            width: 120, // Increased size for prominence
            height: 120,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'PANGASINAN STATE UNIVERSITY',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _brandNavy,
            letterSpacing: 1.2,
          ),
        ),
        const Text(
          'MAINTENANCE MANAGEMENT SYSTEM',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _brandBlue,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFormBody(Size size) {
    return FadeTransition(
      opacity: _fadeForm,
      child: SlideTransition(
        position: _slideForm,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFieldLabel('Email'),
                    _buildTextField(
                      controller: _emailController,
                      hint: 'Enter your Email',
                      prefixIcon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    _buildFieldLabel('Password'),
                    _buildTextField(
                      controller: _passwordController,
                      hint: 'Enter your Password',
                      prefixIcon: Icons.lock_outline_rounded,
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          foregroundColor: _brandNavy,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Forgot Password?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 48, // Reduced from 56
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandBlue, // Changed to Dark Blue (1E40AF)
          foregroundColor: Colors.white,
          elevation: 2, // Added slight elevation for better visual depth
          shadowColor: _brandBlue.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading 
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Log in', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.8)),
                SizedBox(width: 12),
                Icon(Icons.chevron_right_rounded, size: 24),
              ],
            ),
      ),
    );
  }



  Widget _buildValuePanel() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF173B75),
            Color(0xFF12315F),
            Color(0xFF0C1F43),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // Background "Blueprint" style abstraction
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 44, right: 44, bottom: 44, top: 37), // Reduced top padding from 53 by 30% (53 * 0.7 ≈ 37)
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: AnimatedBuilder(
                        animation: _floatController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _floatOffset.value),
                            child: Transform.scale(
                              scale: _floatScale.value,
                              child: child,
                            ),
                          );
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    _brandAmber.withValues(alpha: 0.28 + (_pulse.value * 0.12)),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2), // Shift the logo down slightly for better visual balance with the floating effect
                              child: Image.asset(
                                'assets/images/app_logo_v2.png',
                                width: 168,
                                height: 168,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 136), // Reduced from 194 by 30% (194 * 0.7 ≈ 136)
                    const Text(
                      'Scan Report Resolve',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'QR-powered maintenance tracking for faster issue resolution.',
                      style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.4, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12), // Added padding to bottom group to lift it up slightly
                  child: Row(
                    children: [
                      _buildValueTile(Icons.qr_code_scanner_rounded, 'QR Tracking', 'Scan rooms and report issues'),
                      const SizedBox(width: 16),
                      _buildValueTile(Icons.analytics_outlined, 'Performance', 'Track maintenance progress'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: _brandNavy, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    bool isPassword = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(fontWeight: FontWeight.w500, color: _textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
        prefixIcon: Icon(prefixIcon, color: _brandNavy, size: 20),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: _textMuted, size: 20),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            )
          : null,
        fillColor: Colors.transparent, // Removed the gray background fill
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _inputBorder, width: 1.5), // Changed to light blue border
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _inputBorder, width: 1.5), // Changed to light blue border
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _brandBlue, width: 2), // Changed to dark blue focus border
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Required field' : null,
    );
  }

  Widget _buildValueTile(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _brandAmber, size: 24),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Divider(height: 36, color: Color(0xFFE2E8F0)),
          Text(
            'CAPSTONE PROJECT.\nBS Information Technology © 2026 ',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1, height: 1.8),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF334155),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

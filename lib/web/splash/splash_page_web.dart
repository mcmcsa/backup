import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashPageWeb extends StatefulWidget {
  final String destinationRoute;
  final String statusText;
  final VoidCallback? onCompleted;

  const SplashPageWeb({
    super.key,
    required this.destinationRoute,
    this.statusText = 'Initializing Secure Connection...',
    this.onCompleted,
  });

  @override
  State<SplashPageWeb> createState() => _SplashPageWebState();
}

class _SplashPageWebState extends State<SplashPageWeb>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final Animation<double> _fadeHeader;
  late final Animation<double> _fadeStatus;
  late final Animation<double> _progress;
  
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _fadeHeader = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _fadeStatus = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
      ),
    );

    _progress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.1, 0.9, curve: Curves.easeInOutCubic),
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _mainController.forward().then((_) => _navigateToDestination());
  }

  void _navigateToDestination() {
    if (_isNavigating) return;
    _isNavigating = true;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        widget.onCompleted?.call();
        context.go(widget.destinationRoute);
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Gradient Mesh
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8FAFC),
                    Color(0xFFF1F5F9),
                    Color(0xFFE2E8F0),
                  ],
                ),
              ),
            ),
          ),
          
          // Decorative Orbs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E40AF).withValues(alpha: 0.03),
              ),
            ),
          ),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Section with Pulse
                ScaleTransition(
                  scale: _pulse,
                  child: FadeTransition(
                    opacity: _fadeHeader,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/psu_logo_v3.png',
                            width: 140,
                            height: 140,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'PSU MMS',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Title and System Name
                FadeTransition(
                  opacity: _fadeHeader,
                  child: Column(
                    children: [
                      const Text(
                        'PANGASINAN STATE UNIVERSITY',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Maintenance Management System'.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 80),
                
                // Progress Bar and Status
                FadeTransition(
                  opacity: _fadeStatus,
                  child: SizedBox(
                    width: 300,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedBuilder(
                            animation: _progress,
                            builder: (context, child) {
                              return LinearProgressIndicator(
                                value: _progress.value,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFE2E8F0),
                                color: const Color(0xFF1E40AF),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.statusText.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Footer
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeStatus,
              child: const Center(
                child: Text(
                  'PRECISION ENGINEERING FOR EDUCATION.\n© 2026 PANGASINAN STATE UNIVERSITY.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 1.0,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

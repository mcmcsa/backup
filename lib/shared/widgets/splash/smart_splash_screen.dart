import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'splash_background_painter.dart';
import 'qr_scan_animator.dart';

class SmartSplashScreen extends StatefulWidget {
  final String destinationRoute;
  final VoidCallback? onCompleted;

  const SmartSplashScreen({
    super.key,
    required this.destinationRoute,
    this.onCompleted,
  });

  @override
  State<SmartSplashScreen> createState() => _SmartSplashScreenState();
}

class _SmartSplashScreenState extends State<SmartSplashScreen>
    with TickerProviderStateMixin {
  
  // Animation Controllers
  late final AnimationController _masterController;
  late final AnimationController _backgroundController;
  
  // Animations
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _systemNameSlide;
  late final Animation<double> _subtitleFade;
  
  // Loading Messages
  final List<String> _loadingMessages = [
    'Loading System Resources...',
    'Verifying Secure Access...',
    'Preparing Facility Data...',
    'Initializing QR Services...',
    'Ready to Launch...',
  ];
  int _currentMessageIndex = 0;
  Timer? _messageTimer;

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    // Background continuous animation
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Choreography controller
    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    // 1. Logo Fade In & Scale (0ms - 600ms)
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.15, curve: Curves.easeOutBack),
      ),
    );

    // 2. System Name Slide Up (600ms - 1200ms)
    _systemNameSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.15, 0.3, curve: Curves.easeOutCubic),
      ),
    );

    // 3. Subtitle & QR Fade In (1200ms - 1800ms)
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.3, 0.45, curve: Curves.easeIn),
      ),
    );

    // Start Choreography
    _masterController.forward();

    // Rotating messages every 1.5 seconds
    _messageTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted) return;
      setState(() {
        if (_currentMessageIndex < _loadingMessages.length - 1) {
          _currentMessageIndex++;
        }
      });
      
      // When we hit the last message, wait a bit and navigate
      if (_currentMessageIndex == _loadingMessages.length - 1) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 800), _navigateToDestination);
      }
    });
  }

  void _navigateToDestination() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    
    // Final fade out transition before route
    _masterController.reverse().then((_) {
      if (mounted) {
        widget.onCompleted?.call();
        context.go(widget.destinationRoute);
      }
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _masterController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090E17),
      body: Stack(
        children: [
          // Animated Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                return CustomPaint(
                  painter: SplashBackgroundPainter(
                    animationValue: _backgroundController.value,
                  ),
                );
              },
            ),
          ),
          
          // Main Content
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Stack(
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 60.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // 1. Logo
                                  AnimatedBuilder(
                                    animation: _masterController,
                                    builder: (context, child) {
                                      return Opacity(
                                        opacity: _logoFade.value,
                                        child: Transform.scale(
                                          scale: _logoScale.value,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: _buildLogoContainer(),
                                  ),
                                  
                                  const SizedBox(height: 32),
                                  
                                  // 2. System Name
                                  AnimatedBuilder(
                                    animation: _masterController,
                                    builder: (context, child) {
                                      return Opacity(
                                        opacity: _logoFade.value >= 0.5 ? 1.0 : 0.0, // Delay visibility
                                        child: SlideTransition(
                                          position: _systemNameSlide,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Column(
                                      children: [
                                        const Text(
                                          'PSU MMS',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFFF8FAFC),
                                            letterSpacing: 2.0,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Maintenance Management System\nwith QR-Based Facility Tracking',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF94A3B8),
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 32),
                                  
                                  // 3. Subtitle & QR Scanner
                                  AnimatedBuilder(
                                    animation: _masterController,
                                    builder: (context, child) {
                                      return Opacity(
                                        opacity: _subtitleFade.value,
                                        child: child,
                                      );
                                    },
                                    child: Column(
                                      children: [
                                        const Text(
                                          'Efficient Facility Maintenance and Monitoring',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 40),
                                        const QRScanAnimator(),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 60),
                                  
                                  // 4. Loading Section
                                  AnimatedBuilder(
                                    animation: _masterController,
                                    builder: (context, child) {
                                      return Opacity(
                                        opacity: _subtitleFade.value,
                                        child: child,
                                      );
                                    },
                                    child: _buildLoadingSection(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoContainer() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
            blurRadius: 60,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
            blurRadius: 40,
            spreadRadius: 15,
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/psu_logo_v3.png',
        width: 140,
        height: 140,
        fit: BoxFit.contain,
        // Using ColorFilter can make a professional overlay, but for a logo it's better to keep original colors
      ),
    );
  }

  Widget _buildLoadingSection() {
    return SizedBox(
      width: 280,
      child: Column(
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutCubic,
                width: 280 * ((_currentMessageIndex + 1) / _loadingMessages.length),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              _loadingMessages[_currentMessageIndex].toUpperCase(),
              key: ValueKey<int>(_currentMessageIndex),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

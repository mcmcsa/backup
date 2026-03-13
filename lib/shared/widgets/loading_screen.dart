import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  final Widget destination;
  final Duration delay;
  final String statusText;
  final bool instant;

  const LoadingScreen({
    super.key,
    required this.destination,
    this.delay = const Duration(seconds: 4),
    this.statusText = 'LOADING SYSTEM',
    this.instant = false,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.delay,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.instant) {
      _controller.value = 1.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => widget.destination),
          );
        }
      });
    } else {
      _controller.forward();

      // Navigate to destination after delay
      Future.delayed(widget.delay, () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => widget.destination),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFFF8F9FA),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // PSU MMS Logo - displayed immediately without fade
              SizedBox(
                height: 260,
                width: 260,
                child: Image.asset(
                  'assets/images/psummsIcon.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 50),

              // Fade in title and status text
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main Title
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'PSU ',
                            style: TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 35,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          TextSpan(
                            text: 'MaintSystem',
                            style: TextStyle(
                              color: Color(0xFF4169E1),
                              fontSize: 35,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'PANGASINAN STATE UNIVERSITY',
                      style: TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 80),
                    // Loading Status
                    Text(
                      widget.statusText,
                      style: const TextStyle(
                        color: Color(0xFF4169E1),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Progress Bar and Percentage
                    AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        final progress = _progressAnimation.value;
                        final percentage = (progress * 100).toInt();
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 60),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFFE0E0E0),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF4169E1),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '$percentage% Loading...',
                              style: const TextStyle(
                                color: Color(0xFF616161),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}






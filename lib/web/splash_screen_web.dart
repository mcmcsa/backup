import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../authentication/screens/login_screen_web.dart';

class SplashScreenWeb extends StatefulWidget {
  const SplashScreenWeb({super.key});

  @override
  State<SplashScreenWeb> createState() => _SplashScreenWebState();
}

class _SplashScreenWebState extends State<SplashScreenWeb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  String _statusMessage = 'Initializing...';
  bool _isConnected = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _checkConnection();
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _statusMessage = 'Ready!';
        _progress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const LoginScreenWeb(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    }
  }

  Future<void> _checkConnection() async {
    for (int i = 0; i < 4; i++) {
      if (mounted) {
        setState(() => _progress = (i + 1) / 4);
      }
      await Future.delayed(const Duration(milliseconds: 600));
    }

    if (mounted) {
      setState(() {
        _statusMessage = 'Checking connection...';
      });
    }

    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (mounted) {
        setState(() {
          _isConnected = connectivityResult.isNotEmpty && 
                         connectivityResult.first != ConnectivityResult.none;
          if (_isConnected && connectivityResult.isNotEmpty) {
            if (connectivityResult.first == ConnectivityResult.wifi) {
              _statusMessage = 'Connected via WiFi';
            } else if (connectivityResult.first == ConnectivityResult.ethernet) {
              _statusMessage = 'Connected via Ethernet';
            } else {
              _statusMessage = 'Connected';
            }
          } else {
            _statusMessage = 'No internet connection';
          }
        });
      }

      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        setState(() {
          _statusMessage = 'Loading resources...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Connection check failed';
          _isConnected = false;
        });
      }
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
        color: const Color(0xFFF5F5F5),
        child: Stack(
          children: [
            // Top-left Logo
            Positioned(
              top: 40,
              left: 40,
              child: Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/images/PsuLogo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, _) => const Icon(
                    Icons.school,
                    size: 64,
                    color: Color(0xFF0D3B6E),
                  ),
                ),
              ),
            ),

            // Main Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Main Title
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'PSU ',
                                style: TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontSize: 56,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              TextSpan(
                                text: 'Mobile',
                                style: TextStyle(
                                  color: Color(0xFF4169E1),
                                  fontSize: 56,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'PANGASINAN STATE UNIVERSITY',
                          style: TextStyle(
                            color: Color(0xFF757575),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 100),

                  // Loading Status
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        const Text(
                          'LOADING SYSTEM',
                          style: TextStyle(
                            color: Color(0xFF4169E1),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Progress Bar
                        SizedBox(
                          width: 300,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _progress,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFE0E0E0),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF4169E1),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            color: Color(0xFF616161),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}






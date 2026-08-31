import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:universal_html/html.dart' as html;

class LandingPageWeb extends StatefulWidget {
  const LandingPageWeb({super.key});

  @override
  State<LandingPageWeb> createState() => _LandingPageWebState();
}

class _LandingPageWebState extends State<LandingPageWeb> {
  // Brand colors from UI-UX-PRO-MAX recommendations
  static const Color _navyBlue = Color(0xFF0F172A);
  static const Color _royalBlue = Color(0xFF1E40AF);
  static const Color _accentAmber = Color(0xFFF59E0B);
  static const Color _textSlate = Color(0xFF475569);
  static const Color _borderSlate = Color(0xFFE2E8F0);

  int _hoveredNavIndex = -1;
  bool _isLoginHovered = false;
  bool _isGetStartedHovered = false;
  bool _isDownloadAppHovered = false;
  bool _isQrCardHovered = false;

  final List<bool> _hoveredSteps = [false, false, false, false, false];
  final List<bool> _hoveredFooterItems = [false, false, false, false];

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _howItWorksKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header / Navbar
          _buildNavbar(isDesktop),

          // Main Body
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  // Hero Section
                  _buildHeroSection(isDesktop, width),

                  // How It Works Section
                  _buildHowItWorksSection(isDesktop, width),

                  // Value / Footer Bar
                  _buildFooterBar(isDesktop, width),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- NAVBAR ---
  Widget _buildNavbar(bool isDesktop) {
    final width = MediaQuery.of(context).size.width;

    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: _borderSlate, width: 1),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: width < 600 ? 16 : 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Brand Logo & Title
          Row(
            children: [
              Image.asset(
                'assets/images/psu_logo_v3.png',
                height: width < 600 ? 36 : 48,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.engineering_rounded,
                  color: _royalBlue,
                  size: width < 600 ? 30 : 40,
                ),
              ),
              SizedBox(width: width < 600 ? 8 : 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'PSU MMS',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: width < 600 ? 16 : 22,
                      fontWeight: FontWeight.bold,
                      color: _navyBlue,
                      height: 1.1,
                    ),
                  ),
                  if (width >= 600) ...[
                    const SizedBox(height: 2),
                    const Text(
                      'Maintenance Management System',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: _textSlate,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Center: Navigation Links (Desktop only)
          if (isDesktop)
            Row(
              children: [
                _buildNavLink(0, 'Home', () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                }),
                const SizedBox(width: 32),
                _buildNavLink(1, 'About', () => _scrollToSection(_aboutKey)),
                const SizedBox(width: 32),
                _buildNavLink(2, 'Features', () => _scrollToSection(_featuresKey)),
                const SizedBox(width: 32),
                _buildNavLink(3, 'How It Works', () => _scrollToSection(_howItWorksKey)),
                const SizedBox(width: 32),
                _buildNavLink(4, 'Contact', () {}),
              ],
            ),

          // Right: Login Button
          MouseRegion(
            onEnter: (_) => setState(() => _isLoginHovered = true),
            onExit: (_) => setState(() => _isLoginHovered = false),
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _isLoginHovered ? _royalBlue.withBlue(200) : _royalBlue,
                borderRadius: BorderRadius.circular(8),
                boxShadow: _isLoginHovered
                    ? [
                        BoxShadow(
                          color: _royalBlue.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: ElevatedButton.icon(
                onPressed: () => context.go('/login'),
                icon: Icon(Icons.login_rounded, size: width < 600 ? 14 : 16, color: Colors.white),
                label: Text(
                  'Login',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: width < 600 ? 12 : 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(
                    horizontal: width < 600 ? 12 : 20,
                    vertical: width < 600 ? 12 : 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavLink(int index, String title, VoidCallback onTap) {
    final isHovered = _hoveredNavIndex == index;
    final isHome = index == 0; // Home defaults to active highlight style

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredNavIndex = index),
      onExit: (_) => setState(() => _hoveredNavIndex = -1),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: (isHome || isHovered) ? FontWeight.bold : FontWeight.w500,
                color: (isHome || isHovered) ? _royalBlue : _navyBlue,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: isHome ? 28 : (isHovered ? 20 : 0),
              color: _royalBlue,
            ),
          ],
        ),
      ),
    );
  }

  // --- HERO SECTION ---
  Widget _buildHeroSection(bool isDesktop, double screenWidth) {
    final contentWidth = isDesktop ? screenWidth * 0.45 : screenWidth;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF0F9FF)], // Sky blue background light tint
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth < 600 ? 16 : 40,
        vertical: screenWidth < 600 ? 32 : 60,
      ),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _buildHeroLeftContent(contentWidth)),
                const SizedBox(width: 40),
                Expanded(child: _buildHeroRightContent(screenWidth * 0.45)),
              ],
            )
          : Column(
              children: [
                _buildHeroLeftContent(contentWidth),
                const SizedBox(height: 60),
                _buildHeroRightContent(screenWidth),
              ],
            ),
    );
  }

  Widget _buildHeroLeftContent(double width) {
    final screenWidth = MediaQuery.of(context).size.width;
    final titleFontSize = screenWidth < 600 ? 24.0 : (screenWidth < 1024 ? 32.0 : 44.0);

    return Column(
      key: _aboutKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PANGASINAN STATE UNIVERSITY – SAN CARLOS CAMPUS',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: screenWidth < 600 ? 11 : 13,
            fontWeight: FontWeight.bold,
            color: _accentAmber,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Maintenance Management System with QR-Based Facility Tracking',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: titleFontSize,
            fontWeight: FontWeight.w900,
            color: _navyBlue,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        // Orange/Yellow short decorative bar
        Container(
          width: 80,
          height: 4,
          decoration: BoxDecoration(
            color: _accentAmber,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'A smart and efficient way to report, monitor, and manage facility maintenance requests across the campus.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: screenWidth < 600 ? 14 : 16,
            color: _textSlate,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: screenWidth < 600 ? 12 : 16,
          runSpacing: screenWidth < 600 ? 12 : 16,
          children: [
            MouseRegion(
              onEnter: (_) => setState(() => _isGetStartedHovered = true),
              onExit: (_) => setState(() => _isGetStartedHovered = false),
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _isGetStartedHovered ? _royalBlue.withBlue(200) : _royalBlue,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _isGetStartedHovered
                      ? [
                          BoxShadow(
                            color: _royalBlue.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          )
                        ]
                      : [],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: Icon(Icons.qr_code_scanner_rounded, size: screenWidth < 600 ? 16 : 20, color: Colors.white),
                  label: Text(
                    'Get Started',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: screenWidth < 600 ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth < 600 ? 20 : 32,
                      vertical: screenWidth < 600 ? 14 : 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            MouseRegion(
              onEnter: (_) => setState(() => _isDownloadAppHovered = true),
              onExit: (_) => setState(() => _isDownloadAppHovered = false),
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _isDownloadAppHovered ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _royalBlue, width: 2),
                  boxShadow: _isDownloadAppHovered
                      ? [
                          BoxShadow(
                            color: _royalBlue.withOpacity(0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          )
                        ]
                      : [],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Logic to download APK using programmatic anchor click for mobile/desktop compatibility.
                    final anchor = html.AnchorElement(href: '/downloads/psu_maintsystem.apk')
                      ..setAttribute('download', 'psu_maintsystem.apk')
                      ..style.display = 'none';
                    html.document.body?.append(anchor);
                    anchor.click();
                    anchor.remove();
                  },
                  icon: Icon(Icons.android_rounded, size: screenWidth < 600 ? 16 : 20, color: _royalBlue),
                  label: Text(
                    'Download App',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: screenWidth < 600 ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: _royalBlue,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth < 600 ? 20 : 32,
                      vertical: screenWidth < 600 ? 14 : 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6), // Compensating for border
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),
        // Inline Features highlights styled as premium pill badges
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _buildCheckmarkFeature('Fast Reporting'),
            _buildCheckmarkFeature('Transparent Process'),
            _buildCheckmarkFeature('Better Facilities'),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckmarkFeature(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _borderSlate, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFFD1FAE5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF10B981),
              size: 12,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _navyBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroRightContent(double width) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 420,
          height: 480,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Background Radial Soft Blue Glow
              Positioned(
                right: 0,
                top: 40,
                width: 420,
                height: 420,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFE0F2FE),
                        const Color(0xFFE0F2FE).withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // 1. Gear emblem background (Rightmost Brand) - Proportional, Not Stretched
              Positioned(
                right: -10,
                top: 50,
                width: 400,
                height: 400,
                child: Image.asset(
                  'assets/images/login_brand.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),

              // 2. Floating smartphone mockup showing form (Obsidian Bezel)
              Positioned(
                left: 20,
                top: 0,
                width: 250,
                height: 480,
                child: _buildSmartphoneMockup(),
              ),

              // 3. Scan QR Code Card overlay - Hover animated
              Positioned(
                left: 210,
                bottom: 40,
                width: 170,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isQrCardHovered = true),
                  onExit: (_) => setState(() => _isQrCardHovered = false),
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.identity()
                      ..translate(_isQrCardHovered ? 4.0 : 0.0, _isQrCardHovered ? -6.0 : 0.0)
                      ..scale(_isQrCardHovered ? 1.03 : 1.0),
                    child: _buildQrScanCard(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmartphoneMockup() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Premium obsidian frame bezel
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: _royalBlue.withOpacity(0.12),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFF334155), width: 6), // Silver/slate ring
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Stack(
          children: [
            // Core screen background
            Positioned.fill(
              child: Container(
                color: const Color(0xFFF8FAFC), // Light background for contrast
              ),
            ),
            // Core screen layout
            Column(
              children: [
                // Phone Status Bar / Notch mockup
                Container(
                  color: _royalBlue,
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '9:41',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.signal_cellular_alt_rounded, size: 10, color: Colors.white),
                          SizedBox(width: 4),
                          Icon(Icons.wifi, size: 10, color: Colors.white),
                          SizedBox(width: 4),
                          Icon(Icons.battery_full_rounded, size: 12, color: Colors.white),
                        ],
                      ),
                    ],
                  ),
                ),

                // Mock App Header
                Container(
                  color: _royalBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_ios_rounded, color: Colors.white.withOpacity(0.8), size: 12),
                      const SizedBox(width: 4),
                      const Text(
                        'New Maintenance Request',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Mock Form Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Facility',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: _navyBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: _borderSlate),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Room 101 - Classroom',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 8, color: _navyBlue),
                              ),
                              Icon(Icons.domain_rounded, size: 10, color: Colors.grey),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Issue Type',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: _navyBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: _borderSlate),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Leaking Faucet',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 8, color: _navyBlue),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded, size: 12, color: Colors.grey),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: _navyBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 48,
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: _borderSlate),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'The faucet in the CR is constantly leaking.',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 8, color: _textSlate),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Photo (Optional)',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: _navyBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // Mock image evidence
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _borderSlate),
                                image: const DecorationImage(
                                  image: AssetImage('assets/images/psu_logo_v3.png'),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Camera container
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _borderSlate),
                              ),
                              child: const Icon(Icons.add_a_photo_rounded, size: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _royalBlue,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text(
                              'Submit Request',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Diagonal Glass Shine reflection overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.0),
                        Colors.black.withOpacity(0.03),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrScanCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: _royalBlue.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header banner
          Container(
            width: double.infinity,
            color: _royalBlue,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: const Text(
              'SCAN TO REPORT',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          // QR Code display
          QrImageView(
            data: 'https://psu-mms.edu/report/bldg-101',
            version: QrVersions.auto,
            size: 100.0,
            gapless: false,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: _navyBlue,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'FACILITY ID: bldg-101',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: _royalBlue,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // --- HOW IT WORKS SECTION ---
  Widget _buildHowItWorksSection(bool isDesktop, double screenWidth) {
    return Container(
      key: _howItWorksKey,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: Column(
        children: [
          const Text(
            'HOW IT WORKS',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _royalBlue,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Simple Steps, Better Maintenance',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: _navyBlue,
            ),
          ),
          const SizedBox(height: 60),

          // Steps list with hover animations
          isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildStepCard(
                        0,
                        Icons.qr_code_scanner_rounded,
                        '1. Scan QR Code',
                        'Scan the QR code assigned to the facility.',
                      ),
                    ),
                    _buildStepArrow(),
                    Expanded(
                      child: _buildStepCard(
                        1,
                        Icons.edit_document,
                        '2. Submit Request',
                        'Fill out the form and submit the maintenance request.',
                      ),
                    ),
                    _buildStepArrow(),
                    Expanded(
                      child: _buildStepCard(
                        2,
                        Icons.person_search_rounded,
                        '3. Admin Review',
                        'Admin reviews the request and assigns personnel.',
                      ),
                    ),
                    _buildStepArrow(),
                    Expanded(
                      child: _buildStepCard(
                        3,
                        Icons.construction_rounded,
                        '4. Maintenance Work',
                        'Maintenance personnel performs the task.',
                      ),
                    ),
                    _buildStepArrow(),
                    Expanded(
                      child: _buildStepCard(
                        4,
                        Icons.check_circle_outline_rounded,
                        '5. Update & Complete',
                        'Update status and record maintenance history.',
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildStepCard(
                      0,
                      Icons.qr_code_scanner_rounded,
                      '1. Scan QR Code',
                      'Scan the QR code assigned to the facility.',
                    ),
                    const Icon(Icons.arrow_downward_rounded, color: Colors.grey, size: 24),
                    _buildStepCard(
                      1,
                      Icons.edit_document,
                      '2. Submit Request',
                      'Fill out the form and submit the maintenance request.',
                    ),
                    const Icon(Icons.arrow_downward_rounded, color: Colors.grey, size: 24),
                    _buildStepCard(
                      2,
                      Icons.person_search_rounded,
                      '3. Admin Review',
                      'Admin reviews the request and assigns personnel.',
                    ),
                    const Icon(Icons.arrow_downward_rounded, color: Colors.grey, size: 24),
                    _buildStepCard(
                      3,
                      Icons.construction_rounded,
                      '4. Maintenance Work',
                      'Maintenance personnel performs the task.',
                    ),
                    const Icon(Icons.arrow_downward_rounded, color: Colors.grey, size: 24),
                    _buildStepCard(
                      4,
                      Icons.check_circle_outline_rounded,
                      '5. Update & Complete',
                      'Update status and record maintenance history.',
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildStepArrow() {
    return const Padding(
      padding: EdgeInsets.only(top: 40),
      child: Icon(
        Icons.chevron_right_rounded,
        color: Colors.grey,
        size: 32,
      ),
    );
  }

  Widget _buildStepCard(int index, IconData icon, String title, String desc) {
    final isHovered = _hoveredSteps[index];
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredSteps[index] = true),
      onExit: (_) => setState(() => _hoveredSteps[index] = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, isHovered ? -8 : 0, 0),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: isHovered ? _royalBlue : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isHovered ? _royalBlue : _royalBlue.withOpacity(0.15),
                  width: 1.5,
                ),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: _royalBlue.withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : [],
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: isHovered ? Colors.white : _royalBlue,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _navyBlue,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                desc,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: _textSlate,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- FOOTER BAR ---
  Widget _buildFooterBar(bool isDesktop, double screenWidth) {
    final padding = isDesktop ? const EdgeInsets.symmetric(horizontal: 60, vertical: 40) : const EdgeInsets.all(24);

    return Container(
      key: _featuresKey,
      color: const Color(0xFF0F172A),
      padding: padding,
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildFooterItem(0, Icons.verified_user_outlined, 'Secure & Reliable', 'Your data is safe with us.'),
                ),
                _buildFooterDivider(),
                Expanded(
                  child: _buildFooterItem(1, Icons.notifications_active_outlined, 'Real-time Notifications', 'Stay updated on request status.'),
                ),
                _buildFooterDivider(),
                Expanded(
                  child: _buildFooterItem(2, Icons.query_stats_rounded, 'Track & Monitor', 'Monitor all maintenance activities.'),
                ),
                _buildFooterDivider(),
                Expanded(
                  child: _buildFooterItem(3, Icons.domain_verification_rounded, 'Better Campus Environment', 'Well-maintained facilities for all.'),
                ),
              ],
            )
          : Column(
              children: [
                _buildFooterItem(0, Icons.verified_user_outlined, 'Secure & Reliable', 'Your data is safe with us.'),
                const Divider(color: Colors.white24, height: 32),
                _buildFooterItem(1, Icons.notifications_active_outlined, 'Real-time Notifications', 'Stay updated on request status.'),
                const Divider(color: Colors.white24, height: 32),
                _buildFooterItem(2, Icons.query_stats_rounded, 'Track & Monitor', 'Monitor all maintenance activities.'),
                const Divider(color: Colors.white24, height: 32),
                _buildFooterItem(3, Icons.domain_verification_rounded, 'Better Campus Environment', 'Well-maintained facilities for all.'),
              ],
            ),
    );
  }

  Widget _buildFooterDivider() {
    return Container(
      width: 1,
      height: 48,
      color: Colors.white.withOpacity(0.12),
    );
  }

  Widget _buildFooterItem(int index, IconData icon, String title, String desc) {
    final isHovered = _hoveredFooterItems[index];
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredFooterItems[index] = true),
      onExit: (_) => setState(() => _hoveredFooterItems[index] = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, isHovered ? -4 : 0, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isHovered ? Colors.white.withOpacity(0.15) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isHovered ? _accentAmber : Colors.white.withOpacity(0.85),
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isHovered ? _accentAmber : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: isHovered ? Colors.white : Colors.white.withOpacity(0.6),
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

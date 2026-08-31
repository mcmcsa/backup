import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/services/room_service.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../admin/shared/notifications_page.dart';

class ScannerPage extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final bool isActive;

  const ScannerPage({
    super.key,
    this.scaffoldKey,
    this.isActive = true,
  });

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _isFlashOn = false;
  bool _isScannerRunning = false;
  bool _isValidating = false;
  String? _scannedCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _queueScannerSync();
  }

  @override
  void didUpdateWidget(covariant ScannerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _queueScannerSync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _stopScanner();
        return;
      case AppLifecycleState.resumed:
        _queueScannerSync();
        return;
    }
  }

  void _queueScannerSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncScannerState();
    });
  }

  Future<void> _syncScannerState() async {
    if (!mounted) return;

    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final shouldRun =
        widget.isActive &&
        lifecycleState != AppLifecycleState.detached &&
        lifecycleState != AppLifecycleState.hidden &&
        lifecycleState != AppLifecycleState.inactive &&
        lifecycleState != AppLifecycleState.paused;

    if (shouldRun) {
      await _startScanner();
    } else {
      await _stopScanner();
    }
  }

  Future<void> _startScanner() async {
    if (_isScannerRunning) return;
    try {
      await cameraController.start();
      if (!mounted) return;
      setState(() => _isScannerRunning = true);
    } catch (_) {}
  }

  Future<void> _stopScanner() async {
    if (!_isScannerRunning) return;
    try {
      await cameraController.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isScannerRunning = false);
  }

  Future<void> _toggleFlash() async {
    setState(() => _isFlashOn = !_isFlashOn);
    try {
      await cameraController.toggleTorch();
    } catch (_) {}
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isValidating) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue?.trim();
    if (code == null || code.isEmpty || code == _scannedCode) return;

    setState(() => _scannedCode = code);
    _validateAndNavigate(code);
  }

  Future<void> _validateAndNavigate(String code) async {
    setState(() => _isValidating = true);
    await _stopScanner();

    try {
      final room = await RoomService.fetchByCode(code);
      if (!mounted) return;

      if (room != null) {
        await context.push(
          '/room-verification',
          extra: {
            'roomId': room.code.isNotEmpty ? room.code : room.id,
            'room': room,
          },
        );
      } else {
        _showInvalidQRCodeDialog();
      }
    } catch (_) {
      if (mounted) _showInvalidQRCodeDialog();
    }

    if (!mounted) return;
    setState(() {
      _scannedCode = null;
      _isValidating = false;
    });
    await _syncScannerState();
  }

  void _showInvalidQRCodeDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red.shade600,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Invalid QR Code',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This QR code is not recognized. Please scan a valid room QR code generated by the admin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4169E1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _enterManually() {
    context.push('/manual-room-entry');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Scaffold(
          backgroundColor: themeProvider.backgroundColor,
          appBar: CommonAppBar(
            roleText: 'Teacher',
            primaryColor: themeProvider.primaryColor,
            onMenuPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
            onNotificationPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsPage(),
                ),
              );
            },
          ),
          body: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: themeProvider.primaryColor,
                              width: 3,
                              strokeAlign: BorderSide.strokeAlignInside,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Stack(
                              children: [
                                if (widget.isActive)
                                  MobileScanner(
                                    controller: cameraController,
                                    fit: BoxFit.cover,
                                    onDetect: _handleBarcode,
                                  )
                                else
                                  Container(
                                    color: Colors.black,
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.qr_code_scanner_rounded,
                                          size: 48,
                                          color: Colors.white.withValues(alpha: 0.7),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Open the Scanner tab to use the camera',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.75),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                CustomPaint(
                                  painter: DashedBorderPainter(
                                    color: themeProvider.primaryColor,
                                    strokeWidth: 3,
                                    dashWidth: 10,
                                    dashSpace: 5,
                                  ),
                                  child: Container(),
                                ),
                                Positioned(
                                  top: 20,
                                  left: 20,
                                  child: _buildCornerBracket(
                                    isTop: true,
                                    isLeft: true,
                                    color: themeProvider.primaryColor,
                                  ),
                                ),
                                Positioned(
                                  top: 20,
                                  right: 20,
                                  child: _buildCornerBracket(
                                    isTop: true,
                                    isLeft: false,
                                    color: themeProvider.primaryColor,
                                  ),
                                ),
                                Positioned(
                                  bottom: 20,
                                  left: 20,
                                  child: _buildCornerBracket(
                                    isTop: false,
                                    isLeft: true,
                                    color: themeProvider.primaryColor,
                                  ),
                                ),
                                Positioned(
                                  bottom: 20,
                                  right: 20,
                                  child: _buildCornerBracket(
                                    isTop: false,
                                    isLeft: false,
                                    color: themeProvider.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: themeProvider.primaryColor,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: themeProvider.cardColor,
                        ),
                        child: Text(
                          _isValidating
                              ? 'Checking the scanned room...'
                              : 'Point your camera at the QR code of the room',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: themeProvider.textColor,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _enterManually,
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          label: const Text(
                            'Enter Manually',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _toggleFlash,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isFlashOn ? Icons.flash_on : Icons.flash_off,
                              color: themeProvider.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isFlashOn ? 'Flash On' : 'Flash Off',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: themeProvider.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCornerBracket({
    required bool isTop,
    required bool isLeft,
    required Color color,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? BorderSide(color: color, width: 4) : BorderSide.none,
          bottom: !isTop ? BorderSide(color: color, width: 4) : BorderSide.none,
          left: isLeft ? BorderSide(color: color, width: 4) : BorderSide.none,
          right: !isLeft ? BorderSide(color: color, width: 4) : BorderSide.none,
        ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    double startX = 0;

    while (startX < size.width) {
      path.moveTo(startX, 0);
      path.lineTo(startX + dashWidth, 0);
      startX += dashWidth + dashSpace;
    }

    double startY = 0;
    while (startY < size.height) {
      path.moveTo(size.width, startY);
      path.lineTo(size.width, startY + dashWidth);
      startY += dashWidth + dashSpace;
    }

    startX = size.width;
    while (startX > 0) {
      path.moveTo(startX, size.height);
      path.lineTo(startX - dashWidth, size.height);
      startX -= dashWidth + dashSpace;
    }

    startY = size.height;
    while (startY > 0) {
      path.moveTo(0, startY);
      path.lineTo(0, startY - dashWidth);
      startY -= dashWidth + dashSpace;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

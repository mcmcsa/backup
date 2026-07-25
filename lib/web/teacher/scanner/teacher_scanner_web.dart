import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../teacher_nav_controller.dart';
import '../../../shared/services/room_service.dart';
import '../../admin/shared/admin_styles.dart';

class TeacherScannerWeb extends StatefulWidget {
  const TeacherScannerWeb({super.key});

  @override
  State<TeacherScannerWeb> createState() => _TeacherScannerWebState();
}

class _TeacherScannerWebState extends State<TeacherScannerWeb> {
  final TextEditingController _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isScanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_forceUppercase);
  }

  void _forceUppercase() {
    final text = _codeController.text;
    final upper = text.toUpperCase();
    if (text != upper) {
      _codeController.value = _codeController.value.copyWith(
        text: upper,
        selection: TextSelection.collapsed(offset: upper.length),
      );
    }
  }

  @override
  void dispose() {
    _codeController.removeListener(_forceUppercase);
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final room = await RoomService.fetchByCode(code);
      if (room != null) {
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
          TeacherNavController.of(context)?.navigateTo(11,
            roomId: room.code,
            roomName: room.name,
            buildingName: room.building,
          );
        }
      } else {
        setState(() {
          _error = 'Room not found. Please scan a valid room QR code.';
        });
      }
    } catch (e) {
      setState(() => _error = 'An error occurred. Please try again later.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminStyles.bg,
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.symmetric(vertical: 40),
            padding: const EdgeInsets.all(40),
            decoration: AdminStyles.cardDecoration(hasShadow: true),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Room Verification', style: AdminStyles.headingStyle(fontSize: 24)),
                const SizedBox(height: 12),
                Text(
                  'Enter the room code located on the door or scan the QR code to quickly start a maintenance request.',
                  textAlign: TextAlign.center,
                  style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary),
                ),
                const SizedBox(height: 32),
                if (_isScanning)
                  Container(
                    width: 300,
                    height: 300,
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AdminStyles.primary, width: 2),
                    ),
                    child: Stack(
                      children: [
                        MobileScanner(
                          onDetect: (capture) {
                            if (_isVerifying) return;
                            final List<Barcode> barcodes = capture.barcodes;
                            for (final barcode in barcodes) {
                              if (barcode.rawValue != null) {
                                setState(() {
                                  _codeController.text = barcode.rawValue!;
                                });
                                _verifyRoom();
                                break;
                              }
                            }
                          },
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => setState(() => _isScanning = false),
                            style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      InkWell(
                        onTap: () => setState(() => _isScanning = true),
                        borderRadius: BorderRadius.circular(40),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(color: AdminStyles.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.qr_code_scanner_rounded, color: AdminStyles.primary, size: 40),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _isScanning = true),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('Open Scanner'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminStyles.primary.withValues(alpha: 0.1),
                          foregroundColor: AdminStyles.primary,
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                style: AdminStyles.headingStyle(fontSize: 18, letterSpacing: 2),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'e.g. 402',
                  hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontSize: 18),
                  filled: true,
                  fillColor: AdminStyles.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AdminStyles.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AdminStyles.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminStyles.primary, width: 2)),
                  errorText: _error,
                ),
                onSubmitted: (_) {
                  _codeController.text = _codeController.text.toUpperCase();
                  _verifyRoom();
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminStyles.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isVerifying
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Verify Room & Report Issue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/services/room_service.dart';
import '../../../shared/utils/qr_decoder_helper.dart';
import '../../../shared/widgets/already_reported_dialog.dart';
import '../../../shared/widgets/department_mismatch_dialog.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class ManualRoomEntryPage extends StatefulWidget {
  const ManualRoomEntryPage({super.key});

  @override
  State<ManualRoomEntryPage> createState() => _ManualRoomEntryPageState();
}

class _ManualRoomEntryPageState extends State<ManualRoomEntryPage> {
  final TextEditingController _roomIdController = TextEditingController();
  bool _isVerifying = false;
  String? _errorMessage;
  Uint8List? _uploadedQrBytes;

  @override
  void initState() {
    super.initState();
    _roomIdController.addListener(() {
      if (_errorMessage != null && mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }

  void _verifyRoom() async {
    final code = _roomIdController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a room code';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final room = await RoomService.findRoomByScannedCode(code);

      if (!mounted) return;

      if (room != null) {
        final user = context.read<AuthService>().currentUser;
        if (isRoomOfOtherDepartment(user: user, room: room)) {
          await showDepartmentMismatchDialog(
            context: context,
            roomCode: room.code,
            roomName: room.name,
            roomDepartment: room.department,
            userDepartment: user?.department,
          );
          _roomIdController.clear();
        } else {
          final s = room.status.toLowerCase().trim();
          final isReported = s != 'available' && s != 'reserved';
          if (isReported) {
            final proceed = await showAlreadyReportedDialog(
              context: context,
              room: room,
            );
            if (!proceed || !mounted) {
              setState(() {
                _isVerifying = false;
              });
              return;
            }
          }

          context.push(
            '/room-verification',
            extra: {
              'roomId': room.code.isNotEmpty ? room.code : room.id,
              'room': room,
              'qrImageBytes': _uploadedQrBytes,
            },
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Room not found. Please enter a valid room code.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error verifying room. Please check your connection and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _uploadAndVerify() async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final result = await QrDecoderHelper.pickAndDecodeQr();
      if (!mounted) return;

      if (result == null || !result.hasCode) {
        setState(() {
          _errorMessage = 'No QR code detected in the selected image.';
          _uploadedQrBytes = result?.imageBytes;
        });
        return;
      }

      setState(() {
        _uploadedQrBytes = result.imageBytes;
      });

      _roomIdController.text = result.code!.toUpperCase();
      _verifyRoom();
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error decoding QR code. Please try another image.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  void _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        _roomIdController.text = clipboardData.text!.trim().toUpperCase();
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.appBarIconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Room Verification',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: themeProvider.appBarTextColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: themeProvider.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: themeProvider.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Circular QR Scanner Icon
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA5).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF00BFA5).withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Color(0xFF00BFA5),
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Room Verification',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Subtitle
                  Text(
                    'Enter the room code located on the door or scan the QR code to quickly start a maintenance request.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: themeProvider.subtitleColor,
                      height: 1.45,
                    ),
                  ),
                  if (_uploadedQrBytes != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00BFA5).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.qr_code_2_rounded, size: 18, color: Color(0xFF00BFA5)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Uploaded QR Code',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: themeProvider.textColor),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () => setState(() => _uploadedQrBytes = null),
                                borderRadius: BorderRadius.circular(8),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _uploadedQrBytes!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),

                  // Room Code Input (Auto-capslock + 'ex. CLR 1' hint)
                  TextField(
                    controller: _roomIdController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      UpperCaseTextFormatter(),
                    ],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: themeProvider.textColor,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ex. CLR 1',
                      hintStyle: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 2,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: themeProvider.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _errorMessage != null
                              ? const Color(0xFFEF4444)
                              : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00BFA5), width: 2),
                      ),
                      errorText: _errorMessage,
                      errorStyle: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      suffixIcon: IconButton(
                        icon: Icon(
                          Icons.content_paste_rounded,
                          color: themeProvider.subtitleColor,
                          size: 20,
                        ),
                        onPressed: _pasteFromClipboard,
                        tooltip: 'Paste from clipboard',
                      ),
                    ),
                    onSubmitted: (_) => _verifyRoom(),
                  ),
                  const SizedBox(height: 24),

                  // Verify Room Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _verifyRoom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFA5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: const Color(0xFF00BFA5).withValues(alpha: 0.5),
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Verify Room & Report Issue',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.check_circle_rounded, size: 18),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Upload Room QR Code Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _isVerifying ? null : _uploadAndVerify,
                      icon: const Icon(
                        Icons.upload_file_rounded,
                        size: 18,
                        color: Color(0xFF00BFA5),
                      ),
                      label: const Text(
                        'Upload Room QR Code',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00BFA5),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00BFA5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Back to Scanner Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 18,
                        color: themeProvider.textColor,
                      ),
                      label: Text(
                        'Back to Scanner',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: themeProvider.textColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: themeProvider.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
    );
  }
}

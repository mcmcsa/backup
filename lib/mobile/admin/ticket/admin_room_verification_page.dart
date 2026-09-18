import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/services/room_service.dart';
import '../../teacher/reports/work_request_form_page.dart';

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

class AdminRoomVerificationPage extends StatefulWidget {
  const AdminRoomVerificationPage({super.key});

  @override
  State<AdminRoomVerificationPage> createState() => _AdminRoomVerificationPageState();
}

class _AdminRoomVerificationPageState extends State<AdminRoomVerificationPage> {
  final TextEditingController _roomCodeController = TextEditingController();
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _roomCodeController.addListener(() {
      if (_errorMessage != null && mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _verifyRoom() async {
    final code = _roomCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a room code.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final room = await RoomService.findRoomByScannedCode(code) ??
                   await RoomService.fetchByCode(code);

      if (!mounted) return;

      if (room != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WorkRequestFormPage(
              roomId: room.code.isNotEmpty ? room.code : room.id,
              buildingName: room.building,
              roomName: room.name,
              verifiedRoom: room,
              lockLocationDetails: true,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Room code not found. Please check the code and try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred while verifying room code. Please try again.';
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

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        _roomCodeController.text = clipboardData.text!.trim().toUpperCase();
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    const adminPrimary = Color(0xFF4169E1);

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
            fontSize: 18,
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
                  // Verification Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: adminPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: adminPrimary.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.meeting_room_outlined,
                      color: adminPrimary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Enter Room Code',
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
                    'Enter the room code to verify room location details before creating a request.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: themeProvider.subtitleColor,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Room Code Input
                  TextField(
                    controller: _roomCodeController,
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
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: adminPrimary, width: 2),
                      ),
                      errorText: _errorMessage,
                      errorStyle: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_roomCodeController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: themeProvider.subtitleColor,
                                size: 20,
                              ),
                              onPressed: () {
                                _roomCodeController.clear();
                                setState(() => _errorMessage = null);
                              },
                              tooltip: 'Clear',
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.content_paste_rounded,
                              color: themeProvider.subtitleColor,
                              size: 20,
                            ),
                            onPressed: _pasteFromClipboard,
                            tooltip: 'Paste from clipboard',
                          ),
                        ],
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
                        backgroundColor: adminPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: adminPrimary.withValues(alpha: 0.5),
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
                                  'Verify Room & Proceed',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cancel / Back Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: themeProvider.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: themeProvider.textColor,
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

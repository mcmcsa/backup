import 'package:flutter/material.dart';
import '../../../shared/models/room_model.dart';
import '../../../shared/services/room_service.dart';
import '../shared/admin_styles.dart';

class AdminRoomVerificationWeb extends StatefulWidget {
  final Function(Room room) onRoomVerified;
  final VoidCallback onBack;

  const AdminRoomVerificationWeb({
    super.key,
    required this.onRoomVerified,
    required this.onBack,
  });

  @override
  State<AdminRoomVerificationWeb> createState() => _AdminRoomVerificationWebState();
}

class _AdminRoomVerificationWebState extends State<AdminRoomVerificationWeb> {
  final TextEditingController _codeController = TextEditingController();
  bool _isVerifying = false;
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
    if (code.isEmpty) {
      setState(() => _error = 'Please enter a room code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final room = await RoomService.findRoomByScannedCode(code) ??
                   await RoomService.fetchByCode(code);
      if (room != null) {
        if (mounted) {
          widget.onRoomVerified(room);
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Room code not found. Please check the code and try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'An error occurred while verifying room code.');
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminStyles.bg,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(40),
          decoration: AdminStyles.cardDecoration(hasShadow: true),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AdminStyles.textPrimary),
                    onPressed: widget.onBack,
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 8),
                  Text('Room Verification', style: AdminStyles.headingStyle(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AdminStyles.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.meeting_room_outlined,
                  color: AdminStyles.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Enter Room Code',
                style: AdminStyles.headingStyle(fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the room code to verify room location details before creating a request.',
                textAlign: TextAlign.center,
                style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                style: AdminStyles.headingStyle(fontSize: 20, letterSpacing: 2),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'ex. CLR 1',
                  hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontSize: 18),
                  filled: true,
                  fillColor: AdminStyles.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AdminStyles.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AdminStyles.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AdminStyles.primary, width: 2),
                  ),
                  errorText: _error,
                ),
                onSubmitted: (_) => _verifyRoom(),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminStyles.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Verify Room & Proceed',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

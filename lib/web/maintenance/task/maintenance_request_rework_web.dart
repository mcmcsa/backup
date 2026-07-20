import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class MaintenanceRequestReworkWeb extends StatefulWidget {
  final String taskId;

  const MaintenanceRequestReworkWeb({super.key, required this.taskId});

  @override
  State<MaintenanceRequestReworkWeb> createState() => _MaintenanceRequestReworkWebState();
}

class _MaintenanceRequestReworkWebState extends State<MaintenanceRequestReworkWeb> {
  final TextEditingController _instructionsController = TextEditingController();
  String _selectedPriority = 'Standard';
  bool _isSubmitting = false;
  
  final List<PlatformFile> _attachedFiles = [];

  static const Color _primarySky = Color(0xFF0EA5E9);
  static const Color _warningOrange = Color(0xFFF59E0B);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _subtleText = Color(0xFF64748B);
  static const Color _pageBg = Color(0xFFF8FAFC);
  static const Color _cardBg = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _borderColor),
                    ),
                    child: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Request Rework',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _darkText,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Warning Banner
            Container(
              decoration: BoxDecoration(
                color: _warningOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _warningOrange.withValues(alpha: 0.3)),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: _warningOrange,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Submit a rework request if additional work is needed on this task.',
                      style: TextStyle(
                        fontSize: 13,
                        color: _subtleText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Form Container
            Container(
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task ID (Read-only)
                  const Text(
                    'Task Information',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _darkText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text(
                      'Task ID: ${widget.taskId.substring(0, 8)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _subtleText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Priority Selection
                  const Text(
                    'Priority Level',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _darkText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPriorityButton('Standard', false),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPriorityButton('High', true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Instructions
                  const Text(
                    'Rework Instructions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _darkText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _instructionsController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Describe what needs to be reworked and any specific instructions...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _borderColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // File Attachments
                  const Text(
                    'Attachments (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _darkText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickFiles,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _borderColor,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_upload_rounded, color: _primarySky, size: 32),
                            const SizedBox(height: 12),
                            const Text(
                              'Click to browse files',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _darkText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Supported formats: JPG, PNG (Max 5MB)',
                              style: TextStyle(
                                fontSize: 12,
                                color: _subtleText.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_attachedFiles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Column(
                      children: _attachedFiles.map((file) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _borderColor),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.insert_drive_file_rounded, color: _subtleText, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  file.name,
                                  style: const TextStyle(fontSize: 12, color: _darkText),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _attachedFiles.remove(file);
                                  });
                                },
                                child: const Icon(Icons.close_rounded, color: Colors.red, size: 16),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: _borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _darkText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _handleSubmit,
                          icon: const Icon(Icons.send_rounded),
                          label: _isSubmitting
                              ? const Text('Submitting...')
                              : const Text('Submit Rework Request'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primarySky,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityButton(String label, bool isHigh) {
    final isSelected = (_selectedPriority == 'Standard' && !isHigh) ||
        (_selectedPriority == 'High' && isHigh);

    return GestureDetector(
      onTap: () => setState(() => _selectedPriority = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primarySky : Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _primarySky : _borderColor,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : _darkText,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        _attachedFiles.addAll(result.files);
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_instructionsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide rework instructions'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rework request submitted successfully'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
    }
  }
}

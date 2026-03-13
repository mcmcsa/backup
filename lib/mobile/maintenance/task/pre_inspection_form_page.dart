import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/pre_inspection_model.dart';
import '../../../shared/services/pre_inspection_service.dart';
import '../../../shared/services/work_request_service.dart';
import 'pre_inspection_success_page.dart';

class PreInspectionFormPage extends StatefulWidget {
  final String workOrderId;
  final String location;
  final String assignedTo;

  const PreInspectionFormPage({
    super.key,
    required this.workOrderId,
    required this.location,
    required this.assignedTo,
  });

  @override
  State<PreInspectionFormPage> createState() => _PreInspectionFormPageState();
}

class _PreInspectionFormPageState extends State<PreInspectionFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _inspectedByController;
  late TextEditingController _conditionFoundController;
  late TextEditingController _descriptionController;
  late TextEditingController _rootCauseController;
  late TextEditingController _materialsController;
  late TextEditingController _estimatedTimeController;
  
  DateTime _inspectionDate = DateTime.now();
  String _severityLevel = 'Minor';
  String _recommendedAction = 'Replace Component';

  final List<String> _severityLevels = ['Minor', 'Moderate', 'Critical'];
  final List<String> _recommendedActions = [
    'Replace Component',
    'Repair',
    'Immediate Replacement',
    'Schedule Maintenance',
  ];

  @override
  void initState() {
    super.initState();
    _inspectedByController = TextEditingController(text: widget.assignedTo);
    _conditionFoundController = TextEditingController();
    _descriptionController = TextEditingController();
    _rootCauseController = TextEditingController();
    _materialsController = TextEditingController();
    _estimatedTimeController = TextEditingController();
  }

  @override
  void dispose() {
    _inspectedByController.dispose();
    _conditionFoundController.dispose();
    _descriptionController.dispose();
    _rootCauseController.dispose();
    _materialsController.dispose();
    _estimatedTimeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _inspectionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4169E1),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _inspectionDate) {
      setState(() {
        _inspectionDate = picked;
      });
    }
  }

  bool _isSubmitting = false;

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final user = authService.currentUser;

        final report = PreInspectionReport(
          id: '',
          workRequestId: widget.workOrderId,
          inspectorId: user?.id ?? '',
          inspectorName: _inspectedByController.text,
          inspectionDate: _inspectionDate,
          conditionFound: _conditionFoundController.text,
          description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
          rootCause: _rootCauseController.text.isNotEmpty ? _rootCauseController.text : null,
          severityLevel: _severityLevel,
          recommendedAction: _recommendedAction,
          materialsNeeded: _materialsController.text.isNotEmpty ? _materialsController.text : null,
          estimatedTime: _estimatedTimeController.text.isNotEmpty ? _estimatedTimeController.text : null,
        );

        final inserted = await PreInspectionService.insert(report);

        // Link the pre-inspection to the work request
        await WorkRequestService.linkPreInspection(widget.workOrderId, inserted.id);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PreInspectionSuccessPage(
                workOrderId: widget.workOrderId,
                repairSummary: _conditionFoundController.text,
                inspectedBy: _inspectedByController.text,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.workOrderId,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.black87),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Pre-Inspection Form'),
                  content: const Text(
                    'Complete this form before starting any repair work. Document the current condition of the equipment/facility, identify safety hazards, and verify the reported issue.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Text(
              'Pre inspection?',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '✓ Inspect & fill out a Short Note',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Technician Details Section
            _buildSectionHeader('TECHNICIAN DETAILS'),
            const SizedBox(height: 12),

            // Inspection Date
            _buildLabel('Inspection Date'),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Text(
                      '${_inspectionDate.month.toString().padLeft(2, '0')}/${_inspectionDate.day.toString().padLeft(2, '0')}/${_inspectionDate.year}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Inspected By
            _buildLabel('Inspected By'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _inspectedByController,
              hint: 'Alex Rivera [Tech ID-8834]',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Inspector name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Initial Findings Section
            _buildSectionHeader('INITIAL FINDINGS'),
            const SizedBox(height: 12),

            // Condition Found
            _buildLabel('Condition Found'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _conditionFoundController,
              hint: 'Describe the current state of the equipment...',
              icon: Icons.search,
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Condition description is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            _buildLabel('Description'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _descriptionController,
              hint: 'Provide detailed description...',
              icon: Icons.description_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Root Cause
            _buildLabel('Root Cause'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _rootCauseController,
              hint: 'Identify the cause of the failure or wear...',
              icon: Icons.warning_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Severity Level
            _buildLabel('Severity Level'),
            const SizedBox(height: 12),
            Row(
              children: _severityLevels.map((level) {
                final isSelected = _severityLevel == level;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _severityLevel = level;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (level == 'Critical'
                                  ? Colors.red
                                  : level == 'Moderate'
                                      ? Colors.orange
                                      : Colors.blue)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? Colors.white : Colors.grey[300],
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.grey,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? Center(
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: level == 'Critical'
                                              ? Colors.red
                                              : level == 'Moderate'
                                                  ? Colors.orange
                                                  : Colors.blue,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              level,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Resolution Plan Section
            _buildSectionHeader('RESOLUTION PLAN'),
            const SizedBox(height: 12),

            // Recommended Action
            _buildLabel('Recommended Action'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _recommendedAction,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  items: _recommendedActions.map((String action) {
                    return DropdownMenuItem<String>(
                      value: action,
                      child: Text(action),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _recommendedAction = newValue;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Estimated Materials Needed
            _buildLabel('Estimated Materials Needed'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _materialsController,
              hint: 'List required parts or quantities...',
              icon: Icons.shopping_cart_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Estimated Time to Repair
            _buildLabel('Estimated Time to Repair'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _estimatedTimeController,
                    hint: 'e.g. 2.5',
                    icon: Icons.access_time,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    'Hours',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Evidence Section
            _buildSectionHeader('EVIDENCE'),
            const SizedBox(height: 12),
            _buildLabel('Upload Pre-Inspection Pictures'),
            const SizedBox(height: 8),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 2, style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: 32,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to capture or upload',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    'Maximum 5 photos (PNG)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Technician Signature Section
            _buildSectionHeader('TECHNICIAN SIGNATURE'),
            const SizedBox(height: 8),
            Text(
              'Sign Here',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/signature_placeholder.png',
                      width: 200,
                      height: 60,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return CustomPaint(
                          size: const Size(200, 60),
                          painter: SignaturePainter(),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Signature cleared')),
                        );
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Clear', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A2E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.send, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Submit Pre-Inspection Report',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600],
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4169E1), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
      validator: validator,
    );
  }
}

// Custom painter for signature placeholder
class SignaturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(20, size.height / 2 + 10)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height / 2 - 10,
        size.width * 0.4,
        size.height / 2 + 5,
      )
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height / 2 + 15,
        size.width * 0.75,
        size.height / 2 - 5,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height / 2 - 15,
        size.width - 20,
        size.height / 2 + 5,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

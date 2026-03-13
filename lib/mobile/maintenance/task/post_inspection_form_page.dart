import 'package:flutter/material.dart';
import 'post_inspection_success_page.dart';

class PostInspectionFormPage extends StatefulWidget {
  final String workOrderId;
  final String location;
  final String assignedTo;

  const PostInspectionFormPage({
    super.key,
    required this.workOrderId,
    required this.location,
    required this.assignedTo,
  });

  @override
  State<PostInspectionFormPage> createState() => _PostInspectionFormPageState();
}

class _PostInspectionFormPageState extends State<PostInspectionFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _technicianNameController;
  late TextEditingController _unitModelController;
  late TextEditingController _postInspectionSummaryController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;

  DateTime _repairDate = DateTime.now();
  String _condition = 'Minor';
  String _finalCondition = 'Fully Operational';
  double _totalHours = 0;

  final List<String> _conditions = ['Minor', 'Moderate', 'Critical'];
  final List<String> _finalConditions = [
    'Fully Operational',
    'Partially Operational',
    'Needs Follow-up',
    'Out of Service',
  ];

  final List<Map<String, dynamic>> _parts = [];

  @override
  void initState() {
    super.initState();
    _technicianNameController = TextEditingController(text: widget.assignedTo);
    _unitModelController = TextEditingController();
    _postInspectionSummaryController = TextEditingController();
    _startTimeController = TextEditingController();
    _endTimeController = TextEditingController();
  }

  @override
  void dispose() {
    _technicianNameController.dispose();
    _unitModelController.dispose();
    _postInspectionSummaryController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _repairDate,
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
    if (picked != null) {
      setState(() {
        _repairDate = picked;
      });
    }
  }

  void _addPart() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Part', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Part Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  setState(() {
                    _parts.add({
                      'description': nameCtrl.text,
                      'qty': int.tryParse(qtyCtrl.text) ?? 1,
                    });
                  });
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4169E1)),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _calculateHours() {
    final startParts = _startTimeController.text.split(':');
    final endParts = _endTimeController.text.split(':');
    if (startParts.length == 2 && endParts.length == 2) {
      final startHour = int.tryParse(startParts[0]) ?? 0;
      final startMin = int.tryParse(startParts[1]) ?? 0;
      final endHour = int.tryParse(endParts[0]) ?? 0;
      final endMin = int.tryParse(endParts[1]) ?? 0;
      final totalMinutes = (endHour * 60 + endMin) - (startHour * 60 + startMin);
      if (totalMinutes > 0) {
        setState(() => _totalHours = totalMinutes / 60.0);
      }
    }
  }

  void _submitReport() {
    if (_formKey.currentState!.validate()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PostInspectionSuccessPage(
            workOrderId: widget.workOrderId,
            inspectedBy: _technicianNameController.text,
            finalCondition: _finalCondition,
          ),
        ),
      );
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Post-Inspection Report',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF4169E1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PSU-MED-01',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // INSPECTION DETAILS
            _buildSectionHeader('INSPECTION DETAILS'),
            const SizedBox(height: 12),

            // Date of Repair
            _buildLabel('Date of Repair'),
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
                      '${_repairDate.month.toString().padLeft(2, '0')}/${_repairDate.day.toString().padLeft(2, '0')}/${_repairDate.year}',
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Technician Name
            _buildLabel('Technician Name'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _technicianNameController,
              hint: 'e.g. Alex Rivera [Tech ID-8834]',
              icon: Icons.person_outline,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Unit Model
            _buildLabel('Unit Model'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _unitModelController,
              hint: 'e.g. CARRIER 50XC-040',
              icon: Icons.precision_manufacturing_outlined,
            ),
            const SizedBox(height: 16),

            // Condition
            _buildLabel('Condition'),
            const SizedBox(height: 12),
            Row(
              children: _conditions.map((c) {
                final isSelected = _condition == c;
                Color condColor = c == 'Critical'
                    ? Colors.red
                    : c == 'Moderate'
                        ? Colors.orange
                        : Colors.blue;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _condition = c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? condColor : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? Colors.transparent : Colors.grey.shade300,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            c,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // INSPECTION FINDINGS
            _buildSectionHeader('INSPECTION FINDINGS'),
            const SizedBox(height: 12),
            _buildLabel('Post-Inspection Summary'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _postInspectionSummaryController,
              hint: 'Describe findings after repair/service...',
              icon: Icons.description_outlined,
              maxLines: 4,
              validator: (v) => (v == null || v.isEmpty) ? 'Summary is required' : null,
            ),
            const SizedBox(height: 24),

            // PARTS & MATERIALS
            _buildSectionHeader('PARTS & MATERIALS'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 3,
                          child: Text(
                            'Part Description',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
                          ),
                        ),
                        const SizedBox(
                          width: 60,
                          child: Text(
                            'Qty',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
                          ),
                        ),
                        const SizedBox(width: 32),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (_parts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No parts added yet',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ),
                    ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _parts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                _parts[index]['description'],
                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                '${_parts[index]['qty']}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.red),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _parts.removeAt(index)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  InkWell(
                    onTap: _addPart,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add, size: 16, color: Color(0xFF4169E1)),
                          SizedBox(width: 6),
                          Text(
                            'Add Part',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4169E1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // TIME TRACKING
            _buildSectionHeader('TIME TRACKING'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Start Time'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _startTimeController,
                        hint: '08:00',
                        icon: Icons.access_time,
                        onChanged: (_) => _calculateHours(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('End Time'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _endTimeController,
                        hint: '10:30',
                        icon: Icons.access_time_filled_outlined,
                        onChanged: (_) => _calculateHours(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF4169E1).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF4169E1).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 20, color: Color(0xFF4169E1)),
                  const SizedBox(width: 10),
                  const Text(
                    'Total Hours:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                  ),
                  const Spacer(),
                  Text(
                    '${_totalHours.toStringAsFixed(1)} Hours',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4169E1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // FINAL CONDITION VERIFICATION
            _buildSectionHeader('FINAL CONDITION VERIFICATION'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _finalCondition,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  items: _finalConditions.map((String fc) {
                    return DropdownMenuItem<String>(
                      value: fc,
                      child: Text(fc),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _finalCondition = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // POST-REPAIR PHOTOS
            _buildSectionHeader('POST-REPAIR PHOTOS'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildPhotoSlot()),
                const SizedBox(width: 12),
                Expanded(child: _buildPhotoSlot()),
              ],
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A2E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Submit Inspection Report',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18),
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

  Widget _buildPhotoSlot() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add_photo_alternate_outlined, size: 28, color: Colors.grey[500]),
          ),
          const SizedBox(height: 6),
          Text(
            'Add Photo',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
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
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
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

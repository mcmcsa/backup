import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../shared/models/cost_tracking_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/cost_tracking_service.dart';
import '../shared/admin_styles.dart';

class AdminCostTrackingForm extends StatefulWidget {
  final WorkRequest workRequest;
  final WorkRequestCost? existingCost;

  const AdminCostTrackingForm({
    super.key,
    required this.workRequest,
    this.existingCost,
  });

  @override
  State<AdminCostTrackingForm> createState() => _AdminCostTrackingFormState();
}

class _AdminCostTrackingFormState extends State<AdminCostTrackingForm> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _estLaborCtrl;
  late TextEditingController _estMaterialCtrl;
  late TextEditingController _actLaborCtrl;
  late TextEditingController _actMaterialCtrl;
  late TextEditingController _additionalCtrl;
  late TextEditingController _budgetSourceCtrl;
  late TextEditingController _purchaseRefCtrl;

  bool _isSaving = false;
  Uint8List? _selectedReceiptBytes;
  String? _selectedReceiptName;
  String? _existingReceiptUrl;

  @override
  void initState() {
    super.initState();
    final cost = widget.existingCost;
    _estLaborCtrl = TextEditingController(text: cost?.estimatedLaborCost.toString() ?? '0.0');
    _estMaterialCtrl = TextEditingController(text: cost?.estimatedMaterialCost.toString() ?? '0.0');
    _actLaborCtrl = TextEditingController(text: cost?.actualLaborCost.toString() ?? '0.0');
    _actMaterialCtrl = TextEditingController(text: cost?.actualMaterialCost.toString() ?? '0.0');
    _additionalCtrl = TextEditingController(text: cost?.additionalExpenses.toString() ?? '0.0');
    _budgetSourceCtrl = TextEditingController(text: cost?.budgetSource ?? '');
    _purchaseRefCtrl = TextEditingController(text: cost?.purchaseReferenceNumber ?? '');
    _existingReceiptUrl = cost?.receiptAttachmentUrl;
  }

  @override
  void dispose() {
    _estLaborCtrl.dispose();
    _estMaterialCtrl.dispose();
    _actLaborCtrl.dispose();
    _actMaterialCtrl.dispose();
    _additionalCtrl.dispose();
    _budgetSourceCtrl.dispose();
    _purchaseRefCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _selectedReceiptBytes = result.files.single.bytes;
        _selectedReceiptName = result.files.single.name;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      String? receiptUrl = _existingReceiptUrl;
      if (_selectedReceiptBytes != null && _selectedReceiptName != null) {
        final ext = '.${_selectedReceiptName!.split('.').last}';
        receiptUrl = await CostTrackingService.uploadReceiptBytes(widget.workRequest.id, _selectedReceiptBytes!, ext);
      }

      final cost = WorkRequestCost(
        id: widget.existingCost?.id ?? '',
        workRequestId: widget.workRequest.id,
        estimatedLaborCost: double.tryParse(_estLaborCtrl.text) ?? 0.0,
        estimatedMaterialCost: double.tryParse(_estMaterialCtrl.text) ?? 0.0,
        actualLaborCost: double.tryParse(_actLaborCtrl.text) ?? 0.0,
        actualMaterialCost: double.tryParse(_actMaterialCtrl.text) ?? 0.0,
        additionalExpenses: double.tryParse(_additionalCtrl.text) ?? 0.0,
        budgetSource: _budgetSourceCtrl.text.trim(),
        purchaseReferenceNumber: _purchaseRefCtrl.text.trim(),
        receiptAttachmentUrl: receiptUrl,
        createdAt: widget.existingCost?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await CostTrackingService.upsert(cost);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Financial data saved successfully.'), backgroundColor: AdminStyles.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: AdminStyles.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('Manage Financials', style: AdminStyles.headingStyle(fontSize: 22, color: AdminStyles.textPrimary)),
              const SizedBox(height: 8),
              Text('Record estimated and actual costs for this request.', style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildTextField('Estimated Labor', _estLaborCtrl, isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('Estimated Material', _estMaterialCtrl, isNumber: true)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField('Actual Labor', _actLaborCtrl, isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('Actual Material', _actMaterialCtrl, isNumber: true)),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField('Additional Expenses', _additionalCtrl, isNumber: true),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFF1F5F9)),
              const SizedBox(height: 16),
              _buildTextField('Budget Source', _budgetSourceCtrl),
              const SizedBox(height: 16),
              _buildTextField('Purchase Reference Number', _purchaseRefCtrl),
              const SizedBox(height: 24),
              Text('Receipt Attachment', style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600, color: AdminStyles.textPrimary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickReceipt,
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Upload Receipt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminStyles.bg,
                      foregroundColor: AdminStyles.textPrimary,
                      elevation: 0,
                      side: const BorderSide(color: AdminStyles.border),
                    ),
                  ),
                  const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _selectedReceiptName ?? (_existingReceiptUrl != null ? 'Receipt currently uploaded' : 'No file selected'),
                        style: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: AdminStyles.textMuted)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminStyles.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Costs'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminStyles.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          validator: isNumber
              ? (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (double.tryParse(val) == null) return 'Must be a valid number';
                  return null;
                }
              : null,
          decoration: InputDecoration(
            isDense: true,
            prefixText: isNumber ? '₱ ' : null,
            prefixStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminStyles.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminStyles.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminStyles.primary)),
          ),
        ),
      ],
    );
  }
}

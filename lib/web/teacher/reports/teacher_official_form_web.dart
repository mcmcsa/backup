import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/iso_pdf_service.dart';
import '../../admin/shared/admin_styles.dart';

class TeacherOfficialFormWeb extends StatefulWidget {
  final WorkRequest request;

  const TeacherOfficialFormWeb({super.key, required this.request});

  @override
  State<TeacherOfficialFormWeb> createState() => _TeacherOfficialFormWebState();
}

class _TeacherOfficialFormWebState extends State<TeacherOfficialFormWeb> {
  List<ESignature> _signatures = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSignatures();
  }

  Future<void> _loadSignatures() async {
    try {
      final sigs = await ESignatureService.fetchByWorkRequest(widget.request.id);
      if (mounted) {
        setState(() {
          _signatures = sigs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _printForm() async {
    try {
      final pdfBytes = await IsoPdfService.generateWorkRequestPdf(widget.request);
      await Printing.layoutPdf(onLayout: (_) => pdfBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing form: $e'), backgroundColor: AdminStyles.error),
        );
      }
    }
  }

  Widget _buildCheckline(String label, bool isChecked, String underlineText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const SizedBox(width: 80), // Indent like the form
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: isChecked
                ? const Center(
                    child: Text(
                      'X',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              alignment: Alignment.bottomLeft,
              children: [
                Container(
                  height: 18,
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 2),
                  child: Text(
                    isChecked ? underlineText : '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildSignatureColumn(String role, String headerLabel, String footerLabel, {String? dateLabel, DateTime? dateVal, String? extraLabel, String? extraVal}) {
    final sig = _signatures.where((s) {
      if (role == 'requestor') return s.signerRole == 'teacher' || s.signerRole == 'faculty' || s.signerRole == 'requestor';
      if (role == 'admin') return s.signerRole == 'admin' || s.signerRole == 'approver';
      if (role == 'accomplished') return s.signerRole == 'maintenance' || s.signerRole == 'technician';
      return false;
    }).firstOrNull;

    Uint8List? sigBytes;
    if (sig != null && sig.signatureData.isNotEmpty) {
      try {
        final cleanBase64 = sig.signatureData.contains(',')
            ? sig.signatureData.split(',').last
            : sig.signatureData;
        sigBytes = base64Decode(cleanBase64.trim());
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headerLabel,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                if (sigBytes != null)
                  Positioned(
                    bottom: 2,
                    child: Container(
                      height: 55,
                      padding: const EdgeInsets.all(2),
                      child: Image.memory(
                        sigBytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      sig?.signerName ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Container(
                      height: 1.5,
                      color: Colors.black,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      footerLabel,
                      style: const TextStyle(
                        fontSize: 9,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (dateLabel != null)
            Row(
              children: [
                Text(
                  '$dateLabel: ',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 2),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
                    ),
                    child: Text(
                      dateVal != null ? DateFormat('dd-MMM-yyyy').format(dateVal) : '',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (extraLabel != null)
            Row(
              children: [
                Text(
                  '$extraLabel: ',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 2),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
                    ),
                    child: Text(
                      extraVal ?? '',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final typeLower = request.typeOfRequest.toLowerCase();
    
    final isOcular = typeLower.contains('ocular') || typeLower.contains('inspection');
    final isInstall = typeLower.contains('installation') || typeLower.contains('install');
    final isRepair = typeLower.contains('repair');
    final isReplace = typeLower.contains('replacement') || typeLower.contains('replace');
    final isOthers = !isOcular && !isInstall && !isRepair && !isReplace;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 850),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Toolbar header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded, color: Color(0xFF00BFA5), size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Official Work Request Form Preview (ISO Standard)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _printForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Print / Save PDF'),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // The sheet container
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BFA5)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: FittedBox(
                          child: Container(
                            width: 1000,
                            height: 680,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ROW 1: Header Row (Logo, Title, ISO Code)
                                Container(
                                  height: 90,
                                  decoration: const BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Logo cell
                                      Container(
                                        width: 140,
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(
                                          border: Border(right: BorderSide(color: Colors.black, width: 2)),
                                        ),
                                        child: Image.asset(
                                          'assets/images/PsuLogo.png',
                                          width: 68,
                                          height: 68,
                                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.school, size: 48, color: Colors.black),
                                        ),
                                      ),
                                      // Title cell
                                      Expanded(
                                        child: Container(
                                          alignment: Alignment.center,
                                          decoration: const BoxDecoration(
                                            border: Border(right: BorderSide(color: Colors.black, width: 2)),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: const [
                                              Text(
                                                'WORK REQUEST FORM',
                                                style: TextStyle(
                                                  fontFamily: 'Courier',
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'PANGASINAN STATE UNIVERSITY',
                                                style: TextStyle(
                                                  fontFamily: 'Courier',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // ISO cell
                                      Container(
                                        width: 180,
                                        padding: const EdgeInsets.all(12),
                                        alignment: Alignment.centerRight,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Text('FM-AD-ENG-02', style: TextStyle(fontFamily: 'Courier', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                                            Text('Rev. 0', style: TextStyle(fontFamily: 'Courier', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                                            Text('03-Oct-2017', style: TextStyle(fontFamily: 'Courier', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // ROW 2: Date Row
                                Container(
                                  height: 38,
                                  decoration: const BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 12),
                                      const Text('DATE :', style: TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                                      const SizedBox(width: 12),
                                      Text(
                                        DateFormat('dd-MMM-yyyy').format(request.createdAt ?? request.dateSubmitted),
                                        style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '20${DateFormat('yy - MM - dd').format(request.createdAt ?? request.dateSubmitted)}',
                                        style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                                      ),
                                      const SizedBox(width: 40),
                                    ],
                                  ),
                                ),
                                // ROW 3: Campus & Department Row
                                Container(
                                  height: 38,
                                  decoration: const BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Campus cell
                                      Expanded(
                                        flex: 6,
                                        child: Container(
                                          alignment: Alignment.centerLeft,
                                          padding: const EdgeInsets.only(left: 12),
                                          decoration: const BoxDecoration(
                                            border: Border(right: BorderSide(color: Colors.black, width: 2)),
                                          ),
                                          child: const Text(
                                            'CAMPUS : SAN CARLOS CITY',
                                            style: TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                                          ),
                                        ),
                                      ),
                                      // Department cell
                                      Expanded(
                                        flex: 5,
                                        child: Container(
                                          alignment: Alignment.centerLeft,
                                          padding: const EdgeInsets.only(left: 12),
                                          child: Text(
                                            'DEPARTMENT: ${request.departmentName ?? ""}',
                                            style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // ROW 4: Building & Room Row
                                Container(
                                  height: 38,
                                  decoration: const BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Building cell
                                      Expanded(
                                        flex: 6,
                                        child: Container(
                                          alignment: Alignment.centerLeft,
                                          padding: const EdgeInsets.only(left: 12),
                                          decoration: const BoxDecoration(
                                            border: Border(right: BorderSide(color: Colors.black, width: 2)),
                                          ),
                                          child: Text(
                                            'BUILDING NAME : ${request.buildingName ?? ""}',
                                            style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                                          ),
                                        ),
                                      ),
                                      // Room cell
                                      Expanded(
                                        flex: 5,
                                        child: Container(
                                          alignment: Alignment.centerLeft,
                                          padding: const EdgeInsets.only(left: 12),
                                          child: Text(
                                            'NAME OF OFFICE / ROOM : ${request.roomName ?? ""}',
                                            style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // ROW 5: Work Request Details Row (Checklist)
                                Expanded(
                                  flex: 6,
                                  child: Container(
                                    padding: const EdgeInsets.only(left: 12, top: 12),
                                    decoration: const BoxDecoration(
                                      border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'WORK REQUEST :',
                                          style: TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                                        ),
                                        const SizedBox(height: 12),
                                        _buildCheckline('Ocular inspection of', isOcular, request.description),
                                        _buildCheckline('Installation of', isInstall, request.description),
                                        _buildCheckline('Repair of', isRepair, request.description),
                                        _buildCheckline('Replacement of', isReplace, request.description),
                                        _buildCheckline('Others (specify)', isOthers, request.typeOfRequest),
                                      ],
                                    ),
                                  ),
                                ),
                                // ROW 6: Footer Signatures Row
                                Expanded(
                                  flex: 5,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Requestor Column
                                      Expanded(
                                        flex: 6,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            border: Border(right: BorderSide(color: Colors.black, width: 2)),
                                          ),
                                          child: _buildSignatureColumn(
                                            'requestor',
                                            'Requestor :',
                                            'Signature over Printed Name',
                                            extraLabel: 'Position / Designation',
                                            extraVal: request.requestorPosition,
                                          ),
                                        ),
                                      ),
                                      // Approved by Column
                                      Expanded(
                                        flex: 5,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            border: Border(right: BorderSide(color: Colors.black, width: 2)),
                                          ),
                                          child: _buildSignatureColumn(
                                            'admin',
                                            'Approved by :',
                                            'Signature over Printed Name',
                                            dateLabel: 'Date',
                                            dateVal: request.approvedDate,
                                          ),
                                        ),
                                      ),
                                      // Accomplished by Column
                                      Expanded(
                                        flex: 5,
                                        child: _buildSignatureColumn(
                                          'accomplished',
                                          'Work Request Accomplished by:',
                                          'Signature over Printed Name',
                                          dateLabel: 'Date',
                                          dateVal: request.dateCompleted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
}

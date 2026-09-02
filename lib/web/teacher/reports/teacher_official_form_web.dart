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

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/work_request_service.dart';

class TeacherOfficialFormWeb extends StatefulWidget {
  final WorkRequest request;

  const TeacherOfficialFormWeb({super.key, required this.request});

  @override
  State<TeacherOfficialFormWeb> createState() => _TeacherOfficialFormWebState();
}

class _TeacherOfficialFormWebState extends State<TeacherOfficialFormWeb> {
  late WorkRequest _currentRequest;
  List<ESignature> _signatures = [];
  bool _isLoading = true;
  int _selectedPage = 0; // 0: Work Request Form, 1: Confirmation Form
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
    _loadData();
    _setupRealtime();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    final reqId = widget.request.id;
    _realtimeChannel = Supabase.instance.client
        .channel('public:official_form_$reqId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'work_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: reqId,
          ),
          callback: (_) => _loadData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'e_signatures',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'work_request_id',
            value: reqId,
          ),
          callback: (_) => _loadData(),
        )
        .subscribe();
  }

  Future<void> _loadData() async {
    try {
      final updated = await WorkRequestService.fetchById(widget.request.id);
      final sigs = await ESignatureService.fetchByWorkRequest(widget.request.id);
      if (mounted) {
        setState(() {
          if (updated != null) {
            _currentRequest = updated;
          }
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
      final pdfBytes = await IsoPdfService.generateWorkRequestPdf(_currentRequest);
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'Work_Request_Forms_${_currentRequest.formattedId}',
        format: IsoPdfService.longLandscapeFormat,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing form: $e'), backgroundColor: AdminStyles.error),
        );
      }
    }
  }

  void _savePdfFile() async {
    try {
      final pdfBytes = await IsoPdfService.generateWorkRequestPdf(_currentRequest);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Work_Request_Forms_${_currentRequest.formattedId}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PDF file: $e'), backgroundColor: AdminStyles.error),
        );
      }
    }
  }

  Widget _buildSignatureColumn(
    String roleKey,
    String headerLabel,
    String footerLabel, {
    String? extraLabel,
    String? extraVal,
    String? dateLabel,
    DateTime? dateVal,
  }) {
    final request = _currentRequest;
    
    ESignature? sig;
    String printName = '';
    
    if (roleKey == 'requestor') {
      sig = _signatures.where((s) =>
        s.signerRole.toLowerCase() == 'teacher' ||
        s.signerRole.toLowerCase() == 'faculty' ||
        s.signerRole.toLowerCase() == 'requestor' ||
        s.signatureType.toLowerCase() == 'requestor'
      ).firstOrNull;
      printName = sig?.signerName ?? request.requestorName;
    } else if (roleKey == 'admin') {
      sig = _signatures.where((s) =>
        (s.signerRole.toLowerCase() == 'admin' || s.signerRole.toLowerCase() == 'campadmin') &&
        (s.signatureType.toLowerCase() == 'approval' || s.signatureType.toLowerCase() == 'admin')
      ).firstOrNull;
      printName = sig?.signerName ?? request.approvedByName ?? '';
    } else if (roleKey == 'accomplished') {
      sig = _signatures.where((s) {
        final role = s.signerRole.toLowerCase();
        final type = s.signatureType.toLowerCase();
        return (role == 'maintenance' || role == 'technician' || role == 'staff') ||
               (type == 'completion' || type == 'accomplished' || type == 'post_repair' || type == 'pre_inspection');
      }).firstOrNull;
      printName = sig?.signerName ?? request.acceptedByName ?? '';
    }

    final effectiveDate = dateVal ?? sig?.signedAt ?? (roleKey == 'accomplished' ? (request.dateCompleted ?? request.maintenanceEndTime ?? request.acceptedDate) : null);

    Uint8List? bytes;
    if (sig != null && sig.signatureData.isNotEmpty) {
      try {
        final cleanBase64 = sig.signatureData.contains(',')
            ? sig.signatureData.split(',').last
            : sig.signatureData;
        bytes = base64Decode(cleanBase64.trim());
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            headerLabel,
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 30,
                  alignment: Alignment.bottomCenter,
                  child: bytes != null
                      ? Image.memory(bytes, fit: BoxFit.contain)
                      : const SizedBox(),
                ),
                const SizedBox(height: 2),
                Text(
                  printName.isNotEmpty ? printName : ' ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 165,
                  height: 1.5,
                  color: Colors.black,
                ),
                const SizedBox(height: 2),
                Text(
                  footerLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 8,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          if (dateLabel != null)
            Row(
              children: [
                Text(
                  '$dateLabel: ',
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 1),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
                    ),
                    child: Text(
                      effectiveDate != null ? DateFormat('dd-MMM-yyyy').format(effectiveDate) : '',
                      style: const TextStyle(
                        fontSize: 10,
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
                    fontSize: 10,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 1),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
                    ),
                    child: Text(
                      extraVal ?? '',
                      style: const TextStyle(
                        fontSize: 10,
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

  Widget _buildCheckline(String label, bool isChecked, String underlineText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1.5),
            ),
            child: isChecked
                ? const Center(
                    child: Text(
                      'X',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 175,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'Courier',
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(bottom: 2),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
              ),
              child: Text(
                isChecked ? underlineText : '',
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
    );
  }

  Widget _buildWorkRequestForm(WorkRequest request, bool isOcular, bool isInstall, bool isRepair, bool isReplace, bool isOthers, String specifyVal) {
    return Container(
      width: 1040,
      height: 650,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 620,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCheckline('Ocular inspection of', isOcular, specifyVal),
                            _buildCheckline('Installation of', isInstall, specifyVal),
                            _buildCheckline('Repair of', isRepair, specifyVal),
                            _buildCheckline('Replacement of', isReplace, specifyVal),
                            _buildCheckline('Others (specify)', isOthers, specifyVal),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ROW 6: Footer Signatures Row
          Expanded(
            flex: 4,
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
                      extraVal: request.requestorPosition.trim().isNotEmpty
                          ? request.requestorPosition
                          : 'Faculty Member / Requestor',
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
    );
  }

  Widget _buildConfirmationForm(WorkRequest request, bool isOcular, bool isInstall, bool isRepair, bool isReplace, bool isOthers, String specifyVal) {
    return Container(
      width: 1040,
      height: 650,
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
          // ROW 1: Header Row
          Container(
            height: 90,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'CONFIRM WORK REQUEST FORM',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'PANGASINAN STATE UNIVERSITY',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Office of the Physical Plant and Facilities',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
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
                  DateFormat('dd-MMM-yyyy').format(request.dateCompleted ?? request.createdAt ?? request.dateSubmitted),
                  style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const Spacer(),
                Text(
                  '20${DateFormat('yy - MM - dd').format(request.dateCompleted ?? request.createdAt ?? request.dateSubmitted)}',
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 620,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCheckline('Ocular inspection of', isOcular, specifyVal),
                            _buildCheckline('Installation of', isInstall, specifyVal),
                            _buildCheckline('Repair of', isRepair, specifyVal),
                            _buildCheckline('Replacement of', isReplace, specifyVal),
                            _buildCheckline('Others (specify)', isOthers, specifyVal),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ROW 6: Footer Signatures Row
          Expanded(
            flex: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.black, width: 2)),
                    ),
                    child: _buildSignatureColumn(
                      'accomplished',
                      'Work Request Accomplished by:',
                      'Signature over Printed Name',
                      dateLabel: 'Date',
                      dateVal: request.dateCompleted,
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.black, width: 2)),
                    ),
                    child: _buildSignatureColumn(
                      'requestor',
                      'Requestor:',
                      'Signature over Printed Name',
                      extraLabel: 'Position / Designation',
                      extraVal: request.requestorPosition.trim().isNotEmpty
                          ? request.requestorPosition
                          : 'Faculty Member / Requestor',
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: _buildSignatureColumn(
                    'admin',
                    'Monitored and Evaluated by:',
                    'Signature over Printed Name',
                    dateLabel: 'Date',
                    dateVal: request.approvedDate ?? request.dateCompleted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = _currentRequest;
    final typeLower = (request.typeOfRequest + ' ' + request.title).toLowerCase();
    bool isOcular = typeLower.contains('ocular') || typeLower.contains('inspection');
    bool isInstall = typeLower.contains('installation') || typeLower.contains('install');
    bool isRepair = typeLower.contains('repair') || typeLower.contains('fix');
    bool isReplace = typeLower.contains('replacement') || typeLower.contains('replace');

    if (typeLower.startsWith('ocular') || typeLower.startsWith('inspection')) {
      isOcular = true; isInstall = false; isRepair = false; isReplace = false;
    } else if (typeLower.startsWith('installation') || typeLower.startsWith('install')) {
      isInstall = true; isOcular = false; isRepair = false; isReplace = false;
    } else if (typeLower.startsWith('repair') || typeLower.startsWith('fix')) {
      isRepair = true; isOcular = false; isInstall = false; isReplace = false;
    } else if (typeLower.startsWith('replacement') || typeLower.startsWith('replace')) {
      isReplace = true; isOcular = false; isInstall = false; isReplace = false;
    }

    final isOthers = !isOcular && !isInstall && !isRepair && !isReplace;

    String specifyVal = request.specifyText.trim();
    if (specifyVal.isEmpty && request.typeOfRequest.contains(':')) {
      specifyVal = request.typeOfRequest.split(':').last.trim();
    }
    if (specifyVal.isEmpty) {
      specifyVal = request.description.trim();
    }
    if (specifyVal.isEmpty) {
      specifyVal = request.title.trim();
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1150, maxHeight: 850),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _selectedPage = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedPage == 0 ? const Color(0xFF00BFA5) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '1. Work Request Form',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => setState(() => _selectedPage = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedPage == 1 ? const Color(0xFF00BFA5) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '2. Confirm Form',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _savePdfFile,
                    icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                    label: const Text('Save / Download PDF File', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF00BFA5), width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _printForm,
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Print Form', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
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
                          child: _selectedPage == 0
                              ? _buildWorkRequestForm(request, isOcular, isInstall, isRepair, isReplace, isOthers, specifyVal)
                              : _buildConfirmationForm(request, isOcular, isInstall, isRepair, isReplace, isOthers, specifyVal),
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

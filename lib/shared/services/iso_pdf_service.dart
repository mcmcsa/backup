import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/work_request_model.dart';
import 'e_signature_service.dart';

class IsoPdfService {
  // Universal Standard Landscape (11.0" x 8.5")
  // Compatible with Letter, A4, and Long Bond Paper in Chrome Print & saved PDF
  static final longLandscapeFormat = PdfPageFormat(
    11.0 * PdfPageFormat.inch, // 792 pt
    8.5 * PdfPageFormat.inch,  // 612 pt
    marginTop: 20,
    marginBottom: 20,
    marginLeft: 20,
    marginRight: 20,
  );

  static Future<Uint8List> generateWorkRequestPdf(WorkRequest request) async {
    final pdf = pw.Document();

    // Load assets
    final psuLogoData = await rootBundle.load('assets/images/PsuLogo.png');
    final psuLogo = pw.MemoryImage(psuLogoData.buffer.asUint8List());

    // Fetch signatures
    final signatures = await ESignatureService.fetchByWorkRequest(request.id);
    
    final requesterSig = signatures.where((s) {
      final role = s.signerRole.toLowerCase();
      final type = s.signatureType.toLowerCase();
      return (role == 'teacher' || role == 'faculty' || role == 'requestor') ||
             (type == 'requestor' || type == 'approval' || type == 'submission');
    }).firstOrNull;

    final adminSig = signatures.where((s) =>
        (s.signerRole.toLowerCase() == 'admin' || s.signerRole.toLowerCase() == 'campadmin') &&
        (s.signatureType.toLowerCase() == 'approval' || s.signatureType.toLowerCase() == 'admin')
    ).firstOrNull;

    final completionSig = signatures.where((s) {
      final role = s.signerRole.toLowerCase();
      final type = s.signatureType.toLowerCase();
      return (role == 'maintenance' || role == 'technician' || role == 'staff' || role == 'admin') ||
             (type == 'completion' || type == 'accomplished');
    }).firstOrNull;

    pw.MemoryImage? decodeSignature(String? base64Str) {
      if (base64Str == null || base64Str.isEmpty) return null;
      try {
        final cleanBase64 = base64Str.contains(',')
            ? base64Str.split(',').last
            : base64Str;
        final bytes = base64Decode(cleanBase64.trim());
        return pw.MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }

    final requesterSigImage = decodeSignature(requesterSig?.signatureData);
    final adminSigImage = decodeSignature(adminSig?.signatureData);
    final completionSigImage = decodeSignature(completionSig?.signatureData);

    final fontCourierBold = pw.Font.courierBold();

    final typeLower = request.typeOfRequest.toLowerCase();
    final isOcular = typeLower.contains('ocular') || typeLower.contains('inspection');
    final isInstall = typeLower.contains('installation') || typeLower.contains('install');
    final isRepair = typeLower.contains('repair');
    final isReplace = typeLower.contains('replacement') || typeLower.contains('replace');
    final isOthers = !isOcular && !isInstall && !isRepair && !isReplace;

    pw.Widget buildCheckline(String label, bool isChecked, String underlineText) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 14,
              height: 14,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
              ),
              child: isChecked
                  ? pw.Center(
                      child: pw.Text(
                        'X',
                        style: pw.TextStyle(
                          font: fontCourierBold,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
            pw.SizedBox(width: 8),
            pw.SizedBox(
              width: 145,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  font: fontCourierBold,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Container(
                height: 16,
                padding: const pw.EdgeInsets.only(left: 4),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                ),
                child: pw.Text(
                  isChecked ? underlineText : '',
                  style: pw.TextStyle(
                    font: fontCourierBold,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget buildSignatureColumn({
      required String headerLabel,
      required String footerLabel,
      required String signerName,
      required pw.MemoryImage? sigImage,
      String? dateLabel,
      DateTime? dateVal,
      String? extraLabel,
      String? extraVal,
    }) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              headerLabel,
              style: pw.TextStyle(
                font: fontCourierBold,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Center(
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Container(
                    height: 35,
                    alignment: pw.Alignment.bottomCenter,
                    child: sigImage != null
                        ? pw.Image(sigImage, fit: pw.BoxFit.contain)
                        : pw.SizedBox(),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    signerName.isNotEmpty ? signerName : ' ',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: fontCourierBold,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Container(
                    width: 170,
                    height: 1.5,
                    color: PdfColors.black,
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    footerLabel,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: fontCourierBold,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (extraLabel != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Row(
                  children: [
                    pw.Text(
                      '$extraLabel: ',
                      style: pw.TextStyle(
                        font: fontCourierBold,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.only(bottom: 1),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
                        ),
                        child: pw.Text(
                          extraVal ?? '',
                          style: pw.TextStyle(
                            font: fontCourierBold,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (dateLabel != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Row(
                  children: [
                    pw.Text(
                      '$dateLabel: ',
                      style: pw.TextStyle(
                        font: fontCourierBold,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.only(bottom: 1),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
                        ),
                        child: pw.Text(
                          dateVal != null ? DateFormat('dd-MMM-yyyy').format(dateVal) : '',
                          style: pw.TextStyle(
                            font: fontCourierBold,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: longLandscapeFormat,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ROW 1: Header Row (Logo, Title, ISO Code)
                pw.Container(
                  height: 80,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 2)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Logo cell
                      pw.Container(
                        width: 140,
                        alignment: pw.Alignment.center,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 2)),
                        ),
                        child: pw.Image(psuLogo, width: 64, height: 64),
                      ),
                      // Title cell
                      pw.Expanded(
                        child: pw.Container(
                          alignment: pw.Alignment.center,
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 2)),
                          ),
                          child: pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text(
                                'WORK REQUEST FORM',
                                style: pw.TextStyle(
                                  font: fontCourierBold,
                                  fontSize: 24,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'PANGASINAN STATE UNIVERSITY',
                                style: pw.TextStyle(
                                  font: fontCourierBold,
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ISO cell
                      pw.Container(
                        width: 170,
                        padding: const pw.EdgeInsets.all(10),
                        alignment: pw.Alignment.centerRight,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text('FM-AD-ENG-02', style: pw.TextStyle(font: fontCourierBold, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Rev. 0', style: pw.TextStyle(font: fontCourierBold, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.Text('03-Oct-2017', style: pw.TextStyle(font: fontCourierBold, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // ROW 2: Date Row
                pw.Container(
                  height: 34,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 2)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.SizedBox(width: 12),
                      pw.Text('DATE :', style: pw.TextStyle(font: fontCourierBold, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(width: 12),
                      pw.Text(
                        DateFormat('dd-MMM-yyyy').format(request.createdAt ?? request.dateSubmitted),
                        style: pw.TextStyle(font: fontCourierBold, fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Expanded(child: pw.SizedBox()),
                      pw.Text(
                        '20${DateFormat('yy - MM - dd').format(request.createdAt ?? request.dateSubmitted)}',
                        style: pw.TextStyle(font: fontCourierBold, fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(width: 40),
                    ],
                  ),
                ),
                // ROW 3: Campus & Department Row
                pw.Container(
                  height: 34,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 2)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Campus cell
                      pw.Expanded(
                        flex: 6,
                        child: pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.only(left: 12),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 2)),
                          ),
                          child: pw.Text(
                            'CAMPUS : SAN CARLOS CITY',
                            style: pw.TextStyle(font: fontCourierBold, fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ),
                      // Department cell
                      pw.Expanded(
                        flex: 5,
                        child: pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.only(left: 12),
                          child: pw.Text(
                            'DEPARTMENT: ${request.departmentName ?? ""}',
                            style: pw.TextStyle(font: fontCourierBold, fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ROW 4: Building & Room Row
                pw.Container(
                  height: 34,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 2)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Building cell
                      pw.Expanded(
                        flex: 6,
                        child: pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.only(left: 12),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 2)),
                          ),
                          child: pw.Text(
                            'BUILDING NAME : ${request.buildingName ?? ""}',
                            style: pw.TextStyle(font: fontCourierBold, fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ),
                      // Room cell
                      pw.Expanded(
                        flex: 5,
                        child: pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.only(left: 12),
                          child: pw.Text(
                            'NAME OF OFFICE / ROOM : ${request.roomName ?? ""}',
                            style: pw.TextStyle(font: fontCourierBold, fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ROW 5: Work Request Details Row (Checklist)
                pw.Container(
                  height: 150,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 2)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'WORK REQUEST :',
                        style: pw.TextStyle(font: fontCourierBold, fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Expanded(
                        child: pw.Center(
                          child: pw.SizedBox(
                            width: 520,
                            child: pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                              children: [
                                buildCheckline('Ocular inspection of', isOcular, request.description),
                                buildCheckline('Installation of', isInstall, request.description),
                                buildCheckline('Repair of', isRepair, request.description),
                                buildCheckline('Replacement of', isReplace, request.description),
                                buildCheckline('Others (specify)', isOthers, request.typeOfRequest),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ROW 6: Footer Signatures Row
                pw.Container(
                  height: 125,
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Requestor Column
                      pw.Expanded(
                        flex: 6,
                        child: pw.Container(
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 2)),
                          ),
                          child: buildSignatureColumn(
                            headerLabel: 'Requestor :',
                            footerLabel: 'Signature over Printed Name',
                            signerName: requesterSig?.signerName ?? request.requestorName,
                            sigImage: requesterSigImage,
                            extraLabel: 'Position / Designation',
                            extraVal: request.requestorPosition,
                          ),
                        ),
                      ),
                      // Approved by Column
                      pw.Expanded(
                        flex: 5,
                        child: pw.Container(
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 2)),
                          ),
                          child: buildSignatureColumn(
                            headerLabel: 'Approved by :',
                            footerLabel: 'Signature over Printed Name',
                            signerName: adminSig?.signerName ?? request.approvedByName ?? '',
                            sigImage: adminSigImage,
                            dateLabel: 'Date',
                            dateVal: request.approvedDate,
                          ),
                        ),
                      ),
                      // Accomplished by Column
                      pw.Expanded(
                        flex: 5,
                        child: buildSignatureColumn(
                          headerLabel: 'Work Request Accomplished by:',
                          footerLabel: 'Signature over Printed Name',
                          signerName: completionSig?.signerName ?? request.acceptedByName ?? '',
                          sigImage: completionSigImage,
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
        },
      ),
    );

    // PAGE 2: CONFIRM WORK REQUEST FORM
    pdf.addPage(
      pw.Page(
        pageFormat: longLandscapeFormat,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ROW 1: Header Row
                pw.Container(
                  height: 80,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 2)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Logo cell
                      pw.Container(
                        width: 140,
                        alignment: pw.Alignment.center,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 2)),
                        ),
                        child: pw.Image(psuLogo, width: 64, height: 64),
                      ),
                      // Title cell
                      pw.Expanded(
                        child: pw.Container(
                          alignment: pw.Alignment.center,
                          child: pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text(
                                'CONFIRM WORK REQUEST FORM',
                                style: pw.TextStyle(
                                  font: fontCourierBold,
                                  fontSize: 20,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                'PANGASINAN STATE UNIVERSITY',
                                style: pw.TextStyle(
                                  font: fontCourierBold,
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Office of the Physical Plant and Facilities',
                                style: pw.TextStyle(
                                  font: fontCourierBold,
                                  fontSize: 10,
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
                pw.Container(
                  height: 34,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 2)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.SizedBox(width: 12),
                      pw.Text('DATE :', style: pw.TextStyle(font: fontCourierBold, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(width: 12),
                      pw.Text(
                        DateFormat('dd-MMM-yyyy').format(request.dateCompleted ?? request.createdAt ?? request.dateSubmitted),
                        style: pw.TextStyle(font: fontCourierBold, fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Expanded(child: pw.SizedBox()),
                      pw.Text(
                        '20${DateFormat('yy - MM - dd').format(request.dateCompleted ?? request.createdAt ?? request.dateSubmitted)}',
                        style: pw.TextStyle(font: fontCourierBold, fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(width: 40),
                    ],
                  ),
                ),
                // ROW 3: Campus & Department Row
                pw.Container(
                  height: 34,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 2)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Campus cell
                      pw.Expanded(
                        flex: 6,
                        child: pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.only(left: 12),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 2)),
                          ),
                          child: pw.Text(
                            'CAMPUS : SAN CARLOS CITY',
                            style: pw.TextStyle(font: fontCourierBold, fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ),
                      // Department cell
                      pw.Expanded(
                        flex: 5,
                        child: pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.only(left: 12),
                          child: pw.Text(
                            'DEPARTMENT: ${request.departmentName ?? ""}',
                            style: pw.TextStyle(font: fontCourierBold, fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ROW 4: Building & Room Row
                pw.Container(
                  height: 34,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 2)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Building cell
                      pw.Expanded(
                        flex: 6,
                        child: pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.only(left: 12),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 2)),
                          ),
                          child: pw.Text(
                            'BUILDING NAME : ${request.buildingName ?? ""}',
                            style: pw.TextStyle(font: fontCourierBold, fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ),
                      // Room cell
                      pw.Expanded(
                        flex: 5,
                        child: pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.only(left: 12),
                          child: pw.Text(
                            'NAME OF OFFICE / ROOM : ${request.roomName ?? ""}',
                            style: pw.TextStyle(font: fontCourierBold, fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ROW 5: Work Request Details Row (Checklist)
                pw.Container(
                  height: 150,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 2)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'WORK REQUEST :',
                        style: pw.TextStyle(font: fontCourierBold, fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Expanded(
                        child: pw.Center(
                          child: pw.SizedBox(
                            width: 520,
                            child: pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                              children: [
                                buildCheckline('Ocular inspection of', isOcular, request.description),
                                buildCheckline('Installation of', isInstall, request.description),
                                buildCheckline('Repair of', isRepair, request.description),
                                buildCheckline('Replacement of', isReplace, request.description),
                                buildCheckline('Others (specify)', isOthers, request.typeOfRequest),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ROW 6: Footer Signatures Row
                pw.Container(
                  height: 125,
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Work Request Accomplished by Column
                      pw.Expanded(
                        flex: 6,
                        child: pw.Container(
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 2)),
                          ),
                          child: buildSignatureColumn(
                            headerLabel: 'Work Request Accomplished by:',
                            footerLabel: 'Signature over Printed Name',
                            signerName: completionSig?.signerName ?? request.acceptedByName ?? '',
                            sigImage: completionSigImage,
                            dateLabel: 'Date',
                            dateVal: request.dateCompleted,
                          ),
                        ),
                      ),
                      // Requestor Column (using initial submission signature)
                      pw.Expanded(
                        flex: 6,
                        child: pw.Container(
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 2)),
                          ),
                          child: buildSignatureColumn(
                            headerLabel: 'Requestor:',
                            footerLabel: 'Signature over Printed Name',
                            signerName: requesterSig?.signerName ?? request.requestorName,
                            sigImage: requesterSigImage,
                            extraLabel: 'Position / Designation',
                            extraVal: request.requestorPosition,
                          ),
                        ),
                      ),
                      // Monitored and Evaluated by Column
                      pw.Expanded(
                        flex: 6,
                        child: buildSignatureColumn(
                          headerLabel: 'Monitored and Evaluated by:',
                          footerLabel: 'Signature over Printed Name',
                          signerName: adminSig?.signerName ?? request.approvedByName ?? '',
                          sigImage: adminSigImage,
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
        },
      ),
    );

    return pdf.save();
  }
}






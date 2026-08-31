import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/work_request_model.dart';
import 'e_signature_service.dart';

class IsoPdfService {
  static Future<Uint8List> generateWorkRequestPdf(WorkRequest request) async {
    final pdf = pw.Document();

    // Load assets
    final psuLogoData = await rootBundle.load('assets/images/PsuLogo.png');
    final psuLogo = pw.MemoryImage(psuLogoData.buffer.asUint8List());

    // Fetch signatures
    final signatures = await ESignatureService.fetchByWorkRequest(request.id);
    
    final requesterSig = signatures.where((s) =>
        (s.signerRole.toLowerCase() == 'teacher' || s.signerRole.toLowerCase() == 'requester') &&
        (s.signatureType.toLowerCase() == 'approval' || s.signatureType.toLowerCase() == 'submission')
    ).firstOrNull;

    final adminSig = signatures.where((s) =>
        s.signerRole.toLowerCase() == 'admin' &&
        s.signatureType.toLowerCase() == 'approval'
    ).firstOrNull;

    final completionSig = signatures.where((s) =>
        s.signerRole.toLowerCase() == 'maintenance' &&
        s.signatureType.toLowerCase() == 'completion'
    ).firstOrNull;

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

    pw.Widget buildCheckbox(String label, bool isChecked) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: 12,
            height: 12,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1),
            ),
            child: isChecked ? pw.Center(child: pw.Text('X', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))) : null,
          ),
          pw.SizedBox(width: 4),
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        ],
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // TOP SECTION: Header
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
                  ),
                  child: pw.Row(
                    children: [
                      // Left Side (Form Details)
                      pw.Expanded(
                        flex: 6,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                children: [
                                  pw.Text('Requestor :', style: const pw.TextStyle(fontSize: 10)),
                                  pw.SizedBox(width: 8),
                                  pw.Expanded(
                                    child: pw.Container(
                                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
                                      child: pw.Text(' ${request.requestorName}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 4),
                              pw.Row(
                                children: [
                                  pw.Text('Position / Designation:', style: const pw.TextStyle(fontSize: 10)),
                                  pw.SizedBox(width: 8),
                                  pw.Expanded(
                                    child: pw.Container(
                                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
                                      child: pw.Text(' ${request.requestorPosition ?? ""}', style: const pw.TextStyle(fontSize: 10)),
                                    ),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 4),
                              pw.Center(
                                child: pw.Stack(
                                  alignment: pw.Alignment.bottomCenter,
                                  children: [
                                    if (requesterSigImage != null)
                                      pw.Container(
                                        height: 35,
                                        margin: const pw.EdgeInsets.only(bottom: 5),
                                        child: pw.Image(requesterSigImage, fit: pw.BoxFit.contain),
                                      ),
                                    pw.Column(
                                      children: [
                                        pw.Container(
                                          width: 150,
                                          height: 1,
                                          color: PdfColors.black,
                                        ),
                                        pw.SizedBox(height: 2),
                                        pw.Text('Signature over Printed Name', style: const pw.TextStyle(fontSize: 8)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Right Side (Title & Logo)
                      pw.Container(
                        width: 1,
                        color: PdfColors.black,
                      ),
                      pw.Expanded(
                        flex: 5,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('DATE :', style: const pw.TextStyle(fontSize: 10)),
                                      pw.Text('CAMPUS :', style: const pw.TextStyle(fontSize: 10)),
                                      pw.Text('BUILDING NAME :', style: const pw.TextStyle(fontSize: 10)),
                                      pw.Text('WORK REQUEST :', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                    ],
                                  ),
                                  pw.Image(psuLogo, width: 40, height: 40),
                                ],
                              ),
                              pw.SizedBox(height: 2),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.start,
                                children: [
                                  pw.SizedBox(width: 80),
                                  pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(DateFormat('dd-MMM-yyyy').format(request.createdAt ?? request.dateSubmitted), style: const pw.TextStyle(fontSize: 10)),
                                      pw.Text('SAN CARLOS CITY', style: const pw.TextStyle(fontSize: 10)),
                                      pw.Text(request.buildingName ?? '', style: const pw.TextStyle(fontSize: 10)),
                                      pw.Text(request.formattedId, style: const pw.TextStyle(fontSize: 10)),
                                    ],
                                  )
                                ]
                              ),
                              pw.SizedBox(height: 8),
                              pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      buildCheckbox('Ocular inspection of', request.typeOfRequest.toLowerCase().contains('inspection')),
                                      pw.SizedBox(height: 4),
                                      buildCheckbox('Installation of', request.typeOfRequest.toLowerCase().contains('install')),
                                      pw.SizedBox(height: 4),
                                      buildCheckbox('Repair of', request.typeOfRequest.toLowerCase().contains('repair')),
                                      pw.SizedBox(height: 4),
                                      buildCheckbox('Replacement of', request.typeOfRequest.toLowerCase().contains('replace')),
                                      pw.SizedBox(height: 4),
                                      buildCheckbox('Others (specify)', !request.typeOfRequest.toLowerCase().contains('inspection') && !request.typeOfRequest.toLowerCase().contains('install') && !request.typeOfRequest.toLowerCase().contains('repair') && !request.typeOfRequest.toLowerCase().contains('replace')),
                                    ],
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 4),
                              pw.Container(
                                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
                                width: double.infinity,
                                child: pw.Text(' ${request.title}', style: const pw.TextStyle(fontSize: 10)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // MIDDLE SECTION: Big Title
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
                  ),
                  child: pw.Row(
                    children: [
                      // Left Approval Box
                      pw.Expanded(
                        flex: 6,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                children: [
                                  pw.Text('Approved by :', style: const pw.TextStyle(fontSize: 10)),
                                  pw.SizedBox(width: 8),
                                  pw.Expanded(
                                    child: pw.Container(
                                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
                                      child: pw.Text(' ${request.approvedByName ?? ""}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 4),
                              pw.Center(
                                child: pw.Stack(
                                  alignment: pw.Alignment.bottomCenter,
                                  children: [
                                    if (adminSigImage != null)
                                      pw.Container(
                                        height: 35,
                                        margin: const pw.EdgeInsets.only(bottom: 5),
                                        child: pw.Image(adminSigImage, fit: pw.BoxFit.contain),
                                      ),
                                    pw.Column(
                                      children: [
                                        pw.Container(
                                          width: 150,
                                          height: 1,
                                          color: PdfColors.black,
                                        ),
                                        pw.SizedBox(height: 2),
                                        pw.Text('Signature over Printed Name', style: const pw.TextStyle(fontSize: 8)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              pw.SizedBox(height: 8),
                              pw.Row(
                                children: [
                                  pw.Text('Date :', style: const pw.TextStyle(fontSize: 10)),
                                  pw.SizedBox(width: 8),
                                  pw.Expanded(
                                    child: pw.Container(
                                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
                                      child: pw.Text(request.approvedDate != null ? DateFormat('dd-MMM-yyyy').format(request.approvedDate!) : '', style: const pw.TextStyle(fontSize: 10)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Right Title Box
                      pw.Container(
                        width: 1,
                        color: PdfColors.black,
                      ),
                      pw.Expanded(
                        flex: 5,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 24),
                          child: pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text('WORK REQUEST FORM', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 4),
                              pw.Text('PANGASINAN STATE UNIVERSITY', style: const pw.TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // BOTTOM SECTION: Department & Accomplishment
                pw.Container(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Left Accomplishment Box
                      pw.Expanded(
                        flex: 6,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.SizedBox(height: 16),
                              pw.Row(
                                children: [
                                  pw.Text('Work Request Accomplished by:', style: const pw.TextStyle(fontSize: 10)),
                                  pw.SizedBox(width: 8),
                                    pw.Expanded(
                                      child: pw.Container(
                                        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
                                        child: pw.Text(' ${request.acceptedByName ?? ""}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                      ),
                                    ),
                                ],
                              ),
                              pw.SizedBox(height: 4),
                              pw.Center(
                                child: pw.Stack(
                                  alignment: pw.Alignment.bottomCenter,
                                  children: [
                                    if (completionSigImage != null)
                                      pw.Container(
                                        height: 35,
                                        margin: const pw.EdgeInsets.only(bottom: 5),
                                        child: pw.Image(completionSigImage, fit: pw.BoxFit.contain),
                                      ),
                                    pw.Column(
                                      children: [
                                        pw.Container(
                                          width: 150,
                                          height: 1,
                                          color: PdfColors.black,
                                        ),
                                        pw.SizedBox(height: 2),
                                        pw.Text('Signature over Printed Name', style: const pw.TextStyle(fontSize: 8)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              pw.SizedBox(height: 8),
                              pw.Row(
                                children: [
                                  pw.Text('Date :', style: const pw.TextStyle(fontSize: 10)),
                                  pw.SizedBox(width: 8),
                                    pw.Expanded(
                                      child: pw.Container(
                                        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
                                        child: pw.Text(request.dateCompleted != null ? DateFormat('dd-MMM-yyyy').format(request.dateCompleted!) : '', style: const pw.TextStyle(fontSize: 10)),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Right Department Box
                      pw.Container(
                        width: 1,
                        color: PdfColors.black,
                      ),
                      pw.Expanded(
                        flex: 5,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                children: [
                                  pw.Text('DEPARTMENT:', style: const pw.TextStyle(fontSize: 10)),
                                ],
                              ),
                              pw.Container(
                                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
                                width: double.infinity,
                                child: pw.Text(' ${request.department ?? ""}', style: const pw.TextStyle(fontSize: 10)),
                              ),
                              pw.SizedBox(height: 12),
                              pw.Row(
                                children: [
                                  pw.Text('NAME OF OFFICE / ROOM :', style: const pw.TextStyle(fontSize: 10)),
                                ],
                              ),
                              pw.Container(
                                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
                                width: double.infinity,
                                child: pw.Text(' ${request.officeRoom ?? ""}', style: const pw.TextStyle(fontSize: 10)),
                              ),
                              pw.Spacer(),
                              // Footer
                              pw.Container(
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                    top: pw.BorderSide(),
                                    left: pw.BorderSide(),
                                  ),
                                ),
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Row(
                                  children: [
                                    pw.Text('20___ - ___ - ___', style: const pw.TextStyle(fontSize: 8)),
                                    pw.Spacer(),
                                    pw.Column(
                                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                                      children: [
                                        pw.Text('FM-AD-ENG-02', style: const pw.TextStyle(fontSize: 6)),
                                        pw.Text('Rev 0', style: const pw.TextStyle(fontSize: 6)),
                                        pw.Text('03-Oct-2017', style: const pw.TextStyle(fontSize: 6)),
                                      ],
                                    ),
                                  ]
                                )
                              )
                            ],
                          ),
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

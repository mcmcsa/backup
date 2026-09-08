import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/work_request_model.dart';
import 'e_signature_service.dart';
import '../utils/signature_image_helper.dart';

class IsoPdfService {
  // Universal Standard Landscape (11.0" x 8.5")
  // Compatible with Letter, A4, and Long Bond Paper in Chrome Print & saved PDF
  // Standard Portrait Format (8.5" x 11.0" Letter / Long Bond compatible)
  // Perfectly fits BOTH Form 1 (top) and Form 2 (bottom) on a single sheet
  static const standardPortraitFormat = PdfPageFormat(
    8.5 * PdfPageFormat.inch,  // 612 pt
    11.0 * PdfPageFormat.inch, // 792 pt
    marginTop: 12,
    marginBottom: 12,
    marginLeft: 16,
    marginRight: 16,
  );

  // Backward compatibility alias so existing callers use the new format seamlessly
  static const longLandscapeFormat = standardPortraitFormat;

  static Future<Uint8List> generateWorkRequestPdf(WorkRequest request) async {
    final pdf = pw.Document();

    // Load assets
    final psuLogoData = await rootBundle.load('assets/images/PsuLogo.png');
    final psuLogo = pw.MemoryImage(psuLogoData.buffer.asUint8List());

    // Fetch signatures
    final signatures = await ESignatureService.fetchByWorkRequest(request.id);
    final isCompleted = request.status.trim().toLowerCase() == 'completed';
    
    final requesterSig = signatures.where((s) {
      final role = s.signerRole.toLowerCase();
      final type = s.signatureType.toLowerCase();
      return (role == 'teacher' || role == 'faculty' || role == 'requestor') ||
             (type == 'requestor' || type == 'request' || type == 'submission');
    }).firstOrNull;

    // Form 1: Admin Initial Approval Signature
    final adminApprovalSig = signatures.where((s) =>
        (s.signerRole.toLowerCase() == 'admin' || s.signerRole.toLowerCase() == 'campadmin' || s.signerRole.toLowerCase() == 'campus admin') &&
        (s.signatureType.toLowerCase() == 'approval' || s.signatureType.toLowerCase() == 'admin')
    ).firstOrNull;

    // Form 2: Admin Pre-Inspection Review / Monitored and Evaluated Signature
    var adminConfirmationSig = signatures.where((s) {
      final role = s.signerRole.toLowerCase();
      final type = s.signatureType.toLowerCase();
      final isAdmin = role == 'admin' || role == 'campadmin' || role == 'campus admin';
      final isPreAdmin = type == 'pre_inspection_approval' ||
          type == 'pre_inspection_admin' ||
          type == 'pre_inspection_review' ||
          (type == 'pre_inspection' && isAdmin);
      final hasPreNotes = s.notes?.toLowerCase().contains('pre') == true &&
          s.notes?.toLowerCase().contains('inspect') == true;
      return isAdmin && (isPreAdmin || hasPreNotes);
    }).firstOrNull;

    adminConfirmationSig ??= signatures.where((s) {
      final role = s.signerRole.toLowerCase();
      final type = s.signatureType.toLowerCase();
      final isAdmin = role == 'admin' || role == 'campadmin' || role == 'campus admin';
      final isConfirm = type == 'completion' || type == 'confirmation' || type == 'evaluation';
      return isAdmin && isConfirm;
    }).firstOrNull;

    if (adminConfirmationSig == null) {
      final adminApprovals = signatures.where((s) {
        final role = s.signerRole.toLowerCase();
        final type = s.signatureType.toLowerCase();
        final isAdmin = role == 'admin' || role == 'campadmin' || role == 'campus admin';
        return isAdmin && (type == 'approval' || type == 'admin');
      }).toList();

      if (adminApprovals.length > 1) {
        adminConfirmationSig = adminApprovals.last;
      } else if (adminApprovals.length == 1) {
        final statusLower = request.status.trim().toLowerCase();
        final hasPreInspection = request.preInspectionId != null;
        final isPastApproval = statusLower != 'pending' && statusLower != 'approved';
        if (hasPreInspection || isPastApproval || isCompleted) {
          adminConfirmationSig = adminApprovals.first;
        }
      }
    }

    // Form 1: Maintenance Acceptance Signature (Signed when technician accepted work request)
    final maintAcceptanceSig = signatures.where((s) {
      final role = s.signerRole.toLowerCase();
      final type = s.signatureType.toLowerCase();
      final isMaint = role == 'maintenance' || role == 'technician' || role == 'staff';
      final isAccept = type == 'acceptance' || type == 'task_acceptance';
      return isAccept && (isMaint || role.isNotEmpty);
    }).firstOrNull;

    // Form 2: Maintenance Pre-Inspection Signature (Signed when technician submitted pre-inspection)
    var maintForm2Sig = signatures.where((s) {
      final role = s.signerRole.toLowerCase();
      final type = s.signatureType.toLowerCase();
      final isMaint = role == 'maintenance' || role == 'technician' || role == 'staff';
      final isPre = type == 'pre_inspection';
      return isPre && (isMaint || role.isNotEmpty);
    }).firstOrNull;

    // Fallback for Form 2: if pre-inspection signature not found, check post-repair / completion
    maintForm2Sig ??= signatures.where((s) {
      final role = s.signerRole.toLowerCase();
      final type = s.signatureType.toLowerCase();
      final isMaint = role == 'maintenance' || role == 'technician' || role == 'staff';
      final isAccomplished = type == 'completion' || type == 'accomplished' || type == 'post_repair';
      return isMaint && isAccomplished;
    }).firstOrNull;

    String reqPosition = request.requestorPosition.trim();
    if (reqPosition.isEmpty || reqPosition == 'Faculty Member / Requestor') {
      if (request.requestorId != null && request.requestorId!.isNotEmpty) {
        try {
          final tRow = await Supabase.instance.client
              .from('teacher_users')
              .select('position')
              .eq('user_id', request.requestorId!)
              .maybeSingle();
          final p = tRow?['position']?.toString().trim();
          if (p != null && p.isNotEmpty) {
            reqPosition = p;
          } else {
            final uRow = await Supabase.instance.client
                .from('users')
                .select('position, role')
                .eq('id', request.requestorId!)
                .maybeSingle();
            final up = uRow?['position']?.toString().trim();
            if (up != null && up.isNotEmpty) {
              reqPosition = up;
            } else if (uRow?['role'] != null) {
              final r = uRow!['role'].toString().toLowerCase().trim();
              if (r == 'campadmin' || r == 'campus admin') {
                reqPosition = 'Campus Administrator';
              } else if (r == 'admin') {
                reqPosition = 'System Administrator';
              }
            }
          }
        } catch (_) {}
      }

      if (reqPosition.isEmpty || reqPosition == 'Faculty Member / Requestor') {
        final rName = request.requestorName.toLowerCase();
        if (rName.contains('campus admin') || rName.contains('campadmin')) {
          reqPosition = 'Campus Administrator';
        } else if (rName.contains('admin')) {
          reqPosition = 'Campus Administrator';
        }
      }
    }
    if (reqPosition.isEmpty) {
      reqPosition = 'Faculty Member / Requestor';
    }

    Future<pw.MemoryImage?> decodeSignature(String? base64Str) async {
      if (base64Str == null || base64Str.isEmpty) return null;
      try {
        final cleanBase64 = base64Str.contains(',')
            ? base64Str.split(',').last
            : base64Str;
        final rawBytes = base64Decode(cleanBase64.trim());
        final cleanBytes = await SignatureImageHelper.removeBackground(rawBytes);
        return pw.MemoryImage(cleanBytes);
      } catch (_) {
        return null;
      }
    }

    final requesterSigImage = await decodeSignature(requesterSig?.signatureData);
    final adminApprovalSigImage = await decodeSignature(adminApprovalSig?.signatureData);
    final adminConfirmationSigImage = await decodeSignature(adminConfirmationSig?.signatureData);
    final maintAcceptanceSigImage = await decodeSignature(maintAcceptanceSig?.signatureData);
    final maintForm2SigImage = await decodeSignature(maintForm2Sig?.signatureData);

    final fontCourierBold = pw.Font.courierBold();

    String primaryType = request.typeDisplay.trim();
    if (primaryType.isEmpty) {
      primaryType = request.typeOfRequest.trim();
    }
    final rawTitle = request.title.trim();

    String strippedTitle = rawTitle;
    if (strippedTitle.toLowerCase().startsWith('maintenance:')) {
      strippedTitle = strippedTitle.substring('maintenance:'.length).trim();
    }

    final pLower = primaryType.toLowerCase();
    final tLower = strippedTitle.toLowerCase();

    bool isOcular = false;
    bool isInstall = false;
    bool isRepair = false;
    bool isReplace = false;

    if (pLower.contains('ocular') || pLower.contains('inspection')) {
      isOcular = true;
    } else if (pLower.contains('install')) {
      isInstall = true;
    } else if (pLower.contains('repair') || pLower.contains('fix')) {
      isRepair = true;
    } else if (pLower.contains('replace')) {
      isReplace = true;
    } else if (tLower.startsWith('ocular') || tLower.contains('inspection of')) {
      isOcular = true;
    } else if (tLower.startsWith('installation') || tLower.contains('installation of')) {
      isInstall = true;
    } else if (tLower.startsWith('repair') || tLower.contains('repair of')) {
      isRepair = true;
    } else if (tLower.startsWith('replacement') || tLower.contains('replacement of')) {
      isReplace = true;
    }

    final isOthers = !isOcular && !isInstall && !isRepair && !isReplace;

    String specifyVal = request.specifyText.trim();
    if (specifyVal.isEmpty && strippedTitle.contains(':')) {
      specifyVal = strippedTitle.split(':').last.trim();
    }
    if (specifyVal.isEmpty && request.typeOfRequest.contains(':')) {
      specifyVal = request.typeOfRequest.split(':').last.trim();
    }
    if (specifyVal.isEmpty && isOthers) {
      if (primaryType.isNotEmpty && primaryType.toLowerCase() != 'others') {
        specifyVal = primaryType;
      } else {
        specifyVal = request.description.trim();
      }
    }
    if (specifyVal.isEmpty) {
      specifyVal = request.description.trim();
    }

    pw.Widget buildCheckline(String label, bool isChecked, String underlineText) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 12,
              height: 12,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.2),
              ),
              child: isChecked
                  ? pw.Center(
                      child: pw.Text(
                        'X',
                        style: pw.TextStyle(
                          font: fontCourierBold,
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
            pw.SizedBox(width: 6),
            pw.SizedBox(
              width: 130,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  font: fontCourierBold,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Container(
                height: 14,
                padding: const pw.EdgeInsets.only(left: 3),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.2)),
                ),
                child: pw.Text(
                  isChecked ? underlineText : '',
                  style: pw.TextStyle(
                    font: fontCourierBold,
                    fontSize: 7.5,
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
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              headerLabel,
              style: pw.TextStyle(
                font: fontCourierBold,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Center(
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Container(
                    height: 30,
                    alignment: pw.Alignment.bottomCenter,
                    child: sigImage != null
                        ? pw.Image(sigImage, fit: pw.BoxFit.contain)
                        : pw.SizedBox(),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    signerName.isNotEmpty ? signerName : ' ',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: fontCourierBold,
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Container(
                    width: 140,
                    height: 1.2,
                    color: PdfColors.black,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    footerLabel,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: fontCourierBold,
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (extraLabel != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Row(
                  children: [
                    pw.Text(
                      '$extraLabel: ',
                      style: pw.TextStyle(
                        font: fontCourierBold,
                        fontSize: 7.5,
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
                            fontSize: 7.5,
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
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Row(
                  children: [
                    pw.Text(
                      '$dateLabel: ',
                      style: pw.TextStyle(
                        font: fontCourierBold,
                        fontSize: 7.5,
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
                            fontSize: 7.5,
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

    // Single Standard Portrait Page (Letter / Long)
    // Contains Form 1 (Top), Perforation Cut Line (Middle), and Form 2 (Bottom)
    pdf.addPage(
      pw.Page(
        pageFormat: standardPortraitFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ==================== FORM 1: WORK REQUEST FORM ====================
              pw.Container(
                height: 360,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // ROW 1: Header Row (Logo, Title, ISO Code)
                    pw.Container(
                      height: 48,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          // Logo cell
                          pw.Container(
                            width: 80,
                            alignment: pw.Alignment.center,
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                            ),
                            child: pw.Image(psuLogo, width: 40, height: 40),
                          ),
                          // Title cell
                          pw.Expanded(
                            child: pw.Container(
                              alignment: pw.Alignment.center,
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                              ),
                              child: pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text(
                                    'WORK REQUEST FORM',
                                    style: pw.TextStyle(
                                      font: fontCourierBold,
                                      fontSize: 14.5,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    'PANGASINAN STATE UNIVERSITY',
                                    style: pw.TextStyle(
                                      font: fontCourierBold,
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // ISO cell
                          pw.Container(
                            width: 100,
                            padding: const pw.EdgeInsets.all(4),
                            alignment: pw.Alignment.centerRight,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Text('FM-AD-ENG-02', style: pw.TextStyle(font: fontCourierBold, fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                                pw.Text('Rev. 0', style: pw.TextStyle(font: fontCourierBold, fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                                pw.Text('03-Oct-2017', style: pw.TextStyle(font: fontCourierBold, fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ROW 2: Date Row
                    pw.Container(
                      height: 21,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.SizedBox(width: 8),
                          pw.Text('DATE :', style: pw.TextStyle(font: fontCourierBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            DateFormat('dd-MMM-yyyy').format(request.createdAt ?? request.dateSubmitted),
                            style: pw.TextStyle(font: fontCourierBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Expanded(child: pw.SizedBox()),
                          pw.Text(
                            '20${DateFormat('yy - MM - dd').format(request.createdAt ?? request.dateSubmitted)}',
                            style: pw.TextStyle(font: fontCourierBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(width: 24),
                        ],
                      ),
                    ),
                    // ROW 3: Campus & Department Row
                    pw.Container(
                      height: 21,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          // Campus cell
                          pw.Expanded(
                            flex: 6,
                            child: pw.Container(
                              alignment: pw.Alignment.centerLeft,
                              padding: const pw.EdgeInsets.only(left: 8),
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                              ),
                              child: pw.Text(
                                'CAMPUS : SAN CARLOS CITY',
                                style: pw.TextStyle(font: fontCourierBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ),
                          // Department cell
                          pw.Expanded(
                            flex: 5,
                            child: pw.Container(
                              alignment: pw.Alignment.centerLeft,
                              padding: const pw.EdgeInsets.only(left: 8),
                              child: pw.Text(
                                'DEPARTMENT: ${request.departmentName ?? ""}',
                                style: pw.TextStyle(font: fontCourierBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ROW 4: Building & Room Row
                    pw.Container(
                      height: 21,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          // Building cell
                          pw.Expanded(
                            flex: 6,
                            child: pw.Container(
                              alignment: pw.Alignment.centerLeft,
                              padding: const pw.EdgeInsets.only(left: 8),
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                              ),
                              child: pw.Text(
                                'BUILDING NAME : ${request.buildingName ?? ""}',
                                style: pw.TextStyle(font: fontCourierBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ),
                          // Room cell
                          pw.Expanded(
                            flex: 5,
                            child: pw.Container(
                              alignment: pw.Alignment.centerLeft,
                              padding: const pw.EdgeInsets.only(left: 8),
                              child: pw.Text(
                                'NAME OF OFFICE / ROOM : ${request.roomName ?? ""}',
                                style: pw.TextStyle(font: fontCourierBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ROW 5: Work Request Details Row (Checklist)
                    pw.Container(
                      height: 135,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'WORK REQUEST :',
                            style: pw.TextStyle(font: fontCourierBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Expanded(
                            child: pw.Center(
                              child: pw.SizedBox(
                                width: 440,
                                child: pw.Column(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                                  children: [
                                    buildCheckline('Ocular inspection of', isOcular, specifyVal),
                                    buildCheckline('Installation of', isInstall, specifyVal),
                                    buildCheckline('Repair of', isRepair, specifyVal),
                                    buildCheckline('Replacement of', isReplace, specifyVal),
                                    buildCheckline('Others (specify)', isOthers, specifyVal),
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
                      height: 114,
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          // Requestor Column
                          pw.Expanded(
                            flex: 6,
                            child: pw.Container(
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                              ),
                              child: buildSignatureColumn(
                                headerLabel: 'Requestor :',
                                footerLabel: 'Signature over Printed Name',
                                signerName: requesterSig?.signerName ?? request.requestorName,
                                sigImage: requesterSigImage,
                                extraLabel: 'Position / Designation',
                                extraVal: reqPosition,
                              ),
                            ),
                          ),
                          // Approved by Column
                          pw.Expanded(
                            flex: 5,
                            child: pw.Container(
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                              ),
                              child: buildSignatureColumn(
                                headerLabel: 'Approved by :',
                                footerLabel: 'Signature over Printed Name',
                                signerName: (adminApprovalSig != null || request.approvedDate != null)
                                    ? (adminApprovalSig?.signerName ?? request.approvedByName ?? '')
                                    : '',
                                sigImage: adminApprovalSigImage,
                                dateLabel: 'Date',
                                dateVal: adminApprovalSig?.signedAt ?? request.approvedDate,
                              ),
                            ),
                          ),
                          // Accomplished by Column (Form 1: Maintenance Acceptance)
                          pw.Expanded(
                            flex: 5,
                            child: buildSignatureColumn(
                              headerLabel: 'Work Request Accomplished by:',
                              footerLabel: 'Signature over Printed Name',
                              signerName: maintAcceptanceSig != null
                                  ? maintAcceptanceSig.signerName
                                  : (request.acceptedByName != null && request.acceptedByName!.trim().isNotEmpty
                                      ? request.acceptedByName!.trim()
                                      : ''),
                              sigImage: maintAcceptanceSigImage,
                              dateLabel: 'Date',
                              dateVal: maintAcceptanceSig?.signedAt ?? request.acceptedDate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ==================== DASHED CUTTING LINE DIVIDER ====================
              pw.Container(
                height: 30,
                alignment: pw.Alignment.center,
                child: pw.Row(
                  children: List.generate(
                    45,
                    (index) => pw.Expanded(
                      child: pw.Container(
                        margin: const pw.EdgeInsets.symmetric(horizontal: 2.5),
                        height: 1.2,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                ),
              ),

              // ==================== FORM 2: CONFIRM WORK REQUEST FORM ====================
              pw.Container(
                height: 360,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // ROW 1: Header Row
                    pw.Container(
                      height: 48,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          // Logo cell
                          pw.Container(
                            width: 80,
                            alignment: pw.Alignment.center,
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                            ),
                            child: pw.Image(psuLogo, width: 40, height: 40),
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
                                      fontSize: 13,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.SizedBox(height: 1),
                                  pw.Text(
                                    'PANGASINAN STATE UNIVERSITY',
                                    style: pw.TextStyle(
                                      font: fontCourierBold,
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.SizedBox(height: 1),
                                  pw.Text(
                                    'Office of the Physical Plant and Facilities',
                                    style: pw.TextStyle(
                                      font: fontCourierBold,
                                      fontSize: 7,
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
                      height: 21,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.SizedBox(width: 8),
                          pw.Text('DATE :', style: pw.TextStyle(font: fontCourierBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            DateFormat('dd-MMM-yyyy').format(request.dateCompleted ?? request.createdAt ?? request.dateSubmitted),
                            style: pw.TextStyle(font: fontCourierBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Expanded(child: pw.SizedBox()),
                          pw.Text(
                            '20${DateFormat('yy - MM - dd').format(request.dateCompleted ?? request.createdAt ?? request.dateSubmitted)}',
                            style: pw.TextStyle(font: fontCourierBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(width: 24),
                        ],
                      ),
                    ),
                    // ROW 3: Campus & Department Row
                    pw.Container(
                      height: 21,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          // Campus cell
                          pw.Expanded(
                            flex: 6,
                            child: pw.Container(
                              alignment: pw.Alignment.centerLeft,
                              padding: const pw.EdgeInsets.only(left: 8),
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                              ),
                              child: pw.Text(
                                'CAMPUS : SAN CARLOS CITY',
                                style: pw.TextStyle(font: fontCourierBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ),
                          // Department cell
                          pw.Expanded(
                            flex: 5,
                            child: pw.Container(
                              alignment: pw.Alignment.centerLeft,
                              padding: const pw.EdgeInsets.only(left: 8),
                              child: pw.Text(
                                'DEPARTMENT: ${request.departmentName ?? ""}',
                                style: pw.TextStyle(font: fontCourierBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ROW 4: Building & Room Row
                    pw.Container(
                      height: 21,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          // Building cell
                          pw.Expanded(
                            flex: 6,
                            child: pw.Container(
                              alignment: pw.Alignment.centerLeft,
                              padding: const pw.EdgeInsets.only(left: 8),
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                              ),
                              child: pw.Text(
                                'BUILDING NAME : ${request.buildingName ?? ""}',
                                style: pw.TextStyle(font: fontCourierBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ),
                          // Room cell
                          pw.Expanded(
                            flex: 5,
                            child: pw.Container(
                              alignment: pw.Alignment.centerLeft,
                              padding: const pw.EdgeInsets.only(left: 8),
                              child: pw.Text(
                                'NAME OF OFFICE / ROOM : ${request.roomName ?? ""}',
                                style: pw.TextStyle(font: fontCourierBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ROW 5: Work Request Details Row (Checklist)
                    pw.Container(
                      height: 135,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'WORK REQUEST :',
                            style: pw.TextStyle(font: fontCourierBold, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Expanded(
                            child: pw.Center(
                              child: pw.SizedBox(
                                width: 440,
                                child: pw.Column(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                                  children: [
                                    buildCheckline('Ocular inspection of', isOcular, specifyVal),
                                    buildCheckline('Installation of', isInstall, specifyVal),
                                    buildCheckline('Repair of', isRepair, specifyVal),
                                    buildCheckline('Replacement of', isReplace, specifyVal),
                                    buildCheckline('Others (specify)', isOthers, specifyVal),
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
                      height: 114,
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          // Work Request Accomplished by Column (Form 2: Maintenance Pre-Inspection)
                          pw.Expanded(
                            flex: 6,
                            child: pw.Container(
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                              ),
                              child: buildSignatureColumn(
                                headerLabel: 'Work Request Accomplished by:',
                                footerLabel: 'Signature over Printed Name',
                                signerName: maintForm2Sig != null
                                    ? maintForm2Sig.signerName
                                    : (request.acceptedByName != null && request.acceptedByName!.trim().isNotEmpty
                                        ? request.acceptedByName!.trim()
                                        : ''),
                                sigImage: maintForm2SigImage,
                                dateLabel: 'Date',
                                dateVal: maintForm2Sig?.signedAt ??
                                    (isCompleted ? (request.dateCompleted ?? request.maintenanceEndTime) : request.acceptedDate),
                              ),
                            ),
                          ),
                          // Requestor Column (using initial submission signature)
                          pw.Expanded(
                            flex: 5,
                            child: pw.Container(
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                              ),
                              child: buildSignatureColumn(
                                headerLabel: 'Requestor:',
                                footerLabel: 'Signature over Printed Name',
                                signerName: requesterSig?.signerName ?? request.requestorName,
                                sigImage: requesterSigImage,
                                extraLabel: 'Position / Designation',
                                extraVal: reqPosition,
                              ),
                            ),
                          ),
                          // Monitored and Evaluated by Column
                          pw.Expanded(
                            flex: 5,
                            child: buildSignatureColumn(
                              headerLabel: 'Monitored and Evaluated by:',
                              footerLabel: 'Signature over Printed Name',
                              signerName: adminConfirmationSig != null
                                  ? adminConfirmationSig.signerName
                                  : (request.approvedByName != null && request.approvedByName!.isNotEmpty
                                      ? request.approvedByName!
                                      : (isCompleted ? (request.approvedByName ?? '') : '')),
                              sigImage: adminConfirmationSigImage,
                              dateLabel: 'Date',
                              dateVal: adminConfirmationSig?.signedAt ?? (isCompleted ? request.dateCompleted : request.approvedDate),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}






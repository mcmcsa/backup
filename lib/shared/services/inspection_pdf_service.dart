import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../models/work_request_model.dart';
import '../models/pre_inspection_model.dart';
import '../models/post_repair_model.dart';
import '../models/e_signature_model.dart';
import 'e_signature_service.dart';
import '../utils/signature_image_helper.dart';

class _PdfEvidenceImage {
  final pw.ImageProvider image;
  final String label;
  final String? caption;
  final PdfColor? tagColor;

  _PdfEvidenceImage({
    required this.image,
    required this.label,
    this.caption,
    this.tagColor,
  });
}

class InspectionPdfService {
  static final pageFormat = PdfPageFormat.a4;

  /// Helper to decode and clean signature into a transparent pw.MemoryImage
  static Future<pw.MemoryImage?> _decodeSignature(String? base64Str) async {
    if (base64Str == null || base64Str.isEmpty) return null;
    try {
      final cleanBase64 = base64Str.contains(',')
          ? base64Str.split(',').last.trim()
          : base64Str.trim();
      final rawBytes = base64Decode(cleanBase64);
      final cleanBytes = await SignatureImageHelper.removeBackground(rawBytes);
      return pw.MemoryImage(cleanBytes);
    } catch (_) {
      return null;
    }
  }

  /// Helper to load the PSU seal
  static Future<pw.MemoryImage?> _loadPsuLogo() async {
    try {
      final data = await rootBundle.load('assets/images/PsuLogo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// Helper to parse raw string/json array into clean URL list
  static List<String> _extractUrls(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      final list = <String>[];
      for (final item in raw) {
        list.addAll(_extractUrls(item));
      }
      return list;
    }
    String str = raw.toString().trim();
    if (str.isEmpty || str == '[]' || str == 'null') return [];

    // Strip wrapping quotes if double-encoded
    if ((str.startsWith('"') && str.endsWith('"')) ||
        (str.startsWith("'") && str.endsWith("'"))) {
      str = str.substring(1, str.length - 1).trim();
    }

    try {
      if (str.startsWith('[') && str.endsWith(']')) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          final list = <String>[];
          for (final item in decoded) {
            list.addAll(_extractUrls(item));
          }
          return list;
        }
      }
    } catch (_) {}

    // Check if comma-separated list of URLs
    if (str.contains(',') && !str.startsWith('data:image')) {
      final parts = str.split(',');
      final list = <String>[];
      for (final p in parts) {
        final trimmed = p.trim();
        if (trimmed.isNotEmpty) list.add(trimmed);
      }
      if (list.isNotEmpty) return list;
    }

    // Extract any embedded http/https links via regex
    if (str.contains('http://') || str.contains('https://')) {
      final regExp = RegExp(r'https?://[^\s",\]\[]+');
      final matches = regExp.allMatches(str).map((m) => m.group(0)!).toList();
      if (matches.isNotEmpty) return matches;
    }

    return [str];
  }

  /// Parse Supabase storage URL to extract bucket and file path
  static Map<String, String>? _parseSupabaseStorageUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final objIdx = segments.indexOf('object');
      if (objIdx != -1 && segments.length > objIdx + 1) {
        int bucketIdx = objIdx + 1;
        if (bucketIdx < segments.length &&
            ['public', 'authenticated', 'sign'].contains(segments[bucketIdx])) {
          bucketIdx++;
        }
        if (bucketIdx < segments.length && segments.length > bucketIdx + 1) {
          final bucket = segments[bucketIdx];
          final path = segments.sublist(bucketIdx + 1).join('/');
          if (bucket.isNotEmpty && path.isNotEmpty) {
            return {'bucket': bucket, 'path': path};
          }
        }
      }
    } catch (_) {}
    return null;
  }


  /// Helper to fetch image from network URL or decode base64 across Web & Mobile
  static Future<pw.ImageProvider?> _fetchImage(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return null;

    // 1. Check if Base64 data URL
    if (cleanUrl.startsWith('data:image') || cleanUrl.startsWith('data:')) {
      try {
        final commaIdx = cleanUrl.indexOf(',');
        if (commaIdx != -1) {
          final b64 = cleanUrl.substring(commaIdx + 1).trim();
          final bytes = base64Decode(b64);
          if (bytes.isNotEmpty) return pw.MemoryImage(bytes);
        }
      } catch (e) {
        debugPrint('InspectionPdfService: Error decoding base64 image: $e');
      }
    }

    // 2. Try Supabase Storage Client download (Fastest & direct on Web/Mobile)
    if (cleanUrl.contains('/storage/v1/object/')) {
      final parsed = _parseSupabaseStorageUrl(cleanUrl);
      if (parsed != null) {
        final bucket = parsed['bucket']!;
        final path = parsed['path']!;

        try {
          final bytes = await Supabase.instance.client.storage
              .from(bucket)
              .download(path)
              .timeout(const Duration(seconds: 4));
          if (bytes.isNotEmpty) {
            return pw.MemoryImage(bytes);
          }
        } catch (_) {
          // If encoded, try URL-decoded path
          try {
            final decodedPath = Uri.decodeComponent(path);
            if (decodedPath != path) {
              final bytes = await Supabase.instance.client.storage
                  .from(bucket)
                  .download(decodedPath)
                  .timeout(const Duration(seconds: 3));
              if (bytes.isNotEmpty) {
                return pw.MemoryImage(bytes);
              }
            }
          } catch (_) {}
        }
      }
    }

    // 3. Try networkImage from printing package
    try {
      final img = await networkImage(cleanUrl).timeout(const Duration(seconds: 3));
      return img;
    } catch (_) {}

    // 4. Try standard http.get with Supabase auth headers
    try {
      final uri = Uri.tryParse(cleanUrl);
      if (uri != null && uri.hasScheme && uri.hasAuthority) {
        final res = await http.get(
          uri,
          headers: {
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer $supabaseAnonKey',
          },
        ).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          return pw.MemoryImage(res.bodyBytes);
        }
      }
    } catch (_) {}

    return null;
  }

  // ===========================================================================
  // PRE-INSPECTION REPORT PDF
  // ===========================================================================
  static Future<Uint8List> generatePreInspectionPdf({
    required WorkRequest request,
    required PreInspectionReport report,
    List<ESignature>? signatures,
  }) async {
    final pdf = pw.Document();
    final psuLogo = await _loadPsuLogo();

    final sigList = signatures ?? await ESignatureService.fetchByWorkRequest(request.id);

    // Inspector signature
    final inspectorSig = sigList.where((s) =>
        s.signatureType == 'pre_inspection' ||
        (s.signerRole.toLowerCase() == 'maintenance' && s.signerId == report.inspectorId)
    ).firstOrNull;

    // Admin Approval signature
    final adminApprovalSig = sigList.where((s) =>
        s.signatureType == 'pre_inspection_admin' ||
        s.signatureType == 'pre_inspection_approval' ||
        (s.signatureType == 'approval' &&
            (s.signerRole.toLowerCase() == 'admin' || s.signerRole.toLowerCase() == 'campadmin' || s.signerRole.toLowerCase() == 'campus admin'))
    ).firstOrNull;

    final inspectorSigImage = await _decodeSignature(inspectorSig?.signatureData);
    final adminSigImage = await _decodeSignature(adminApprovalSig?.signatureData);

    final fontBold = pw.Font.helveticaBold();
    final fontRegular = pw.Font.helvetica();

    final primaryColor = PdfColor.fromHex('1E3A8A'); // Navy
    final borderColor = PdfColor.fromHex('CBD5E1'); // Slate 300
    final headerBg = PdfColor.fromHex('F8FAFC'); // Slate 50
    final textDark = PdfColor.fromHex('0F172A');
    final textMuted = PdfColor.fromHex('64748B');

    // ── 0. EVIDENCE GATHERING & PHOTO RETRIEVAL ──────────────────────────────
    // ONLY collect images specifically submitted for this Pre-Inspection report:
    List<String> targetUrls = _extractUrls(report.photoEvidence);

    // Fallback only if report.photoEvidence is completely empty
    if (targetUrls.isEmpty && report.notes != null) {
      targetUrls = _extractUrls(report.notes);
    }

    final List<_PdfEvidenceImage> evidenceList = [];

    if (targetUrls.isNotEmpty) {
      final downloadedImages = await Future.wait(
        targetUrls.map((u) => _fetchImage(u)),
      );

      for (int i = 0; i < downloadedImages.length; i++) {
        final img = downloadedImages[i];
        if (img != null) {
          evidenceList.add(_PdfEvidenceImage(
            image: img,
            label: targetUrls.length == 1
                ? 'PRE-INSPECTION EVIDENCE'
                : 'Pre-Inspection Evidence #${evidenceList.length + 1}',
            caption: report.conditionFound.isNotEmpty ? report.conditionFound : 'Site assessment defect/condition',
            tagColor: primaryColor,
          ));
        }
      }
    }

    // Calculate annex chunks
    final annexChunks = <List<_PdfEvidenceImage>>[];
    for (var i = 0; i < evidenceList.length; i += 4) {
      annexChunks.add(evidenceList.sublist(i, i + 4 > evidenceList.length ? evidenceList.length : i + 4));
    }
    final totalReportPages = 1 + annexChunks.length;

    // ── PAGE 1: PRE-INSPECTION ASSESSMENT CERTIFICATE ────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── 1. INSTITUTIONAL HEADER ─────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 12),
                decoration: pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: primaryColor, width: 2)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (psuLogo != null)
                      pw.Container(
                        width: 58,
                        height: 58,
                        margin: const pw.EdgeInsets.only(right: 14),
                        child: pw.Image(psuLogo),
                      ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PANGASINAN STATE UNIVERSITY',
                            style: pw.TextStyle(font: fontBold, fontSize: 13, color: primaryColor),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Office of Physical Plant & Facilities Management / Campus Administration',
                            style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: textMuted),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'PRE-INSPECTION ASSESSMENT REPORT',
                            style: pw.TextStyle(font: fontBold, fontSize: 12, color: textDark),
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: headerBg,
                        border: pw.Border.all(color: borderColor),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('DOC CODE: FM-AD-ENG-02A', style: pw.TextStyle(font: fontBold, fontSize: 7, color: textMuted)),
                          pw.Text('TRACKING NO: ${request.formattedId}', style: pw.TextStyle(font: fontBold, fontSize: 8, color: primaryColor)),
                          pw.Text('DATE: ${DateFormat('MM/dd/yyyy').format(DateTime.now())}', style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: textMuted)),
                          if (evidenceList.isNotEmpty)
                            pw.Text('PAGES: 1 OF $totalReportPages (${annexChunks.length} ANNEX PAGE${annexChunks.length > 1 ? 'S' : ''})', style: pw.TextStyle(font: fontBold, fontSize: 6.5, color: PdfColor.fromHex('15803D'))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // ── 2. WORK REQUEST REFERENCE ──────────────────────────────
              _buildSectionHeader('WORK REQUEST REFERENCE', primaryColor, fontBold),
              pw.SizedBox(height: 4),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.2),
                    1: const pw.FlexColumnWidth(2.0),
                    2: const pw.FlexColumnWidth(1.2),
                    3: const pw.FlexColumnWidth(2.0),
                  },
                  children: [
                    _buildTableRow('Requesting Room/Office', request.officeRoom ?? 'N/A', 'Requestor', request.displayRequestorName, fontBold, fontRegular, headerBg, borderColor),
                    _buildTableRow('Request Type', request.typeDisplay.isNotEmpty ? request.typeDisplay : request.typeOfRequest, 'Date Requested', DateFormat('MMM dd, yyyy - hh:mm a').format(request.dateSubmitted), fontBold, fontRegular, null, borderColor),
                    _buildTableRow('Issue / Subject', request.title, 'Current Status', request.status, fontBold, fontRegular, headerBg, borderColor),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // ── 3. PRE-INSPECTION FINDINGS ─────────────────────────────
              _buildSectionHeader('SITE INSPECTION ASSESSMENT', primaryColor, fontBold),
              pw.SizedBox(height: 4),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.2),
                    1: const pw.FlexColumnWidth(2.0),
                    2: const pw.FlexColumnWidth(1.2),
                    3: const pw.FlexColumnWidth(2.0),
                  },
                  children: [
                    _buildTableRow('Inspecting Technician', report.inspectorName, 'Inspection Date', DateFormat('MMM dd, yyyy - hh:mm a').format(report.inspectionDate), fontBold, fontRegular, headerBg, borderColor),
                    _buildTableRow('Severity Level', report.severityLevel.toUpperCase(), 'Estimated Duration', report.estimatedTime?.isNotEmpty == true ? report.estimatedTime! : 'N/A', fontBold, fontRegular, null, borderColor),
                    _buildTableRow('Photo Documentation', evidenceList.isNotEmpty ? '${evidenceList.length} Photographic Record(s) Attached' : 'No Photographs Attached', 'Photographic Annex', evidenceList.isNotEmpty ? 'See Annex (Pages 2-$totalReportPages)' : 'None', fontBold, fontRegular, headerBg, borderColor),
                  ],
                ),
              ),

              pw.SizedBox(height: 6),

              // Detailed assessment cards
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildDetailField('CONDITION FOUND / OBSERVATIONS', report.conditionFound, fontBold, fontRegular),
                    if (report.rootCause?.isNotEmpty == true) ...[
                      pw.SizedBox(height: 6),
                      _buildDetailField('POSSIBLE ROOT CAUSE', report.rootCause!, fontBold, fontRegular),
                    ],
                    if (report.recommendedAction?.isNotEmpty == true) ...[
                      pw.SizedBox(height: 6),
                      _buildDetailField('RECOMMENDED ACTION / SCOPE OF WORK', report.recommendedAction!, fontBold, fontRegular),
                    ],
                    if (report.materialsNeeded?.isNotEmpty == true) ...[
                      pw.SizedBox(height: 6),
                      _buildDetailField('MATERIALS / TOOLS NEEDED', report.materialsNeeded!, fontBold, fontRegular),
                    ],
                    if (report.notes?.isNotEmpty == true) ...[
                      pw.SizedBox(height: 6),
                      _buildDetailField('INSPECTOR NOTES', report.notes!, fontBold, fontRegular),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // ── 4. ADMINISTRATIVE REVIEW & DECISION ────────────────────
              _buildSectionHeader('CAMPUS ADMIN REVIEW & DECISION', primaryColor, fontBold),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: report.status == 'Approved'
                      ? PdfColor.fromHex('F0FDF4') // light green
                      : (report.status == 'Declined' ? PdfColor.fromHex('FEF2F2') : headerBg),
                  border: pw.Border.all(
                    color: report.status == 'Approved'
                        ? PdfColor.fromHex('86EFAC')
                        : (report.status == 'Declined' ? PdfColor.fromHex('FECACA') : borderColor),
                  ),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text('DECISION:  ', style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: textDark)),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: pw.BoxDecoration(
                                color: report.status == 'Approved'
                                    ? PdfColor.fromHex('16A34A')
                                    : (report.status == 'Declined' ? PdfColor.fromHex('DC2626') : PdfColor.fromHex('E2E8F0')),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                              ),
                              child: pw.Text(
                                report.status == 'Approved'
                                    ? 'APPROVED / CONFIRMED'
                                    : (report.status == 'Declined' ? 'DECLINED / REJECTED' : 'PENDING REVIEW'),
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 8,
                                  color: report.status == 'Approved' || report.status == 'Declined' ? PdfColors.white : textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.Text(
                          'Decision Date: ${report.adminApprovedDate != null ? DateFormat('MMM dd, yyyy - hh:mm a').format(report.adminApprovedDate!) : 'Pending'}',
                          style: pw.TextStyle(font: fontRegular, fontSize: 8, color: textMuted),
                        ),
                      ],
                    ),
                    if (report.reviewNotes?.isNotEmpty == true) ...[
                      pw.SizedBox(height: 6),
                      pw.Text('Administrator Review Notes:', style: pw.TextStyle(font: fontBold, fontSize: 8, color: textDark)),
                      pw.SizedBox(height: 2),
                      pw.Text(report.reviewNotes!, style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: textDark)),
                    ],
                  ],
                ),
              ),

              pw.Spacer(),

              // ── 5. FORMAL SIGNATURES BLOCK ──────────────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  // Inspector Signature
                  pw.Expanded(
                    child: _buildSignatureCell(
                      label: 'INSPECTED & FILED BY:',
                      name: report.inspectorName,
                      role: 'Maintenance Technician / Inspector',
                      signatureImage: inspectorSigImage,
                      date: report.inspectionDate,
                      fontBold: fontBold,
                      fontRegular: fontRegular,
                      borderColor: borderColor,
                    ),
                  ),
                  pw.SizedBox(width: 32),
                  // Admin Approval Signature
                  pw.Expanded(
                    child: _buildSignatureCell(
                      label: 'REVIEWED & APPROVED BY:',
                      name: request.approvedByName ?? "Campus Administrator",
                      role: 'Campus Administrator',
                      signatureImage: adminSigImage,
                      date: report.adminApprovedDate ?? DateTime.now(),
                      fontBold: fontBold,
                      fontRegular: fontRegular,
                      borderColor: borderColor,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),

              // System watermark
              pw.Center(
                child: pw.Text(
                  'System-generated Official Pre-Inspection Document | PSU Maintenance Management Portal',
                  style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: textMuted),
                ),
              ),
            ],
          );
        },
      ),
    );

    // ── 6. ANNEX: WORK EVIDENCE & PHOTO DOCUMENTATION ────────────────────────
    if (annexChunks.isNotEmpty) {
      for (int pIdx = 0; pIdx < annexChunks.length; pIdx++) {
        pdf.addPage(
          _buildEvidencePage(
            images: annexChunks[pIdx],
            pageIndex: pIdx,
            totalPages: annexChunks.length,
            documentTitle: 'PRE-INSPECTION ASSESSMENT & WORK EVIDENCE',
            trackingNo: request.formattedId,
            psuLogo: psuLogo,
            fontBold: fontBold,
            fontRegular: fontRegular,
            primaryColor: primaryColor,
            borderColor: borderColor,
            headerBg: headerBg,
            textDark: textDark,
            textMuted: textMuted,
          ),
        );
      }
    }

    return pdf.save();
  }

  // ===========================================================================
  // POST-REPAIR REPORT PDF
  // ===========================================================================
  static Future<Uint8List> generatePostRepairPdf({
    required WorkRequest request,
    required PostRepairReport report,
    List<ESignature>? signatures,
  }) async {
    final pdf = pw.Document();
    final psuLogo = await _loadPsuLogo();

    final sigList = signatures ?? await ESignatureService.fetchByWorkRequest(request.id);

    // Technician signature (signatureType == 'post_repair')
    final techSig = sigList.where((s) =>
        s.signatureType == 'post_repair' ||
        (s.signerRole.toLowerCase() == 'maintenance' && s.signerId == report.technicianId)
    ).firstOrNull;

    // Admin Evaluation signature (signatureType == 'completion' or 'approval')
    final adminEvalSig = sigList.where((s) =>
        (s.signatureType == 'completion' || s.signatureType == 'post_repair_evaluation' || s.signatureType == 'evaluation') &&
        (s.signerRole.toLowerCase() == 'admin' || s.signerRole.toLowerCase() == 'campadmin' || s.signerRole.toLowerCase() == 'campus admin')
    ).firstOrNull;

    final techSigImage = await _decodeSignature(techSig?.signatureData);
    final adminSigImage = await _decodeSignature(adminEvalSig?.signatureData);

    final fontBold = pw.Font.helveticaBold();
    final fontRegular = pw.Font.helvetica();

    final primaryColor = PdfColor.fromHex('1E3A8A'); // Navy
    final borderColor = PdfColor.fromHex('CBD5E1'); // Slate 300
    final headerBg = PdfColor.fromHex('F8FAFC'); // Slate 50
    final textDark = PdfColor.fromHex('0F172A');
    final textMuted = PdfColor.fromHex('64748B');

    final isSatisfied = report.adminEvaluation == 'satisfied' || report.status == 'Completed';
    final isRework = report.adminEvaluation == 'rework' || report.status == 'Rework';

    // ── 0. EVIDENCE GATHERING & BEFORE/AFTER PHOTO RETRIEVAL ──────────────────
    // ONLY collect images specifically submitted for Post-Repair:
    final beforeUrls = _extractUrls(report.photoBefore);
    final afterUrls = _extractUrls(report.photoAfter);

    final List<_PdfEvidenceImage> evidenceList = [];

    // Parallel fetch for before and after photos
    final beforeImages = await Future.wait(beforeUrls.map((u) => _fetchImage(u)));
    final afterImages = await Future.wait(afterUrls.map((u) => _fetchImage(u)));

    for (int i = 0; i < beforeImages.length; i++) {
      final img = beforeImages[i];
      if (img != null) {
        evidenceList.add(_PdfEvidenceImage(
          image: img,
          label: beforeImages.length == 1 ? 'BEFORE REPAIR' : 'BEFORE REPAIR #${i + 1}',
          caption: 'Defect / problem state prior to maintenance repair',
          tagColor: PdfColor.fromHex('D97706'),
        ));
      }
    }

    for (int i = 0; i < afterImages.length; i++) {
      final img = afterImages[i];
      if (img != null) {
        evidenceList.add(_PdfEvidenceImage(
          image: img,
          label: afterImages.length == 1 ? 'AFTER REPAIR' : 'AFTER REPAIR #${i + 1}',
          caption: report.workPerformed.isNotEmpty ? report.workPerformed : 'Completed repair work accomplishment',
          tagColor: PdfColor.fromHex('16A34A'),
        ));
      }
    }

    // Fallback only if both before and after photos are completely empty
    if (evidenceList.isEmpty && report.materialsUsed != null) {
      final matUrls = _extractUrls(report.materialsUsed);
      final matImages = await Future.wait(matUrls.map((u) => _fetchImage(u)));
      for (final img in matImages) {
        if (img != null) {
          evidenceList.add(_PdfEvidenceImage(
            image: img,
            label: 'PARTS & MATERIALS #${evidenceList.length + 1}',
            caption: 'Parts or materials documentation',
            tagColor: primaryColor,
          ));
        }
      }
    }

    // Calculate annex chunks
    final annexChunks = <List<_PdfEvidenceImage>>[];
    for (var i = 0; i < evidenceList.length; i += 4) {
      annexChunks.add(evidenceList.sublist(i, i + 4 > evidenceList.length ? evidenceList.length : i + 4));
    }
    final totalReportPages = 1 + annexChunks.length;

    // ── PAGE 1: POST-REPAIR EVALUATION CERTIFICATE ───────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── 1. INSTITUTIONAL HEADER ─────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 12),
                decoration: pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: primaryColor, width: 2)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (psuLogo != null)
                      pw.Container(
                        width: 58,
                        height: 58,
                        margin: const pw.EdgeInsets.only(right: 14),
                        child: pw.Image(psuLogo),
                      ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PANGASINAN STATE UNIVERSITY',
                            style: pw.TextStyle(font: fontBold, fontSize: 13, color: primaryColor),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Office of Physical Plant & Facilities Management / Campus Administration',
                            style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: textMuted),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'POST-REPAIR INSPECTION & EVALUATION REPORT',
                            style: pw.TextStyle(font: fontBold, fontSize: 12, color: textDark),
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: headerBg,
                        border: pw.Border.all(color: borderColor),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('DOC CODE: FM-AD-ENG-03A', style: pw.TextStyle(font: fontBold, fontSize: 7, color: textMuted)),
                          pw.Text('TRACKING NO: ${request.formattedId}', style: pw.TextStyle(font: fontBold, fontSize: 8, color: primaryColor)),
                          pw.Text('ATTEMPT: #${report.attemptNumber}', style: pw.TextStyle(font: fontBold, fontSize: 7, color: textDark)),
                          if (evidenceList.isNotEmpty)
                            pw.Text('PAGES: 1 OF $totalReportPages (${annexChunks.length} ANNEX PAGE${annexChunks.length > 1 ? 'S' : ''})', style: pw.TextStyle(font: fontBold, fontSize: 6.5, color: PdfColor.fromHex('15803D'))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // ── 2. WORK REQUEST REFERENCE ──────────────────────────────
              _buildSectionHeader('WORK REQUEST REFERENCE', primaryColor, fontBold),
              pw.SizedBox(height: 4),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.2),
                    1: const pw.FlexColumnWidth(2.0),
                    2: const pw.FlexColumnWidth(1.2),
                    3: const pw.FlexColumnWidth(2.0),
                  },
                  children: [
                    _buildTableRow('Room / Facility', request.officeRoom ?? 'N/A', 'Original Requestor', request.displayRequestorName, fontBold, fontRegular, headerBg, borderColor),
                    _buildTableRow('Request Title', request.title, 'Nature of Work', request.typeDisplay.isNotEmpty ? request.typeDisplay : request.typeOfRequest, fontBold, fontRegular, null, borderColor),
                    _buildTableRow('Date Submitted', DateFormat('MMM dd, yyyy').format(request.dateSubmitted), 'Current Status', request.status, fontBold, fontRegular, headerBg, borderColor),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // ── 3. MAINTENANCE ACCOMPLISHMENT DETAILS ──────────────────
              _buildSectionHeader('MAINTENANCE ACCOMPLISHMENT DETAILS', primaryColor, fontBold),
              pw.SizedBox(height: 4),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.2),
                    1: const pw.FlexColumnWidth(2.0),
                    2: const pw.FlexColumnWidth(1.2),
                    3: const pw.FlexColumnWidth(2.0),
                  },
                  children: [
                    _buildTableRow('Technician', report.technicianName, 'Completion Date', DateFormat('MMM dd, yyyy - hh:mm a').format(report.repairDate), fontBold, fontRegular, headerBg, borderColor),
                    _buildTableRow('Repair Duration', report.repairDuration?.isNotEmpty == true ? report.repairDuration! : 'N/A', 'Execution Status', report.repairStatus.toUpperCase(), fontBold, fontRegular, null, borderColor),
                    _buildTableRow('Photo Documentation', evidenceList.isNotEmpty ? '${evidenceList.length} Photo Evidence Record(s) Attached' : 'No Photographs Attached', 'Photographic Annex', evidenceList.isNotEmpty ? 'See Annex (Pages 2-$totalReportPages)' : 'None', fontBold, fontRegular, headerBg, borderColor),
                  ],
                ),
              ),

              pw.SizedBox(height: 6),

              // Work performed card
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildDetailField('WORK PERFORMED / RESOLUTION SUMMARY', report.workPerformed, fontBold, fontRegular),
                    if (report.materialsUsed?.isNotEmpty == true) ...[
                      pw.SizedBox(height: 6),
                      _buildDetailField('MATERIALS & PARTS UTILIZED', report.materialsUsed!, fontBold, fontRegular),
                    ],
                    if (report.technicianNotes?.isNotEmpty == true) ...[
                      pw.SizedBox(height: 6),
                      _buildDetailField('TECHNICIAN NOTES & RECOMMENDATIONS', report.technicianNotes!, fontBold, fontRegular),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // ── 4. ADMINISTRATIVE EVALUATION ───────────────────────────
              _buildSectionHeader('CAMPUS ADMIN POST-REPAIR EVALUATION', primaryColor, fontBold),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: isSatisfied
                      ? PdfColor.fromHex('F0FDF4')
                      : (isRework ? PdfColor.fromHex('FFFBEB') : headerBg),
                  border: pw.Border.all(
                    color: isSatisfied
                        ? PdfColor.fromHex('86EFAC')
                        : (isRework ? PdfColor.fromHex('FDE68A') : borderColor),
                  ),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text('EVALUATION:  ', style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: textDark)),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: pw.BoxDecoration(
                                color: isSatisfied
                                    ? PdfColor.fromHex('16A34A')
                                    : (isRework ? PdfColor.fromHex('D97706') : PdfColor.fromHex('64748B')),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                              ),
                              child: pw.Text(
                                isSatisfied
                                    ? 'SATISFIED (COMPLETED)'
                                    : (isRework ? 'REWORK REQUIRED' : 'EVALUATION PENDING'),
                                style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
                              ),
                            ),
                          ],
                        ),
                        pw.Text(
                          'Evaluated Date: ${report.adminEvaluatedDate != null ? DateFormat('MMM dd, yyyy - hh:mm a').format(report.adminEvaluatedDate!) : 'Pending'}',
                          style: pw.TextStyle(font: fontRegular, fontSize: 8, color: textMuted),
                        ),
                      ],
                    ),
                    if (report.adminEvaluationNotes?.isNotEmpty == true) ...[
                      pw.SizedBox(height: 6),
                      pw.Text('Campus Admin Evaluation Notes:', style: pw.TextStyle(font: fontBold, fontSize: 8, color: textDark)),
                      pw.SizedBox(height: 2),
                      pw.Text(report.adminEvaluationNotes!, style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: textDark)),
                    ],
                  ],
                ),
              ),

              pw.Spacer(),

              // ── 5. FORMAL SIGNATURES BLOCK ──────────────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  // Technician Accomplishment Signature
                  pw.Expanded(
                    child: _buildSignatureCell(
                      label: 'ACCOMPLISHED & SUBMITTED BY:',
                      name: report.technicianName,
                      role: 'Maintenance Technician',
                      signatureImage: techSigImage,
                      date: report.repairDate,
                      fontBold: fontBold,
                      fontRegular: fontRegular,
                      borderColor: borderColor,
                    ),
                  ),
                  pw.SizedBox(width: 32),
                  // Admin Evaluation Signature
                  pw.Expanded(
                    child: _buildSignatureCell(
                      label: 'EVALUATED & VERIFIED BY:',
                      name: request.approvedByName ?? "Campus Administrator",
                      role: 'Campus Administrator',
                      signatureImage: adminSigImage,
                      date: report.adminEvaluatedDate ?? DateTime.now(),
                      fontBold: fontBold,
                      fontRegular: fontRegular,
                      borderColor: borderColor,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),

              // System watermark
              pw.Center(
                child: pw.Text(
                  'System-generated Official Post-Repair Document | PSU Maintenance Management Portal',
                  style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: textMuted),
                ),
              ),
            ],
          );
        },
      ),
    );

    // ── 6. ANNEX: WORK EVIDENCE & BEFORE/AFTER PHOTO DOCUMENTATION ─────────
    if (annexChunks.isNotEmpty) {
      for (int pIdx = 0; pIdx < annexChunks.length; pIdx++) {
        pdf.addPage(
          _buildEvidencePage(
            images: annexChunks[pIdx],
            pageIndex: pIdx,
            totalPages: annexChunks.length,
            documentTitle: 'POST-REPAIR ACCOMPLISHMENT & WORK EVIDENCE',
            trackingNo: request.formattedId,
            psuLogo: psuLogo,
            fontBold: fontBold,
            fontRegular: fontRegular,
            primaryColor: primaryColor,
            borderColor: borderColor,
            headerBg: headerBg,
            textDark: textDark,
            textMuted: textMuted,
          ),
        );
      }
    }

    return pdf.save();
  }

  // ===========================================================================
  // PRINT EXECUTION METHODS
  // ===========================================================================

  static Future<void> printPreInspection({
    required BuildContext context,
    required WorkRequest request,
    required PreInspectionReport report,
    List<ESignature>? signatures,
  }) async {
    // Show smooth modern loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preparing Pre-Inspection Report...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Compiling assessment & photographic evidence',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
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
    );

    try {
      final pdfBytes = await generatePreInspectionPdf(
        request: request,
        report: report,
        signatures: signatures,
      );
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'Pre_Inspection_Report_${request.formattedId}',
        format: pageFormat,
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing pre-inspection report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static Future<void> printPostRepair({
    required BuildContext context,
    required WorkRequest request,
    required PostRepairReport report,
    List<ESignature>? signatures,
  }) async {
    // Show smooth modern loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preparing Post-Repair Report...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Compiling accomplishment & before/after evidence',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
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
    );

    try {
      final pdfBytes = await generatePostRepairPdf(
        request: request,
        report: report,
        signatures: signatures,
      );
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'Post_Repair_Report_${request.formattedId}_Attempt_${report.attemptNumber}',
        format: pageFormat,
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing post-repair report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ===========================================================================
  // HELPER WIDGET BUILDERS (PDF)
  // ===========================================================================

  static pw.Page _buildEvidencePage({
    required List<_PdfEvidenceImage> images,
    required int pageIndex,
    required int totalPages,
    required String documentTitle,
    required String trackingNo,
    required pw.MemoryImage? psuLogo,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required PdfColor primaryColor,
    required PdfColor borderColor,
    required PdfColor headerBg,
    required PdfColor textDark,
    required PdfColor textMuted,
  }) {
    return pw.Page(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(28),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Institutional Header
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 10),
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: primaryColor, width: 2)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (psuLogo != null)
                    pw.Container(
                      width: 42,
                      height: 42,
                      margin: const pw.EdgeInsets.only(right: 12),
                      child: pw.Image(psuLogo),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PANGASINAN STATE UNIVERSITY',
                          style: pw.TextStyle(font: fontBold, fontSize: 11, color: primaryColor),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'ANNEX: PHOTOGRAPHIC WORK EVIDENCE & DOCUMENTATION',
                          style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: textDark),
                        ),
                        pw.Text(
                          documentTitle,
                          style: pw.TextStyle(font: fontRegular, fontSize: 8, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: headerBg,
                      border: pw.Border.all(color: borderColor),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('TRACKING NO: $trackingNo', style: pw.TextStyle(font: fontBold, fontSize: 8, color: primaryColor)),
                        pw.Text('ANNEX PAGE: ${pageIndex + 1} OF $totalPages', style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 12),

            // Content Grid
            pw.Expanded(
              child: _buildEvidenceGrid(
                images,
                fontBold,
                fontRegular,
                borderColor,
                headerBg,
                textDark,
                textMuted,
                primaryColor,
              ),
            ),

            pw.SizedBox(height: 8),

            // Watermark Footer
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Official Photographic Record | PSU Physical Plant & Facilities Management',
                    style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: textMuted),
                  ),
                  pw.Text(
                    'Doc Ref: $trackingNo | Verified Evidence',
                    style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: textMuted),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static pw.Widget _buildEvidenceGrid(
    List<_PdfEvidenceImage> items,
    pw.Font fontBold,
    pw.Font fontRegular,
    PdfColor borderColor,
    PdfColor headerBg,
    PdfColor textDark,
    PdfColor textMuted,
    PdfColor primaryColor,
  ) {
    if (items.isEmpty) return pw.SizedBox.shrink();

    if (items.length == 1) {
      final item = items[0];
      return pw.Center(
        child: _buildEvidenceCard(
          item: item,
          width: 480,
          height: 480,
          fontBold: fontBold,
          fontRegular: fontRegular,
          borderColor: borderColor,
          headerBg: headerBg,
          textDark: textDark,
          textMuted: textMuted,
          primaryColor: primaryColor,
        ),
      );
    }

    if (items.length == 2) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: items.map((item) {
          return _buildEvidenceCard(
            item: item,
            width: 260,
            height: 480,
            fontBold: fontBold,
            fontRegular: fontRegular,
            borderColor: borderColor,
            headerBg: headerBg,
            textDark: textDark,
            textMuted: textMuted,
            primaryColor: primaryColor,
          );
        }).toList(),
      );
    }

    // 3 or 4 items: 2x2 grid
    final row1 = items.sublist(0, 2);
    final row2 = items.sublist(2);

    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: row1.map((item) {
            return _buildEvidenceCard(
              item: item,
              width: 260,
              height: 290,
              fontBold: fontBold,
              fontRegular: fontRegular,
              borderColor: borderColor,
              headerBg: headerBg,
              textDark: textDark,
              textMuted: textMuted,
              primaryColor: primaryColor,
            );
          }).toList(),
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: row2.map((item) {
            return _buildEvidenceCard(
              item: item,
              width: 260,
              height: 290,
              fontBold: fontBold,
              fontRegular: fontRegular,
              borderColor: borderColor,
              headerBg: headerBg,
              textDark: textDark,
              textMuted: textMuted,
              primaryColor: primaryColor,
            );
          }).toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildEvidenceCard({
    required _PdfEvidenceImage item,
    required double width,
    required double height,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required PdfColor borderColor,
    required PdfColor headerBg,
    required PdfColor textDark,
    required PdfColor textMuted,
    required PdfColor primaryColor,
  }) {
    final badgeColor = item.tagColor ?? primaryColor;

    return pw.Container(
      width: width,
      height: height,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: borderColor, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Card Header with Badge
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: headerBg,
              border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 0.8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: pw.BoxDecoration(
                    color: badgeColor,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Text(
                    item.label.toUpperCase(),
                    style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.white),
                  ),
                ),
                pw.Text(
                  'CONFIRMED ATTACHMENT',
                  style: pw.TextStyle(font: fontBold, fontSize: 6.5, color: textMuted),
                ),
              ],
            ),
          ),

          // Image display
          pw.Expanded(
            child: pw.Container(
              color: PdfColor.fromHex('F8FAFC'),
              padding: const pw.EdgeInsets.all(6),
              child: pw.Center(
                child: pw.Image(item.image, fit: pw.BoxFit.contain),
              ),
            ),
          ),

          // Caption
          if (item.caption != null && item.caption!.trim().isNotEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.8)),
              ),
              child: pw.Text(
                item.caption!.trim(),
                maxLines: 2,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: textDark),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionHeader(String title, PdfColor color, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Text(
        title,
        style: pw.TextStyle(font: font, fontSize: 8.5, color: color, letterSpacing: 0.5),
      ),
    );
  }

  static pw.TableRow _buildTableRow(
    String label1,
    String val1,
    String label2,
    String val2,
    pw.Font fontBold,
    pw.Font fontRegular,
    PdfColor? bgColor,
    PdfColor borderColor,
  ) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bgColor),
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: borderColor))),
          child: pw.Text(label1, style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColor.fromHex('475569'))),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: borderColor))),
          child: pw.Text(val1, style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColor.fromHex('0F172A'))),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: borderColor))),
          child: pw.Text(label2, style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColor.fromHex('475569'))),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(val2, style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColor.fromHex('0F172A'))),
        ),
      ],
    );
  }

  static pw.Widget _buildDetailField(String label, String value, pw.Font fontBold, pw.Font fontRegular) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColor.fromHex('64748B'))),
        pw.SizedBox(height: 1),
        pw.Text(value, style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColor.fromHex('0F172A'))),
      ],
    );
  }

  static pw.Widget _buildSignatureCell({
    required String label,
    required String name,
    required String role,
    required pw.MemoryImage? signatureImage,
    required DateTime date,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required PdfColor borderColor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColor.fromHex('475569'))),
        pw.SizedBox(height: 3),
        pw.Container(
          height: 48,
          alignment: pw.Alignment.bottomLeft,
          child: signatureImage != null
              ? pw.Image(signatureImage, height: 42, fit: pw.BoxFit.contain)
              : pw.SizedBox(height: 42),
        ),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: borderColor, width: 1)),
          ),
          padding: const pw.EdgeInsets.only(top: 3),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(name.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColor.fromHex('0F172A'))),
              pw.Text(role, style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: PdfColor.fromHex('64748B'))),
              pw.Text('Date Signed: ${DateFormat('MM/dd/yyyy').format(date)}', style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColor.fromHex('94A3B8'))),
            ],
          ),
        ),
      ],
    );
  }
}

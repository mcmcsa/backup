import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/work_request_model.dart';

class AdminReportPrintService {
  /// Loads PSU Seal logo for the PDF header
  static Future<pw.MemoryImage?> _loadPsuLogo() async {
    try {
      final data = await rootBundle.load('assets/images/PsuLogo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// Formats date for display in reports
  static String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('MMM dd, yyyy').format(dt);
  }

  /// Formats timestamp with time for the header
  static String _formatDateTime(DateTime dt) {
    return DateFormat('MMMM dd, yyyy | hh:mm a').format(dt);
  }

  /// Returns text color for status badge in PDF
  static PdfColor _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('completed')) return PdfColor.fromHex('15803D'); // green
    if (s.contains('progress') || s.contains('maintenance')) return PdfColor.fromHex('0369A1'); // sky blue
    if (s.contains('pending') || s.contains('queue')) return PdfColor.fromHex('D97706'); // amber
    if (s.contains('rework')) return PdfColor.fromHex('7C3AED'); // purple
    if (s.contains('decline') || s.contains('cancel')) return PdfColor.fromHex('DC2626'); // red
    return PdfColor.fromHex('475569'); // slate
  }

  /// Prints a professional PSU Campus Admin report containing ONLY records within the selected date range.
  static Future<void> printReport({
    required BuildContext context,
    required String reportTitle,
    required List<WorkRequest> requests,
    DateTime? startDate,
    DateTime? endDate,
    String? statusFilter,
    String? searchQuery,
    String campusName = 'San Carlos Campus',
    String subtitle = 'Campus Maintenance & Facilities Management Portal',
  }) async {
    // Strictly filter records if a custom date range is provided
    List<WorkRequest> recordsToPrint = List<WorkRequest>.from(requests);

    if (startDate != null && endDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

      recordsToPrint = recordsToPrint.where((r) {
        return !r.dateSubmitted.isBefore(start) && !r.dateSubmitted.isAfter(end);
      }).toList();
    }

    // Sort by newest date submitted first
    recordsToPrint.sort((a, b) => b.dateSubmitted.compareTo(a.dateSubmitted));

    if (recordsToPrint.isEmpty) {
      if (context.mounted) {
        final periodMsg = (startDate != null && endDate != null)
            ? 'for the selected period (${_formatDate(startDate)} to ${_formatDate(endDate)})'
            : 'matching the current filter';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No records found $periodMsg to print.'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final psuLogo = await _loadPsuLogo();
    final pdf = pw.Document();

    final dateRangeLabel = (startDate != null && endDate != null)
        ? '${_formatDate(startDate)} to ${_formatDate(endDate)}'
        : 'All Available Records (All-Time)';

    final isCustomRange = startDate != null && endDate != null;
    final totalCount = recordsToPrint.length;

    final primaryColor = PdfColor.fromHex('0F766E'); // PSU Teal / Deep Emerald
    final headerBgColor = PdfColor.fromHex('0F766E');
    final rowAltColor = PdfColor.fromHex('F8FAFC');
    final borderColor = PdfColor.fromHex('CBD5E1');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 22),
        header: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (psuLogo != null) ...[
                    pw.Container(
                      width: 48,
                      height: 48,
                      child: pw.Image(psuLogo, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 14),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PANGASINAN STATE UNIVERSITY',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '$subtitle | $campusName',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                        ),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          'OFFICE OF THE CAMPUS ADMINISTRATOR',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: isCustomRange ? PdfColor.fromHex('FEF3C7') : PdfColor.fromHex('F1F5F9'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          border: pw.Border.all(
                            color: isCustomRange ? PdfColor.fromHex('F59E0B') : borderColor,
                          ),
                        ),
                        child: pw.Text(
                          isCustomRange ? 'CUSTOM DATE RANGE' : 'OFFICIAL REPORT',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: isCustomRange ? PdfColor.fromHex('B45309') : PdfColors.grey800,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Generated: ${_formatDateTime(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                height: 2,
                color: primaryColor,
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
        footer: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'PSU E-Ayos Maintenance Management System | Confidential Official Record',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor),
                ),
              ],
            ),
          );
        },
        build: (pw.Context ctx) {
          return [
            // Report Title Banner & Filter Metadata
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('F8FAFC'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: borderColor),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          reportTitle.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.RichText(
                          text: pw.TextSpan(
                            text: 'Covered Period: ',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                            children: [
                              pw.TextSpan(
                                text: dateRangeLabel,
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All' && statusFilter != 'all') ...[
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Status Filter:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                          pw.Text(
                            statusFilter.toUpperCase(),
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _statusColor(statusFilter)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Total Records in Range', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        pw.Text(
                          '$totalCount records',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 14),

            // Records Table
            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(24), // #
                1: pw.FixedColumnWidth(80), // Tracking ID
                2: pw.FixedColumnWidth(66), // Date
                3: pw.FlexColumnWidth(2.0), // Requestor & Dept
                4: pw.FlexColumnWidth(2.0), // Location
                5: pw.FlexColumnWidth(2.5), // Request Title / Type
                6: pw.FixedColumnWidth(52), // Priority
                7: pw.FixedColumnWidth(68), // Status
                8: pw.FlexColumnWidth(1.6), // Assigned / Completed
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: headerBgColor),
                  children: [
                    _tableHeaderCell('#', align: pw.TextAlign.center),
                    _tableHeaderCell('TRACKING ID'),
                    _tableHeaderCell('DATE SUBMITTED', align: pw.TextAlign.center),
                    _tableHeaderCell('REQUESTOR & DEPT'),
                    _tableHeaderCell('LOCATION / ROOM'),
                    _tableHeaderCell('REQUEST DETAILS'),
                    _tableHeaderCell('PRIORITY', align: pw.TextAlign.center),
                    _tableHeaderCell('STATUS', align: pw.TextAlign.center),
                    _tableHeaderCell('COMPLETED / ASSIGNED'),
                  ],
                ),
                // Data Rows
                ...recordsToPrint.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final r = entry.value;
                  final isEven = index % 2 == 0;

                  final locationStr = [
                    if (r.buildingName?.isNotEmpty == true) r.buildingName,
                    if (r.roomName?.isNotEmpty == true) r.roomName
                    else if (r.officeRoom?.isNotEmpty == true) r.officeRoom,
                  ].join(' | ');

                  final reqDept = [
                    r.requestorName,
                    if (r.department?.isNotEmpty == true) '(${r.department})'
                    else if (r.departmentName?.isNotEmpty == true) '(${r.departmentName})',
                  ].join(' ');

                  final completedOrAssigned = r.dateCompleted != null
                      ? 'Done: ${_formatDate(r.dateCompleted)}'
                      : (r.acceptedByName?.isNotEmpty == true ? 'Tech: ${r.acceptedByName}' : 'Unassigned');

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? rowAltColor : PdfColors.white,
                    ),
                    children: [
                      _tableDataCell('$index', align: pw.TextAlign.center, isMuted: true),
                      _tableDataCell(r.formattedId, isBold: true),
                      _tableDataCell(_formatDate(r.dateSubmitted), align: pw.TextAlign.center),
                      _tableDataCell(reqDept),
                      _tableDataCell(locationStr.isNotEmpty ? locationStr : '-'),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              r.typeDisplay.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 6.5,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            pw.Text(
                              r.title,
                              style: const pw.TextStyle(fontSize: 7.5),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                      _tablePriorityCell(r.priority),
                      _tableStatusCell(r.status),
                      _tableDataCell(completedOrAssigned),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 24),

            // Sign-off Block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Report Generated By:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.SizedBox(height: 22),
                    pw.Container(width: 170, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 3),
                    pw.Text('CAMPUS ADMINISTRATOR', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text('PSU $campusName', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Verified / Noted By:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.SizedBox(height: 22),
                    pw.Container(width: 170, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 3),
                    pw.Text('HEAD, PHYSICAL PLANT & FACILITIES', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date: ________________________', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    final cleanFileName = 'PSU_${reportTitle.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: cleanFileName,
      format: PdfPageFormat.letter.landscape,
    );
  }

  static pw.Widget _tableHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  static pw.Widget _tableDataCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
    bool isMuted = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isMuted ? PdfColors.grey600 : PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _tablePriorityCell(String priority) {
    PdfColor color;
    final p = priority.toLowerCase();
    if (p == 'urgent' || p == 'emergency') {
      color = PdfColor.fromHex('DC2626');
    } else if (p == 'high') {
      color = PdfColor.fromHex('EA580C');
    } else if (p == 'medium') {
      color = PdfColor.fromHex('D97706');
    } else {
      color = PdfColor.fromHex('16A34A');
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Center(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: pw.BoxDecoration(
            color: color.luminance > 0.5 ? color : PdfColors.white,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            border: pw.Border.all(color: color, width: 0.5),
          ),
          child: pw.Text(
            priority.toUpperCase(),
            style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: color),
          ),
        ),
      ),
    );
  }

  static pw.Widget _tableStatusCell(String status) {
    final color = _statusColor(status);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Center(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: pw.BoxDecoration(
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            border: pw.Border.all(color: color, width: 0.5),
          ),
          child: pw.Text(
            status.toUpperCase(),
            style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: color),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

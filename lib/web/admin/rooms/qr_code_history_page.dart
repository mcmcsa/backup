import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../shared/models/qr_code_history_model.dart';
import '../../../shared/services/qr_code_history_service.dart';

class QRCodeHistoryPage extends StatefulWidget {
  const QRCodeHistoryPage({super.key});

  @override
  State<QRCodeHistoryPage> createState() => _QRCodeHistoryPageState();
}

class _QRCodeHistoryPageState extends State<QRCodeHistoryPage> {
  List<QRCodeHistory> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await QRCodeHistoryService.getHistory();
      if (mounted) setState(() { _history = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  pw.Widget _buildPrintableQrCard(QRCodeHistory qr) {
    final roomLabel = (qr.roomName != null && qr.roomName!.trim().isNotEmpty)
        ? qr.roomName!
        : (qr.roomId != null && qr.roomId!.trim().isNotEmpty)
            ? qr.roomId!
            : 'Room QR';

    return pw.Container(
      width: 240,
      margin: const pw.EdgeInsets.only(bottom: 18),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            roomLabel,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          if ((qr.roomId ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'ID: ${qr.roomId}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
          if ((qr.building ?? '').isNotEmpty || (qr.department ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              [
                if ((qr.building ?? '').isNotEmpty) qr.building!,
                if ((qr.department ?? '').isNotEmpty) qr.department!,
              ].join(' • '),
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.center,
            ),
          ],
          pw.SizedBox(height: 12),
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: qr.qrCodeValue,
            width: 135,
            height: 135,
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Created: ${_formatDate(qr.createdAt)}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  Future<void> _printSingleQr(QRCodeHistory qr) async {
    try {
      final doc = pw.Document();
      final roomLabel = (qr.roomName != null && qr.roomName!.trim().isNotEmpty)
          ? qr.roomName!
          : 'Room QR';

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Room QR Code',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  roomLabel,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                if ((qr.building ?? '').isNotEmpty || (qr.department ?? '').isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    [
                      if ((qr.building ?? '').isNotEmpty) qr.building!,
                      if ((qr.department ?? '').isNotEmpty) qr.department!,
                    ].join(' • '),
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
                pw.SizedBox(height: 28),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qr.qrCodeValue,
                  width: 220,
                  height: 220,
                ),
                pw.SizedBox(height: 20),
                pw.Text('Created: ${_formatDate(qr.createdAt)}', style: const pw.TextStyle(fontSize: 11)),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: '${roomLabel.replaceAll(' ', '_')}_QR.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to print QR code: $e')),
      );
    }
  }

  Future<void> _printAllQr() async {
    final printableHistory = _history
        .where((qr) => qr.qrCodeValue.trim().isNotEmpty)
        .toList();

    if (printableHistory.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No QR codes available to print.')),
      );
      return;
    }

    try {
      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Text(
              'QR Code History',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '${printableHistory.length} QR code${printableHistory.length == 1 ? '' : 's'} from this page',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 18),
            pw.Wrap(
              spacing: 14,
              runSpacing: 14,
              alignment: pw.WrapAlignment.start,
              children: printableHistory.map(_buildPrintableQrCard).toList(),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'All_Room_QR_Codes.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to print all QR codes: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'QR Code History',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _history.isEmpty ? null : _printAllQr,
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text(
                'Print All',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_2, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No QR codes generated yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final qr = _history[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: QrImageView(
                                data: qr.qrCodeValue,
                                version: QrVersions.auto,
                                size: 72,
                                gapless: true,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    qr.roomName ?? qr.qrCodeValue,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (qr.building != null && qr.building!.isNotEmpty || qr.department != null && qr.department!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        if (qr.building != null && qr.building!.isNotEmpty) qr.building!,
                                        if (qr.department != null && qr.department!.isNotEmpty) qr.department!,
                                      ].join(' • '),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF4169E1).withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    'Created: ${_formatDate(qr.createdAt)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.qr_code_scanner, size: 14, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${qr.scannedCount} scan${qr.scannedCount != 1 ? 's' : ''}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      if (qr.lastScanned != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '• Last: ${_formatDate(qr.lastScanned!)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: qr.isActive
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    qr.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: qr.isActive ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _printSingleQr(qr),
                                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                                  label: const Text('Print', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    side: BorderSide(color: const Color(0xFF4169E1).withValues(alpha: 0.35)),
                                    foregroundColor: const Color(0xFF4169E1),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

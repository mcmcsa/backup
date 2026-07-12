import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../shared/models/qr_code_history_model.dart';
import '../../../../shared/services/room_service.dart';
import '../../../../shared/services/qr_code_history_service.dart';
import '../../shared/admin_styles.dart';

class AdminQrHistoryPageWeb extends StatefulWidget {
  const AdminQrHistoryPageWeb({super.key});

  @override
  State<AdminQrHistoryPageWeb> createState() => _AdminQrHistoryPageWebState();
}

class _AdminQrHistoryPageWebState extends State<AdminQrHistoryPageWeb> {
  List<QRCodeHistory> _history = [];
  Map<String, String> _roomCodeById = {};
  Map<String, String> _roomNameById = {};
  Map<String, String> _roomNameByCode = {};
  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  bool _isLoading = true;

  List<QRCodeHistory> get _visibleHistory {
    if (_filterStartDate == null && _filterEndDate == null) {
      return _history;
    }

    final start = _filterStartDate != null
        ? DateTime(
            _filterStartDate!.year,
            _filterStartDate!.month,
            _filterStartDate!.day,
          )
        : null;
    final end = _filterEndDate != null
        ? DateTime(
            _filterEndDate!.year,
            _filterEndDate!.month,
            _filterEndDate!.day,
          )
        : null;

    return _history.where((item) {
      final created = DateTime(
        item.createdAt.year,
        item.createdAt.month,
        item.createdAt.day,
      );
      if (start != null && created.isBefore(start)) return false;
      if (end != null && created.isAfter(end)) return false;
      return true;
    }).toList();
  }

  bool get _hasDateFilter => _filterStartDate != null || _filterEndDate != null;

  int get _activeCount => _visibleHistory.where((item) => item.isActive).length;

  int get _totalScans =>
      _visibleHistory.fold<int>(0, (sum, item) => sum + item.scannedCount);

  DateTime? get _latestCreatedAt {
    if (_visibleHistory.isEmpty) return null;

    DateTime latest = _visibleHistory.first.createdAt;
    for (final item in _visibleHistory.skip(1)) {
      if (item.createdAt.isAfter(latest)) {
        latest = item.createdAt;
      }
    }
    return latest;
  }

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    _loadHistory();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await QRCodeHistoryService.getHistory();
      final rooms = await RoomService.fetchAll();

      final roomCodeById = <String, String>{};
      final roomNameById = <String, String>{};
      final roomNameByCode = <String, String>{};
      for (final room in rooms) {
        final roomId = room.id.trim();
        final roomCode = room.code.trim();
        final roomName = room.name.trim();

        if (roomId.isNotEmpty) {
          roomCodeById[roomId] = roomCode.isNotEmpty ? roomCode : roomId;
          roomNameById[roomId] = roomName;
        }

        if (roomCode.isNotEmpty && roomName.isNotEmpty) {
          roomNameByCode[roomCode.toLowerCase()] = roomName;
        }
      }

      if (mounted) {
        setState(() {
          _history = data;
          _roomCodeById = roomCodeById;
          _roomNameById = roomNameById;
          _roomNameByCode = roomNameByCode;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final dateText = _formatDate(date);
    final hour24 = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$dateText, $hour12:$minute $period';
  }

  String _formatLiveDateTime(DateTime date) {
    final dateText = _formatDate(date);
    final hour24 = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$dateText, $hour12:$minute:$second $period';
  }

  String _timeAgo(DateTime date) {
    final diff = _now.difference(date);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDate: _filterStartDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      _filterStartDate = picked;
      if (_filterEndDate != null && _filterEndDate!.isBefore(picked)) {
        _filterEndDate = picked;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDate: _filterEndDate ?? _filterStartDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    if (_filterStartDate != null && picked.isBefore(_filterStartDate!)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date cannot be earlier than start date.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _filterEndDate = picked;
    });
  }

  void _clearDateFilter() {
    setState(() {
      _filterStartDate = null;
      _filterEndDate = null;
    });
  }

  bool _looksLikeUuid(String value) {
    final normalized = value.trim();
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(normalized);
  }

  String _extractRoomCodeText(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '';

    if (normalized.contains(' - ')) {
      final codePart = normalized.split(' - ').first.trim();
      if (codePart.isNotEmpty) return codePart;
    }

    return normalized;
  }

  String _resolvePrintableRoomCode(QRCodeHistory qr) {
    final roomName = _extractRoomCodeText(qr.roomName ?? '');
    if (roomName.isNotEmpty && !_looksLikeUuid(roomName)) {
      return roomName;
    }

    final qrValue = _extractRoomCodeText(qr.qrCodeValue);
    if (qrValue.isNotEmpty && !_looksLikeUuid(qrValue)) {
      return qrValue;
    }

    return 'Room QR';
  }

  String _resolveDisplayRoomCode(QRCodeHistory qr) {
    final roomId = (qr.roomId ?? '').trim();
    if (roomId.isNotEmpty) {
      final code = _roomCodeById[roomId] ?? '';
      if (code.isNotEmpty) return code;
    }

    final parsed = _extractRoomCodeText(qr.roomName ?? '');
    if (parsed.isNotEmpty && !_looksLikeUuid(parsed)) {
      final looksLikeRoomCode = RegExp(
        r'^rm\d+$',
        caseSensitive: false,
      ).hasMatch(parsed);
      if (looksLikeRoomCode) return parsed;
    }

    return '-';
  }

  String _resolveDisplayRoomName(QRCodeHistory qr) {
    final roomId = (qr.roomId ?? '').trim();
    if (roomId.isNotEmpty) {
      final name = _roomNameById[roomId] ?? '';
      if (name.isNotEmpty) return name;
    }

    final parsed = _extractRoomCodeText(qr.roomName ?? '');
    if (parsed.isNotEmpty && !_looksLikeUuid(parsed)) {
      final matchedName = _roomNameByCode[parsed.toLowerCase()];
      if (matchedName != null && matchedName.isNotEmpty) return matchedName;

      final looksLikeRoomCode = RegExp(
        r'^rm\d+$',
        caseSensitive: false,
      ).hasMatch(parsed);
      if (!looksLikeRoomCode) return parsed;
    }

    return '-';
  }

  pw.Widget _buildPrintableQrCard(QRCodeHistory qr) {
    final roomLabel = _resolvePrintableRoomCode(qr);

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
          if ((qr.building ?? '').isNotEmpty ||
              (qr.department ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              [
                if ((qr.building ?? '').isNotEmpty) qr.building!,
                if ((qr.department ?? '').isNotEmpty) qr.department!,
              ].join(' - '),
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
      final roomLabel = _resolvePrintableRoomCode(qr);

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
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  roomLabel,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if ((qr.building ?? '').isNotEmpty ||
                    (qr.department ?? '').isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    [
                      if ((qr.building ?? '').isNotEmpty) qr.building!,
                      if ((qr.department ?? '').isNotEmpty) qr.department!,
                    ].join(' - '),
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
                pw.Text(
                  'Created: ${_formatDate(qr.createdAt)}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to print QR code: $e')));
    }
  }

  Future<void> _printAllQr() async {
    final printableHistory = _visibleHistory
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final isTablet =
            constraints.maxWidth >= 768 && constraints.maxWidth < 1100;

        return Container(
          color: const Color(0xFFF2F6FC),
          child: Stack(
            children: [
              Positioned(
                top: -120,
                right: -140,
                child: _buildBackgroundGlow(
                  size: isMobile ? 260 : 360,
                  colors: const [Color(0xFFDFF4FF), Color(0x00DFF4FF)],
                ),
              ),
              Positioned(
                top: 80,
                left: -100,
                child: _buildBackgroundGlow(
                  size: isMobile ? 210 : 280,
                  colors: const [Color(0xFFE9EEFF), Color(0x00E9EEFF)],
                ),
              ),
              SingleChildScrollView(
                primary: false,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile
                      ? 14
                      : isTablet
                      ? 22
                      : 32,
                  vertical: isMobile ? 16 : 28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroHeader(),
                        SizedBox(height: isMobile ? 14 : 18),
                        _buildOverviewStats(),
                        SizedBox(height: isMobile ? 14 : 18),
                        _buildMainPanel(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackgroundGlow({
    required double size,
    required List<Color> colors,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 24,
            isMobile ? 16 : 22,
            isMobile ? 16 : 24,
            isMobile ? 16 : 22,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(isMobile ? 14 : 18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3326354A),
                blurRadius: 26,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room QR History',
                      style: AdminStyles.headingStyle(
                        fontSize: isMobile ? 24 : 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Review generated room QR codes, monitor usage trends, and print professional labels for onsite operations.',
                      style: AdminStyles.bodyStyle(
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFDDE6FF),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x26FFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x45FFFFFF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_visibleHistory.length} total QR code${_visibleHistory.length == 1 ? '' : 's'}',
                      style: AdminStyles.bodyStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewStats() {
    final latestDate = _latestCreatedAt != null
        ? _formatDate(_latestCreatedAt!)
        : 'No records';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 680;
        final isTablet =
            constraints.maxWidth >= 680 && constraints.maxWidth < 1180;
        final cardWidth = isMobile
            ? constraints.maxWidth
            : isTablet
            ? (constraints.maxWidth - 14) / 2
            : (constraints.maxWidth - 42) / 4;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _buildStatCard(
              title: 'Generated',
              value: '${_history.length}',
              caption: 'Room QR records in this list',
              icon: Icons.inventory_2_outlined,
              accent: const Color(0xFF2563EB),
              cardWidth: cardWidth,
              mobile: isMobile,
            ),
            _buildStatCard(
              title: 'Active QR',
              value: '$_activeCount',
              caption: 'Currently enabled for scanning',
              icon: Icons.verified_outlined,
              accent: const Color(0xFF059669),
              cardWidth: cardWidth,
              mobile: isMobile,
            ),
            _buildStatCard(
              title: 'Total Scans',
              value: '$_totalScans',
              caption: 'Combined scans across all codes',
              icon: Icons.query_stats_rounded,
              accent: const Color(0xFF7C3AED),
              cardWidth: cardWidth,
              mobile: isMobile,
            ),
            _buildStatCard(
              title: 'Last Created',
              value: latestDate,
              caption: 'Most recent generated QR',
              icon: Icons.event_available_outlined,
              accent: const Color(0xFFEA580C),
              cardWidth: cardWidth,
              mobile: isMobile,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String caption,
    required IconData icon,
    required Color accent,
    required double cardWidth,
    required bool mobile,
  }) {
    return Container(
      width: cardWidth,
      padding: EdgeInsets.all(mobile ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1223344A),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AdminStyles.bodyStyle(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AdminStyles.headingStyle(
                    fontSize: mobile ? 18 : 20,
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: AdminStyles.bodyStyle(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final visibleHistory = _visibleHistory;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            isMobile ? 12 : 18,
            isMobile ? 12 : 18,
            isMobile ? 12 : 18,
            8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1223344A),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildToolbar(),
              const SizedBox(height: 10),
              _buildDateFilterFields(isMobile: isMobile),
              const SizedBox(height: 14),
              if (!isMobile) ...[_buildListHeader(), const SizedBox(height: 8)],
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                  ),
                )
              else if (visibleHistory.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _buildEmptyState(),
                )
              else
                ...visibleHistory.map(_buildHistoryCard),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 720;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            isMobile ? 12 : 16,
            isMobile ? 12 : 14,
            isMobile ? 12 : 16,
            isMobile ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            spacing: 12,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.grid_view_rounded,
                        color: Color(0xFF1D4ED8),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Generated QR Codes',
                            style: AdminStyles.headingStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _hasDateFilter
                                ? 'Filtered results: ${_visibleHistory.length} record${_visibleHistory.length == 1 ? '' : 's'}'
                                : 'Manage, review, and print room QR code records. Live: ${_formatLiveDateTime(_now)}',
                            style: AdminStyles.bodyStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    height: 44,
                    width: isMobile ? double.infinity : null,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _loadHistory,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF334155),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    width: isMobile ? double.infinity : null,
                    child: ElevatedButton.icon(
                      onPressed: _visibleHistory.isEmpty ? null : _printAllQr,
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Print All QR Codes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateFilterFields({required bool isMobile}) {
    final fromLabel = _filterStartDate == null
        ? 'From date'
        : _formatDate(_filterStartDate!);
    final toLabel = _filterEndDate == null
        ? 'To date'
        : _formatDate(_filterEndDate!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: isMobile ? double.infinity : 210,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: _pickStartDate,
              icon: const Icon(Icons.date_range_rounded, size: 16),
              label: Text(fromLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF334155),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 210,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: _pickEndDate,
              icon: const Icon(Icons.event_rounded, size: 16),
              label: Text(toLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF334155),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          SizedBox(
            width: isMobile ? double.infinity : 110,
            height: 42,
            child: TextButton.icon(
              onPressed: _hasDateFilter ? _clearDateFilter : null,
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF475569),
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if (_hasDateFilter)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF93C5FD)),
              ),
              child: Text(
                '${_visibleHistory.length} filtered',
                style: AdminStyles.bodyStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D4ED8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        'Room Code / Room Name / Created Date & Time',
        style: AdminStyles.bodyStyle(
          fontSize: 12,
          color: const Color(0xFF64748B),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.qr_code_2_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(
            'No QR codes generated yet',
            style: AdminStyles.headingStyle(
              fontSize: 20,
              color: const Color(0xFF334155),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Generate a room QR code first and it will appear here.',
            style: AdminStyles.bodyStyle(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(QRCodeHistory qr) {
    final roomCode = _resolveDisplayRoomCode(qr);
    final roomName = _resolveDisplayRoomName(qr);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 920;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQrPreview(qr, compact: true),
                    const SizedBox(height: 12),
                    _buildRoomDetails(
                      roomCode: roomCode,
                      roomName: roomName,
                      createdAt: qr.createdAt,
                    ),
                    const SizedBox(height: 12),
                    _buildStatusAndAction(qr, alignEnd: false),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildQrPreview(qr, compact: false),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildRoomDetails(
                        roomCode: roomCode,
                        roomName: roomName,
                        createdAt: qr.createdAt,
                      ),
                    ),
                    const SizedBox(width: 14),
                    _buildStatusAndAction(qr, alignEnd: true),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildQrPreview(QRCodeHistory qr, {required bool compact}) {
    final previewSize = compact ? 84.0 : 96.0;
    final qrSize = compact ? 70.0 : 82.0;

    return Container(
      width: previewSize,
      height: previewSize,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: QrImageView(
        data: qr.qrCodeValue,
        version: QrVersions.auto,
        size: qrSize,
        gapless: true,
      ),
    );
  }

  Widget _buildRoomDetails({
    required String roomCode,
    required String roomName,
    required DateTime createdAt,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Room Code:',
              style: AdminStyles.bodyStyle(
                fontSize: 13,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                roomCode,
                style: AdminStyles.headingStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'Room Name:',
              style: AdminStyles.bodyStyle(
                fontSize: 13,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                roomName,
                style: AdminStyles.bodyStyle(
                  fontSize: 14,
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'Created:',
              style: AdminStyles.bodyStyle(
                fontSize: 13,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_formatDateTime(createdAt)} • ${_timeAgo(createdAt)}',
                style: AdminStyles.bodyStyle(
                  fontSize: 13,
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusAndAction(QRCodeHistory qr, {required bool alignEnd}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: qr.isActive
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: qr.isActive
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFFFCA5A5),
            ),
          ),
          child: Text(
            qr.isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: qr.isActive
                  ? const Color(0xFF166534)
                  : const Color(0xFFB91C1C),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: OutlinedButton.icon(
            onPressed: () => _printSingleQr(qr),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: const Text('Print'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF93C5FD)),
              foregroundColor: const Color(0xFF1D4ED8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}

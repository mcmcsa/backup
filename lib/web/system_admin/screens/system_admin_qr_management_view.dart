import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/qr_code_history_model.dart';
import '../../../shared/models/room_model.dart';
import '../../../shared/services/qr_code_history_service.dart';
import '../../../shared/services/room_service.dart';
import '../../admin/shared/admin_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Main Widget
// ─────────────────────────────────────────────────────────────────────────────

class SystemAdminQrManagementView extends StatefulWidget {
  const SystemAdminQrManagementView({super.key});

  @override
  State<SystemAdminQrManagementView> createState() =>
      _SystemAdminQrManagementViewState();
}

class _SystemAdminQrManagementViewState
    extends State<SystemAdminQrManagementView> {
  // ── Data ──────────────────────────────────────────────────────────────────
  List<QRCodeHistory> _qrHistory = [];
  Map<String, Room> _roomsMap = {};
  bool _loading = true;
  String? _error;

  // ── Filters ───────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all'; // 'all' | 'active' | 'inactive'
  bool _isGridView = false;

  // ── Pagination ────────────────────────────────────────────────────────────
  static const _pageSize = 12;
  int _page = 0;

  // ── Sort ──────────────────────────────────────────────────────────────────
  String _sortField = 'created'; // 'created' | 'scans'
  bool _sortAsc = false;

  RealtimeChannel? _syncChannel;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _page = 0));
    _load();
    _setupRealtime();
  }

  void _setupRealtime() {
    _syncChannel = Supabase.instance.client
        .channel('system_admin_qr_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'qr_code_history',
          callback: (payload) {
            if (mounted) _load();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rooms',
          callback: (payload) {
            if (mounted) _load();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _syncChannel?.unsubscribe();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Data
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        QRCodeHistoryService.fetchAllHistory(),
        RoomService.fetchAll(),
      ]);

      final history = results[0] as List<QRCodeHistory>;
      final rooms = results[1] as List<Room>;

      final map = <String, Room>{};
      for (var r in rooms) {
        map[r.id] = r;
      }

      if (mounted) {
        setState(() {
          _qrHistory = history;
          _roomsMap = map;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Derived
  // ─────────────────────────────────────────────────────────────────────────

  List<QRCodeHistory> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    var list = _qrHistory.where((qr) {
      if (q.isNotEmpty) {
        final r = _roomsMap[qr.roomId];
        final matchValue = qr.qrCodeValue.toLowerCase().contains(q);
        final matchRoom = r?.code.toLowerCase().contains(q) ?? false;
        final matchBldg = r?.building.toLowerCase().contains(q) ?? false;
        if (!matchValue && !matchRoom && !matchBldg) return false;
      }
      if (_statusFilter == 'active' && !qr.isActive) return false;
      if (_statusFilter == 'inactive' && qr.isActive) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      int cmp;
      if (_sortField == 'scans') {
        cmp = a.scannedCount.compareTo(b.scannedCount);
      } else {
        cmp = a.createdAt.compareTo(b.createdAt);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  List<QRCodeHistory> get _paginated {
    final f = _filtered;
    final start = _page * _pageSize;
    if (start >= f.length) return [];
    return f.sublist(start, (start + _pageSize).clamp(0, f.length));
  }

  int get _totalPages => (_filtered.isEmpty
      ? 1
      : ((_filtered.length - 1) / _pageSize).ceil());

  int get _active => _qrHistory.where((qr) => qr.isActive).length;
  int get _inactive => _qrHistory.where((qr) => !qr.isActive).length;

  // ─────────────────────────────────────────────────────────────────────────
  //  Actions
  // ─────────────────────────────────────────────────────────────────────────

  void _showDetailDialog(QRCodeHistory qr, Room? room) {
    showDialog(
      context: context,
      builder: (_) => _QrDetailDialog(qr: qr, room: room),
    );
  }

  Future<void> _toggleActive(QRCodeHistory qr) async {
    final activate = !qr.isActive;
    final confirmed = await _confirm(
      title: activate ? 'Activate QR Code' : 'Deactivate QR Code',
      message: activate
          ? 'Re-activate this QR Code for scanning and reporting?'
          : 'Deactivate this QR Code? Users will not be able to report issues using it.',
      confirmLabel: activate ? 'Activate' : 'Deactivate',
      danger: !activate,
    );
    if (!confirmed) return;

    try {
      if (activate) {
        await QRCodeHistoryService.activateQRCode(qr.id);
        _toast('QR Code activated.');
      } else {
        await QRCodeHistoryService.deactivateQRCode(qr.id);
        _toast('QR Code deactivated.');
      }
      _load();
    } catch (e) {
      _toast('Error: $e', isError: true);
    }
  }

  Future<void> _delete(QRCodeHistory qr) async {
    final confirmed = await _confirm(
      title: 'Delete QR Code',
      message:
          'Permanently delete this QR code?\n\nThis cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!confirmed) return;

    try {
      await QRCodeHistoryService.deleteQRCode(qr.id);
      _toast('QR Code deleted.');
      _load();
    } catch (e) {
      _toast('Error: $e', isError: true);
    }
  }

  Future<void> _printQr(QRCodeHistory qr, Room? room) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(room?.code ?? 'Unknown Room', style: pw.TextStyle(fontSize: 40, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text(room?.building ?? '', style: const pw.TextStyle(fontSize: 20)),
                pw.SizedBox(height: 40),
                pw.BarcodeWidget(
                  data: qr.qrCodeValue,
                  barcode: pw.Barcode.qrCode(),
                  width: 300,
                  height: 300,
                ),
                pw.SizedBox(height: 20),
                pw.Text('Scan for Maintenance Request', style: const pw.TextStyle(fontSize: 16)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'QR_${room?.code ?? "Room"}',
    );
  }

  Future<void> _printAllQrs() async {
    final list = _filtered;
    if (list.isEmpty) {
      _toast('No QR codes to print', isError: true);
      return;
    }

    // Long Bond Paper size: 8.5 inches x 13.0 inches
    const longBondFormat = PdfPageFormat(
      8.5 * PdfPageFormat.inch,
      13.0 * PdfPageFormat.inch,
      marginTop: 0.4 * PdfPageFormat.inch,
      marginBottom: 0.4 * PdfPageFormat.inch,
      marginLeft: 0.4 * PdfPageFormat.inch,
      marginRight: 0.4 * PdfPageFormat.inch,
    );

    final doc = pw.Document();
    const qrPerPage = 6;
    final totalPages = (list.length / qrPerPage).ceil();

    for (var pageIdx = 0; pageIdx < totalPages; pageIdx++) {
      final startIdx = pageIdx * qrPerPage;
      final chunk = list.sublist(startIdx, (startIdx + qrPerPage).clamp(0, list.length));

      doc.addPage(
        pw.Page(
          pageFormat: longBondFormat,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Page Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'PSU Maintenance System - Room QR Codes (Long Bond Paper)',
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal900),
                    ),
                    pw.Text(
                      'Page ${pageIdx + 1} of $totalPages (${list.length} QR codes)',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Divider(color: PdfColors.grey400, thickness: 0.8),
                pw.SizedBox(height: 10),

                // 3 Rows x 2 Columns Grid (6 QR Codes Per Page)
                for (var r = 0; r < 3; r++) ...[
                  pw.Expanded(
                    child: pw.Row(
                      children: [
                        if (r * 2 < chunk.length) ...[
                          pw.Expanded(
                            child: _buildPdfQrCard(
                              chunk[r * 2],
                              _roomsMap[chunk[r * 2].roomId],
                            ),
                          ),
                        ] else ...[
                          pw.Expanded(child: pw.SizedBox()),
                        ],
                        pw.SizedBox(width: 14),
                        if (r * 2 + 1 < chunk.length) ...[
                          pw.Expanded(
                            child: _buildPdfQrCard(
                              chunk[r * 2 + 1],
                              _roomsMap[chunk[r * 2 + 1].roomId],
                            ),
                          ),
                        ] else ...[
                          pw.Expanded(child: pw.SizedBox()),
                        ],
                      ],
                    ),
                  ),
                  if (r < 2) pw.SizedBox(height: 14),
                ],
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'PSU_Room_QR_Codes_LongBond',
    );
  }

  pw.Widget _buildPdfQrCard(QRCodeHistory qr, Room? room) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: PdfColors.grey400, width: 1.5),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            room?.code ?? 'Unknown Room',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            textAlign: pw.TextAlign.center,
            maxLines: 1,
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            room?.building ?? 'Campus Facility',
            style: const pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.center,
            maxLines: 1,
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.BarcodeWidget(
              data: qr.qrCodeValue,
              barcode: pw.Barcode.qrCode(),
              width: 125,
              height: 125,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Scan for Maintenance Request',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.teal800,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  UI helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(
            danger ? Icons.warning_rounded : Icons.info_outline_rounded,
            color: danger ? AdminStyles.error : AdminStyles.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title, style: AdminStyles.headingStyle(fontSize: 18))),
        ]),
        content: Text(message, style: AdminStyles.bodyStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? AdminStyles.error : AdminStyles.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
          color: Colors.white, size: 18,
        ),
        const SizedBox(width: 10),
        Flexible(child: Text(msg)),
      ]),
      backgroundColor: isError ? AdminStyles.error : AdminStyles.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _toggleSort(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortField = field;
        _sortAsc = true;
      }
      _page = 0;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();

    return LayoutBuilder(builder: (ctx, constraints) {
      final isMobile = constraints.maxWidth < 800;
      return Container(
        color: AdminStyles.bg,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 32,
                isMobile ? 16 : 28,
                isMobile ? 16 : 32,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPageHeader(isMobile),
                  const SizedBox(height: 20),
                  _buildStatCards(isMobile),
                  const SizedBox(height: 20),
                  _buildToolbar(isMobile),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 32),
                child: _filtered.isEmpty
                    ? _buildEmpty()
                    : _isGridView
                        ? _buildGridView(isMobile)
                        : (isMobile
                            ? _buildMobileCards()
                            : _buildDesktopTable()),
              ),
            ),
            if (_filtered.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 32, vertical: 12),
                child: _buildPagination(isMobile),
              ),
          ],
        ),
      );
    });
  }

  // ── States ────────────────────────────────────────────────────────────────

  Widget _buildLoading() => Container(
        color: AdminStyles.bg,
        child: const Center(
          child: CircularProgressIndicator(
              color: AdminStyles.primary, strokeWidth: 3),
        ),
      );

  Widget _buildError() => Container(
        color: AdminStyles.bg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AdminStyles.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    size: 36, color: AdminStyles.error),
              ),
              const SizedBox(height: 20),
              Text('Failed to load QR codes',
                  style: AdminStyles.headingStyle(fontSize: 20)),
              const SizedBox(height: 8),
              Text(_error ?? '', style: AdminStyles.bodyStyle(), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminStyles.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_2_rounded,
                size: 60, color: AdminStyles.textMuted),
            const SizedBox(height: 16),
            Text(
              _searchCtrl.text.isNotEmpty || _statusFilter != 'all'
                  ? 'No QR codes match your filters'
                  : 'No QR codes generated yet',
              style: AdminStyles.headingStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _searchCtrl.text.isNotEmpty || _statusFilter != 'all'
                  ? 'Try adjusting your search or filters.'
                  : 'Generate QR codes from the Rooms page.',
              style: AdminStyles.bodyStyle(),
            ),
          ],
        ),
      );

  // ── Page header ───────────────────────────────────────────────────────────

  Widget _buildPageHeader(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('QR Management',
                  style: AdminStyles.headingStyle(
                      fontSize: isMobile ? 22 : 28)),
              const SizedBox(height: 4),
              Text('Manage, print, and track all room QR codes.',
                  style: AdminStyles.bodyStyle(fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _printAllQrs,
          icon: const Icon(Icons.print_rounded, size: 18),
          label: Text(isMobile ? 'Print All' : 'Print All QR Codes'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminStyles.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 20, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _load,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded,
              color: AdminStyles.textSecondary),
        ),
      ],
    );
  }

  // ── Stat Cards ────────────────────────────────────────────────────────────

  Widget _buildStatCards(bool isMobile) {
    final cards = [
      _Stat('Total QR Codes', _qrHistory.length, Icons.qr_code_2_rounded, AdminStyles.primary),
      _Stat('Active', _active, Icons.check_circle_rounded, AdminStyles.success),
      _Stat('Inactive', _inactive, Icons.do_not_disturb_on_rounded, AdminStyles.error),
    ];

    if (isMobile) {
      return Row(
        children: cards.asMap().entries
            .expand((e) => [
                  Expanded(child: _buildStatTile(e.value)),
                  if (e.key < cards.length - 1) const SizedBox(width: 10),
                ])
            .toList(),
      );
    }
    return Row(
      children: cards.asMap().entries
          .expand((e) => [
                Expanded(child: _buildStatTile(e.value)),
                if (e.key < cards.length - 1) const SizedBox(width: 14),
              ])
          .toList(),
    );
  }

  Widget _buildStatTile(_Stat s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(s.icon, color: s.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${s.value}',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: s.color,
                        letterSpacing: -0.5)),
                Text(s.label, style: AdminStyles.bodyStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────

  Widget _buildToolbar(bool isMobile) {
    final searchBox = Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: AdminStyles.bodyStyle(
            color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Search by room or value…',
          hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AdminStyles.textMuted, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AdminStyles.textMuted, size: 18),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        ),
      ),
    );

    final statusFilter = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AdminStyles.textMuted, size: 18),
          style: AdminStyles.bodyStyle(
              color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Status')),
            DropdownMenuItem(value: 'active', child: Text('Active Only')),
            DropdownMenuItem(value: 'inactive', child: Text('Inactive Only')),
          ],
          onChanged: (v) => setState(() {
            _statusFilter = v ?? 'all';
            _page = 0;
          }),
        ),
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          searchBox,
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: statusFilter),
              const SizedBox(width: 8),
              _buildViewToggle(),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: 4, child: searchBox),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: statusFilter),
        const SizedBox(width: 10),
        _buildViewToggle(),
      ],
    );
  }

  // ── Desktop Table ─────────────────────────────────────────────────────────

  Widget _buildDesktopTable() {
    final rows = _paginated;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            _buildTableHeader(),
            const Divider(height: 1, color: AdminStyles.border),
            Expanded(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: AdminStyles.border),
                itemBuilder: (_, i) => _buildTableRow(rows[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isGridView = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: !_isGridView ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: !_isGridView
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Icon(
                Icons.list_rounded,
                size: 18,
                color:
                    !_isGridView ? AdminStyles.primary : AdminStyles.textMuted,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isGridView = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isGridView ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: _isGridView
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Icon(
                Icons.grid_view_rounded,
                size: 18,
                color:
                    _isGridView ? AdminStyles.primary : AdminStyles.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(bool isMobile) {
    final list = _paginated;
    return GridView.builder(
      itemCount: list.length,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isMobile ? 220 : 280,
        mainAxisSpacing: isMobile ? 12 : 16,
        crossAxisSpacing: isMobile ? 12 : 16,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, i) => _buildGridCard(list[i]),
    );
  }

  Widget _buildGridCard(QRCodeHistory qr) {
    final room = _roomsMap[qr.roomId];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Status and Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusChip(isActive: qr.isActive, compact: true),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AdminStyles.textMuted, size: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'view') _showDetailDialog(qr, room);
                    if (v == 'toggle') _toggleActive(qr);
                    if (v == 'delete') _delete(qr);
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(children: [
                        const Icon(Icons.visibility_outlined,
                            size: 18, color: AdminStyles.secondary),
                        const SizedBox(width: 10),
                        Text('View Detail',
                            style: AdminStyles.bodyStyle(
                                color: AdminStyles.secondary,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    if (qr.isActive)
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(children: [
                          const Icon(Icons.do_not_disturb_on_rounded,
                              size: 18, color: AdminStyles.warning),
                          const SizedBox(width: 10),
                          Text('Deactivate',
                              style: AdminStyles.bodyStyle(
                                  color: AdminStyles.warning,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_outline_rounded,
                            size: 18, color: AdminStyles.error),
                        const SizedBox(width: 10),
                        Text('Delete',
                            style: AdminStyles.bodyStyle(
                                color: AdminStyles.error,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // QR Image
          Expanded(
            child: Center(
              child: Container(
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AdminStyles.border.withValues(alpha: 0.5)),
                ),
                child: QrImageView(
                  data: qr.qrCodeValue,
                  version: QrVersions.auto,
                ),
              ),
            ),
          ),

          // Info Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                Text(
                  room?.code ?? 'Unknown Room',
                  style: AdminStyles.headingStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  room?.building ?? 'Unknown Building',
                  style: AdminStyles.bodyStyle(
                      fontSize: 11, color: AdminStyles.textMuted),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AdminStyles.border),

          // Bottom row: Stats and Print Button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scans: ${qr.scannedCount}',
                        style: AdminStyles.bodyStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _formatDate(qr.createdAt),
                        style: AdminStyles.bodyStyle(
                            fontSize: 9, color: AdminStyles.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _printQr(qr, room),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  color: AdminStyles.primary,
                  tooltip: 'Print PDF',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(
        children: [
          const SizedBox(
            width: 70,
            child: Text(
              'QR PREVIEW',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AdminStyles.textMuted,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 16),
          _th('Room & Location', flex: 3),
          _sortableHeader('Generated', 'created', flex: 2),
          _sortableHeader('Scans', 'scans', flex: 1, center: true),
          _th('Status', flex: 2, center: true),
          _th('Actions', flex: 2, center: true),
        ],
      ),
    );
  }

  Widget _sortableHeader(String label, String field, {int flex = 1, bool center = false}) {
    final active = _sortField == field;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => _toggleSort(field),
        child: Row(
          mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: active ? AdminStyles.primary : AdminStyles.textMuted,
                  letterSpacing: 1.0,
                )),
            const SizedBox(width: 4),
            Icon(
              active
                  ? (_sortAsc
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 14,
              color: active ? AdminStyles.primary : AdminStyles.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _th(String label, {int flex = 1, bool center = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AdminStyles.textMuted,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTableRow(QRCodeHistory qr) {
    final room = _roomsMap[qr.roomId];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // QR Preview
          SizedBox(
            width: 70,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminStyles.border),
                ),
                padding: const EdgeInsets.all(4),
                child: QrImageView(
                  data: qr.qrCodeValue,
                  version: QrVersions.auto,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Room & Location
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  room?.code ?? 'Unknown Room',
                  style: AdminStyles.bodyStyle(
                      fontWeight: FontWeight.w700,
                      color: AdminStyles.textPrimary,
                      fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  room?.building ?? 'Unknown Building',
                  style: AdminStyles.bodyStyle(
                      fontSize: 11, color: AdminStyles.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Generated Date
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(qr.createdAt),
              style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Scans
          Expanded(
            flex: 1,
            child: Text(
              '${qr.scannedCount}',
              textAlign: TextAlign.center,
              style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          // Status
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.center,
              child: _StatusChip(isActive: qr.isActive),
            ),
          ),
          // Actions
          Expanded(
            flex: 2,
            child: _buildActions(qr, room),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(QRCodeHistory qr, Room? room) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _IconBtn(
          icon: Icons.visibility_outlined,
          tooltip: 'View Detail',
          color: AdminStyles.secondary,
          onTap: () => _showDetailDialog(qr, room),
        ),
        const SizedBox(width: 6),
        _IconBtn(
          icon: qr.isActive
              ? Icons.do_not_disturb_on_outlined
              : Icons.check_circle_outline_rounded,
          tooltip: qr.isActive ? 'Deactivate' : 'Activate',
          color: qr.isActive ? AdminStyles.warning : AdminStyles.success,
          onTap: () => _toggleActive(qr),
        ),
        const SizedBox(width: 6),
        _IconBtn(
          icon: Icons.print_outlined,
          tooltip: 'Print PDF',
          color: AdminStyles.primary,
          onTap: () => _printQr(qr, room),
        ),
        const SizedBox(width: 6),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded,
              color: AdminStyles.textMuted, size: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (v) {
            if (v == 'toggle') _toggleActive(qr);
            if (v == 'delete') _delete(qr);
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'toggle',
              child: Row(children: [
                Icon(
                    qr.isActive
                        ? Icons.do_not_disturb_on_rounded
                        : Icons.check_circle_rounded,
                    size: 18,
                    color: qr.isActive ? AdminStyles.warning : AdminStyles.success),
                const SizedBox(width: 10),
                Text(qr.isActive ? 'Deactivate' : 'Activate',
                    style: AdminStyles.bodyStyle(
                        color: qr.isActive ? AdminStyles.warning : AdminStyles.success,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                const Icon(Icons.delete_outline_rounded,
                    size: 18, color: AdminStyles.error),
                const SizedBox(width: 10),
                Text('Delete',
                    style: AdminStyles.bodyStyle(
                        color: AdminStyles.error,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  // ── Mobile Cards ──────────────────────────────────────────────────────────

  Widget _buildMobileCards() {
    return ListView.separated(
      itemCount: _paginated.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildMobileCard(_paginated[i]),
    );
  }

  Widget _buildMobileCard(QRCodeHistory qr) {
    final room = _roomsMap[qr.roomId];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AdminStyles.border),
            ),
            padding: const EdgeInsets.all(4),
            child: QrImageView(
              data: qr.qrCodeValue,
              version: QrVersions.auto,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(room?.code ?? 'Unknown Room',
                          style: AdminStyles.bodyStyle(
                              fontWeight: FontWeight.w700,
                              color: AdminStyles.textPrimary,
                              fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                    ),
                    _StatusChip(isActive: qr.isActive, compact: true),
                  ],
                ),
                const SizedBox(height: 4),
                Text(room?.building ?? 'Unknown Building',
                    style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 12, color: AdminStyles.textMuted),
                    const SizedBox(width: 4),
                    Text(_formatDate(qr.createdAt),
                        style: AdminStyles.bodyStyle(
                            fontSize: 11, color: AdminStyles.textMuted)),
                    const SizedBox(width: 12),
                    Icon(Icons.qr_code_scanner_rounded, size: 12, color: AdminStyles.textMuted),
                    const SizedBox(width: 4),
                    Text('${qr.scannedCount} Scans',
                        style: AdminStyles.bodyStyle(
                            fontSize: 11, color: AdminStyles.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AdminStyles.textMuted, size: 20),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              switch (v) {
                case 'view':
                  _showDetailDialog(qr, room);
                  break;
                case 'print':
                  _printQr(qr, room);
                  break;
                case 'toggle':
                  _toggleActive(qr);
                  break;
                case 'delete':
                  _delete(qr);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              _popItem(Icons.visibility_outlined, 'View Detail', 'view'),
              _popItem(Icons.print_outlined, 'Print PDF', 'print', color: AdminStyles.primary),
              if (qr.isActive)
                _popItem(Icons.do_not_disturb_on_rounded, 'Deactivate', 'toggle',
                    color: AdminStyles.warning),
              _popItem(Icons.delete_outline_rounded, 'Delete', 'delete',
                  color: AdminStyles.error),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _popItem(IconData icon, String label, String value,
      {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: color ?? AdminStyles.textSecondary),
        const SizedBox(width: 10),
        Text(label,
            style: AdminStyles.bodyStyle(
                color: color ?? AdminStyles.textPrimary, fontSize: 13)),
      ]),
    );
  }

  // ── Pagination ────────────────────────────────────────────────────────────

  Widget _buildPagination(bool isMobile) {
    final total = _filtered.length;
    final start = _page * _pageSize + 1;
    final end = ((_page + 1) * _pageSize).clamp(0, total);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!isMobile)
          Text(
            'Showing $start–$end of $total',
            style: AdminStyles.bodyStyle(fontSize: 12),
          ),
        Row(
          children: [
            _PageBtn(
                icon: Icons.first_page_rounded,
                onTap: _page > 0 ? () => setState(() => _page = 0) : null),
            _PageBtn(
                icon: Icons.chevron_left_rounded,
                onTap: _page > 0 ? () => setState(() => _page--) : null),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  color: AdminStyles.primary,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                '${_page + 1} / ${_totalPages.clamp(1, 9999)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
            _PageBtn(
                icon: Icons.chevron_right_rounded,
                onTap: _page < _totalPages - 1
                    ? () => setState(() => _page++)
                    : null),
            _PageBtn(
                icon: Icons.last_page_rounded,
                onTap: _page < _totalPages - 1
                    ? () => setState(() => _page = _totalPages - 1)
                    : null),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Detail Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _QrDetailDialog extends StatefulWidget {
  final QRCodeHistory qr;
  final Room? room;

  const _QrDetailDialog({required this.qr, required this.room});

  @override
  State<_QrDetailDialog> createState() => _QrDetailDialogState();
}

class _QrDetailDialogState extends State<_QrDetailDialog> {
  late QRCodeHistory _qr = widget.qr;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _setupRealtime();
  }

  void _setupRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('qr_detail_sync_${widget.qr.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'qr_code_history',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.qr.id,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord != null && newRecord.isNotEmpty && mounted) {
              setState(() {
                _qr = QRCodeHistory.fromMap(newRecord);
              });
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('QR Details', style: AdminStyles.headingStyle(fontSize: 18)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AdminStyles.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Big QR Code
              Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminStyles.border, width: 2),
                ),
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  data: _qr.qrCodeValue,
                  version: QrVersions.auto,
                ),
              ),
              const SizedBox(height: 20),
              Text(widget.room?.code ?? 'Unknown Room', style: AdminStyles.headingStyle(fontSize: 22)),
              Text(widget.room?.building ?? 'Unknown Building', style: AdminStyles.bodyStyle(fontSize: 14, color: AdminStyles.textSecondary)),
              const SizedBox(height: 16),
              _StatusChip(isActive: _qr.isActive),
              const SizedBox(height: 20),
              const Divider(color: AdminStyles.border),
              const SizedBox(height: 16),

              _row(Icons.fingerprint_rounded, 'QR Value', _qr.qrCodeValue),
              _row(Icons.calendar_today_outlined, 'Generated', _fmt(_qr.createdAt)),
              _row(Icons.qr_code_scanner_rounded, 'Total Scans', '${_qr.scannedCount}'),
              _row(Icons.update_rounded, 'Last Scanned', _qr.lastScanned != null ? _fmt(_qr.lastScanned!) : 'Never'),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.pop(context),
                  label: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminStyles.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: AdminStyles.textMuted),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(label,
              style: AdminStyles.bodyStyle(
                  fontSize: 12, color: AdminStyles.textMuted)),
        ),
        Expanded(
          child: Text(value,
              style: AdminStyles.bodyStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AdminStyles.textPrimary)),
        ),
      ]),
    );
  }

  String _fmt(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final bool isActive;
  final bool compact;

  const _StatusChip({required this.isActive, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: isActive ? AdminStyles.success : AdminStyles.error,
              shape: BoxShape.circle,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 5),
            Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: isActive
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn(
      {required this.icon,
      required this.tooltip,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _PageBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: onTap != null ? Colors.white : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                border: Border.all(color: AdminStyles.border),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon,
                size: 18,
                color: onTap != null
                    ? AdminStyles.textPrimary
                    : AdminStyles.textMuted),
          ),
        ),
      ),
    );
  }
}

class _Stat {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _Stat(this.label, this.value, this.icon, this.color);
}

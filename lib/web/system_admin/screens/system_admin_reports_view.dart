import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import '../../../authentication/models/user_model.dart';
import '../../../shared/models/request_type_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/request_type_service.dart';
import '../../../shared/services/system_admin_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../admin/shared/admin_styles.dart';

// PDF / Printing
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SystemAdminReportsView extends StatefulWidget {
  const SystemAdminReportsView({super.key});

  @override
  State<SystemAdminReportsView> createState() => _SystemAdminReportsViewState();
}

class _SystemAdminReportsViewState extends State<SystemAdminReportsView> {
  bool _loading = true;
  String? _error;

  List<WorkRequest> _allRequests = [];
  List<AppUser> _allUsers = [];
  List<RequestType> _allRequestTypes = [];

  RealtimeChannel? _realtimeChannel;
  Timer? _autoRefreshTimer;

  static const List<String> _standardRequestTypes = [
    'Ocular Inspection',
    'Installation',
    'Repair',
    'Replacement',
    'Others',
  ];

  // ── Filters ───────────────────────────────────────────────────────────────
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedBuilding;
  String? _selectedRequestType;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtime();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  void _setupRealtime() {
    try {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = WorkRequestService.listenToAllWorkRequests((updatedRequests) {
        if (mounted) {
          setState(() {
            _allRequests = updatedRequests;
          });
        }
      });
    } catch (_) {}
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _silentRefresh();
    });
  }

  Future<void> _silentRefresh() async {
    try {
      final reqs = await WorkRequestService.fetchAll();
      if (mounted) {
        setState(() {
          _allRequests = reqs;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        WorkRequestService.fetchAll(),
        SystemAdminService.fetchAllUsers(),
        RequestTypeService.fetchAll(),
      ]);

      if (mounted) {
        setState(() {
          _allRequests = results[0] as List<WorkRequest>;
          _allUsers = results[1] as List<AppUser>;
          _allRequestTypes = results[2] as List<RequestType>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _normalizeRequestType(WorkRequest r) {
    final raw = (r.typeDisplay.isNotEmpty ? r.typeDisplay : r.typeOfRequest).trim();
    final lower = raw.toLowerCase();

    if (lower.startsWith('ocular inspection') || lower.startsWith('ocular')) {
      return 'Ocular Inspection';
    } else if (lower.startsWith('installation')) {
      return 'Installation';
    } else if (lower.startsWith('repair')) {
      return 'Repair';
    } else if (lower.startsWith('replacement')) {
      return 'Replacement';
    } else {
      return 'Others';
    }
  }

  // ── Derived Data for Charts ───────────────────────────────────────────────

  List<WorkRequest> get _filteredRequests {
    return _allRequests.where((r) {
      // Date filter
      if (_startDate != null && r.dateSubmitted.isBefore(_startDate!)) return false;
      if (_endDate != null && r.dateSubmitted.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
      
      // Request Type filter
      if (_selectedRequestType != null && _selectedRequestType!.isNotEmpty) {
        final category = _normalizeRequestType(r);
        if (category.toLowerCase() != _selectedRequestType!.trim().toLowerCase()) {
          return false;
        }
      }

      if (_selectedBuilding != null && !(r.buildingName ?? '').contains(_selectedBuilding!)) return false;
      
      return true;
    }).toList();
  }

  Map<String, int> get _monthlyRequests {
    final map = <String, int>{};
    // Initialize last 6 months
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('MMM').format(d);
      map[key] = 0;
    }
    for (final r in _filteredRequests) {
      final key = DateFormat('MMM').format(r.dateSubmitted);
      if (map.containsKey(key)) {
        map[key] = map[key]! + 1;
      }
    }
    return map;
  }

  Map<String, int> get _statusDistribution {
    final map = <String, int>{};
    for (final r in _filteredRequests) {
      final s = r.status.toUpperCase();
      map[s] = (map[s] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get _categoryDistribution {
    final map = <String, int>{
      'Ocular Inspection': 0,
      'Installation': 0,
      'Repair': 0,
      'Replacement': 0,
      'Others': 0,
    };
    for (final r in _filteredRequests) {
      final c = _normalizeRequestType(r);
      map[c] = (map[c] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get _personnelPerformance {
    final map = <String, int>{};
    for (final r in _filteredRequests) {
      if (r.status.trim().toLowerCase() == 'completed' && r.assignedToId != null) {
        final userName = _allUsers.firstWhere(
          (u) => u.id == r.assignedToId,
          orElse: () => AppUser(id: '', email: '', name: 'Unknown', role: UserRole.maintenance, isActive: true),
        ).name;
        map[userName] = (map[userName] ?? 0) + 1;
      }
    }
    return map;
  }

  // ── Exports ───────────────────────────────────────────────────────────────

  Future<void> _exportPDF() async {
    final pdf = pw.Document();
    
    // Add page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('System Admin Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Generated: ${DateFormat.yMMMd().format(DateTime.now())}'),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Total Requests: ${_filteredRequests.length}', style: pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 20),
              pw.Text('Status Distribution', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ..._statusDistribution.entries.map((e) => pw.Text('${e.key}: ${e.value}')),
              pw.SizedBox(height: 20),
              pw.Text('Request Type Distribution', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ..._categoryDistribution.entries.map((e) => pw.Text('${e.key}: ${e.value}')),
              pw.SizedBox(height: 20),
              pw.Text('Top Performing Personnel (Completed)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ..._personnelPerformance.entries.map((e) => pw.Text('${e.key}: ${e.value}')),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'System_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  void _exportCSV() {
    final StringBuffer buffer = StringBuffer();
    // Add UTF-8 BOM so Excel opens it with correct column formatting
    buffer.write('\uFEFF');
    buffer.writeln('ID,Title,Request Type,Status,Location,Priority,Date Submitted,Date Completed');

    for (final r in _filteredRequests) {
      final id = _escapeCsv(r.id);
      final title = _escapeCsv(r.title);
      final reqType = _escapeCsv(_normalizeRequestType(r));
      final status = _escapeCsv(r.status);
      final loc = _escapeCsv(r.buildingName ?? 'N/A');
      final priority = _escapeCsv(r.priority);
      final dateSub = _escapeCsv(DateFormat('yyyy-MM-dd HH:mm').format(r.dateSubmitted));
      final dateComp = _escapeCsv(r.dateCompleted != null ? DateFormat('yyyy-MM-dd HH:mm').format(r.dateCompleted!) : 'N/A');

      buffer.writeln('$id,$title,$reqType,$status,$loc,$priority,$dateSub,$dateComp');
    }

    try {
      final bytes = utf8.encode(buffer.toString());
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final fileName = 'System_Reports_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded $fileName'),
            backgroundColor: AdminStyles.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Export CSV error: $e');
    }
  }

  String _escapeCsv(dynamic item) {
    if (item == null) return '';
    final str = item.toString().replaceAll('"', '""');
    if (str.contains(',') || str.contains('"') || str.contains('\n')) {
      return '"$str"';
    }
    return str;
  }

  // ── UI Building ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AdminStyles.primary));
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error', style: const TextStyle(color: AdminStyles.error)));
    }

    return LayoutBuilder(builder: (ctx, constraints) {
      final isMobile = constraints.maxWidth < 800;
      return Container(
        color: AdminStyles.bg,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile),
              const SizedBox(height: 24),
              _buildFilters(isMobile),
              const SizedBox(height: 24),
              _buildStatCards(isMobile),
              const SizedBox(height: 24),
              _buildCharts(isMobile),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildHeader(bool isMobile) {
    final titleCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('System Reports', style: AdminStyles.headingStyle(fontSize: isMobile ? 22 : 28)),
        const SizedBox(height: 4),
        Text('Generate analytics, insights, and data exports.', style: AdminStyles.bodyStyle(fontSize: 13)),
      ],
    );

    final csvBtn = ElevatedButton.icon(
      onPressed: _exportCSV,
      icon: const Icon(Icons.table_chart_rounded, size: 18),
      label: const Text('Excel / CSV'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminStyles.success,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );

    final pdfBtn = ElevatedButton.icon(
      onPressed: _exportPDF,
      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
      label: const Text('Export PDF'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminStyles.error,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleCol,
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: csvBtn),
              const SizedBox(width: 12),
              Expanded(child: pdfBtn),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: titleCol),
        const SizedBox(width: 16),
        csvBtn,
        const SizedBox(width: 12),
        pdfBtn,
      ],
    );
  }

  Widget _buildFilters(bool isMobile) {
    final dateFilter = InkWell(
      onTap: () async {
        final range = await showDialog<DateTimeRange>(
          context: context,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 560),
              child: Theme(
                data: ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AdminStyles.primary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AdminStyles.textPrimary,
                  ),
                ),
                child: DateRangePickerDialog(
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: _startDate != null && _endDate != null
                      ? DateTimeRange(start: _startDate!, end: _endDate!)
                      : null,
                ),
              ),
            ),
          ),
        );
        if (range != null) {
          setState(() {
            _startDate = range.start;
            _endDate = range.end;
          });
        }
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminStyles.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 18, color: AdminStyles.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _startDate != null && _endDate != null
                    ? '${DateFormat.yMMMd().format(_startDate!)} - ${DateFormat.yMMMd().format(_endDate!)}'
                    : 'All Time Dates',
                style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600, color: AdminStyles.textPrimary),
              ),
            ),
            if (_startDate != null)
              IconButton(
                icon: const Icon(Icons.clear_rounded, size: 16, color: AdminStyles.textMuted),
                onPressed: () => setState(() {
                  _startDate = null;
                  _endDate = null;
                }),
              ),
          ],
        ),
      ),
    );

    final reqTypeFilter = Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRequestType,
          isExpanded: true,
          hint: const Text('All Request Type'),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminStyles.textMuted, size: 18),
          style: AdminStyles.bodyStyle(color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Request Type')),
            ..._standardRequestTypes.map((name) => DropdownMenuItem(value: name, child: Text(name))),
          ],
          onChanged: (v) => setState(() => _selectedRequestType = v),
        ),
      ),
    );

    final clearBtn = TextButton.icon(
      onPressed: () {
        setState(() {
          _startDate = null;
          _endDate = null;
          _selectedBuilding = null;
          _selectedRequestType = null;
        });
      },
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: const Text('Reset Filters'),
      style: TextButton.styleFrom(foregroundColor: AdminStyles.textSecondary),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          dateFilter,
          const SizedBox(height: 12),
          reqTypeFilter,
          const SizedBox(height: 12),
          clearBtn,
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 2, child: dateFilter),
        const SizedBox(width: 16),
        Expanded(flex: 1, child: reqTypeFilter),
        const SizedBox(width: 16),
        clearBtn,
      ],
    );
  }

  Widget _buildStatCards(bool isMobile) {
    final pending = _filteredRequests.where((r) => r.status.trim().toLowerCase() == 'pending').length;
    final completed = _filteredRequests.where((r) => r.status.trim().toLowerCase() == 'completed').length;
    
    final cards = [
      _StatCard(label: 'Total Filtered', value: _filteredRequests.length, icon: Icons.assignment_rounded, color: AdminStyles.primary),
      _StatCard(label: 'Pending', value: pending, icon: Icons.hourglass_top_rounded, color: AdminStyles.warning),
      _StatCard(label: 'Completed', value: completed, icon: Icons.task_alt_rounded, color: AdminStyles.success),
    ];

    if (isMobile) {
      return LayoutBuilder(
        builder: (context, cardConstraints) {
          final cardWidth = cardConstraints.maxWidth;
          int crossAxisCount = 3;
          double aspect = 1.8;
          if (cardWidth < 500) {
            crossAxisCount = 1;
            aspect = 2.4;
          } else if (cardWidth < 800) {
            crossAxisCount = 2;
            aspect = 2.0;
          }
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: aspect,
            children: cards.map(_buildStatTile).toList(),
          );
        },
      );
    }

    return Row(
      children: cards
          .map((c) => Expanded(child: _buildStatTile(c)))
          .expand((w) => [w, const SizedBox(width: 16)])
          .toList()..removeLast(),
    );
  }

  Widget _buildStatTile(_StatCard s) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(s.icon, color: s.color, size: 20),
          ),
          const SizedBox(height: 10),
          Text('${s.value}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: s.color, letterSpacing: -0.5)),
          Text(s.label, style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildCharts(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          _buildBarChart('Monthly Requests', _monthlyRequests),
          const SizedBox(height: 16),
          _buildBarChart('Requests by Status', _statusDistribution),
          const SizedBox(height: 16),
          _buildBarChart('Request Type Statistics', _categoryDistribution),
          const SizedBox(height: 16),
          _buildBarChart('Top Personnel', _personnelPerformance),
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildBarChart('Monthly Requests', _monthlyRequests)),
            const SizedBox(width: 16),
            Expanded(child: _buildBarChart('Requests by Status', _statusDistribution)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildBarChart('Request Type Statistics', _categoryDistribution)),
            const SizedBox(width: 16),
            Expanded(child: _buildBarChart('Personnel Performance (Completed)', _personnelPerformance)),
          ],
        ),
      ],
    );
  }

  Widget _buildBarChart(String title, Map<String, int> data) {
    final maxVal = data.values.isEmpty ? 1 : data.values.reduce(math.max);

    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AdminStyles.headingStyle(fontSize: 16)),
          const SizedBox(height: 16),
          Expanded(
            child: data.isEmpty
                ? const Center(child: Text('No data available'))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final double maxBarHeight = math.max(10.0, constraints.maxHeight - 54);

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: data.entries.map((e) {
                          final ratio = maxVal == 0 ? 0.0 : e.value / maxVal;
                          final barHeight = maxBarHeight * ratio;

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (e.value > 0)
                                    Text(
                                      '${e.value}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AdminStyles.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  else
                                    const SizedBox(height: 12),
                                  const SizedBox(height: 4),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 800),
                                    height: math.max(4.0, barHeight),
                                    decoration: BoxDecoration(
                                      color: AdminStyles.primary.withValues(alpha: 0.8),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 24,
                                    child: Center(
                                      child: Text(
                                        e.key,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AdminStyles.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatCard {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  _StatCard({required this.label, required this.value, required this.icon, required this.color});
}


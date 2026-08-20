import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  // ── Filters ───────────────────────────────────────────────────────────────
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedBuilding;
  String? _selectedRequestType;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  // ── Derived Data for Charts ───────────────────────────────────────────────

  List<WorkRequest> get _filteredRequests {
    return _allRequests.where((r) {
      // Date filter
      if (_startDate != null && r.dateSubmitted.isBefore(_startDate!)) return false;
      if (_endDate != null && r.dateSubmitted.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
      if (_selectedRequestType != null && r.typeOfRequest != _selectedRequestType) return false;
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
    final map = <String, int>{};
    for (final r in _filteredRequests) {
      final c = r.typeOfRequest;
      map[c] = (map[c] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get _personnelPerformance {
    final map = <String, int>{};
    for (final r in _filteredRequests) {
      if (r.status == 'completed' && r.assignedToId != null) {
        final userName = _allUsers.firstWhere((u) => u.id == r.assignedToId, orElse: () => AppUser(id: '', email: '', name: 'Unknown', role: UserRole.maintenance, isActive: true)).name;
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
              pw.Text('Category Distribution', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
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
    // Generate CSV string
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('ID,Title,Category,Status,Location,Priority,Created At');
    for (final r in _filteredRequests) {
      final title = r.title.replaceAll(',', ' ');
      final loc = (r.buildingName ?? '').replaceAll(',', ' ');
      buffer.writeln('${r.id},$title,${r.typeOfRequest},${r.status},$loc,${r.priority},${r.dateSubmitted.toIso8601String()}');
    }
    
    // In a real web environment we'd use dart:html anchor download. 
    // For Desktop we'd use path_provider. 
    // Here we just show a dialog with the CSV text since we want simple cross-platform.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Data (CSV / Excel format)'),
        content: SizedBox(
          width: 500,
          height: 300,
          child: SelectableText(buffer.toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('System Reports', style: AdminStyles.headingStyle(fontSize: isMobile ? 22 : 28)),
              const SizedBox(height: 4),
              Text('Generate analytics, insights, and data exports.', style: AdminStyles.bodyStyle(fontSize: 13)),
            ],
          ),
        ),
        if (!isMobile) ...[
          ElevatedButton.icon(
            onPressed: _exportCSV,
            icon: const Icon(Icons.table_chart_rounded, size: 18),
            label: const Text('Excel / CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _exportPDF,
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: const Text('Export PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildFilters(bool isMobile) {
    final dateFilter = InkWell(
      onTap: () async {
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: _startDate != null && _endDate != null
              ? DateTimeRange(start: _startDate!, end: _endDate!)
              : null,
          builder: (context, child) => Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(primary: AdminStyles.primary),
            ),
            child: child!,
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

    final catFilter = Container(
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
          hint: const Text('All Categories'),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminStyles.textMuted, size: 18),
          style: AdminStyles.bodyStyle(color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Categories')),
            ..._allRequestTypes.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))),
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
          catFilter,
          const SizedBox(height: 12),
          clearBtn,
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 2, child: dateFilter),
        const SizedBox(width: 16),
        Expanded(flex: 1, child: catFilter),
        const SizedBox(width: 16),
        clearBtn,
      ],
    );
  }

  Widget _buildStatCards(bool isMobile) {
    final pending = _filteredRequests.where((r) => r.status == 'pending').length;
    final completed = _filteredRequests.where((r) => r.status == 'completed').length;
    
    final cards = [
      _StatCard(label: 'Total Filtered', value: _filteredRequests.length, icon: Icons.assignment_rounded, color: AdminStyles.primary),
      _StatCard(label: 'Pending', value: pending, icon: Icons.hourglass_top_rounded, color: AdminStyles.warning),
      _StatCard(label: 'Completed', value: completed, icon: Icons.task_alt_rounded, color: AdminStyles.success),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: cards.map(_buildStatTile).toList(),
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
            Expanded(child: _buildBarChart('Category Statistics', _categoryDistribution)),
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
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: data.entries.map((e) {
                      final ratio = maxVal == 0 ? 0.0 : e.value / maxVal;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (e.value > 0)
                                Text(
                                  '${e.value}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AdminStyles.textPrimary),
                                ),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 800),
                                height: 140 * ratio,
                                decoration: BoxDecoration(
                                  color: AdminStyles.primary.withValues(alpha: 0.8),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                e.key,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 10, color: AdminStyles.textMuted, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
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

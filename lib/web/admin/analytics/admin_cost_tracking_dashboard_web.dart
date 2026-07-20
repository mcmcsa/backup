import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;
import '../../../shared/services/cost_analytics_service.dart';
import '../shared/admin_styles.dart';

class AdminCostTrackingDashboardWeb extends StatefulWidget {
  const AdminCostTrackingDashboardWeb({super.key});

  @override
  State<AdminCostTrackingDashboardWeb> createState() => _AdminCostTrackingDashboardWebState();
}

class _AdminCostTrackingDashboardWebState extends State<AdminCostTrackingDashboardWeb> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rawData = [];
  Map<String, double> _monthlyExpenses = {};
  Map<String, double> _yearlyExpenses = {};
  Map<String, double> _costByDepartment = {};
  Map<String, double> _costByBuilding = {};
  Map<String, double> _costByPersonnel = {};
  List<Map<String, dynamic>> _topExpensive = [];

  double get _totalExpenses {
    return _rawData.fold(0.0, (sum, item) => sum + ((item['total_cost'] as num?)?.toDouble() ?? 0.0));
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await CostAnalyticsService.fetchCostAnalytics();
      setState(() {
        _rawData = data;
        _monthlyExpenses = CostAnalyticsService.getMonthlyExpenses(data);
        _yearlyExpenses = CostAnalyticsService.getYearlyExpenses(data);
        _costByDepartment = CostAnalyticsService.getCostByDepartment(data);
        _costByBuilding = CostAnalyticsService.getCostByBuilding(data);
        _costByPersonnel = CostAnalyticsService.getCostByPersonnel(data);
        _topExpensive = CostAnalyticsService.getTopExpensiveRepairs(data);
      });
    } catch (e) {
      debugPrint('Error loading cost analytics: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _exportCSV() {
    final List<List<dynamic>> rows = [];
    rows.add([
      'Work Request ID',
      'Title',
      'Department',
      'Building',
      'Personnel',
      'Est Labor',
      'Est Material',
      'Act Labor',
      'Act Material',
      'Additional',
      'Total Cost',
      'Budget Source',
      'Purchase Ref',
      'Date Created'
    ]);

    for (var item in _rawData) {
      final req = item['work_requests'];
      rows.add([
        req?['id'] ?? '',
        req?['title'] ?? '',
        req?['department'] ?? '',
        req?['building_name'] ?? '',
        req?['completed_by_name'] ?? req?['accepted_by_name'] ?? '',
        item['estimated_labor_cost'],
        item['estimated_material_cost'],
        item['actual_labor_cost'],
        item['actual_material_cost'],
        item['additional_expenses'],
        item['total_cost'],
        item['budget_source'] ?? '',
        item['purchase_reference_number'] ?? '',
        item['created_at']
      ]);
    }

    final String csv = rows.map((row) {
      return row.map((item) {
        if (item == null) return '';
        final str = item.toString().replaceAll('"', '""');
        if (str.contains(',') || str.contains('"') || str.contains('\n')) {
          return '"$str"';
        }
        return str;
      }).join(',');
    }).join('\n');
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'cost_tracking_export_${DateTime.now().toIso8601String()}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _exportPDF() async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, child: pw.Text('Cost Tracking Report')),
            pw.SizedBox(height: 10),
            pw.Text('Total Expenses: ₱${NumberFormat.currency(symbol: '', decimalDigits: 2).format(_totalExpenses)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
            pw.SizedBox(height: 20),
            pw.Header(level: 1, child: pw.Text('Top Expensive Repairs')),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Title', 'Building', 'Total Cost'],
              data: _topExpensive.map((item) {
                final req = item['work_requests'];
                return [
                  req?['title'] ?? 'Unknown',
                  req?['building_name'] ?? 'Unknown',
                  '₱${item['total_cost']}'
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    final Uint8List pdfBytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AdminStyles.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Cost Tracking Analytics', style: AdminStyles.headingStyle()),
        actions: [
          TextButton.icon(
            onPressed: _exportCSV,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Export CSV'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _exportPDF,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Export PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: AdminStyles.primary, foregroundColor: Colors.white),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminStyles.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Expenses', style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
                  const SizedBox(height: 8),
                  Text(
                    NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(_totalExpenses),
                    style: AdminStyles.headingStyle(fontSize: 32, color: AdminStyles.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildBreakdownCard('Monthly Expenses', _monthlyExpenses)),
                const SizedBox(width: 24),
                Expanded(child: _buildBreakdownCard('Yearly Expenses', _yearlyExpenses)),
                const SizedBox(width: 24),
                Expanded(child: _buildBreakdownCard('By Department', _costByDepartment)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildBreakdownCard('By Building', _costByBuilding)),
                const SizedBox(width: 24),
                Expanded(child: _buildBreakdownCard('By Personnel', _costByPersonnel)),
              ],
            ),
            const SizedBox(height: 24),
            Text('Most Expensive Repairs', style: AdminStyles.headingStyle(fontSize: 20)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminStyles.border)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _topExpensive.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: AdminStyles.border),
                itemBuilder: (context, index) {
                  final item = _topExpensive[index];
                  final req = item['work_requests'];
                  return ListTile(
                    title: Text(req?['title'] ?? 'Unknown', style: AdminStyles.headingStyle(fontSize: 15)),
                    subtitle: Text('${req?['department']} - ${req?['building_name']}', style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
                    trailing: Text(
                      NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(item['total_cost']),
                      style: AdminStyles.headingStyle(fontSize: 16, color: AdminStyles.primary),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownCard(String title, Map<String, double> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminStyles.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AdminStyles.headingStyle(fontSize: 16)),
          const SizedBox(height: 16),
          ...data.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(e.key, style: AdminStyles.bodyStyle(), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(e.value), style: AdminStyles.headingStyle(fontSize: 14)),
              ],
            ),
          )),
          if (data.isEmpty)
            Text('No data available', style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
        ],
      ),
    );
  }
}

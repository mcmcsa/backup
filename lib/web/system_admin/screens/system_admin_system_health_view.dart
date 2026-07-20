import 'dart:async';
import 'package:flutter/material.dart';

import '../../../shared/services/system_health_service.dart';
import '../../admin/shared/admin_styles.dart';

class SystemAdminSystemHealthView extends StatefulWidget {
  const SystemAdminSystemHealthView({super.key});

  @override
  State<SystemAdminSystemHealthView> createState() => _SystemAdminSystemHealthViewState();
}

class _SystemAdminSystemHealthViewState extends State<SystemAdminSystemHealthView> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _metrics;

  Timer? _autoRefreshTimer;
  DateTime _lastRefresh = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadData(isAutoRefresh: true));
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool isAutoRefresh = false}) async {
    if (!isAutoRefresh) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await SystemHealthService.fetchHealthMetrics();
      if (mounted) {
        setState(() {
          _metrics = data;
          _lastRefresh = DateTime.now();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && !isAutoRefresh) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── UI Building ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading && _metrics == null) return const Center(child: CircularProgressIndicator(color: AdminStyles.primary));
    if (_error != null && _metrics == null) return Center(child: Text('Error: $_error', style: const TextStyle(color: AdminStyles.error)));

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
              _buildCoreMetrics(isMobile),
              const SizedBox(height: 24),
              _buildSecondaryMetrics(isMobile),
              const SizedBox(height: 24),
              _buildChartsRow(isMobile),
              const SizedBox(height: 24),
              _buildRecentErrors(),
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
              Text('System Health', style: AdminStyles.headingStyle(fontSize: isMobile ? 22 : 28)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.circle, color: AdminStyles.success, size: 10),
                  const SizedBox(width: 6),
                  Text('All Systems Operational. Last updated: ${_lastRefresh.hour}:${_lastRefresh.minute.toString().padLeft(2, '0')}:${_lastRefresh.second.toString().padLeft(2, '0')}', style: AdminStyles.bodyStyle(fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
        if (!isMobile) ...[
          ElevatedButton.icon(
            onPressed: () => _loadData(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AdminStyles.primary,
              side: const BorderSide(color: AdminStyles.border),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCoreMetrics(bool isMobile) {
    if (_metrics == null) return const SizedBox();
    
    final cards = [
      _StatusCard('Server Status', _metrics!['server_status'], Icons.dns_rounded, AdminStyles.success),
      _StatusCard('Database Status', _metrics!['database_status'], Icons.storage_rounded, AdminStyles.success),
      _StatusCard('Supabase Auth', _metrics!['supabase_connection'], Icons.security_rounded, AdminStyles.success),
    ];

    if (isMobile) {
      return Column(children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildStatusTile(c))).toList());
    }

    return Row(
      children: cards.map((c) => Expanded(child: _buildStatusTile(c))).expand((w) => [w, const SizedBox(width: 16)]).toList()..removeLast(),
    );
  }

  Widget _buildStatusTile(_StatusCard s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: s.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(s.icon, color: s.color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.label, style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminStyles.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(s.value, style: AdminStyles.headingStyle(fontSize: 18, color: AdminStyles.textPrimary)),
                    const SizedBox(width: 8),
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryMetrics(bool isMobile) {
    if (_metrics == null) return const SizedBox();

    final cpu = _metrics!['cpu_usage_percent'] as int;
    final mem = _metrics!['memory_usage_percent'] as int;
    
    final cards = [
      _MetricCard('CPU Usage', '$cpu%', Icons.memory_rounded, cpu > 80 ? AdminStyles.error : cpu > 50 ? AdminStyles.warning : AdminStyles.primary),
      _MetricCard('Memory Usage', '$mem%', Icons.sd_card_rounded, mem > 80 ? AdminStyles.error : mem > 50 ? AdminStyles.warning : AdminStyles.primary),
      _MetricCard('Storage', '${_metrics!['storage_usage_gb']} GB', Icons.cloud_rounded, AdminStyles.primary),
      _MetricCard('Active Sessions', '${_metrics!['active_sessions']}', Icons.people_rounded, AdminStyles.success),
      _MetricCard('Failed Logins', '${_metrics!['failed_login_attempts']}', Icons.gpp_bad_rounded, _metrics!['failed_login_attempts'] > 10 ? AdminStyles.error : AdminStyles.warning),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12, crossAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: cards.map((c) => _buildMetricTile(c)).toList(),
      );
    }

    return Row(
      children: cards.map((c) => Expanded(child: _buildMetricTile(c))).expand((w) => [w, const SizedBox(width: 12)]).toList()..removeLast(),
    );
  }

  Widget _buildMetricTile(_MetricCard m) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminStyles.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(m.label, style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminStyles.textSecondary)),
              Icon(m.icon, size: 16, color: m.color.withValues(alpha: 0.5)),
            ],
          ),
          Text(m.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: m.color)),
        ],
      ),
    );
  }

  Widget _buildChartsRow(bool isMobile) {
    if (_metrics == null) return const SizedBox();

    final reqs = _metrics!['requests_per_hour'] as List<int>;
    final maxReq = reqs.reduce((a, b) => a > b ? a : b);

    final reqChart = _ChartCard(
      title: 'Requests Per Hour (Last 24h)',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: reqs.map((val) {
          final ratio = maxReq == 0 ? 0.0 : val / maxReq;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: 150 * ratio,
                decoration: BoxDecoration(color: AdminStyles.primary, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
              ),
            ),
          );
        }).toList(),
      ),
    );

    final storage = _metrics!['storage_growth'] as List<int>;
    final maxStorage = storage.reduce((a, b) => a > b ? a : b);

    final storageChart = _ChartCard(
      title: 'Storage Growth (Last 7 Days)',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: storage.map((val) {
          final ratio = maxStorage == 0 ? 0.0 : val / maxStorage;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: 150 * ratio,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AdminStyles.success.withValues(alpha: 0.8), AdminStyles.success], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );

    if (isMobile) {
      return Column(children: [reqChart, const SizedBox(height: 16), storageChart]);
    }
    return Row(children: [Expanded(flex: 2, child: reqChart), const SizedBox(width: 16), Expanded(flex: 1, child: storageChart)]);
  }

  Widget _buildRecentErrors() {
    if (_metrics == null) return const SizedBox();
    final errors = _metrics!['recent_errors'] as List<Map<String, String>>;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF2F2),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: AdminStyles.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 20, color: AdminStyles.error),
                const SizedBox(width: 10),
                Text('Recent System Errors', style: AdminStyles.headingStyle(fontSize: 16, color: AdminStyles.error)),
              ],
            ),
          ),
          if (errors.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('No recent errors detected.', style: AdminStyles.bodyStyle(color: AdminStyles.success, fontWeight: FontWeight.w700))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: errors.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: AdminStyles.border),
              itemBuilder: (_, i) {
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  leading: const Icon(Icons.error_outline_rounded, color: AdminStyles.error, size: 20),
                  title: Text(errors[i]['error']!, style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600)),
                  trailing: Text(errors[i]['time']!, style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StatusCard {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _StatusCard(this.label, this.value, this.icon, this.color);
}

class _MetricCard {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _MetricCard(this.label, this.value, this.icon, this.color);
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AdminStyles.headingStyle(fontSize: 16)),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

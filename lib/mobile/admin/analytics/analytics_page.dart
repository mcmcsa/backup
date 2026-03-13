import 'package:flutter/material.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../shared/notifications_page.dart';

class AnalyticsPage extends StatefulWidget {
  final VoidCallback openDrawer;
  
  const AnalyticsPage({super.key, required this.openDrawer});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int _selectedPeriod = 1; // 0: Last 30 Days, 1: Quarterly, 2: Yearly
  List<WorkRequest> _allRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await WorkRequestService.fetchAll();
      if (mounted) setState(() { _allRequests = data; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  List<WorkRequest> get _filteredByPeriod {
    final now = DateTime.now();
    return _allRequests.where((r) {
      final diff = now.difference(r.dateSubmitted).inDays;
      switch (_selectedPeriod) {
        case 0: return diff <= 30;
        case 1: return diff <= 90;
        case 2: return diff <= 365;
        default: return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: widget.openDrawer,
            child: const Icon(
              Icons.menu,
              color: Colors.black87,
              size: 28,
            ),
          ),
        ),
        title: Row(
          children: [
            SizedBox(
              height: 35,
              width: 35,
              child: Image.asset(
                'assets/images/PsuLogo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, _) => const Icon(
                  Icons.school,
                  color: Color(0xFF4169E1),
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PSU',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1,
                  ),
                ),
                Text(
                  'CAMPUS ADMINISTRATOR',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.black54,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsPage(),
                      ),
                    );
                  },
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Period Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildPeriodTab('Last 30 Days', 0),
                const SizedBox(width: 12),
                _buildPeriodTab('Quarterly', 1),
                const SizedBox(width: 12),
                _buildPeriodTab('Yearly', 2),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredByPeriod.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'No data available',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Analytics will appear once work requests are submitted.',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistics Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'TOTAL ISSUES',
                          '${_filteredByPeriod.length}',
                          '',
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'RESOLVED',
                          _filteredByPeriod.isEmpty
                              ? '0%'
                              : '${(_filteredByPeriod.where((r) => r.status == 'done').length * 100 / _filteredByPeriod.length).round()}%',
                          '',
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Most Frequent Request Type
                  _buildSectionCard(
                    title: 'Most Frequent Request Type',
                    icon: Icons.insert_chart_outlined,
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          _getTopCategoryCount(),
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getTopCategoryName(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildCategoryLegend(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Most Active Rooms
                  _buildSectionCard(
                    title: 'Most Active Rooms',
                    icon: Icons.meeting_room_outlined,
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        ..._getTopRooms().map((entry) =>
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildRoomBar(entry.key, entry.value, const Color(0xFF4169E1)),
                          ),
                        ),
                        if (_getTopRooms().isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('No room data yet', style: TextStyle(color: Colors.grey.shade400)),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Request Types Breakdown
                  _buildSectionCard(
                    title: 'Request Types Breakdown',
                    icon: Icons.build_outlined,
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 180,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: _getRequestTypeCounts().entries.take(5).map((entry) =>
                              _buildEquipmentBar(entry.key.toUpperCase(), entry.value),
                            ).toList(),
                          ),
                        ),
                        if (_getRequestTypeCounts().isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('No request type data yet', style: TextStyle(color: Colors.grey.shade400)),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String label, int index) {
    final isSelected = _selectedPeriod == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4169E1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF4169E1) : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String change, Color changeColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: changeColor,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: const Color(0xFF4169E1),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildCategoryLegend() {
    final typeCounts = _getRequestTypeCounts();
    final total = _filteredByPeriod.length;
    final colors = [Colors.blue, Colors.orange, Colors.grey.shade700, Colors.grey.shade400, Colors.green];
    final entries = typeCounts.entries.take(4).toList();
    
    if (entries.isEmpty) {
      return Text('No data', style: TextStyle(fontSize: 12, color: Colors.grey.shade400));
    }

    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i += 2) {
      rows.add(Row(
        children: [
          _buildLegendItem(
            colors[i % colors.length],
            entries[i].key,
            total > 0 ? '${(entries[i].value * 100 / total).round()}%' : '0%',
          ),
          const SizedBox(width: 24),
          if (i + 1 < entries.length)
            _buildLegendItem(
              colors[(i + 1) % colors.length],
              entries[i + 1].key,
              total > 0 ? '${(entries[i + 1].value * 100 / total).round()}%' : '0%',
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ));
      if (i + 2 < entries.length) rows.add(const SizedBox(height: 8));
    }
    return Column(children: rows);
  }

  Widget _buildLegendItem(Color color, String label, String percentage) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label ($percentage)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomBar(String label, int count, Color color) {
    final topRooms = _getTopRooms();
    final maxCount = topRooms.isNotEmpty ? topRooms.first.value : 1;
    final percentage = (count / maxCount).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827),
              ),
            ),
            Text(
              '$count Issues',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildEquipmentBar(String label, int count) {
    final typeCounts = _getRequestTypeCounts();
    final maxCount = typeCounts.isNotEmpty ? typeCounts.values.reduce((a, b) => a > b ? a : b) : 1;
    final heightPercentage = maxCount > 0 ? (count / maxCount).clamp(0.1, 1.0) : 0.1;

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 140 * heightPercentage,
            decoration: BoxDecoration(
              color: const Color(0xFF4169E1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // Data methods computed from real requests
  String _getTopCategoryCount() {
    final typeCounts = _getRequestTypeCounts();
    if (typeCounts.isEmpty) return '0';
    return '${typeCounts.values.first}';
  }

  String _getTopCategoryName() {
    final typeCounts = _getRequestTypeCounts();
    if (typeCounts.isEmpty) return 'N/A';
    return typeCounts.keys.first.toUpperCase();
  }

  Map<String, int> _getRequestTypeCounts() {
    final counts = <String, int>{};
    for (final r in _filteredByPeriod) {
      counts[r.typeOfRequest] = (counts[r.typeOfRequest] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  List<MapEntry<String, int>> _getTopRooms() {
    final counts = <String, int>{};
    for (final r in _filteredByPeriod) {
      final room = r.officeRoom.isNotEmpty ? r.officeRoom : 'Unknown';
      counts[room] = (counts[room] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).toList();
  }
}






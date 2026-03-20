import 'package:flutter/material.dart';

class MaintenanceHistoryPageWeb extends StatefulWidget {
  const MaintenanceHistoryPageWeb({super.key});

  @override
  State<MaintenanceHistoryPageWeb> createState() =>
      _MaintenanceHistoryPageWebState();
}

class _MaintenanceHistoryPageWebState
    extends State<MaintenanceHistoryPageWeb> {
  // Modern color palette
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color primaryIndigo = Color(0xFF6366F1);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color darkText = Color(0xFF0F172A);
  static const Color subtleText = Color(0xFF64748B);
  static const Color cardBackground = Colors.white;
  static const Color pageBackground = Color(0xFFF8FAFC);

  final List<Map<String, dynamic>> _maintenanceHistory = [
    {
      'id': 'MH-001',
      'workRequest': 'WR-001',
      'title': 'HVAC System Inspection',
      'type': 'Preventive Maintenance',
      'location': 'Building A, Room 101',
      'technician': 'Carlos Rodriguez',
      'startDate': '2026-02-15',
      'endDate': '2026-02-16',
      'status': 'Completed',
      'hoursSpent': '8',
      'notes': 'System cleaned and serviced. All components working properly.',
    },
    {
      'id': 'MH-002',
      'workRequest': 'WR-002',
      'title': 'Electrical Panel Upgrade',
      'type': 'Corrective Maintenance',
      'location': 'Building B, Room 205',
      'technician': 'Maria Santos',
      'startDate': '2026-02-20',
      'endDate': '2026-02-22',
      'status': 'Completed',
      'hoursSpent': '12',
      'notes': 'Panel upgraded to new standards. Safety inspection passed.',
    },
    {
      'id': 'MH-003',
      'workRequest': 'WR-003',
      'title': 'Plumbing Maintenance',
      'type': 'Preventive Maintenance',
      'location': 'Building C, Room 302',
      'technician': 'Juan Dela Cruz',
      'startDate': '2026-03-01',
      'endDate': '2026-03-02',
      'status': 'In Progress',
      'hoursSpent': '4',
      'notes': 'Cleaning pipes and checking for leaks.',
    },
  ];

  String _searchQuery = '';
  String _selectedFilter = 'All';

  List<Map<String, dynamic>> get _filteredHistory {
    var filtered = _maintenanceHistory;

    // Filter by status
    if (_selectedFilter != 'All') {
      filtered = filtered.where((item) =>
        item['status'].toString().toLowerCase() == _selectedFilter.toLowerCase()
      ).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (item) =>
                item['id']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                item['title']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                item['technician']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    return filtered;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFFDEF7EC);
      case 'in progress':
        return const Color(0xFFEFF6FF);
      case 'pending':
        return const Color(0xFFFEF3C7);
      default:
        return Colors.grey[100]!;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return successGreen;
      case 'in progress':
        return primaryBlue;
      case 'pending':
        return warningAmber;
      default:
        return Colors.grey[600]!;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'in progress':
        return Icons.autorenew_rounded;
      case 'pending':
        return Icons.schedule_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredHistory = _filteredHistory;

    return Material(
      color: pageBackground,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Header
              _buildHeader(),
              const SizedBox(height: 28),

              // Summary Stats Row
              _buildStatsRow(),
              const SizedBox(height: 28),

              // Filters and Search Row
              _buildFiltersRow(),
              const SizedBox(height: 24),

              // History Table
              _buildHistoryTable(filteredHistory),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryBlue, primaryIndigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MAINTENANCE HISTORY',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'View all completed and ongoing maintenance records',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          // Export Button
          _ModernHeaderButton(
            icon: Icons.download_rounded,
            label: 'Export',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Exporting maintenance records...'),
                  backgroundColor: successGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalRecords = _maintenanceHistory.length;
    final completedCount = _maintenanceHistory
        .where((m) => m['status'] == 'Completed')
        .length;
    final inProgressCount = _maintenanceHistory
        .where((m) => m['status'] == 'In Progress')
        .length;
    final totalHours = _maintenanceHistory.fold<int>(
      0,
      (sum, item) => sum + int.parse(item['hoursSpent'].toString()),
    );

    return Row(
      children: [
        Expanded(
          child: _ModernStatCard(
            title: 'Total Records',
            value: '$totalRecords',
            icon: Icons.history_rounded,
            color: primaryBlue,
            trend: '+5%',
            isUp: true,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _ModernStatCard(
            title: 'Completed',
            value: '$completedCount',
            icon: Icons.check_circle_rounded,
            color: successGreen,
            trend: '+12%',
            isUp: true,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _ModernStatCard(
            title: 'In Progress',
            value: '$inProgressCount',
            icon: Icons.autorenew_rounded,
            color: warningAmber,
            trend: '-2%',
            isUp: false,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _ModernStatCard(
            title: 'Total Hours',
            value: '${totalHours}h',
            icon: Icons.access_time_rounded,
            color: primaryIndigo,
            trend: '+8%',
            isUp: true,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersRow() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Search Field
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: pageBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search by ID, title, or technician...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Filter Chips
          _FilterChip(
            label: 'All',
            isSelected: _selectedFilter == 'All',
            onTap: () => setState(() => _selectedFilter = 'All'),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: 'Completed',
            isSelected: _selectedFilter == 'Completed',
            color: successGreen,
            onTap: () => setState(() => _selectedFilter = 'Completed'),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: 'In Progress',
            isSelected: _selectedFilter == 'In Progress',
            color: primaryBlue,
            onTap: () => setState(() => _selectedFilter = 'In Progress'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTable(List<Map<String, dynamic>> history) {
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(60),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: pageBackground,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.history_rounded,
                  size: 48,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Maintenance Records',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No maintenance history records found',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: pageBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                _TableHeader('ID', flex: 1),
                _TableHeader('Title', flex: 2),
                _TableHeader('Type', flex: 1),
                _TableHeader('Technician', flex: 1),
                _TableHeader('Status', flex: 1),
                _TableHeader('Hours', flex: 1),
                const SizedBox(width: 100, child: Text(
                  'Actions',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: subtleText,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                )),
              ],
            ),
          ),
          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: Colors.grey.withValues(alpha: 0.1),
            ),
            itemBuilder: (context, index) {
              final item = history[index];
              return _HistoryRow(
                item: item,
                statusColor: _getStatusColor(item['status']),
                statusTextColor: _getStatusTextColor(item['status']),
                statusIcon: _getStatusIcon(item['status']),
                onViewDetails: () => _showDetailsDialog(item),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => _ModernDetailsDialog(item: item),
    );
  }
}

class _ModernHeaderButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ModernHeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ModernHeaderButton> createState() => _ModernHeaderButtonState();
}

class _ModernHeaderButtonState extends State<_ModernHeaderButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernStatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String trend;
  final bool isUp;

  const _ModernStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
    required this.isUp,
  });

  @override
  State<_ModernStatCard> createState() => _ModernStatCardState();
}

class _ModernStatCardState extends State<_ModernStatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.3)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: _isHovered ? 16 : 12,
              offset: Offset(0, _isHovered ? 6 : 4),
            ),
          ],
        ),
        transform: _isHovered
            ? (Matrix4.identity()..translate(0.0, -3.0))
            : Matrix4.identity(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                widget.icon,
                color: widget.color,
                size: 26,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.value,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: widget.isUp
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : const Color(0xFFDC2626).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isUp
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 14,
                    color: widget.isUp
                        ? const Color(0xFF10B981)
                        : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.trend,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.isUp
                          ? const Color(0xFF10B981)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final chipColor = widget.color ?? const Color(0xFF3B82F6);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? chipColor.withValues(alpha: 0.15)
                : (_isHovered ? const Color(0xFFF1F5F9) : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isSelected
                  ? chipColor.withValues(alpha: 0.4)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.isSelected ? chipColor : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  final int flex;

  const _TableHeader(this.text, {this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _HistoryRow extends StatefulWidget {
  final Map<String, dynamic> item;
  final Color statusColor;
  final Color statusTextColor;
  final IconData statusIcon;
  final VoidCallback onViewDetails;

  const _HistoryRow({
    required this.item,
    required this.statusColor,
    required this.statusTextColor,
    required this.statusIcon,
    required this.onViewDetails,
  });

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _isHovered = false;
  bool _isViewHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _isHovered ? const Color(0xFFF8FAFC) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // ID
            Expanded(
              child: Text(
                widget.item['id'],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                  fontFamily: 'monospace',
                ),
              ),
            ),
            // Title & Location
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item['title'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.item['location'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Type
            Expanded(
              child: Text(
                widget.item['type'],
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Technician
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    child: Text(
                      widget.item['technician'].toString().substring(0, 1),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.item['technician'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Status
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.statusColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.statusTextColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.statusIcon,
                      size: 14,
                      color: widget.statusTextColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.item['status'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.statusTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Hours
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.item['hoursSpent']}h',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            // Actions
            SizedBox(
              width: 100,
              child: Center(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _isViewHovered = true),
                  onExit: (_) => setState(() => _isViewHovered = false),
                  child: GestureDetector(
                    onTap: widget.onViewDetails,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: _isViewHovered
                            ? const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                              )
                            : null,
                        color: _isViewHovered
                            ? null
                            : const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_rounded,
                            size: 14,
                            color: _isViewHovered
                                ? Colors.white
                                : const Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'View',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isViewHovered
                                  ? Colors.white
                                  : const Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> item;

  const _ModernDetailsDialog({required this.item});

  @override
  State<_ModernDetailsDialog> createState() => _ModernDetailsDialogState();
}

class _ModernDetailsDialogState extends State<_ModernDetailsDialog> {
  bool _isCloseHovered = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.description_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Maintenance Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.item['id'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Details Grid
                  Row(
                    children: [
                      Expanded(
                        child: _DetailField(
                          label: 'Work Request',
                          value: widget.item['workRequest'],
                          icon: Icons.assignment_rounded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _DetailField(
                          label: 'Type',
                          value: widget.item['type'],
                          icon: Icons.category_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _DetailField(
                          label: 'Start Date',
                          value: widget.item['startDate'],
                          icon: Icons.calendar_today_rounded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _DetailField(
                          label: 'End Date',
                          value: widget.item['endDate'],
                          icon: Icons.event_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _DetailField(
                          label: 'Technician',
                          value: widget.item['technician'],
                          icon: Icons.person_rounded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _DetailField(
                          label: 'Hours Spent',
                          value: '${widget.item['hoursSpent']} hours',
                          icon: Icons.access_time_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Notes Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notes_rounded,
                              size: 18,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Notes',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.item['notes'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _isCloseHovered = true),
                    onExit: (_) => setState(() => _isCloseHovered = false),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: _isCloseHovered
                              ? const LinearGradient(
                                  colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                                )
                              : null,
                          color: _isCloseHovered ? null : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isCloseHovered
                                ? Colors.transparent
                                : const Color(0xFF3B82F6),
                          ),
                          boxShadow: _isCloseHovered
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF3B82F6)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _isCloseHovered
                                ? Colors.white
                                : const Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

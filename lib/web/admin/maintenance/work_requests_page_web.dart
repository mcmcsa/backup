import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import 'request_details_page.dart';

class WorkRequestsPageWeb extends StatefulWidget {
  const WorkRequestsPageWeb({super.key});

  @override
  State<WorkRequestsPageWeb> createState() => _WorkRequestsPageWebState();
}

class _WorkRequestsPageWebState extends State<WorkRequestsPageWeb> {
  int _selectedFilter = 0;
  final TextEditingController _searchController = TextEditingController();
  List<WorkRequest> _requests = [];
  bool _isLoading = true;

  // Modern color palette
  static const _primaryBlue = Color(0xFF2563EB);
  static const _successGreen = Color(0xFF10B981);
  static const _warningOrange = Color(0xFFF59E0B);
  static const _dangerRed = Color(0xFFEF4444);
  static const _infoViolet = Color(0xFF8B5CF6);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _cardBg = Color(0xFFFFFFFF);
  static const _pageBg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final data = await WorkRequestService.fetchAll();
      if (mounted) {
        setState(() {
          _requests = data;
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

  List<WorkRequest> get _filteredRequests {
    final query = _searchController.text.toLowerCase();
    var requests = _requests;

    // Apply status filter
    switch (_selectedFilter) {
      case 1:
        requests = requests.where((r) => r.status.toLowerCase() == 'pending').toList();
        break;
      case 2:
        requests = requests.where((r) => r.status.toLowerCase() == 'approved').toList();
        break;
      case 3:
        requests = requests.where((r) =>
          r.status.toLowerCase() == 'in_progress' ||
          r.status.toLowerCase() == 'ongoing'
        ).toList();
        break;
      case 4:
        requests = requests.where((r) => r.status.toLowerCase() == 'under_maintenance').toList();
        break;
      case 5:
        requests = requests.where((r) =>
          r.status.toLowerCase() == 'completed' ||
          r.status.toLowerCase() == 'done'
        ).toList();
        break;
      case 6:
        requests = requests.where((r) => r.status.toLowerCase() == 'rework').toList();
        break;
    }

    // Apply search
    if (query.isNotEmpty) {
      requests = requests.where((r) =>
        r.title.toLowerCase().contains(query) ||
        r.id.toLowerCase().contains(query) ||
        r.department.toLowerCase().contains(query) ||
        r.buildingName.toLowerCase().contains(query)
      ).toList();
    }

    return requests;
  }

  int _getStatusCount(int filterIndex) {
    switch (filterIndex) {
      case 0:
        return _requests.length;
      case 1:
        return _requests.where((r) => r.status.toLowerCase() == 'pending').length;
      case 2:
        return _requests.where((r) => r.status.toLowerCase() == 'approved').length;
      case 3:
        return _requests.where((r) =>
          r.status.toLowerCase() == 'in_progress' ||
          r.status.toLowerCase() == 'ongoing'
        ).length;
      case 4:
        return _requests.where((r) => r.status.toLowerCase() == 'under_maintenance').length;
      case 5:
        return _requests.where((r) =>
          r.status.toLowerCase() == 'completed' ||
          r.status.toLowerCase() == 'done'
        ).length;
      case 6:
        return _requests.where((r) => r.status.toLowerCase() == 'rework').length;
      default:
        return 0;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _pageBg,
      child: Column(
        children: [
          // Modern Header
          _buildHeader(),

          // Content
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Cards
                        _buildStatsRow(),
                        const SizedBox(height: 28),

                        // Status Filter Tabs
                        _buildStatusTabs(),
                        const SizedBox(height: 24),

                        // Requests Table
                        _buildRequestsTable(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _cardBg,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Title Section
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryBlue, _primaryBlue.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.assignment_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Work Requests Management',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage and track all maintenance work requests',
                  style: TextStyle(
                    fontSize: 14,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Search
          Container(
            width: 350,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by title, ID, department...',
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(
                    Icons.search_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 46,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        color: const Color(0xFF94A3B8),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Refresh Button
          _ModernIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadRequests();
            },
          ),
          const SizedBox(width: 8),

          // Export Button
          _ModernIconButton(
            icon: Icons.download_rounded,
            tooltip: 'Export',
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(_primaryBlue),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading requests...',
            style: TextStyle(
              fontSize: 15,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final pendingCount = _getStatusCount(1);
    final inProgressCount = _getStatusCount(3);
    final completedCount = _getStatusCount(5);

    return Row(
      children: [
        Expanded(
          child: _ModernStatCard(
            title: 'Total Requests',
            value: _requests.length.toString(),
            icon: Icons.assignment_rounded,
            color: _primaryBlue,
            subtitle: 'All work requests',
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _ModernStatCard(
            title: 'Pending',
            value: pendingCount.toString(),
            icon: Icons.hourglass_empty_rounded,
            color: _warningOrange,
            subtitle: 'Awaiting approval',
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _ModernStatCard(
            title: 'In Progress',
            value: inProgressCount.toString(),
            icon: Icons.engineering_rounded,
            color: _infoViolet,
            subtitle: 'Currently being worked on',
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _ModernStatCard(
            title: 'Completed',
            value: completedCount.toString(),
            icon: Icons.check_circle_rounded,
            color: _successGreen,
            subtitle: 'Successfully resolved',
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTabs() {
    final statuses = [
      ('All', Icons.all_inbox_rounded, null),
      ('Pending', Icons.hourglass_empty_rounded, _warningOrange),
      ('Approved', Icons.thumb_up_rounded, _successGreen),
      ('In Progress', Icons.engineering_rounded, _primaryBlue),
      ('Maintenance', Icons.build_rounded, _infoViolet),
      ('Completed', Icons.check_circle_rounded, _successGreen),
      ('Rework', Icons.replay_rounded, _dangerRed),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(statuses.length, (index) {
          final status = statuses[index];
          final count = _getStatusCount(index);
          final isSelected = _selectedFilter == index;

          return Padding(
            padding: EdgeInsets.only(right: index < statuses.length - 1 ? 12 : 0),
            child: _StatusFilterChip(
              label: status.$1,
              icon: status.$2,
              count: count,
              color: status.$3 ?? _primaryBlue,
              isSelected: isSelected,
              onTap: () => setState(() => _selectedFilter = index),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRequestsTable() {
    final filtered = _filteredRequests;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.list_alt_rounded,
                    color: _primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Work Request Records',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${filtered.length} request${filtered.length != 1 ? 's' : ''} found',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Column Headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: _TableHeader('SUBJECT')),
                SizedBox(width: 110, child: _TableHeader('REQUEST ID')),
                Expanded(flex: 2, child: _TableHeader('DEPARTMENT')),
                SizedBox(width: 130, child: _TableHeader('STATUS')),
                SizedBox(width: 100, child: _TableHeader('PRIORITY')),
                SizedBox(width: 100, child: _TableHeader('DATE')),
                SizedBox(width: 100, child: _TableHeader('ACTIONS')),
              ],
            ),
          ),

          // Table Rows
          if (filtered.isEmpty)
            _buildEmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                color: Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                return _RequestRow(
                  request: filtered[index],
                  isLast: index == filtered.length - 1,
                  onView: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RequestDetailsPage(
                          request: filtered[index],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 40,
              color: _primaryBlue.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Work Requests Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No requests match your search criteria',
            style: TextStyle(
              fontSize: 14,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modern stat card
class _ModernStatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _ModernStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(24),
        transform: Matrix4.identity()..translate(0.0, _isHovered ? -4.0 : 0.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isHovered ? widget.color.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: _isHovered ? 24 : 12,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(widget.icon, color: widget.color, size: 26),
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
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
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

/// Status filter chip
class _StatusFilterChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.label,
    required this.icon,
    required this.count,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_StatusFilterChip> createState() => _StatusFilterChipState();
}

class _StatusFilterChipState extends State<_StatusFilterChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.color.withValues(alpha: 0.1)
                : _isHovered
                    ? const Color(0xFFF1F5F9)
                    : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? widget.color.withValues(alpha: 0.3)
                  : _isHovered
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFFF1F5F9),
              width: widget.isSelected ? 1.5 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isSelected ? widget.color : const Color(0xFF64748B),
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isSelected ? widget.color : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? widget.color
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modern icon button
class _ModernIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ModernIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_ModernIconButton> createState() => _ModernIconButtonState();
}

class _ModernIconButtonState extends State<_ModernIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isHovered ? const Color(0xFFE2E8F0) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: _isHovered ? const Color(0xFF475569) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

/// Table header
class _TableHeader extends StatelessWidget {
  final String text;

  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        letterSpacing: 0.8,
      ),
    );
  }
}

/// Request row widget
class _RequestRow extends StatefulWidget {
  final WorkRequest request;
  final bool isLast;
  final VoidCallback onView;

  const _RequestRow({
    required this.request,
    this.isLast = false,
    required this.onView,
  });

  @override
  State<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends State<_RequestRow> {
  bool _isHovered = false;

  (Color, String, IconData) _getStatusInfo() {
    switch (widget.request.status.toLowerCase()) {
      case 'pending':
        return (const Color(0xFFF59E0B), 'Pending', Icons.hourglass_empty_rounded);
      case 'approved':
        return (const Color(0xFF8B5CF6), 'Approved', Icons.thumb_up_rounded);
      case 'in_progress':
      case 'ongoing':
        return (const Color(0xFF2563EB), 'In Progress', Icons.engineering_rounded);
      case 'under_maintenance':
        return (const Color(0xFF8B5CF6), 'Maintenance', Icons.build_rounded);
      case 'completed':
      case 'done':
        return (const Color(0xFF10B981), 'Completed', Icons.check_circle_rounded);
      case 'rework':
        return (const Color(0xFFEF4444), 'Rework', Icons.replay_rounded);
      case 'cancelled':
        return (const Color(0xFF64748B), 'Cancelled', Icons.cancel_rounded);
      default:
        return (const Color(0xFF64748B), widget.request.status, Icons.help_outline_rounded);
    }
  }

  (Color, String) _getPriorityInfo() {
    switch (widget.request.priority.toLowerCase()) {
      case 'high':
        return (const Color(0xFFEF4444), 'High');
      case 'medium':
        return (const Color(0xFFF59E0B), 'Medium');
      case 'low':
        return (const Color(0xFF10B981), 'Low');
      default:
        return (const Color(0xFF64748B), widget.request.priority);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo();
    final priorityInfo = _getPriorityInfo();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: widget.isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(18))
              : null,
        ),
        child: Row(
          children: [
            // Subject
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.request.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.request.officeRoom} • ${widget.request.buildingName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

            // Request ID
            SizedBox(
              width: 110,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${widget.request.id.substring(0, widget.request.id.length > 8 ? 8 : widget.request.id.length).toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),

            // Department
            Expanded(
              flex: 2,
              child: Text(
                widget.request.department,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Status
            SizedBox(
              width: 130,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: statusInfo.$1.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusInfo.$3, size: 14, color: statusInfo.$1),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        statusInfo.$2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusInfo.$1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Priority
            SizedBox(
              width: 100,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: priorityInfo.$1.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: priorityInfo.$1,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      priorityInfo.$2,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: priorityInfo.$1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Date
            SizedBox(
              width: 100,
              child: Text(
                DateFormat('MMM dd').format(widget.request.dateSubmitted),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ),

            // Actions
            SizedBox(
              width: 100,
              child: _ViewButton(onPressed: widget.onView),
            ),
          ],
        ),
      ),
    );
  }
}

/// View button
class _ViewButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _ViewButton({required this.onPressed});

  @override
  State<_ViewButton> createState() => _ViewButtonState();
}

class _ViewButtonState extends State<_ViewButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isHovered
                  ? [const Color(0xFF1D4ED8), const Color(0xFF1E40AF)]
                  : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: _isHovered ? 0.3 : 0.2),
                blurRadius: _isHovered ? 10 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility_outlined, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'View',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

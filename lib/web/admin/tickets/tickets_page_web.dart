import 'package:flutter/material.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import 'package:intl/intl.dart';

class TicketsPageWeb extends StatefulWidget {
  const TicketsPageWeb({super.key});

  @override
  State<TicketsPageWeb> createState() => _TicketsPageWebState();
}

class _TicketsPageWebState extends State<TicketsPageWeb> {
  int _selectedFilter = 0;
  final TextEditingController _searchController = TextEditingController();
  List<WorkRequest> _requests = [];
  bool _isLoading = true;

  // Professional color palette
  static const Color _primaryBlue = Color(0xFF3B82F6);
  static const Color _successGreen = Color(0xFF22C55E);
  static const Color _warningYellow = Color(0xFFFBBF24);
  static const Color _darkText = Color(0xFF1E293B);
  static const Color _subtleText = Color(0xFF64748B);
  static const Color _pageBg = Color(0xFFF1F5F9);

  final List<String> _filters = ['All Tickets', 'Pending', 'Active', 'Completed'];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<WorkRequest> get _filteredRequests {
    final query = _searchController.text.toLowerCase();
    var requests = _requests;

    // Apply status filter
    if (_selectedFilter == 1) {
      requests = requests.where((r) => r.status.toLowerCase() == 'pending').toList();
    } else if (_selectedFilter == 2) {
      requests = requests.where((r) =>
        r.status.toLowerCase() == 'in_progress' ||
        r.status.toLowerCase() == 'approved' ||
        r.status.toLowerCase() == 'under_maintenance'
      ).toList();
    } else if (_selectedFilter == 3) {
      requests = requests.where((r) => r.status.toLowerCase() == 'completed').toList();
    }

    // Apply search filter
    if (query.isNotEmpty) {
      requests = requests.where((r) =>
        r.title.toLowerCase().contains(query) ||
        r.id.toLowerCase().contains(query) ||
        r.requestorName.toLowerCase().contains(query)
      ).toList();
    }

    return requests;
  }

  int _getCountByFilter(int filter) {
    switch (filter) {
      case 0: return _requests.length;
      case 1: return _requests.where((r) => r.status.toLowerCase() == 'pending').length;
      case 2: return _requests.where((r) =>
        r.status.toLowerCase() == 'in_progress' ||
        r.status.toLowerCase() == 'approved' ||
        r.status.toLowerCase() == 'under_maintenance'
      ).length;
      case 3: return _requests.where((r) => r.status.toLowerCase() == 'completed').length;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _pageBg,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Cards Row
                  _buildStatsRow(),
                  const SizedBox(height: 24),

                  // Main Content Card
                  _buildMainCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'All Tickets',
            value: _getCountByFilter(0),
            icon: Icons.confirmation_num_rounded,
            iconColor: _primaryBlue,
            isSelected: _selectedFilter == 0,
            onTap: () => setState(() => _selectedFilter = 0),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Pending',
            value: _getCountByFilter(1),
            icon: Icons.hourglass_empty_rounded,
            iconColor: _warningYellow,
            isSelected: _selectedFilter == 1,
            onTap: () => setState(() => _selectedFilter = 1),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Active',
            value: _getCountByFilter(2),
            icon: Icons.build_rounded,
            iconColor: _primaryBlue,
            isSelected: _selectedFilter == 2,
            onTap: () => setState(() => _selectedFilter = 2),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Completed',
            value: _getCountByFilter(3),
            icon: Icons.check_circle_rounded,
            iconColor: _successGreen,
            isSelected: _selectedFilter == 3,
            onTap: () => setState(() => _selectedFilter = 3),
          ),
        ),
      ],
    );
  }

  Widget _buildMainCard() {
    final filteredRequests = _filteredRequests;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.confirmation_num_rounded, color: _primaryBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _filters[_selectedFilter],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _darkText,
                      ),
                    ),
                    Text(
                      '${filteredRequests.length} tickets',
                      style: const TextStyle(fontSize: 13, color: _subtleText),
                    ),
                  ],
                ),
                const Spacer(),
                // Search
                Container(
                  width: 280,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _pageBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search tickets...',
                      hintStyle: TextStyle(color: _subtleText, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: _subtleText, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: _pageBg,
              border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(width: 100, child: _TableHeader('TICKET #')),
                Expanded(flex: 2, child: _TableHeader('SUBJECT')),
                Expanded(child: _TableHeader('REQUESTOR')),
                Expanded(child: _TableHeader('LOCATION')),
                SizedBox(width: 100, child: _TableHeader('PRIORITY')),
                SizedBox(width: 100, child: _TableHeader('STATUS')),
                SizedBox(width: 100, child: _TableHeader('DATE')),
              ],
            ),
          ),

          // Table Body
          if (filteredRequests.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text(
                    'No tickets found',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _subtleText),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredRequests.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
              itemBuilder: (context, index) {
                final request = filteredRequests[index];
                return _TicketRow(request: request);
              },
            ),
        ],
      ),
    );
  }
}

// ==================== WIDGETS ====================

class _StatCard extends StatefulWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(20),
          transform: Matrix4.identity()..translate(0.0, _isHovered ? -2.0 : 0.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? widget.iconColor.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? widget.iconColor.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: _isHovered ? 16 : 12,
                offset: Offset(0, _isHovered ? 6 : 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.value.toString(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        letterSpacing: 0.5,
      ),
    );
  }
}

class _TicketRow extends StatefulWidget {
  final WorkRequest request;
  const _TicketRow({required this.request});

  @override
  State<_TicketRow> createState() => _TicketRowState();
}

class _TicketRowState extends State<_TicketRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
        child: Row(
          children: [
            // Ticket ID
            SizedBox(
              width: 100,
              child: Text(
                '#${widget.request.id.length > 6 ? widget.request.id.substring(0, 6) : widget.request.id}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3B82F6),
                  fontFamily: 'monospace',
                ),
              ),
            ),
            // Subject
            Expanded(
              flex: 2,
              child: Text(
                widget.request.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Requestor
            Expanded(
              child: Text(
                widget.request.requestorName,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Location
            Expanded(
              child: Text(
                '${widget.request.officeRoom}, ${widget.request.buildingName}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Priority
            SizedBox(width: 100, child: _PriorityBadge(priority: widget.request.priority)),
            // Status
            SizedBox(width: 100, child: _StatusBadge(status: widget.request.status)),
            // Date
            SizedBox(
              width: 100,
              child: Text(
                DateFormat('MMM d, y').format(widget.request.dateSubmitted),
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: config.textColor,
        ),
      ),
    );
  }

  _Config _getConfig() {
    switch (status.toLowerCase()) {
      case 'pending':
        return _Config('REVIEW', const Color(0xFFFEF3C7), const Color(0xFFD97706));
      case 'approved':
      case 'in_progress':
      case 'under_maintenance':
        return _Config('ACTIVE', const Color(0xFFDBEAFE), const Color(0xFF2563EB));
      case 'completed':
        return _Config('DONE', const Color(0xFFDCFCE7), const Color(0xFF16A34A));
      case 'rework':
        return _Config('REWORK', const Color(0xFFFEE2E2), const Color(0xFFDC2626));
      default:
        return _Config(status.toUpperCase(), const Color(0xFFF1F5F9), const Color(0xFF64748B));
    }
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: config.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          priority.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: config.color,
          ),
        ),
      ],
    );
  }

  _PriorityConfig _getConfig() {
    switch (priority.toLowerCase()) {
      case 'high':
        return _PriorityConfig(const Color(0xFFDC2626));
      case 'medium':
        return _PriorityConfig(const Color(0xFFD97706));
      case 'low':
        return _PriorityConfig(const Color(0xFF16A34A));
      default:
        return _PriorityConfig(const Color(0xFF64748B));
    }
  }
}

class _Config {
  final String label;
  final Color bgColor;
  final Color textColor;
  _Config(this.label, this.bgColor, this.textColor);
}

class _PriorityConfig {
  final Color color;
  _PriorityConfig(this.color);
}

import 'package:flutter/material.dart';

class ApprovalQueuePageWeb extends StatefulWidget {
  const ApprovalQueuePageWeb({super.key});

  @override
  State<ApprovalQueuePageWeb> createState() =>
      _ApprovalQueuePageWebState();
}

class _ApprovalQueuePageWebState extends State<ApprovalQueuePageWeb> {
  String _searchQuery = '';
  String _selectedPriority = 'All Priorities';

  // Modern color palette
  static const _primaryBlue = Color(0xFF2563EB);
  static const _successGreen = Color(0xFF10B981);
  static const _warningOrange = Color(0xFFF59E0B);
  static const _dangerRed = Color(0xFFEF4444);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _cardBg = Color(0xFFFFFFFF);
  static const _pageBg = Color(0xFFF8FAFC);

  final List<Map<String, dynamic>> _approvalQueue = [
    {
      'id': 'WR-001',
      'title': 'Fix HVAC System',
      'description': 'Air conditioning unit not working properly in the main lecture hall',
      'department': 'Engineering',
      'room': 'Room 101',
      'building': 'Main Building',
      'requestor': 'John Doe',
      'submittedDate': '2026-03-10',
      'priority': 'High',
      'status': 'Pending Approval',
    },
    {
      'id': 'WR-002',
      'title': 'Replace Light Bulbs',
      'description': 'Multiple fluorescent lights flickering in the laboratory',
      'department': 'Science',
      'room': 'Lab 205',
      'building': 'Science Building',
      'requestor': 'Jane Smith',
      'submittedDate': '2026-03-11',
      'priority': 'Low',
      'status': 'Pending Approval',
    },
    {
      'id': 'WR-003',
      'title': 'Repair Door Lock',
      'description': 'Door lock mechanism is broken, security concern',
      'department': 'Administration',
      'room': 'Office 302',
      'building': 'Admin Building',
      'requestor': 'Mike Johnson',
      'submittedDate': '2026-03-12',
      'priority': 'Medium',
      'status': 'Pending Approval',
    },
    {
      'id': 'WR-004',
      'title': 'Fix Water Leak',
      'description': 'Water leaking from ceiling, causing floor damage',
      'department': 'Facilities',
      'room': 'Room 408',
      'building': 'East Wing',
      'requestor': 'Sarah Wilson',
      'submittedDate': '2026-03-13',
      'priority': 'High',
      'status': 'Pending Approval',
    },
  ];

  List<Map<String, dynamic>> get _filteredQueue {
    var queue = _approvalQueue;

    if (_selectedPriority != 'All Priorities') {
      queue = queue.where((item) => item['priority'] == _selectedPriority).toList();
    }

    if (_searchQuery.isNotEmpty) {
      queue = queue.where((item) =>
        item['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
        item['id'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
        item['requestor'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    return queue;
  }

  int get _highPriorityCount => _approvalQueue.where((item) => item['priority'] == 'High').length;
  int get _mediumPriorityCount => _approvalQueue.where((item) => item['priority'] == 'Medium').length;
  int get _lowPriorityCount => _approvalQueue.where((item) => item['priority'] == 'Low').length;

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Cards
                  _buildStatsRow(),
                  const SizedBox(height: 28),

                  // Approval Queue Table
                  _buildApprovalQueueTable(),
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
                colors: [_warningOrange, _warningOrange.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _warningOrange.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.pending_actions_rounded,
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
                  'Approval Queue',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Review and approve pending work requests',
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
            width: 320,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                hintText: 'Search requests...',
                hintStyle: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(
                    Icons.search_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
                prefixIconConstraints: BoxConstraints(
                  minWidth: 44,
                  minHeight: 46,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Priority Filter
          _ModernFilterDropdown(
            icon: Icons.flag_rounded,
            value: _selectedPriority,
            items: ['All Priorities', 'High', 'Medium', 'Low'],
            onChanged: (value) => setState(() => _selectedPriority = value!),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _ModernStatCard(
            title: 'Total Pending',
            value: _approvalQueue.length.toString(),
            icon: Icons.pending_actions_rounded,
            color: _primaryBlue,
            subtitle: 'Awaiting review',
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _ModernStatCard(
            title: 'High Priority',
            value: _highPriorityCount.toString(),
            icon: Icons.keyboard_double_arrow_up_rounded,
            color: _dangerRed,
            subtitle: 'Urgent requests',
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _ModernStatCard(
            title: 'Medium Priority',
            value: _mediumPriorityCount.toString(),
            icon: Icons.remove_rounded,
            color: _warningOrange,
            subtitle: 'Standard requests',
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _ModernStatCard(
            title: 'Low Priority',
            value: _lowPriorityCount.toString(),
            icon: Icons.keyboard_double_arrow_down_rounded,
            color: _successGreen,
            subtitle: 'Non-urgent requests',
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalQueueTable() {
    final filtered = _filteredQueue;

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
          // Table Header Title
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
                    color: _warningOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assignment_rounded,
                    color: _warningOrange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pending Approvals',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${filtered.length} request${filtered.length != 1 ? 's' : ''} awaiting approval',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _ModernIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh',
                  onPressed: () {},
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
                SizedBox(width: 100, child: _TableHeader('REQUEST ID')),
                Expanded(flex: 3, child: _TableHeader('SUBJECT')),
                Expanded(flex: 2, child: _TableHeader('REQUESTOR')),
                Expanded(flex: 2, child: _TableHeader('LOCATION')),
                SizedBox(width: 100, child: _TableHeader('PRIORITY')),
                SizedBox(width: 100, child: _TableHeader('DATE')),
                SizedBox(width: 180, child: _TableHeader('ACTIONS')),
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
                return _ApprovalRow(
                  item: filtered[index],
                  isLast: index == filtered.length - 1,
                  onApprove: () => _showApproveDialog(filtered[index]),
                  onReject: () => _showRejectDialog(filtered[index]),
                  onView: () => _showDetailsDialog(filtered[index]),
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
              color: _successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 40,
              color: _successGreen,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'All Caught Up!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No pending requests to approve',
            style: TextStyle(
              fontSize: 14,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _ApprovalDialog(
        title: 'Approve Request',
        description: 'Are you sure you want to approve "${item['title']}"?',
        confirmLabel: 'Approve',
        confirmColor: _successGreen,
        icon: Icons.check_circle_rounded,
        onConfirm: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request ${item['id']} approved'),
              backgroundColor: _successGreen,
            ),
          );
        },
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _ApprovalDialog(
        title: 'Reject Request',
        description: 'Are you sure you want to reject "${item['title']}"? This action cannot be undone.',
        confirmLabel: 'Reject',
        confirmColor: _dangerRed,
        icon: Icons.cancel_rounded,
        onConfirm: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request ${item['id']} rejected'),
              backgroundColor: _dangerRed,
            ),
          );
        },
      ),
    );
  }

  void _showDetailsDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          margin: const EdgeInsets.all(24),
          child: Material(
            color: Colors.transparent,
            child: Container(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _primaryBlue.withValues(alpha: 0.05),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.assignment_rounded,
                            color: _primaryBlue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['id'],
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _textSecondary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          color: _textSecondary,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(label: 'Description', value: item['description']),
                        const SizedBox(height: 16),
                        _DetailRow(label: 'Department', value: item['department']),
                        const SizedBox(height: 16),
                        _DetailRow(label: 'Location', value: '${item['room']}, ${item['building']}'),
                        const SizedBox(height: 16),
                        _DetailRow(label: 'Requestor', value: item['requestor']),
                        const SizedBox(height: 16),
                        _DetailRow(label: 'Submitted', value: item['submittedDate']),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text(
                              'Priority: ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _textSecondary,
                              ),
                            ),
                            _PriorityBadge(priority: item['priority']),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern filter dropdown
class _ModernFilterDropdown extends StatelessWidget {
  final IconData icon;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _ModernFilterDropdown({
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
              icon: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: Color(0xFF64748B),
                ),
              ),
              items: items
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: onChanged,
              isDense: true,
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _isHovered ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
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

/// Approval row widget
class _ApprovalRow extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isLast;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onView;

  const _ApprovalRow({
    required this.item,
    this.isLast = false,
    required this.onApprove,
    required this.onReject,
    required this.onView,
  });

  @override
  State<_ApprovalRow> createState() => _ApprovalRowState();
}

class _ApprovalRowState extends State<_ApprovalRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
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
            // Request ID
            SizedBox(
              width: 100,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.item['id'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),

            // Subject
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
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
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.item['department'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Requestor
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        widget.item['requestor'].substring(0, 1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.item['requestor'],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Location
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.item['room'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Priority
            SizedBox(
              width: 100,
              child: _PriorityBadge(priority: widget.item['priority']),
            ),

            // Date
            SizedBox(
              width: 100,
              child: Text(
                widget.item['submittedDate'],
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ),

            // Actions
            SizedBox(
              width: 180,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionButton(
                    icon: Icons.visibility_outlined,
                    tooltip: 'View Details',
                    onPressed: widget.onView,
                  ),
                  const SizedBox(width: 8),
                  _ApproveButton(onPressed: widget.onApprove),
                  const SizedBox(width: 8),
                  _RejectButton(onPressed: widget.onReject),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Priority badge
class _PriorityBadge extends StatelessWidget {
  final String priority;

  const _PriorityBadge({required this.priority});

  Color get _color {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData get _icon {
    switch (priority.toLowerCase()) {
      case 'high':
        return Icons.keyboard_double_arrow_up_rounded;
      case 'medium':
        return Icons.remove_rounded;
      case 'low':
        return Icons.keyboard_double_arrow_down_rounded;
      default:
        return Icons.remove_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: _color),
          const SizedBox(width: 6),
          Text(
            priority,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Action button
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
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
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _isHovered ? const Color(0xFFF1F5F9) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: _isHovered ? const Color(0xFF475569) : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }
}

/// Approve button
class _ApproveButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _ApproveButton({required this.onPressed});

  @override
  State<_ApproveButton> createState() => _ApproveButtonState();
}

class _ApproveButtonState extends State<_ApproveButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0xFF059669)
                : const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_rounded, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Approve',
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

/// Reject button
class _RejectButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _RejectButton({required this.onPressed});

  @override
  State<_RejectButton> createState() => _RejectButtonState();
}

class _RejectButtonState extends State<_RejectButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFEF4444),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close_rounded, size: 16, color: Color(0xFFEF4444)),
              SizedBox(width: 6),
              Text(
                'Reject',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail row
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

/// Approval dialog
class _ApprovalDialog extends StatelessWidget {
  final String title;
  final String description;
  final String confirmLabel;
  final Color confirmColor;
  final IconData icon;
  final VoidCallback onConfirm;

  const _ApprovalDialog({
    required this.title,
    required this.description,
    required this.confirmLabel,
    required this.confirmColor,
    required this.icon,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.all(24),
        child: Material(
          color: Colors.transparent,
          child: Container(
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: confirmColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: confirmColor, size: 32),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onConfirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: confirmColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            confirmLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

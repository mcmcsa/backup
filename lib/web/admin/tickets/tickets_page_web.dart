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
  String? _selectedPriority;
  String _sortBy = 'date';
  bool _sortAscending = false;

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
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<WorkRequest> get _filteredRequests {
    final query = _searchController.text.toLowerCase();
    var requests = _requests;

    // Status filter
    if (_selectedFilter == 1) {
      requests = requests.where((r) => r.status == 'pending').toList();
    } else if (_selectedFilter == 2) {
      requests = requests.where((r) => r.status == 'ongoing').toList();
    } else if (_selectedFilter == 3) {
      requests = requests.where((r) => r.status == 'done').toList();
    }

    // Priority filter
    if (_selectedPriority != null) {
      requests = requests.where((r) => r.priority == _selectedPriority).toList();
    }

    // Search filter
    if (query.isNotEmpty) {
      requests = requests
          .where((r) =>
              r.title.toLowerCase().contains(query) ||
              r.requestorName.toLowerCase().contains(query) ||
              r.id.toLowerCase().contains(query))
          .toList();
    }

    // Sort
    requests.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'title':
          cmp = a.title.compareTo(b.title);
          break;
        case 'requestor':
          cmp = a.requestorName.compareTo(b.requestorName);
          break;
        case 'priority':
          final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
          cmp = (priorityOrder[a.priority] ?? 3)
              .compareTo(priorityOrder[b.priority] ?? 3);
          break;
        case 'status':
          cmp = a.status.compareTo(b.status);
          break;
        case 'date':
        default:
          cmp = a.dateSubmitted.compareTo(b.dateSubmitted);
      }
      return _sortAscending ? cmp : -cmp;
    });

    return requests;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _requests.where((r) => r.status == 'pending').length;
    final ongoingCount = _requests.where((r) => r.status == 'ongoing').length;
    final completedCount = _requests.where((r) => r.status == 'done').length;

    return Column(
      children: [
        // Header Section
        Container(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Row - Stats and Search
              Row(
                children: [
                  // Status Tabs
                  _StatusTab(
                    label: 'All',
                    count: _requests.length,
                    isSelected: _selectedFilter == 0,
                    onTap: () => setState(() => _selectedFilter = 0),
                  ),
                  const SizedBox(width: 8),
                  _StatusTab(
                    label: 'Pending',
                    count: pendingCount,
                    color: const Color(0xFFD97706),
                    isSelected: _selectedFilter == 1,
                    onTap: () => setState(() => _selectedFilter = 1),
                  ),
                  const SizedBox(width: 8),
                  _StatusTab(
                    label: 'In Progress',
                    count: ongoingCount,
                    color: const Color(0xFF2563EB),
                    isSelected: _selectedFilter == 2,
                    onTap: () => setState(() => _selectedFilter = 2),
                  ),
                  const SizedBox(width: 8),
                  _StatusTab(
                    label: 'Completed',
                    count: completedCount,
                    color: const Color(0xFF059669),
                    isSelected: _selectedFilter == 3,
                    onTap: () => setState(() => _selectedFilter = 3),
                  ),
                  const Spacer(),
                  // Search
                  Container(
                    width: 280,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search tickets...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF94A3B8),
                          size: 20,
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
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Bottom Row - Filters and Actions
              Row(
                children: [
                  // Priority Filter
                  _FilterDropdown(
                    icon: Icons.flag_outlined,
                    label: 'Priority',
                    value: _selectedPriority,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Priorities')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                    ],
                    onChanged: (value) => setState(() => _selectedPriority = value),
                  ),
                  const SizedBox(width: 12),
                  // Sort Dropdown
                  _FilterDropdown(
                    icon: Icons.sort_rounded,
                    label: 'Sort by',
                    value: _sortBy,
                    items: const [
                      DropdownMenuItem(value: 'date', child: Text('Date')),
                      DropdownMenuItem(value: 'title', child: Text('Title')),
                      DropdownMenuItem(value: 'priority', child: Text('Priority')),
                      DropdownMenuItem(value: 'status', child: Text('Status')),
                    ],
                    onChanged: (value) => setState(() => _sortBy = value ?? 'date'),
                  ),
                  const SizedBox(width: 8),
                  // Sort Direction
                  InkWell(
                    onTap: () => setState(() => _sortAscending = !_sortAscending),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Icon(
                        _sortAscending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 18,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Results count
                  Text(
                    '${_filteredRequests.length} ticket${_filteredRequests.length != 1 ? 's' : ''} found',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Export Button
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Export'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Refresh Button
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _loadRequests();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Table Content
        Expanded(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Loading tickets...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : _filteredRequests.isEmpty
                  ? _EmptyState(hasFilters: _selectedFilter != 0 || _selectedPriority != null || _searchController.text.isNotEmpty)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
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
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                border: Border(
                                  bottom: BorderSide(color: Color(0xFFF1F5F9)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(flex: 2, child: _SortableHeader(title: 'TICKET ID', sortKey: 'id', currentSort: _sortBy, ascending: _sortAscending, onSort: (_) {})),
                                  Expanded(flex: 3, child: _SortableHeader(title: 'DESCRIPTION', sortKey: 'title', currentSort: _sortBy, ascending: _sortAscending, onSort: (key) => setState(() { _sortBy = key; }))),
                                  Expanded(flex: 2, child: _SortableHeader(title: 'REQUESTOR', sortKey: 'requestor', currentSort: _sortBy, ascending: _sortAscending, onSort: (key) => setState(() { _sortBy = key; }))),
                                  Expanded(flex: 2, child: _SortableHeader(title: 'DATE', sortKey: 'date', currentSort: _sortBy, ascending: _sortAscending, onSort: (key) => setState(() { _sortBy = key; }))),
                                  const SizedBox(width: 100, child: _TableHeader('PRIORITY')),
                                  const SizedBox(width: 110, child: _TableHeader('STATUS')),
                                  const SizedBox(width: 80, child: _TableHeader('ACTIONS')),
                                ],
                              ),
                            ),
                            // Table Body
                            ...List.generate(_filteredRequests.length, (index) {
                              return _TicketRow(
                                request: _filteredRequests[index],
                                isLast: index == _filteredRequests.length - 1,
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _StatusTab extends StatefulWidget {
  final String label;
  final int count;
  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusTab({
    required this.label,
    required this.count,
    this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<_StatusTab> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ?? const Color(0xFF475569);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? baseColor.withValues(alpha: 0.1)
                : _isHovered
                    ? const Color(0xFFF8FAFC)
                    : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isSelected
                  ? baseColor.withValues(alpha: 0.3)
                  : _isHovered
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFFF1F5F9),
              width: widget.isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isSelected ? baseColor : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? baseColor
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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

class _FilterDropdown extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final List<DropdownMenuItem<String?>> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
              items: items,
              onChanged: onChanged,
              isDense: true,
            ),
          ),
        ],
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
        fontWeight: FontWeight.w600,
        color: Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SortableHeader extends StatefulWidget {
  final String title;
  final String sortKey;
  final String currentSort;
  final bool ascending;
  final ValueChanged<String> onSort;

  const _SortableHeader({
    required this.title,
    required this.sortKey,
    required this.currentSort,
    required this.ascending,
    required this.onSort,
  });

  @override
  State<_SortableHeader> createState() => _SortableHeaderState();
}

class _SortableHeaderState extends State<_SortableHeader> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.currentSort == widget.sortKey;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onSort(widget.sortKey),
        child: Row(
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            if (_isHovered || isActive) ...[
              const SizedBox(width: 4),
              Icon(
                isActive
                    ? (widget.ascending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                    : Icons.unfold_more_rounded,
                size: 14,
                color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TicketRow extends StatefulWidget {
  final WorkRequest request;
  final bool isLast;

  const _TicketRow({required this.request, this.isLast = false});

  @override
  State<_TicketRow> createState() => _TicketRowState();
}

class _TicketRowState extends State<_TicketRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (widget.request.status) {
      case 'pending':
        statusColor = const Color(0xFFD97706);
        statusText = 'Pending';
        statusIcon = Icons.schedule_rounded;
        break;
      case 'ongoing':
        statusColor = const Color(0xFF2563EB);
        statusText = 'In Progress';
        statusIcon = Icons.engineering_rounded;
        break;
      case 'done':
        statusColor = const Color(0xFF059669);
        statusText = 'Completed';
        statusIcon = Icons.check_circle_rounded;
        break;
      default:
        statusColor = const Color(0xFF64748B);
        statusText = widget.request.status;
        statusIcon = Icons.help_outline_rounded;
    }

    Color priorityColor;
    String priorityText;
    switch (widget.request.priority) {
      case 'high':
        priorityColor = const Color(0xFFDC2626);
        priorityText = 'High';
        break;
      case 'medium':
        priorityColor = const Color(0xFFD97706);
        priorityText = 'Medium';
        break;
      case 'low':
        priorityColor = const Color(0xFF059669);
        priorityText = 'Low';
        break;
      default:
        priorityColor = const Color(0xFF64748B);
        priorityText = widget.request.priority;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFFAFAFA) : Colors.white,
          border: widget.isLast
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFF8FAFC))),
          borderRadius: widget.isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(16))
              : null,
        ),
        child: Row(
          children: [
            // Ticket ID
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${widget.request.id.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            // Description
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  widget.request.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
            // Requestor
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Center(
                      child: Text(
                        widget.request.requestorName.isNotEmpty
                            ? widget.request.requestorName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.request.requestorName,
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
            // Date
            Expanded(
              flex: 2,
              child: Text(
                DateFormat('MMM dd, yyyy').format(widget.request.dateSubmitted),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            // Priority
            SizedBox(
              width: 100,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: priorityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      priorityText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: priorityColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Status
            SizedBox(
              width: 110,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Actions
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionButton(
                    icon: Icons.visibility_outlined,
                    tooltip: 'View Details',
                    onPressed: () {},
                  ),
                  _ActionButton(
                    icon: Icons.more_horiz_rounded,
                    tooltip: 'More Options',
                    onPressed: () {},
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
              borderRadius: BorderRadius.circular(6),
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

class _EmptyState extends StatelessWidget {
  final bool hasFilters;

  const _EmptyState({this.hasFilters = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              size: 40,
              color: Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            hasFilters ? 'No tickets match your filters' : 'No tickets yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Try adjusting your search or filter criteria'
                : 'Maintenance requests will appear here when submitted',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text('Clear Filters'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF3B82F6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

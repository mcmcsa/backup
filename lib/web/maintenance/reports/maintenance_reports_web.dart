import 'package:flutter/material.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../maintenance_nav_controller.dart';

// ─── Design Tokens ─────────────────────────────────────────────────────────
const Color _blue = Color(0xFF0EA5E9);
const Color _green = Color(0xFF10B981);
const Color _orange = Color(0xFFF59E0B);
const Color _red = Color(0xFFEF4444);
const Color _indigo = Color(0xFF6366F1);
const Color _ink = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);
const Color _pageBg = Color(0xFFF1F5F9);
const Color _card = Colors.white;
const Color _border = Color(0xFFE2E8F0);

class MaintenanceReportsWeb extends StatefulWidget {
  const MaintenanceReportsWeb({super.key});

  @override
  State<MaintenanceReportsWeb> createState() => _MaintenanceReportsWebState();
}

class _MaintenanceReportsWebState extends State<MaintenanceReportsWeb> {
  List<WorkRequest> _requests = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  final _filters = ['All', 'Pending', 'In Progress', 'Completed', 'High Priority'];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final data = await WorkRequestService.fetchAll();
      if (mounted) setState(() { _requests = data; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WorkRequest> get _filtered {
    List<WorkRequest> list = _requests;
    if (_selectedFilter == 'Pending') {
      list = list.where((r) => r.status == 'pending').toList();
    } else if (_selectedFilter == 'In Progress') {
      list = list.where((r) => r.status == 'in_progress' || r.status == 'under_maintenance').toList();
    } else if (_selectedFilter == 'Completed') {
      list = list.where((r) => r.status == 'completed').toList();
    } else if (_selectedFilter == 'High Priority') {
      list = list.where((r) => r.priority == 'high').toList();
    }
    final q = _searchController.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) =>
          r.id.toLowerCase().contains(q) ||
          (r.roomName?.toLowerCase().contains(q) ?? false) ||
          r.title.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return _green;
      case 'in_progress':
      case 'under_maintenance': return _indigo;
      case 'pending': return _orange;
      default: return _muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(color: _pageBg, child: const Center(child: CircularProgressIndicator(color: _blue)));
    }

    final isMobile = MediaQuery.of(context).size.width < 768;
    final filtered = _filtered;

    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            _buildHeader(filtered.length),
            const SizedBox(height: 24),

            // ── Search + Filters ─────────────────────────────────────────
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildFilterBar(isMobile),
            const SizedBox(height: 28),

            // ── Table ───────────────────────────────────────────────────
            _buildTable(filtered, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Work Reports', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              const Text('All maintenance work requests across the campus.', style: TextStyle(fontSize: 14, color: _muted)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _blue.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.assignment_rounded, size: 14, color: _blue),
              const SizedBox(width: 6),
              Text('$count records', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _blue)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search by tracking number, title or room...',
          hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFilterBar(bool isMobile) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((f) {
          final isSelected = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _FilterChip(
              label: f,
              isSelected: isSelected,
              onTap: () => setState(() => _selectedFilter = f),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTable(List<WorkRequest> filtered, bool isMobile) {
    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 64),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Icon(Icons.assignment_outlined, size: 52, color: _muted.withValues(alpha: 0.25)),
            const SizedBox(height: 14),
            const Text('No reports found', style: TextStyle(fontSize: 15, color: _muted, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            const Text('Try adjusting your filters or search query.', style: TextStyle(fontSize: 12, color: _muted)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          // Table header
          if (!isMobile) Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 2, child: _TableHeader('Tracking #')),
                Expanded(flex: 4, child: _TableHeader('Title')),
                Expanded(flex: 2, child: _TableHeader('Room', center: true)),
                Expanded(flex: 2, child: _TableHeader('Priority', center: true)),
                Expanded(flex: 2, child: _TableHeader('Status', center: true)),
                SizedBox(width: 160, child: _TableHeader('Actions', center: true)),
                SizedBox(width: 16),
              ],
            ),
          ),
          // Rows
          ...filtered.asMap().entries.map((e) {
            final idx = e.key;
            final r = e.value;
            final isLast = idx == filtered.length - 1;
            return _TableRow(
              request: r,
              isLast: isLast,
              isMobile: isMobile,
              statusColor: _statusColor(r.status),
              onTap: () => MaintenanceNavController.of(context)?.navigateTo(1, request: r),
            );
          }),
        ],
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected ? _blue : (_hovered ? const Color(0xFFF1F5F9) : _card),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: widget.isSelected ? _blue : _border),
            boxShadow: widget.isSelected
                ? [BoxShadow(color: _blue.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))]
                : [],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.isSelected ? Colors.white : _ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  final bool center;
  const _TableHeader(this.text, {this.center = false});

  @override
  Widget build(BuildContext context) {
    final t = Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 0.5));
    if (center) return Center(child: t);
    return t;
  }
}

class _TableRow extends StatefulWidget {
  final WorkRequest request;
  final bool isLast;
  final bool isMobile;
  final Color statusColor;
  final VoidCallback onTap;

  const _TableRow({
    required this.request,
    required this.isLast,
    required this.isMobile,
    required this.statusColor,
    required this.onTap,
  });

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high': return _red;
      case 'medium': return _orange;
      default: return _green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pc = _priorityColor(widget.request.priority);
    final sc = widget.statusColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFFF0F9FF) : _card,
          border: Border(
            left: BorderSide(color: sc, width: 3),
            bottom: widget.isLast ? BorderSide.none : BorderSide(color: _border),
          ),
          borderRadius: widget.isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(16))
              : BorderRadius.zero,
        ),
        padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 16 : 24, vertical: 14),
        child: widget.isMobile
            ? _buildMobile(pc, sc)
            : _buildDesktop(pc, sc),
      ),
    );
  }

  Widget _buildDesktop(Color pc, Color sc) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(widget.request.id.substring(0, 8),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink, fontFamily: 'monospace')),
        ),
        Expanded(
          flex: 4,
          child: Text(widget.request.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Text(widget.request.roomName ?? 'N/A',
                style: const TextStyle(fontSize: 12, color: _muted),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(child: _Chip(widget.request.priority, pc)),
        ),
        Expanded(
          flex: 2,
          child: Center(child: _Chip(widget.request.status.replaceAll('_', ' '), sc)),
        ),
        SizedBox(
          width: 160,
          child: Center(
            child: ElevatedButton.icon(
              onPressed: widget.onTap,
              icon: const Icon(Icons.visibility_rounded, size: 16),
              label: const Text('View Progress', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                elevation: _hovered ? 2 : 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildMobile(Color pc, Color sc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.request.id.substring(0, 8),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _muted, fontFamily: 'monospace')),
            _Chip(widget.request.status.replaceAll('_', ' '), sc),
          ],
        ),
        const SizedBox(height: 6),
        Text(widget.request.title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.room_rounded, size: 12, color: _muted),
            const SizedBox(width: 4),
            Text(widget.request.roomName ?? 'N/A', style: const TextStyle(fontSize: 11, color: _muted)),
            const SizedBox(width: 12),
            _Chip(widget.request.priority, pc),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.3)),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../maintenance_nav_controller.dart';

const Color _blue = Color(0xFF0EA5E9);
const Color _green = Color(0xFF10B981);
const Color _ink = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);
const Color _pageBg = Color(0xFFF1F5F9);
const Color _card = Colors.white;
const Color _border = Color(0xFFE2E8F0);

class MaintenanceHistoryWeb extends StatefulWidget {
  const MaintenanceHistoryWeb({super.key});

  @override
  State<MaintenanceHistoryWeb> createState() => _MaintenanceHistoryWebState();
}

class _MaintenanceHistoryWebState extends State<MaintenanceHistoryWeb> {
  List<WorkRequest> _history = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await WorkRequestService.fetchAll();
      final completed = data.where((r) => r.status == 'completed').toList();
      if (mounted) setState(() { _history = completed; _isLoading = false; });
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
    final q = _searchController.text.toLowerCase();
    if (q.isEmpty) return _history;
    return _history.where((r) =>
        r.id.toLowerCase().contains(q) ||
        (r.roomName?.toLowerCase().contains(q) ?? false) ||
        r.title.toLowerCase().contains(q)).toList();
  }

  /// Groups requests by formatted date string
  Map<String, List<WorkRequest>> _groupByDate(List<WorkRequest> items) {
    final map = <String, List<WorkRequest>>{};
    for (final r in items) {
      final date = r.dateCompleted ?? r.dateSubmitted;
      String key;
      try {
        final dt = DateTime.parse(date.toString());
        final now = DateTime.now();
        if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          key = 'Today';
        } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
          key = 'Yesterday';
        } else {
          key = DateFormat('MMMM d, yyyy').format(dt);
        }
      } catch (_) {
        key = 'Unknown Date';
      }
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(color: _pageBg, child: const Center(child: CircularProgressIndicator(color: _blue)));
    }

    final isMobile = MediaQuery.of(context).size.width < 768;
    final filtered = _filtered;
    final grouped = _groupByDate(filtered);

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

            // ── Search ───────────────────────────────────────────────────
            _buildSearchBar(),
            const SizedBox(height: 28),

            // ── Grouped List ─────────────────────────────────────────────
            if (filtered.isEmpty)
              _buildEmpty()
            else
              ...grouped.entries.map((e) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateDivider(e.key),
                  const SizedBox(height: 12),
                  ...e.value.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HistoryCard(
                      request: r,
                      onTap: () => MaintenanceNavController.of(context)?.navigateTo(3, request: r),
                    ),
                  )),
                  const SizedBox(height: 16),
                ],
              )),
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
            children: const [
              Text('Task History', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.5)),
              SizedBox(height: 6),
              Text('All completed work requests and resolved maintenance tasks.', style: TextStyle(fontSize: 14, color: _muted)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _green.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 14, color: _green),
              const SizedBox(width: 6),
              Text('$count completed', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _green)),
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
        decoration: const InputDecoration(
          hintText: 'Search by title, room, or tracking number...',
          hintStyle: TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: _muted, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDateDivider(String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: _ink.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 0.3)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: _border, height: 1)),
      ],
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 72),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: _green.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: const Icon(Icons.history_rounded, size: 36, color: _green),
          ),
          const SizedBox(height: 16),
          const Text('No completed tasks yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 6),
          const Text('Completed work requests will appear here.', style: TextStyle(fontSize: 13, color: _muted)),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  final WorkRequest request;
  final VoidCallback onTap;

  const _HistoryCard({required this.request, required this.onTap});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final date = widget.request.dateCompleted ?? widget.request.dateSubmitted;
    String displayDate = 'N/A';
    try {
      displayDate = DateFormat('h:mm a').format(DateTime.parse(date.toString()));
    } catch (_) {}

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFF0FDF4) : _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? _green.withValues(alpha: 0.4) : _border,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: _green.withValues(alpha: 0.1), blurRadius: 14, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              // Completion indicator
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _green.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.check_circle_rounded, color: _green, size: 24),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.request.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 12,
                      children: [
                        _InfoChip(Icons.room_rounded, widget.request.roomName ?? 'N/A'),
                        _InfoChip(Icons.tag_rounded, widget.request.id.substring(0, 8)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('DONE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _green, letterSpacing: 0.5)),
                  ),
                  const SizedBox(height: 6),
                  Text(displayDate, style: const TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: _muted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

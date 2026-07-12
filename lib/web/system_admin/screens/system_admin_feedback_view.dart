import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/system_feedback_model.dart';
import '../../../shared/services/system_feedback_service.dart';
import '../../admin/shared/admin_styles.dart';

class SystemAdminFeedbackView extends StatefulWidget {
  const SystemAdminFeedbackView({super.key});

  @override
  State<SystemAdminFeedbackView> createState() => _SystemAdminFeedbackViewState();
}

class _SystemAdminFeedbackViewState extends State<SystemAdminFeedbackView> {
  bool _loading = true;
  String? _error;
  List<SystemFeedback> _feedbacks = [];

  // Filters
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all'; // all, pending, resolved
  String _categoryFilter = 'all'; // all, Bug Report, Feature Request, General Feedback, Other

  // Pagination
  static const _pageSize = 15;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _page = 0));
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await SystemFeedbackService.fetchAll();
      if (mounted) {
        setState(() {
          _feedbacks = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Derived Data ────────────────────────────────────────────────────────

  List<SystemFeedback> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _feedbacks.where((f) {
      if (q.isNotEmpty && !f.userName.toLowerCase().contains(q) && !f.message.toLowerCase().contains(q)) return false;
      if (_statusFilter != 'all' && f.status != _statusFilter) return false;
      if (_categoryFilter != 'all' && f.category != _categoryFilter) return false;
      return true;
    }).toList();
  }

  List<SystemFeedback> get _paginated {
    final f = _filtered;
    final start = _page * _pageSize;
    if (start >= f.length) return [];
    return f.sublist(start, (start + _pageSize).clamp(0, f.length));
  }

  int get _totalPages => (_filtered.isEmpty ? 1 : ((_filtered.length - 1) / _pageSize).ceil());

  // ── Actions ─────────────────────────────────────────────────────────────

  void _viewFeedback(SystemFeedback feedback) {
    showDialog(
      context: context,
      builder: (_) => _FeedbackDetailsDialog(
        feedback: feedback,
        onResolve: (reply) async {
          final err = await SystemFeedbackService.updateFeedbackStatus(id: feedback.id, status: 'resolved', reply: reply);
          if (err == null) {
            _toast('Feedback marked as resolved');
            _loadData();
          } else {
            _toast('Error: $err', isError: true);
          }
        },
      ),
    );
  }

  Future<void> _deleteFeedback(SystemFeedback f) async {
    final confirmed = await _confirm(
      title: 'Delete Feedback',
      message: 'Permanently delete this feedback from ${f.userName}?',
      danger: true,
    );
    if (!confirmed) return;

    final err = await SystemFeedbackService.deleteFeedback(f.id);
    if (err == null) {
      _toast('Feedback deleted');
      _loadData();
    } else {
      _toast('Error: $err', isError: true);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Flexible(child: Text(msg)),
      ]),
      backgroundColor: isError ? AdminStyles.error : AdminStyles.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<bool> _confirm({required String title, required String message, bool danger = false}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(danger ? Icons.warning_rounded : Icons.info_outline_rounded, color: danger ? AdminStyles.error : AdminStyles.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: AdminStyles.headingStyle(fontSize: 18))),
        ]),
        content: Text(message, style: AdminStyles.bodyStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? AdminStyles.error : AdminStyles.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result == true;
  }

  // ── UI Building ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AdminStyles.primary));
    if (_error != null) return Center(child: Text('Error: $_error', style: const TextStyle(color: AdminStyles.error)));

    return LayoutBuilder(builder: (ctx, constraints) {
      final isMobile = constraints.maxWidth < 800;
      return Container(
        color: AdminStyles.bg,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(isMobile ? 16 : 32, isMobile ? 16 : 28, isMobile ? 16 : 32, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isMobile),
                  const SizedBox(height: 24),
                  _buildStatCards(isMobile),
                  const SizedBox(height: 24),
                  _buildToolbar(isMobile),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
                child: _filtered.isEmpty ? _buildEmpty() : _buildTable(),
              ),
            ),
            if (_filtered.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 12),
                child: _buildPagination(isMobile),
              ),
          ],
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
              Text('User Feedback', style: AdminStyles.headingStyle(fontSize: isMobile ? 22 : 28)),
              const SizedBox(height: 4),
              Text('Review bug reports and feature requests from system users.', style: AdminStyles.bodyStyle(fontSize: 13)),
            ],
          ),
        ),
        IconButton(
          onPressed: _loadData,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded, color: AdminStyles.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStatCards(bool isMobile) {
    final pending = _feedbacks.where((f) => f.status == 'pending').length;
    final resolved = _feedbacks.where((f) => f.status == 'resolved').length;
    final bugs = _feedbacks.where((f) => f.category == 'Bug Report').length;
    final features = _feedbacks.where((f) => f.category == 'Feature Request').length;

    final cards = [
      _Stat('Total Pending', pending, Icons.mark_chat_unread_rounded, AdminStyles.warning),
      _Stat('Resolved', resolved, Icons.mark_chat_read_rounded, AdminStyles.success),
      _Stat('Bug Reports', bugs, Icons.bug_report_rounded, AdminStyles.error),
      _Stat('Feature Requests', features, Icons.lightbulb_rounded, AdminStyles.primary),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10, crossAxisSpacing: 10,
        childAspectRatio: 1.4,
        children: cards.map((c) => _buildStatTile(c)).toList(),
      );
    }

    return Row(
      children: cards.map((c) => Expanded(child: _buildStatTile(c))).expand((w) => [w, const SizedBox(width: 16)]).toList()..removeLast(),
    );
  }

  Widget _buildStatTile(_Stat s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: s.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(s.icon, color: s.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${s.value}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: s.color, letterSpacing: -0.5)),
                Text(s.label, style: AdminStyles.bodyStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isMobile) {
    final searchBox = Container(
      height: 44,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminStyles.border)),
      child: TextField(
        controller: _searchCtrl,
        style: AdminStyles.bodyStyle(color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Search user or message…',
          hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted),
          prefixIcon: const Icon(Icons.search_rounded, color: AdminStyles.textMuted, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded, color: AdminStyles.textMuted, size: 18), onPressed: () => _searchCtrl.clear()) : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        ),
      ),
    );

    final statusFilter = Container(
      height: 44, padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminStyles.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter, isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminStyles.textMuted, size: 18),
          style: AdminStyles.bodyStyle(color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Status')),
            DropdownMenuItem(value: 'pending', child: Text('Pending Review')),
            DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
          ],
          onChanged: (v) => setState(() { _statusFilter = v ?? 'all'; _page = 0; }),
        ),
      ),
    );

    final categoryFilter = Container(
      height: 44, padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminStyles.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _categoryFilter, isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminStyles.textMuted, size: 18),
          style: AdminStyles.bodyStyle(color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Categories')),
            DropdownMenuItem(value: 'Bug Report', child: Text('Bug Reports')),
            DropdownMenuItem(value: 'Feature Request', child: Text('Feature Requests')),
            DropdownMenuItem(value: 'General Feedback', child: Text('General Feedback')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (v) => setState(() { _categoryFilter = v ?? 'all'; _page = 0; }),
        ),
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          searchBox,
          const SizedBox(height: 8),
          Row(children: [Expanded(child: statusFilter), const SizedBox(width: 8), Expanded(child: categoryFilter)]),
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: 3, child: searchBox),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: statusFilter),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: categoryFilter),
      ],
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mark_chat_read_rounded, size: 60, color: AdminStyles.textMuted),
            const SizedBox(height: 16),
            Text('No feedback found', style: AdminStyles.headingStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('You are all caught up!', style: AdminStyles.bodyStyle()),
          ],
        ),
      );

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  _th('Sender', flex: 2),
                  _th('Category', flex: 2),
                  _th('Message', flex: 4),
                  _th('Status', flex: 1),
                  _th('Actions', flex: 1, center: true),
                ],
              ),
            ),
            const Divider(height: 1, color: AdminStyles.border),
            Expanded(
              child: ListView.separated(
                itemCount: _paginated.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AdminStyles.border),
                itemBuilder: (_, i) => _buildRow(_paginated[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _th(String label, {int flex = 1, bool center = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AdminStyles.textMuted, letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildRow(SystemFeedback f) {
    Color catColor = AdminStyles.primary;
    if (f.category == 'Bug Report') catColor = AdminStyles.error;
    if (f.category == 'Feature Request') catColor = AdminStyles.warning;

    return InkWell(
      onTap: () => _viewFeedback(f),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.userName, style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AdminStyles.textPrimary)),
                  Text(DateFormat('MMM d, yyyy').format(f.createdAt), style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(f.category, style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.w600, color: catColor)),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(f.message, style: AdminStyles.bodyStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: f.status == 'resolved' ? AdminStyles.success.withValues(alpha: 0.1) : AdminStyles.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    f.status.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: f.status == 'resolved' ? AdminStyles.success : AdminStyles.warning),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'View / Reply',
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AdminStyles.primary),
                    onPressed: () => _viewFeedback(f),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AdminStyles.error),
                    onPressed: () => _deleteFeedback(f),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(bool isMobile) {
    final total = _filtered.length;
    final start = _page * _pageSize + 1;
    final end = ((_page + 1) * _pageSize).clamp(0, total);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!isMobile) Text('Showing $start–$end of $total feedbacks', style: AdminStyles.bodyStyle(fontSize: 12)),
        Row(
          children: [
            _PageBtn(icon: Icons.first_page_rounded, onTap: _page > 0 ? () => setState(() => _page = 0) : null),
            _PageBtn(icon: Icons.chevron_left_rounded, onTap: _page > 0 ? () => setState(() => _page--) : null),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: AdminStyles.primary, borderRadius: BorderRadius.circular(8)),
              child: Text('${_page + 1} / ${_totalPages.clamp(1, 99999)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            _PageBtn(icon: Icons.chevron_right_rounded, onTap: _page < _totalPages - 1 ? () => setState(() => _page++) : null),
            _PageBtn(icon: Icons.last_page_rounded, onTap: _page < _totalPages - 1 ? () => setState(() => _page = _totalPages - 1) : null),
          ],
        ),
      ],
    );
  }
}

// ── Details Dialog ────────────────────────────────────────────────────────

class _FeedbackDetailsDialog extends StatefulWidget {
  final SystemFeedback feedback;
  final Function(String reply) onResolve;

  const _FeedbackDetailsDialog({required this.feedback, required this.onResolve});

  @override
  State<_FeedbackDetailsDialog> createState() => _FeedbackDetailsDialogState();
}

class _FeedbackDetailsDialogState extends State<_FeedbackDetailsDialog> {
  final _replyCtrl = TextEditingController();

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.feedback;
    final isResolved = f.status == 'resolved';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: AdminStyles.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.forum_rounded, color: AdminStyles.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Feedback Details', style: AdminStyles.headingStyle(fontSize: 20))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AdminStyles.textMuted)),
                ],
              ),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sender', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
                        Text(f.userName, style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Category', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
                        Text(f.category, style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700, fontSize: 14, color: f.category == 'Bug Report' ? AdminStyles.error : AdminStyles.primary)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
                        Text(DateFormat('MMM d, yyyy h:mm a').format(f.createdAt), style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              Text('Message Content', style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminStyles.textMuted)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminStyles.border)),
                child: Text(f.message, style: AdminStyles.bodyStyle(fontSize: 14)),
              ),
              const SizedBox(height: 24),

              if (isResolved) ...[
                Text('Admin Reply', style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminStyles.success)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AdminStyles.success.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminStyles.success.withValues(alpha: 0.2))),
                  child: Text(f.adminReply ?? 'Resolved without a text reply.', style: AdminStyles.bodyStyle(fontSize: 14)),
                ),
              ] else ...[
                Text('Write a Reply & Resolve', style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminStyles.primary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _replyCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Thank the user or explain the fix...',
                    hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontSize: 13),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminStyles.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminStyles.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminStyles.primary, width: 2)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminStyles.textSecondary,
                        side: const BorderSide(color: AdminStyles.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        widget.onResolve(_replyCtrl.text.trim());
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Resolve Feedback'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminStyles.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                      ),
                    ),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.icon, this.color);
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _PageBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: onTap != null ? Colors.white : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(border: Border.all(color: AdminStyles.border), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: onTap != null ? AdminStyles.textPrimary : AdminStyles.textMuted),
          ),
        ),
      ),
    );
  }
}

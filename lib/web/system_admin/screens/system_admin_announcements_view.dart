import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/system_announcement_model.dart';
import '../../../shared/services/system_announcement_service.dart';
import '../../admin/shared/admin_styles.dart';

class SystemAdminAnnouncementsView extends StatefulWidget {
  const SystemAdminAnnouncementsView({super.key});

  @override
  State<SystemAdminAnnouncementsView> createState() => _SystemAdminAnnouncementsViewState();
}

class _SystemAdminAnnouncementsViewState extends State<SystemAdminAnnouncementsView> {
  bool _loading = true;
  String? _error;
  List<SystemAnnouncement> _announcements = [];

  // Filters
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all'; // all, draft, published, expired
  String _priorityFilter = 'all'; // all, low, normal, high, urgent

  // Pagination
  static const _pageSize = 12;
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
      final list = await SystemAnnouncementService.fetchAll();
      if (mounted) {
        setState(() {
          _announcements = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Derived Data ────────────────────────────────────────────────────────

  List<SystemAnnouncement> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _announcements.where((a) {
      if (q.isNotEmpty && !a.title.toLowerCase().contains(q) && !a.content.toLowerCase().contains(q)) return false;
      if (_statusFilter != 'all' && a.status != _statusFilter) return false;
      if (_priorityFilter != 'all' && a.priority != _priorityFilter) return false;
      return true;
    }).toList();
  }

  List<SystemAnnouncement> get _paginated {
    final f = _filtered;
    final start = _page * _pageSize;
    if (start >= f.length) return [];
    return f.sublist(start, (start + _pageSize).clamp(0, f.length));
  }

  int get _totalPages => (_filtered.isEmpty ? 1 : ((_filtered.length - 1) / _pageSize).ceil());

  // ── Actions ─────────────────────────────────────────────────────────────

  void _showFormDialog({SystemAnnouncement? announcement}) {
    showDialog(
      context: context,
      builder: (_) => _AnnouncementFormDialog(
        announcement: announcement,
        onSave: (title, content, priority, status, scheduledFor, expiresAt) async {
          String? err;
          if (announcement == null) {
            err = await SystemAnnouncementService.create(
              title: title, content: content, priority: priority, status: status,
              scheduledFor: scheduledFor, expiresAt: expiresAt,
            );
          } else {
            err = await SystemAnnouncementService.updateAnnouncement(
              id: announcement.id, title: title, content: content, priority: priority, status: status,
              scheduledFor: scheduledFor, expiresAt: expiresAt,
            );
          }
          return err;
        },
        onSuccess: () {
          Navigator.pop(context);
          _loadData();
          _toast(announcement == null ? 'Announcement created' : 'Announcement updated');
        },
      ),
    );
  }

  Future<void> _delete(SystemAnnouncement a) async {
    final confirmed = await _confirm(
      title: 'Delete Announcement',
      message: 'Permanently delete "${a.title}"? This cannot be undone.',
      danger: true,
    );
    if (!confirmed) return;

    final err = await SystemAnnouncementService.deleteAnnouncement(a.id, a.title);
    if (err == null) {
      _toast('Announcement deleted');
      _loadData();
    } else {
      _toast('Error: $err', isError: true);
    }
  }

  Future<void> _duplicate(SystemAnnouncement a) async {
    _showFormDialog(
      announcement: SystemAnnouncement(
        id: '',
        title: '${a.title} (Copy)',
        content: a.content,
        priority: a.priority,
        status: 'draft',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: '',
      ),
    );
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
                  const SizedBox(height: 20),
                  _buildStatCards(isMobile),
                  const SizedBox(height: 20),
                  _buildToolbar(isMobile),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
                child: _filtered.isEmpty ? _buildEmpty() : _buildCardsGrid(isMobile),
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
              Text('System Announcements', style: AdminStyles.headingStyle(fontSize: isMobile ? 22 : 28)),
              const SizedBox(height: 4),
              Text('Manage global broadcasts, alerts, and system notifications.', style: AdminStyles.bodyStyle(fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => _showFormDialog(),
          icon: const Icon(Icons.add_alert_rounded, size: 18),
          label: Text(isMobile ? 'Create' : 'New Announcement'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminStyles.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _loadData,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded, color: AdminStyles.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStatCards(bool isMobile) {
    final active = _announcements.where((a) => a.isPublished).length;
    final scheduled = _announcements.where((a) => a.isScheduled).length;
    final drafts = _announcements.where((a) => a.status == 'draft').length;

    final cards = [
      _Stat('Active', active, Icons.campaign_rounded, AdminStyles.success),
      _Stat('Scheduled', scheduled, Icons.schedule_rounded, AdminStyles.primary),
      _Stat('Drafts', drafts, Icons.edit_note_rounded, AdminStyles.warning),
    ];

    if (isMobile) {
      return Row(
        children: cards.asMap().entries.expand((e) => [
          Expanded(child: _buildStatTile(e.value)),
          if (e.key < cards.length - 1) const SizedBox(width: 10),
        ]).toList(),
      );
    }
    return Row(
      children: cards.asMap().entries.expand((e) => [
        Expanded(child: _buildStatTile(e.value)),
        if (e.key < cards.length - 1) const SizedBox(width: 14),
      ]).toList(),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: AdminStyles.bodyStyle(color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Search title or content…',
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

    final statusDropdown = Container(
      height: 44, padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminStyles.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter, isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminStyles.textMuted, size: 18),
          style: AdminStyles.bodyStyle(color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Status')),
            DropdownMenuItem(value: 'published', child: Text('Published')),
            DropdownMenuItem(value: 'draft', child: Text('Drafts')),
            DropdownMenuItem(value: 'expired', child: Text('Expired')),
          ],
          onChanged: (v) => setState(() { _statusFilter = v ?? 'all'; _page = 0; }),
        ),
      ),
    );

    final priorityDropdown = Container(
      height: 44, padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminStyles.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _priorityFilter, isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminStyles.textMuted, size: 18),
          style: AdminStyles.bodyStyle(color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Priorities')),
            DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
            DropdownMenuItem(value: 'high', child: Text('High')),
            DropdownMenuItem(value: 'normal', child: Text('Normal')),
            DropdownMenuItem(value: 'low', child: Text('Low')),
          ],
          onChanged: (v) => setState(() { _priorityFilter = v ?? 'all'; _page = 0; }),
        ),
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          searchBox,
          const SizedBox(height: 8),
          Row(children: [Expanded(child: statusDropdown), const SizedBox(width: 8), Expanded(child: priorityDropdown)]),
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: 3, child: searchBox),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: statusDropdown),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: priorityDropdown),
      ],
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.campaign_outlined, size: 60, color: AdminStyles.textMuted),
            const SizedBox(height: 16),
            Text('No announcements found', style: AdminStyles.headingStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Adjust your filters or create a new broadcast.', style: AdminStyles.bodyStyle()),
          ],
        ),
      );

  Widget _buildCardsGrid(bool isMobile) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isMobile ? 1.4 : 1.3,
      ),
      itemCount: _paginated.length,
      itemBuilder: (ctx, i) => _buildCard(_paginated[i]),
    );
  }

  Widget _buildCard(SystemAnnouncement a) {
    // Determine visual status
    String statusLabel = a.status.toUpperCase();
    Color statusColor = AdminStyles.secondary;
    if (a.isPublished) { statusLabel = 'ACTIVE'; statusColor = AdminStyles.success; }
    else if (a.isScheduled) { statusLabel = 'SCHEDULED'; statusColor = AdminStyles.primary; }
    else if (a.isExpired) { statusLabel = 'EXPIRED'; statusColor = AdminStyles.error; }
    else if (a.status == 'draft') { statusLabel = 'DRAFT'; statusColor = AdminStyles.warning; }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PriorityBadge(priority: a.priority),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor, letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: AdminStyles.headingStyle(fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    a.content,
                    style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AdminStyles.border),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (a.scheduledFor != null && a.isScheduled) ...[
                    Text('Publishes', style: AdminStyles.bodyStyle(fontSize: 10, color: AdminStyles.textMuted)),
                    Text(DateFormat('MMM d, yyyy').format(a.scheduledFor!), style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ] else ...[
                    Text('Created', style: AdminStyles.bodyStyle(fontSize: 10, color: AdminStyles.textMuted)),
                    Text(DateFormat('MMM d, yyyy').format(a.createdAt), style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AdminStyles.textMuted, size: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'edit') _showFormDialog(announcement: a);
                  if (v == 'delete') _delete(a);
                  if (v == 'duplicate') _duplicate(a);
                },
                itemBuilder: (ctx) => [
                  _popItem(Icons.edit_outlined, 'Edit', 'edit'),
                  _popItem(Icons.copy_rounded, 'Duplicate', 'duplicate'),
                  _popItem(Icons.delete_outline_rounded, 'Delete', 'delete', color: AdminStyles.error),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _popItem(IconData icon, String label, String value, {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: color ?? AdminStyles.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: AdminStyles.bodyStyle(color: color ?? AdminStyles.textPrimary, fontSize: 13)),
      ]),
    );
  }

  Widget _buildPagination(bool isMobile) {
    final total = _filtered.length;
    final start = _page * _pageSize + 1;
    final end = ((_page + 1) * _pageSize).clamp(0, total);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!isMobile) Text('Showing $start–$end of $total', style: AdminStyles.bodyStyle(fontSize: 12)),
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

// ── Form Dialog ──────────────────────────────────────────────────────────

class _AnnouncementFormDialog extends StatefulWidget {
  final SystemAnnouncement? announcement;
  final Future<String?> Function(String title, String content, String priority, String status, DateTime? scheduledFor, DateTime? expiresAt) onSave;
  final VoidCallback onSuccess;

  const _AnnouncementFormDialog({this.announcement, required this.onSave, required this.onSuccess});

  @override
  State<_AnnouncementFormDialog> createState() => _AnnouncementFormDialogState();
}

class _AnnouncementFormDialogState extends State<_AnnouncementFormDialog> {
  late final _titleCtrl = TextEditingController(text: widget.announcement?.title ?? '');
  late final _contentCtrl = TextEditingController(text: widget.announcement?.content ?? '');
  
  String _priority = 'normal';
  String _status = 'draft';
  DateTime? _scheduledFor;
  DateTime? _expiresAt;

  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    if (widget.announcement != null) {
      _priority = widget.announcement!.priority;
      _status = widget.announcement!.status;
      _scheduledFor = widget.announcement!.scheduledFor;
      _expiresAt = widget.announcement!.expiresAt;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _serverError = null; });

    final err = await widget.onSave(
      _titleCtrl.text.trim(),
      _contentCtrl.text.trim(),
      _priority,
      _status,
      _scheduledFor,
      _expiresAt,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (err == null) {
      widget.onSuccess();
    } else {
      setState(() => _serverError = err);
    }
  }

  Future<void> _pickDate(bool forSchedule) async {
    final init = forSchedule ? _scheduledFor : _expiresAt;
    final date = await showDatePicker(
      context: context,
      initialDate: init ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null && mounted) {
      setState(() {
        if (forSchedule) _scheduledFor = date;
        else _expiresAt = date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: AdminStyles.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.campaign_rounded, color: AdminStyles.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(widget.announcement == null ? 'Create Announcement' : 'Edit Announcement', style: AdminStyles.headingStyle(fontSize: 20))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AdminStyles.textMuted)),
                ]),
                const SizedBox(height: 24),

                _label('Title *'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: _inputDecor(Icons.title_rounded, hint: 'e.g. Scheduled System Maintenance'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                _label('Content *'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _contentCtrl,
                  maxLines: 5,
                  decoration: _inputDecor(Icons.subject_rounded, hint: 'Full announcement details...'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Priority'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _priority,
                            decoration: _inputDecor(Icons.flag_outlined),
                            items: const [
                              DropdownMenuItem(value: 'low', child: Text('Low')),
                              DropdownMenuItem(value: 'normal', child: Text('Normal')),
                              DropdownMenuItem(value: 'high', child: Text('High')),
                              DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                            ],
                            onChanged: (v) => setState(() => _priority = v ?? 'normal'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Status'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _status,
                            decoration: _inputDecor(Icons.toggle_on_outlined),
                            items: const [
                              DropdownMenuItem(value: 'draft', child: Text('Draft')),
                              DropdownMenuItem(value: 'published', child: Text('Published')),
                              DropdownMenuItem(value: 'expired', child: Text('Expired')),
                            ],
                            onChanged: (v) => setState(() => _status = v ?? 'draft'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Schedule Publish Date'),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _pickDate(true),
                            child: Container(
                              height: 52, padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AdminStyles.border)),
                              child: Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 18, color: AdminStyles.textSecondary),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(_scheduledFor == null ? 'Immediately' : DateFormat('MMM d, yyyy').format(_scheduledFor!), style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600))),
                                  if (_scheduledFor != null)
                                    GestureDetector(onTap: () => setState(() => _scheduledFor = null), child: const Icon(Icons.clear_rounded, size: 16, color: AdminStyles.textMuted))
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Expiration Date'),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _pickDate(false),
                            child: Container(
                              height: 52, padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AdminStyles.border)),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_busy_rounded, size: 18, color: AdminStyles.textSecondary),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(_expiresAt == null ? 'Never' : DateFormat('MMM d, yyyy').format(_expiresAt!), style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600))),
                                  if (_expiresAt != null)
                                    GestureDetector(onTap: () => setState(() => _expiresAt = null), child: const Icon(Icons.clear_rounded, size: 16, color: AdminStyles.textMuted))
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),

                if (_serverError != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AdminStyles.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AdminStyles.error.withValues(alpha: 0.3))),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded, color: AdminStyles.error, size: 18),
                      const SizedBox(width: 8),
                      Flexible(child: Text(_serverError!, style: AdminStyles.bodyStyle(color: AdminStyles.error, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminStyles.textSecondary,
                        side: const BorderSide(color: AdminStyles.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminStyles.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Announcement', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminStyles.textSecondary));
  }

  InputDecoration _inputDecor(IconData icon, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, size: 18, color: AdminStyles.textSecondary),
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminStyles.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminStyles.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminStyles.primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminStyles.error, width: 1.5)),
    );
  }
}

// ── Small Helpers ─────────────────────────────────────────────────────────

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    Color bg; Color fg;
    switch (priority.toLowerCase()) {
      case 'low': bg = const Color(0xFFE2E8F0); fg = const Color(0xFF475569); break;
      case 'urgent': bg = const Color(0xFFFECACA); fg = const Color(0xFFB91C1C); break;
      case 'high': bg = const Color(0xFFFED7AA); fg = const Color(0xFFC2410C); break;
      case 'normal': default: bg = const Color(0xFFDBEAFE); fg = const Color(0xFF1D4ED8);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(priority.toUpperCase(), style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }
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

class _Stat {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.icon, this.color);
}

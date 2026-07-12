import 'package:flutter/material.dart';

import '../../../shared/models/department_model.dart';
import '../../../shared/services/department_service.dart';
import '../../admin/shared/admin_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Main Widget
// ─────────────────────────────────────────────────────────────────────────────

class SystemAdminDepartmentsView extends StatefulWidget {
  const SystemAdminDepartmentsView({super.key});

  @override
  State<SystemAdminDepartmentsView> createState() =>
      _SystemAdminDepartmentsViewState();
}

class _SystemAdminDepartmentsViewState
    extends State<SystemAdminDepartmentsView> {
  // ── Data ──────────────────────────────────────────────────────────────────
  List<Department> _departments = [];
  bool _loading = true;
  String? _error;

  // ── Filters ───────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all'; // 'all' | 'active' | 'inactive'

  // ── Pagination ────────────────────────────────────────────────────────────
  static const _pageSize = 12;
  int _page = 0;

  // ── Sort ──────────────────────────────────────────────────────────────────
  String _sortField = 'name'; // 'name' | 'createdAt'
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _page = 0));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Data
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await DepartmentService.fetchAll();
      if (mounted) setState(() { _departments = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Derived
  // ─────────────────────────────────────────────────────────────────────────

  List<Department> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    var list = _departments.where((d) {
      if (q.isNotEmpty) {
        final matchName = d.name.toLowerCase().contains(q);
        final matchDesc = (d.description ?? '').toLowerCase().contains(q);
        if (!matchName && !matchDesc) return false;
      }
      if (_statusFilter == 'active' && !d.isActive) return false;
      if (_statusFilter == 'inactive' && d.isActive) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      int cmp;
      if (_sortField == 'name') {
        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else {
        cmp = a.createdAt.compareTo(b.createdAt);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  List<Department> get _paginated {
    final f = _filtered;
    final start = _page * _pageSize;
    if (start >= f.length) return [];
    return f.sublist(start, (start + _pageSize).clamp(0, f.length));
  }

  int get _totalPages => (_filtered.isEmpty
      ? 1
      : ((_filtered.length - 1) / _pageSize).ceil());

  int get _active => _departments.where((d) => d.isActive).length;
  int get _inactive => _departments.where((d) => !d.isActive).length;

  // ─────────────────────────────────────────────────────────────────────────
  //  Actions
  // ─────────────────────────────────────────────────────────────────────────

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => _DeptFormDialog(
        title: 'Add Department',
        existingDepts: _departments,
        onSave: (name, desc) async {
          final err = await DepartmentService.create(
              name: name, description: desc);
          return err;
        },
        onSuccess: () {
          Navigator.pop(context);
          _load();
          _toast('Department added successfully.');
        },
      ),
    );
  }

  void _showEditDialog(Department dept) {
    showDialog(
      context: context,
      builder: (_) => _DeptFormDialog(
        title: 'Edit Department',
        dept: dept,
        existingDepts: _departments,
        onSave: (name, desc) async {
          final err = await DepartmentService.updateDepartment(
            id: dept.id,
            name: name,
            description: desc,
            isActive: dept.isActive,
            allDepartments: _departments,
          );
          return err;
        },
        onSuccess: () {
          Navigator.pop(context);
          _load();
          _toast('Department updated.');
        },
      ),
    );
  }

  void _showDetailDialog(Department dept) {
    showDialog(
      context: context,
      builder: (_) => _DeptDetailDialog(dept: dept),
    );
  }

  Future<void> _toggleActive(Department dept) async {
    final activate = !dept.isActive;
    final confirmed = await _confirm(
      title: activate ? 'Restore Department' : 'Disable Department',
      message: activate
          ? 'Restore "${dept.name}"? Users will be able to be assigned to it again.'
          : 'Disable "${dept.name}"? It will be hidden from selection lists.',
      confirmLabel: activate ? 'Restore' : 'Disable',
      danger: !activate,
    );
    if (!confirmed) return;

    final err = await DepartmentService.setActive(dept.id, active: activate);
    if (err == null) {
      _toast(activate ? '${dept.name} restored.' : '${dept.name} disabled.');
      _load();
    } else {
      _toast('Error: $err', isError: true);
    }
  }

  Future<void> _delete(Department dept) async {
    final confirmed = await _confirm(
      title: 'Delete Department',
      message:
          'Permanently delete "${dept.name}"?\n\nThis cannot be undone and may affect existing users assigned to this department.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!confirmed) return;

    final err = await DepartmentService.deleteDepartment(dept.id, dept.name);
    if (err == null) {
      _toast('"${dept.name}" has been deleted.');
      _load();
    } else {
      _toast('Error: $err', isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  UI helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(
            danger ? Icons.warning_rounded : Icons.info_outline_rounded,
            color: danger ? AdminStyles.error : AdminStyles.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title, style: AdminStyles.headingStyle(fontSize: 18))),
        ]),
        content: Text(message, style: AdminStyles.bodyStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? AdminStyles.error : AdminStyles.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
          color: Colors.white, size: 18,
        ),
        const SizedBox(width: 10),
        Flexible(child: Text(msg)),
      ]),
      backgroundColor: isError ? AdminStyles.error : AdminStyles.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _toggleSort(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortField = field;
        _sortAsc = true;
      }
      _page = 0;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();

    return LayoutBuilder(builder: (ctx, constraints) {
      final isMobile = constraints.maxWidth < 700;
      return Container(
        color: AdminStyles.bg,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 32,
                isMobile ? 16 : 28,
                isMobile ? 16 : 32,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPageHeader(isMobile),
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
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 32),
                child: _filtered.isEmpty
                    ? _buildEmpty()
                    : isMobile
                        ? _buildMobileCards()
                        : _buildDesktopTable(),
              ),
            ),
            if (_filtered.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 32, vertical: 12),
                child: _buildPagination(isMobile),
              ),
          ],
        ),
      );
    });
  }

  // ── States ────────────────────────────────────────────────────────────────

  Widget _buildLoading() => Container(
        color: AdminStyles.bg,
        child: const Center(
          child: CircularProgressIndicator(
              color: AdminStyles.primary, strokeWidth: 3),
        ),
      );

  Widget _buildError() => Container(
        color: AdminStyles.bg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AdminStyles.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    size: 36, color: AdminStyles.error),
              ),
              const SizedBox(height: 20),
              Text('Failed to load departments',
                  style: AdminStyles.headingStyle(fontSize: 20)),
              const SizedBox(height: 8),
              Text(_error ?? '', style: AdminStyles.bodyStyle(), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminStyles.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_rounded,
                size: 60, color: AdminStyles.textMuted),
            const SizedBox(height: 16),
            Text(
              _searchCtrl.text.isNotEmpty || _statusFilter != 'all'
                  ? 'No departments match your filters'
                  : 'No departments yet',
              style: AdminStyles.headingStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _searchCtrl.text.isNotEmpty || _statusFilter != 'all'
                  ? 'Try adjusting your search or filters.'
                  : 'Click "Add Department" to get started.',
              style: AdminStyles.bodyStyle(),
            ),
            if (_searchCtrl.text.isEmpty && _statusFilter == 'all') ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Department'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminStyles.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ],
        ),
      );

  // ── Page header ───────────────────────────────────────────────────────────

  Widget _buildPageHeader(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Departments',
                  style: AdminStyles.headingStyle(
                      fontSize: isMobile ? 22 : 28)),
              const SizedBox(height: 4),
              Text('Create and manage academic/operational departments.',
                  style: AdminStyles.bodyStyle(fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _showAddDialog,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(isMobile ? 'Add' : 'Add Department'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminStyles.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 20, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _load,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded,
              color: AdminStyles.textSecondary),
        ),
      ],
    );
  }

  // ── Stat Cards ────────────────────────────────────────────────────────────

  Widget _buildStatCards(bool isMobile) {
    final cards = [
      _Stat('Total Departments', _departments.length,
          Icons.business_rounded, AdminStyles.primary),
      _Stat('Active', _active, Icons.check_circle_rounded, AdminStyles.success),
      _Stat('Disabled', _inactive, Icons.do_not_disturb_on_rounded,
          AdminStyles.error),
    ];

    if (isMobile) {
      return Row(
        children: cards.asMap().entries
            .expand((e) => [
                  Expanded(child: _buildStatTile(e.value)),
                  if (e.key < cards.length - 1) const SizedBox(width: 10),
                ])
            .toList(),
      );
    }
    return Row(
      children: cards.asMap().entries
          .expand((e) => [
                Expanded(child: _buildStatTile(e.value)),
                if (e.key < cards.length - 1) const SizedBox(width: 14),
              ])
          .toList(),
    );
  }

  Widget _buildStatTile(_Stat s) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(s.icon, color: s.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${s.value}',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: s.color,
                        letterSpacing: -0.5)),
                Text(s.label, style: AdminStyles.bodyStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────

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
        style: AdminStyles.bodyStyle(
            color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Search departments…',
          hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AdminStyles.textMuted, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AdminStyles.textMuted, size: 18),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        ),
      ),
    );

    final statusFilter = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AdminStyles.textMuted, size: 18),
          style: AdminStyles.bodyStyle(
              color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Status')),
            DropdownMenuItem(value: 'active', child: Text('Active Only')),
            DropdownMenuItem(value: 'inactive', child: Text('Disabled Only')),
          ],
          onChanged: (v) => setState(() {
            _statusFilter = v ?? 'all';
            _page = 0;
          }),
        ),
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          searchBox,
          const SizedBox(height: 8),
          statusFilter,
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: 4, child: searchBox),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: statusFilter),
      ],
    );
  }

  // ── Desktop Table ─────────────────────────────────────────────────────────

  Widget _buildDesktopTable() {
    final rows = _paginated;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            _buildTableHeader(),
            const Divider(height: 1, color: AdminStyles.border),
            Expanded(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AdminStyles.border),
                itemBuilder: (_, i) => _buildTableRow(rows[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(
        children: [
          _sortableHeader('Department Name', 'name', flex: 4),
          _th('Description', flex: 4),
          _sortableHeader('Created', 'createdAt', flex: 2),
          _th('Status', flex: 2),
          _th('Actions', flex: 2, center: true),
        ],
      ),
    );
  }

  Widget _sortableHeader(String label, String field, {int flex = 1}) {
    final active = _sortField == field;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => _toggleSort(field),
        child: Row(
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: active ? AdminStyles.primary : AdminStyles.textMuted,
                  letterSpacing: 1.0,
                )),
            const SizedBox(width: 4),
            Icon(
              active
                  ? (_sortAsc
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 14,
              color: active ? AdminStyles.primary : AdminStyles.textMuted,
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
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AdminStyles.textMuted,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTableRow(Department dept) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Name
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AdminStyles.primary, AdminStyles.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      dept.name.isNotEmpty
                          ? dept.name[0].toUpperCase()
                          : 'D',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    dept.name,
                    style: AdminStyles.bodyStyle(
                        fontWeight: FontWeight.w700,
                        color: AdminStyles.textPrimary,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Description
          Expanded(
            flex: 4,
            child: Text(
              dept.description ?? '—',
              style: AdminStyles.bodyStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          // Created
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(dept.createdAt),
              style: AdminStyles.bodyStyle(
                  fontSize: 12, color: AdminStyles.textMuted),
            ),
          ),
          // Status
          Expanded(
            flex: 2,
            child: _StatusChip(isActive: dept.isActive),
          ),
          // Actions
          Expanded(
            flex: 2,
            child: _buildActions(dept),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(Department dept) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _IconBtn(
          icon: Icons.visibility_outlined,
          tooltip: 'View',
          color: AdminStyles.primary,
          onTap: () => _showDetailDialog(dept),
        ),
        const SizedBox(width: 6),
        _IconBtn(
          icon: Icons.edit_outlined,
          tooltip: 'Edit',
          color: AdminStyles.secondary,
          onTap: () => _showEditDialog(dept),
        ),
        const SizedBox(width: 6),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded,
              color: AdminStyles.textMuted, size: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (v) {
            if (v == 'toggle') _toggleActive(dept);
            if (v == 'delete') _delete(dept);
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'toggle',
              child: Row(children: [
                Icon(
                  dept.isActive
                      ? Icons.do_not_disturb_on_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                  color: dept.isActive ? AdminStyles.warning : AdminStyles.success,
                ),
                const SizedBox(width: 10),
                Text(dept.isActive ? 'Disable' : 'Restore',
                    style: AdminStyles.bodyStyle(
                        color: dept.isActive
                            ? AdminStyles.warning
                            : AdminStyles.success,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                const Icon(Icons.delete_outline_rounded,
                    size: 18, color: AdminStyles.error),
                const SizedBox(width: 10),
                Text('Delete',
                    style: AdminStyles.bodyStyle(
                        color: AdminStyles.error,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  // ── Mobile Cards ──────────────────────────────────────────────────────────

  Widget _buildMobileCards() {
    return ListView.separated(
      itemCount: _paginated.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildMobileCard(_paginated[i]),
    );
  }

  Widget _buildMobileCard(Department dept) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AdminStyles.primary, AdminStyles.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                dept.name.isNotEmpty ? dept.name[0].toUpperCase() : 'D',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(dept.name,
                          style: AdminStyles.bodyStyle(
                              fontWeight: FontWeight.w700,
                              color: AdminStyles.textPrimary,
                              fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                    ),
                    _StatusChip(isActive: dept.isActive, compact: true),
                  ],
                ),
                if (dept.description != null) ...[
                  const SizedBox(height: 4),
                  Text(dept.description!,
                      style: AdminStyles.bodyStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 6),
                Text('Created ${_formatDate(dept.createdAt)}',
                    style: AdminStyles.bodyStyle(
                        fontSize: 11, color: AdminStyles.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AdminStyles.textMuted, size: 20),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              switch (v) {
                case 'view':
                  _showDetailDialog(dept);
                  break;
                case 'edit':
                  _showEditDialog(dept);
                  break;
                case 'toggle':
                  _toggleActive(dept);
                  break;
                case 'delete':
                  _delete(dept);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              _popItem(Icons.visibility_outlined, 'View', 'view'),
              _popItem(Icons.edit_outlined, 'Edit', 'edit'),
              if (dept.isActive)
                _popItem(Icons.do_not_disturb_on_rounded, 'Disable', 'toggle',
                    color: AdminStyles.warning)
              else
                _popItem(Icons.check_circle_outline_rounded, 'Restore', 'toggle',
                    color: AdminStyles.success),
              _popItem(Icons.delete_outline_rounded, 'Delete', 'delete',
                  color: AdminStyles.error),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _popItem(IconData icon, String label, String value,
      {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: color ?? AdminStyles.textSecondary),
        const SizedBox(width: 10),
        Text(label,
            style: AdminStyles.bodyStyle(
                color: color ?? AdminStyles.textPrimary, fontSize: 13)),
      ]),
    );
  }

  // ── Pagination ────────────────────────────────────────────────────────────

  Widget _buildPagination(bool isMobile) {
    final total = _filtered.length;
    final start = _page * _pageSize + 1;
    final end = ((_page + 1) * _pageSize).clamp(0, total);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!isMobile)
          Text(
            'Showing $start–$end of $total',
            style: AdminStyles.bodyStyle(fontSize: 12),
          ),
        Row(
          children: [
            _PageBtn(
                icon: Icons.first_page_rounded,
                onTap: _page > 0 ? () => setState(() => _page = 0) : null),
            _PageBtn(
                icon: Icons.chevron_left_rounded,
                onTap: _page > 0 ? () => setState(() => _page--) : null),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  color: AdminStyles.primary,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                '${_page + 1} / ${_totalPages.clamp(1, 9999)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
            _PageBtn(
                icon: Icons.chevron_right_rounded,
                onTap: _page < _totalPages - 1
                    ? () => setState(() => _page++)
                    : null),
            _PageBtn(
                icon: Icons.last_page_rounded,
                onTap: _page < _totalPages - 1
                    ? () => setState(() => _page = _totalPages - 1)
                    : null),
          ],
        ),
      ],
    );
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Add / Edit Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _DeptFormDialog extends StatefulWidget {
  final String title;
  final Department? dept;
  final List<Department> existingDepts;
  final Future<String?> Function(String name, String? desc) onSave;
  final VoidCallback onSuccess;

  const _DeptFormDialog({
    required this.title,
    this.dept,
    required this.existingDepts,
    required this.onSave,
    required this.onSuccess,
  });

  @override
  State<_DeptFormDialog> createState() => _DeptFormDialogState();
}

class _DeptFormDialogState extends State<_DeptFormDialog> {
  late final _nameCtrl =
      TextEditingController(text: widget.dept?.name ?? '');
  late final _descCtrl =
      TextEditingController(text: widget.dept?.description ?? '');
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _serverError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _serverError = null; });

    final err = await widget.onSave(
      _nameCtrl.text.trim(),
      _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (err == null) {
      widget.onSuccess();
    } else {
      setState(() => _serverError = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: AdminStyles.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.business_rounded,
                        color: AdminStyles.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(widget.title,
                          style: AdminStyles.headingStyle(fontSize: 20))),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: AdminStyles.textMuted),
                  ),
                ]),
                const SizedBox(height: 24),

                // Name
                _label('Department Name *'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  autofocus: true,
                  style: AdminStyles.bodyStyle(
                      color: AdminStyles.textPrimary,
                      fontWeight: FontWeight.w600),
                  decoration: _inputDecor(Icons.business_outlined,
                      hint: 'e.g. College of Engineering'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    // Duplicate check client-side
                    final dup = widget.existingDepts.any((d) =>
                        d.id != (widget.dept?.id ?? '') &&
                        d.name.trim().toLowerCase() ==
                            v.trim().toLowerCase());
                    if (dup) {
                      return 'A department with this name already exists.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description
                _label('Description (Optional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  style: AdminStyles.bodyStyle(
                      color: AdminStyles.textPrimary,
                      fontWeight: FontWeight.w600),
                  decoration: _inputDecor(Icons.description_outlined,
                      hint: 'Brief description of this department…'),
                ),

                // Server error
                if (_serverError != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminStyles.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AdminStyles.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AdminStyles.error, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(_serverError!,
                            style: AdminStyles.bodyStyle(
                                color: AdminStyles.error,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 24),

                // Buttons
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminStyles.textSecondary,
                        side: const BorderSide(color: AdminStyles.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              widget.dept == null ? 'Add Department' : 'Save Changes',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
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
    return Text(text,
        style: AdminStyles.bodyStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AdminStyles.textSecondary));
  }

  InputDecoration _inputDecor(IconData icon, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, size: 18, color: AdminStyles.textSecondary),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminStyles.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminStyles.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminStyles.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminStyles.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminStyles.error, width: 2),
      ),
      alignLabelWithHint: true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Detail Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _DeptDetailDialog extends StatelessWidget {
  final Department dept;

  const _DeptDetailDialog({required this.dept});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AdminStyles.primary, AdminStyles.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      dept.name.isNotEmpty ? dept.name[0].toUpperCase() : 'D',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dept.name,
                          style: AdminStyles.headingStyle(fontSize: 18)),
                      const SizedBox(height: 4),
                      _StatusChip(isActive: dept.isActive),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: AdminStyles.textMuted),
                ),
              ]),
              const SizedBox(height: 20),
              const Divider(color: AdminStyles.border),
              const SizedBox(height: 16),

              _row(Icons.description_outlined, 'Description',
                  dept.description ?? 'No description provided.'),
              _row(Icons.calendar_today_outlined, 'Created',
                  _fmt(dept.createdAt)),
              _row(Icons.update_rounded, 'Last Updated', _fmt(dept.updatedAt)),
              _row(Icons.fingerprint_rounded, 'ID', dept.id),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminStyles.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Close',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: AdminStyles.textMuted),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(label,
              style: AdminStyles.bodyStyle(
                  fontSize: 12, color: AdminStyles.textMuted)),
        ),
        Expanded(
          child: Text(value,
              style: AdminStyles.bodyStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AdminStyles.textPrimary)),
        ),
      ]),
    );
  }

  String _fmt(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final bool isActive;
  final bool compact;

  const _StatusChip({required this.isActive, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: isActive ? AdminStyles.success : AdminStyles.error,
              shape: BoxShape.circle,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 5),
            Text(
              isActive ? 'Active' : 'Disabled',
              style: TextStyle(
                color: isActive
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn(
      {required this.icon,
      required this.tooltip,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
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
            decoration: BoxDecoration(
                border: Border.all(color: AdminStyles.border),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon,
                size: 18,
                color: onTap != null
                    ? AdminStyles.textPrimary
                    : AdminStyles.textMuted),
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

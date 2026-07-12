import 'package:flutter/material.dart';

import '../../../authentication/models/user_model.dart';
import '../../../shared/models/specialization_model.dart';
import '../../../shared/services/specialization_service.dart';
import '../../../shared/services/system_admin_service.dart';
import '../../admin/shared/admin_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Main Widget
// ─────────────────────────────────────────────────────────────────────────────

class SystemAdminSpecializationsView extends StatefulWidget {
  const SystemAdminSpecializationsView({super.key});

  @override
  State<SystemAdminSpecializationsView> createState() =>
      _SystemAdminSpecializationsViewState();
}

class _SystemAdminSpecializationsViewState
    extends State<SystemAdminSpecializationsView> {
  // ── Data ──────────────────────────────────────────────────────────────────
  List<Specialization> _specializations = [];
  List<AppUser> _maintenanceUsers = [];
  bool _loading = true;
  String? _error;

  // ── Filters ───────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all'; // 'all' | 'active' | 'inactive'

  // ── Pagination ────────────────────────────────────────────────────────────
  static const _pageSize = 12;
  int _page = 0;

  // ── Sort ──────────────────────────────────────────────────────────────────
  String _sortField = 'name'; // 'name' | 'personnel'
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
      final results = await Future.wait([
        SpecializationService.fetchAll(),
        SystemAdminService.fetchAllUsers(),
      ]);

      if (mounted) {
        setState(() {
          _specializations = results[0] as List<Specialization>;
          final allUsers = results[1] as List<AppUser>;
          _maintenanceUsers =
              allUsers.where((u) => u.role == UserRole.maintenance).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  int _getPersonnelCount(String specName) {
    return _maintenanceUsers
        .where((u) => u.position?.toLowerCase() == specName.toLowerCase())
        .length;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Derived
  // ─────────────────────────────────────────────────────────────────────────

  List<Specialization> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    var list = _specializations.where((s) {
      if (q.isNotEmpty) {
        if (!s.name.toLowerCase().contains(q) &&
            !s.description.toLowerCase().contains(q)) return false;
      }
      if (_statusFilter == 'active' && !s.isActive) return false;
      if (_statusFilter == 'inactive' && s.isActive) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      int cmp;
      if (_sortField == 'name') {
        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else {
        cmp = _getPersonnelCount(b.name).compareTo(_getPersonnelCount(a.name));
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  List<Specialization> get _paginated {
    final f = _filtered;
    final start = _page * _pageSize;
    if (start >= f.length) return [];
    return f.sublist(start, (start + _pageSize).clamp(0, f.length));
  }

  int get _totalPages => (_filtered.isEmpty
      ? 1
      : ((_filtered.length - 1) / _pageSize).ceil());

  int get _activeCount => _specializations.where((s) => s.isActive).length;
  int get _inactiveCount => _specializations.where((s) => !s.isActive).length;

  // ─────────────────────────────────────────────────────────────────────────
  //  Actions
  // ─────────────────────────────────────────────────────────────────────────

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => _SpecializationFormDialog(
        title: 'Add Specialization',
        existing: _specializations,
        onSave: (name, desc, isActive) async {
          final err = await SpecializationService.create(
            name: name,
            description: desc,
            isActive: isActive,
          );
          return err;
        },
        onSuccess: () {
          Navigator.pop(context);
          _load();
          _toast('Specialization added successfully.');
        },
      ),
    );
  }

  void _showEditDialog(Specialization spec) {
    showDialog(
      context: context,
      builder: (_) => _SpecializationFormDialog(
        title: 'Edit Specialization',
        specialization: spec,
        existing: _specializations,
        onSave: (name, desc, isActive) async {
          final err = await SpecializationService.updateSpecialization(
            id: spec.id,
            name: name,
            description: desc,
            isActive: isActive,
          );
          return err;
        },
        onSuccess: () {
          Navigator.pop(context);
          _load();
          _toast('Specialization updated.');
        },
      ),
    );
  }

  Future<void> _toggleActive(Specialization spec) async {
    final activate = !spec.isActive;
    final confirmed = await _confirm(
      title: activate ? 'Restore Specialization' : 'Disable Specialization',
      message: activate
          ? 'Restore "${spec.name}"? It will be available for assigning to personnel again.'
          : 'Disable "${spec.name}"? Users will no longer be able to select it as a specialization.',
      confirmLabel: activate ? 'Restore' : 'Disable',
      danger: !activate,
    );
    if (!confirmed) return;

    await SpecializationService.setActive(spec.id, activate, spec.name);
    _toast(activate ? 'Specialization restored.' : 'Specialization disabled.');
    _load();
  }

  Future<void> _delete(Specialization spec) async {
    final count = _getPersonnelCount(spec.name);
    if (count > 0) {
      _toast(
          'Cannot delete: There are $count personnel assigned to "${spec.name}". Reassign them first.',
          isError: true);
      return;
    }

    final confirmed = await _confirm(
      title: 'Delete Specialization',
      message:
          'Permanently delete specialization "${spec.name}"?\n\nThis cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!confirmed) return;

    final err = await SpecializationService.deleteSpecialization(spec.id, spec.name);
    if (err == null) {
      _toast('Specialization "${spec.name}" deleted.');
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
      final isMobile = constraints.maxWidth < 800;
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
              Text('Failed to load specializations',
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
            Icon(Icons.handyman_rounded,
                size: 60, color: AdminStyles.textMuted),
            const SizedBox(height: 16),
            Text(
              _searchCtrl.text.isNotEmpty || _statusFilter != 'all'
                  ? 'No specializations match your filters'
                  : 'No specializations yet',
              style: AdminStyles.headingStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _searchCtrl.text.isNotEmpty || _statusFilter != 'all'
                  ? 'Try adjusting your search or filters.'
                  : 'Click "Add Specialization" to create the first one.',
              style: AdminStyles.bodyStyle(),
            ),
            if (_searchCtrl.text.isEmpty && _statusFilter == 'all') ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Specialization'),
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
              Text('Maintenance Specializations',
                  style: AdminStyles.headingStyle(
                      fontSize: isMobile ? 22 : 28)),
              const SizedBox(height: 4),
              Text('Manage disciplines like Electrical, Carpentry, Plumbing.',
                  style: AdminStyles.bodyStyle(fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _showAddDialog,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(isMobile ? 'Add' : 'Add Specialization'),
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
      _Stat('Total Specs', _specializations.length, Icons.handyman_rounded, AdminStyles.primary),
      _Stat('Active', _activeCount, Icons.check_circle_rounded, AdminStyles.success),
      _Stat('Inactive', _inactiveCount, Icons.do_not_disturb_on_rounded, AdminStyles.error),
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
      padding: const EdgeInsets.all(16),
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
          hintText: 'Search specializations…',
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
            DropdownMenuItem(value: 'inactive', child: Text('Inactive Only')),
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
          _sortableHeader('Specialization', 'name', flex: 3),
          _sortableHeader('Personnel Assigned', 'personnel', flex: 2),
          _th('Status', flex: 1, center: true),
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

  Widget _buildTableRow(Specialization spec) {
    final count = _getPersonnelCount(spec.name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Specialization Name
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AdminStyles.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.handyman_rounded, color: AdminStyles.primary, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        spec.name,
                        style: AdminStyles.bodyStyle(
                            fontWeight: FontWeight.w700,
                            color: AdminStyles.textPrimary,
                            fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (spec.description.isNotEmpty)
                        Text(
                          spec.description,
                          style: AdminStyles.bodyStyle(
                              fontSize: 11, color: AdminStyles.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Personnel Assigned
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(Icons.people_rounded, size: 16, color: count > 0 ? AdminStyles.textSecondary : AdminStyles.border),
                const SizedBox(width: 6),
                Text(
                  '$count staff',
                  style: AdminStyles.bodyStyle(fontSize: 13, color: count > 0 ? AdminStyles.textPrimary : AdminStyles.textMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          // Status
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: spec.isActive ? AdminStyles.success : AdminStyles.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          // Actions
          Expanded(
            flex: 2,
            child: _buildActions(spec),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(Specialization spec) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _IconBtn(
          icon: Icons.edit_outlined,
          tooltip: 'Edit',
          color: AdminStyles.secondary,
          onTap: () => _showEditDialog(spec),
        ),
        const SizedBox(width: 6),
        _IconBtn(
          icon: spec.isActive ? Icons.do_not_disturb_on_rounded : Icons.settings_backup_restore_rounded,
          tooltip: spec.isActive ? 'Disable' : 'Restore',
          color: spec.isActive ? AdminStyles.warning : AdminStyles.success,
          onTap: () => _toggleActive(spec),
        ),
        const SizedBox(width: 6),
        _IconBtn(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Delete',
          color: AdminStyles.error,
          onTap: () => _delete(spec),
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

  Widget _buildMobileCard(Specialization spec) {
    final count = _getPersonnelCount(spec.name);
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
              color: AdminStyles.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.handyman_rounded, color: AdminStyles.primary, size: 24),
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
                      child: Text(spec.name,
                          style: AdminStyles.bodyStyle(
                              fontWeight: FontWeight.w700,
                              color: AdminStyles.textPrimary,
                              fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: spec.isActive ? AdminStyles.success : AdminStyles.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                if (spec.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(spec.description,
                      style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary)),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people_rounded, size: 12, color: count > 0 ? AdminStyles.textSecondary : AdminStyles.border),
                    const SizedBox(width: 4),
                    Text('$count Staff', style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted, fontWeight: FontWeight.w600)),
                  ],
                ),
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
                case 'edit':
                  _showEditDialog(spec);
                  break;
                case 'toggle':
                  _toggleActive(spec);
                  break;
                case 'delete':
                  _delete(spec);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              _popItem(Icons.edit_outlined, 'Edit', 'edit'),
              if (spec.isActive)
                _popItem(Icons.do_not_disturb_on_rounded, 'Disable', 'toggle', color: AdminStyles.warning)
              else
                _popItem(Icons.settings_backup_restore_rounded, 'Restore', 'toggle', color: AdminStyles.success),
              _popItem(Icons.delete_outline_rounded, 'Delete', 'delete', color: AdminStyles.error),
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  Add / Edit Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _SpecializationFormDialog extends StatefulWidget {
  final String title;
  final Specialization? specialization;
  final List<Specialization> existing;
  final Future<String?> Function(String name, String description, bool isActive) onSave;
  final VoidCallback onSuccess;

  const _SpecializationFormDialog({
    required this.title,
    this.specialization,
    required this.existing,
    required this.onSave,
    required this.onSuccess,
  });

  @override
  State<_SpecializationFormDialog> createState() => _SpecializationFormDialogState();
}

class _SpecializationFormDialogState extends State<_SpecializationFormDialog> {
  late final _nameCtrl = TextEditingController(text: widget.specialization?.name ?? '');
  late final _descCtrl = TextEditingController(text: widget.specialization?.description ?? '');
  bool _isActive = true;

  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    if (widget.specialization != null) {
      _isActive = widget.specialization!.isActive;
    }
  }

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
      _descCtrl.text.trim(),
      _isActive,
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
        constraints: const BoxConstraints(maxWidth: 500),
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
                    child: const Icon(Icons.handyman_rounded,
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
                _label('Specialization Name *'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  autofocus: true,
                  style: AdminStyles.bodyStyle(
                      color: AdminStyles.textPrimary,
                      fontWeight: FontWeight.w600),
                  decoration: _inputDecor(Icons.label_outline_rounded,
                      hint: 'e.g. Electrical, Plumbing'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final dup = widget.existing.any((s) =>
                        s.id != (widget.specialization?.id ?? '') &&
                        s.name.trim().toLowerCase() ==
                            v.trim().toLowerCase());
                    if (dup) return 'Specialization exists.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description
                _label('Description (Optional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  style: AdminStyles.bodyStyle(
                      color: AdminStyles.textPrimary,
                      fontWeight: FontWeight.w600),
                  decoration: _inputDecor(Icons.subject_rounded,
                      hint: 'Scope of work for this discipline...'),
                ),
                const SizedBox(height: 16),

                // Status
                _label('Status'),
                const SizedBox(height: 8),
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminStyles.border),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(Icons.check_circle_outline_rounded, size: 18, color: AdminStyles.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Active', style: AdminStyles.bodyStyle(color: AdminStyles.textPrimary, fontWeight: FontWeight.w600)),
                      ),
                      Switch(
                        value: _isActive,
                        activeColor: AdminStyles.primary,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
                  ),
                ),

                // Server error
                if (_serverError != null) ...[
                  const SizedBox(height: 16),
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
                              widget.specialization == null ? 'Add Specialization' : 'Save Changes',
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

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

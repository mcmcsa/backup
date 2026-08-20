import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../admin/shared/admin_styles.dart';
import '../teacher_nav_controller.dart';

class TeacherReportsWeb extends StatefulWidget {
  const TeacherReportsWeb({super.key});

  @override
  State<TeacherReportsWeb> createState() => _TeacherReportsWebState();
}

class _TeacherReportsWebState extends State<TeacherReportsWeb>
    with SingleTickerProviderStateMixin {
  List<WorkRequest> _requests = [];
  List<WorkRequest> _filteredRequests = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'All';
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  RealtimeChannel? _realtimeChannel;

  final List<String> _statuses = [
    'All',
    'Pending',
    'In Progress',
    'Completed',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _loadRequests();
    _setupRealtime();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _animController.dispose();
    super.dispose();
  }

  void _setupRealtime() {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    _realtimeChannel = WorkRequestService.listenToRequestorRequests(user.id, (data) {
      if (mounted) {
        setState(() {
          _requests = data;
          _applyFilters();
        });
      }
    });
  }

  Future<void> _loadRequests() async {
    try {
      final user = context.read<AuthService>().currentUser;
      if (user == null) return;
      final data = await WorkRequestService.fetchByRequestor(user.id);
      if (mounted) {
        setState(() {
          _requests = data;
          _applyFilters();
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredRequests = _requests.where((r) {
        final matchesSearch =
            r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (r.roomName
                        ?.toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ??
                    false);
        final normalizedStatus =
            _selectedStatus.toLowerCase().replaceAll(' ', '_');
        final matchesStatus =
            _selectedStatus == 'All' ||
            r.status.toLowerCase() == normalizedStatus;
        return matchesSearch && matchesStatus;
      }).toList();
      _filteredRequests.sort(
        (a, b) => b.dateSubmitted.compareTo(a.dateSubmitted),
      );
    });
  }


  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 900;

    return Container(
      color: AdminStyles.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(isCompact),
          if (!_isLoading) ...[
            _buildSearchAndFilters(isCompact),
          ],
          Expanded(
            child:
                _isLoading
                    ? _buildLoadingState()
                    : FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildContent(isCompact),
                    ),
          ),
        ],
      ),
    );
  }

  // ─── Page Header ────────────────────────────────────────────────────────────
  Widget _buildPageHeader(bool isCompact) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 20 : 40,
        isCompact ? 24 : 36,
        isCompact ? 20 : 40,
        isCompact ? 10 : 16,
      ),
      child:
          isCompact
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderTitle(),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: _buildExportButton()),
                ],
              )
              : Row(
                children: [
                  Expanded(child: _buildHeaderTitle()),
                  const SizedBox(width: 24),
                  _buildExportButton(),
                ],
              ),
    );
  }

  Widget _buildHeaderTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.assessment_rounded,
              color: AdminStyles.primary,
              size: 32,
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Reports',
                  style: AdminStyles.headingStyle(fontSize: 26),
                ),
                Text(
                  'Track all your maintenance requests',
                  style: AdminStyles.bodyStyle(
                    color: AdminStyles.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExportButton() {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.download_rounded, size: 18),
      label: const Text('Export'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminStyles.textPrimary,
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: AdminStyles.bodyStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AdminStyles.textPrimary,
        ),
      ),
    );
  }


  // ─── Search & Filters ───────────────────────────────────────────────────────
  Widget _buildSearchAndFilters(bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 20 : 40,
        vertical: 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child:
          isCompact
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchField(),
                  const SizedBox(height: 14),
                  _buildFilterChips(),
                ],
              )
              : Row(
                children: [
                  Expanded(flex: 4, child: _buildSearchField()),
                  const SizedBox(width: 24),
                  Expanded(flex: 6, child: _buildFilterChips()),
                ],
              ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: (v) {
          _searchQuery = v;
          _applyFilters();
        },
        style: AdminStyles.bodyStyle(
          color: AdminStyles.textPrimary,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AdminStyles.textMuted,
            size: 20,
          ),
          hintText: 'Search by title or room...',
          hintStyle: AdminStyles.bodyStyle(
            color: AdminStyles.textMuted,
            fontSize: 14,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            _statuses.map((status) {
              final isSelected = _selectedStatus == status;
              final color = _getStatusChipColor(status);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedStatus = status;
                        _applyFilters();
                      });
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? color.withValues(alpha: 0.12)
                                : Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color:
                              isSelected
                                  ? color.withValues(alpha: 0.5)
                                  : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow:
                            isSelected
                                ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                                : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            Icon(Icons.check_rounded, color: color, size: 14),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            status,
                            style: AdminStyles.bodyStyle(
                              fontSize: 13,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                              color:
                                  isSelected ? color : AdminStyles.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  // ─── Content ────────────────────────────────────────────────────────────────
  Widget _buildContent(bool isCompact) {
    if (_filteredRequests.isEmpty) {
      return _buildEmptyState();
    }

    return isCompact
        ? _buildCardList()
        : _buildTableLayout();
  }

  // ─── Card List (Mobile/Compact) ─────────────────────────────────────────────
  Widget _buildCardList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _filteredRequests.length,
      itemBuilder: (context, index) {
        final request = _filteredRequests[index];
        return _PremiumRequestCard(
          request: request,
          onTap: () {
            TeacherNavController.of(context)?.navigateTo(3, request: request);
          },
        );
      },
    );
  }

  // ─── Table Layout (Desktop) ──────────────────────────────────────────────────
  Widget _buildTableLayout() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildTableHeader(),
            Expanded(
              child: ListView.separated(
                itemCount: _filteredRequests.length,
                separatorBuilder:
                    (context, index) => const Divider(
                      height: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                itemBuilder:
                    (context, index) =>
                        _buildTableRow(_filteredRequests[index], index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text('REQUEST', style: _tableHeaderStyle),
          ),
          Expanded(
            flex: 3,
            child: Text('LOCATION', style: _tableHeaderStyle, textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 2,
            child: Text('DATE FILED', style: _tableHeaderStyle),
          ),
          Expanded(flex: 2, child: Text('STATUS', style: _tableHeaderStyle)),
          Expanded(
            flex: 1,
            child: Text('ACTION', style: _tableHeaderStyle, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(WorkRequest request, int index) {
    final statusColor = _getStatusColor(request.status);
    return _TableRowHover(
      onTap: () {
        TeacherNavController.of(context)?.navigateTo(3, request: request);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          style: AdminStyles.headingStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          request.typeOfRequest,
                          style: AdminStyles.bodyStyle(
                            fontSize: 12,
                            color: AdminStyles.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 15,
                    color: AdminStyles.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      request.roomName ?? 'N/A',
                      style: AdminStyles.bodyStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: AdminStyles.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('MMM dd, yyyy').format(request.dateSubmitted),
                    style: AdminStyles.bodyStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildStatusBadge(request.status),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AdminStyles.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Loading & Empty States ──────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AdminStyles.primary,
              strokeWidth: 3,
              backgroundColor: AdminStyles.primary.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading your reports...',
            style: AdminStyles.bodyStyle(color: AdminStyles.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = _searchQuery.isNotEmpty || _selectedStatus != 'All';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AdminStyles.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : Icons.assignment_outlined,
              size: 48,
              color: AdminStyles.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            hasSearch ? 'No matching requests found' : 'No reports yet',
            style: AdminStyles.headingStyle(
              fontSize: 20,
              color: AdminStyles.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'Try adjusting your search or filters.'
                : 'Submit a maintenance request to get started.',
            style: AdminStyles.bodyStyle(
              color: AdminStyles.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────
  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final label = _getStatusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: AdminStyles.headingStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AdminStyles.success;
      case 'in_progress':
      case 'under_maintenance':
        return AdminStyles.info;
      case 'pending':
        return AdminStyles.warning;
      case 'cancelled':
        return AdminStyles.error;
      default:
        return AdminStyles.textMuted;
    }
  }

  Color _getStatusChipColor(String status) {
    switch (status) {
      case 'All':
        return AdminStyles.primary;
      case 'Pending':
        return AdminStyles.warning;
      case 'In Progress':
        return AdminStyles.info;
      case 'Completed':
        return AdminStyles.success;
      case 'Cancelled':
        return AdminStyles.error;
      default:
        return AdminStyles.textMuted;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return 'IN PROGRESS';
      case 'under_maintenance':
        return 'UNDER MAINT.';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return status.toUpperCase().replaceAll('_', ' ');
    }
  }

  TextStyle get _tableHeaderStyle => const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 1.2,
  );
}

// ─── Premium Request Card (Compact Mode) ────────────────────────────────────
class _PremiumRequestCard extends StatefulWidget {
  final WorkRequest request;
  final VoidCallback onTap;

  const _PremiumRequestCard({required this.request, required this.onTap});

  @override
  State<_PremiumRequestCard> createState() => _PremiumRequestCardState();
}

class _PremiumRequestCardState extends State<_PremiumRequestCard> {
  bool _isHovered = false;

  Color get _statusColor {
    switch (widget.request.status.toLowerCase()) {
      case 'completed':
        return AdminStyles.success;
      case 'in_progress':
      case 'under_maintenance':
        return AdminStyles.info;
      case 'pending':
        return AdminStyles.warning;
      case 'cancelled':
        return AdminStyles.error;
      default:
        return AdminStyles.textMuted;
    }
  }

  String get _statusLabel {
    switch (widget.request.status.toLowerCase()) {
      case 'in_progress':
        return 'IN PROGRESS';
      case 'under_maintenance':
        return 'MAINTENANCE';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return widget.request.status.toUpperCase().replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    _isHovered
                        ? _statusColor.withValues(alpha: 0.4)
                        : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      _isHovered
                          ? _statusColor.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.04),
                  blurRadius: _isHovered ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  // Left accent bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 5,
                    height: 90,
                    color: _statusColor,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.request.title,
                                      style: AdminStyles.headingStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      widget.request.typeOfRequest,
                                      style: AdminStyles.bodyStyle(
                                        fontSize: 12,
                                        color: AdminStyles.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Status badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _statusColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: _statusColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _statusLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _statusColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildMeta(
                                Icons.location_on_rounded,
                                widget.request.roomName ?? 'N/A',
                              ),
                              const SizedBox(width: 20),
                              _buildMeta(
                                Icons.calendar_today_rounded,
                                DateFormat(
                                  'MMM dd, yyyy',
                                ).format(widget.request.dateSubmitted),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 13,
                                color:
                                    _isHovered
                                        ? _statusColor
                                        : AdminStyles.textMuted,
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Widget _buildMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AdminStyles.textMuted),
        const SizedBox(width: 5),
        Text(
          text,
          style: AdminStyles.bodyStyle(
            fontSize: 12,
            color: AdminStyles.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─── Hover wrapper for table rows ────────────────────────────────────────────
class _TableRowHover extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TableRowHover({required this.child, required this.onTap});

  @override
  State<_TableRowHover> createState() => _TableRowHoverState();
}

class _TableRowHoverState extends State<_TableRowHover> {
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
          color: _isHovered ? const Color(0xFFF0FDFA) : Colors.white,
          child: widget.child,
        ),
      ),
    );
  }
}


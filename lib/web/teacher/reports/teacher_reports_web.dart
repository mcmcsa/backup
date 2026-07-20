import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../admin/shared/admin_styles.dart';

class TeacherReportsWeb extends StatefulWidget {
  const TeacherReportsWeb({super.key});

  @override
  State<TeacherReportsWeb> createState() => _TeacherReportsWebState();
}

class _TeacherReportsWebState extends State<TeacherReportsWeb> {
  List<WorkRequest> _requests = [];
  List<WorkRequest> _filteredRequests = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'All';

  final List<String> _statuses = ['All', 'Pending', 'In Progress', 'Under Maintenance', 'Completed'];

  @override
  void initState() {
    super.initState();
    _loadRequests();
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
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredRequests = _requests.where((r) {
        final matchesSearch = r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                             (r.roomName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        final matchesStatus = _selectedStatus == 'All' || 
                             r.status.toLowerCase() == _selectedStatus.toLowerCase().replaceAll(' ', '_');
        return matchesSearch && matchesStatus;
      }).toList();
      _filteredRequests.sort((a, b) => b.dateSubmitted.compareTo(a.dateSubmitted));
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 900;

    return Container(
      color: AdminStyles.bg,
      padding: EdgeInsets.all(isCompact ? 16 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isCompact),
          SizedBox(height: isCompact ? 24 : 40),
          _buildFilters(isCompact),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary))
              : _buildTable(isCompact),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isCompact) {
    final titleWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Work Request Reports', style: AdminStyles.headingStyle(fontSize: isCompact ? 22 : 28)),
        const SizedBox(height: 8),
        Text('Track the history and real-time status of all your maintenance requests.', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
      ],
    );

    final exportButton = _buildExportButton();

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget,
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: exportButton),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: titleWidget),
        const SizedBox(width: 16),
        exportButton,
      ],
    );
  }

  Widget _buildExportButton() {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.download_rounded),
      label: const Text('Export Data'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminStyles.textPrimary,
        side: BorderSide(color: AdminStyles.border),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildFilters(bool isCompact) {
    final searchField = Container(
      height: 48,
      decoration: BoxDecoration(color: AdminStyles.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminStyles.border)),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        onChanged: (v) {
          _searchQuery = v;
          _applyFilters();
        },
        decoration: InputDecoration(
          icon: Icon(Icons.search_rounded, color: AdminStyles.textMuted, size: 20),
          hintText: 'Search by title or room...',
          hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted),
          border: InputBorder.none,
        ),
      ),
    );

    final dropdownField = Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AdminStyles.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminStyles.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          isExpanded: isCompact,
          items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: AdminStyles.bodyStyle()))).toList(),
          onChanged: (v) {
            setState(() {
              _selectedStatus = v!;
              _applyFilters();
            });
          },
        ),
      ),
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchField,
          const SizedBox(height: 12),
          dropdownField,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: searchField),
        const SizedBox(width: 24),
        dropdownField,
      ],
    );
  }

  Widget _buildTable(bool isCompact) {
    if (_filteredRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: AdminStyles.textMuted.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text('No requests found matching your filters', style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
          ],
        ),
      );
    }

    if (isCompact) {
      return ListView.builder(
        itemCount: _filteredRequests.length,
        itemBuilder: (context, index) {
          final request = _filteredRequests[index];
          return Card(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.go('/request-details', extra: {'request': request}),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(request.title, style: AdminStyles.headingStyle(fontSize: 14)),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusPill(request.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(request.typeOfRequest, style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary)),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 14, color: AdminStyles.textSecondary),
                            const SizedBox(width: 4),
                            Text(request.roomName ?? 'N/A', style: AdminStyles.bodyStyle(fontSize: 12)),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 14, color: AdminStyles.textSecondary),
                            const SizedBox(width: 4),
                            Text(DateFormat('MMM dd, yyyy').format(request.dateSubmitted), style: AdminStyles.bodyStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Container(
      decoration: AdminStyles.cardDecoration(hasShadow: false, borderColor: AdminStyles.border),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: ListView.separated(
              itemCount: _filteredRequests.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: AdminStyles.border),
              itemBuilder: (context, index) => _buildTableRow(_filteredRequests[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: AdminStyles.bg.withValues(alpha: 0.5),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('REQUEST DETAILS', style: _headerStyle)),
          Expanded(flex: 2, child: Text('ROOM / LOCATION', style: _headerStyle)),
          Expanded(flex: 2, child: Text('SUBMITTED DATE', style: _headerStyle)),
          Expanded(flex: 2, child: Text('STATUS', style: _headerStyle)),
          const SizedBox(width: 48), // Action column space
        ],
      ),
    );
  }

  Widget _buildTableRow(WorkRequest request) {
    return Material(
      color: AdminStyles.surface,
      child: InkWell(
        onTap: () => context.go('/request-details', extra: {'request': request}),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.title, style: AdminStyles.headingStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(request.typeOfRequest, style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: AdminStyles.textSecondary),
                    const SizedBox(width: 8),
                    Text(request.roomName ?? 'N/A', style: AdminStyles.bodyStyle(fontSize: 13)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(DateFormat('MMM dd, yyyy').format(request.dateSubmitted), style: AdminStyles.bodyStyle(fontSize: 13)),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    _buildStatusPill(request.status),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AdminStyles.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: AdminStyles.pillDecoration(color: color, isSecondary: true),
      child: Text(status.toUpperCase().replaceAll('_', ' '), style: AdminStyles.headingStyle(fontSize: 10, color: color)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return AdminStyles.success;
      case 'in_progress':
      case 'under_maintenance': return AdminStyles.info;
      case 'pending': return AdminStyles.warning;
      default: return AdminStyles.textMuted;
    }
  }

  TextStyle get _headerStyle => AdminStyles.headingStyle(fontSize: 11, color: AdminStyles.textSecondary, letterSpacing: 1.0);
}

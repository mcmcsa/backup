import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../admin/shared/admin_styles.dart';

class TeacherArchivesWeb extends StatefulWidget {
  const TeacherArchivesWeb({super.key});

  @override
  State<TeacherArchivesWeb> createState() => _TeacherArchivesWebState();
}

class _TeacherArchivesWebState extends State<TeacherArchivesWeb> {
  final TextEditingController _searchController = TextEditingController();
  List<WorkRequest> _archivedRequests = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadArchives();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadArchives() async {
    try {
      final user = context.read<AuthService>().currentUser;
      if (user == null) return;
      final data = await WorkRequestService.fetchByRequestor(user.id);
      if (mounted) {
        setState(() {
          _archivedRequests = data.where((r) => ['completed', 'cancelled'].contains(r.status.toLowerCase())).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<WorkRequest> get _filteredArchives {
    return _archivedRequests.where((r) {
      final matchesFilter = _selectedFilter == 'All' || r.status.toLowerCase() == _selectedFilter.toLowerCase();
      final query = _searchController.text.toLowerCase();
      final matchesSearch = r.title.toLowerCase().contains(query) || (r.roomName?.toLowerCase().contains(query) ?? false);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminStyles.bg,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary))
              : _buildArchiveList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(40),
      color: AdminStyles.surface,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AdminStyles.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Archives', style: AdminStyles.headingStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text('Review your historical work requests and cancellations.', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontSize: 16)),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: AdminStyles.cardDecoration(hasShadow: false, borderColor: AdminStyles.border),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() {}),
                    decoration: AdminStyles.searchInputDecoration(hintText: 'Search archived requests...', prefixIcon: Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              _buildFilterChip('All'),
              const SizedBox(width: 12),
              _buildFilterChip('Completed'),
              const SizedBox(width: 12),
              _buildFilterChip('Cancelled'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AdminStyles.primary : AdminStyles.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AdminStyles.primary : AdminStyles.border),
        ),
        child: Text(
          label,
          style: AdminStyles.bodyStyle(
            color: isSelected ? Colors.white : AdminStyles.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildArchiveList() {
    final archives = _filteredArchives;
    if (archives.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, size: 64, color: AdminStyles.textMuted.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text('No archived requests found', style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(40),
      itemCount: archives.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildArchiveItem(archives[index]),
    );
  }

  Widget _buildArchiveItem(WorkRequest request) {
    final isCompleted = request.status.toLowerCase() == 'completed';
    final color = isCompleted ? AdminStyles.success : AdminStyles.error;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminStyles.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 28),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.title, style: AdminStyles.headingStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: AdminStyles.textSecondary),
                    const SizedBox(width: 4),
                    Text(request.roomName ?? 'N/A', style: AdminStyles.bodyStyle(fontSize: 13)),
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_today_outlined, size: 14, color: AdminStyles.textSecondary),
                    const SizedBox(width: 4),
                    Text(DateFormat('MMM dd, yyyy').format(request.dateSubmitted), style: AdminStyles.bodyStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          _buildStatusPill(request.status),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    final isCompleted = status.toLowerCase() == 'completed';
    final color = isCompleted ? AdminStyles.success : AdminStyles.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: AdminStyles.pillDecoration(color: color, isSecondary: true),
      child: Text(status.toUpperCase(), style: AdminStyles.headingStyle(fontSize: 10, color: color)),
    );
  }
}

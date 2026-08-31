import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../admin/shared/admin_styles.dart';
import '../teacher_nav_controller.dart';
import '../../../shared/widgets/room_comparison_dialog.dart';

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
          _archivedRequests = data.where((r) => ['completed', 'cancelled', 'declined'].contains(r.status.toLowerCase())).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<WorkRequest> get _filteredArchives {
    return _archivedRequests.where((r) {
      final matchesFilter = _selectedFilter == 'All' ||
          (r.status.toLowerCase() == _selectedFilter.toLowerCase()) ||
          (_selectedFilter == 'Declined' && (r.status.toLowerCase() == 'cancelled' || r.status.toLowerCase() == 'declined'));
      final query = _searchController.text.toLowerCase();
      final matchesSearch = r.title.toLowerCase().contains(query) || (r.roomName?.toLowerCase().contains(query) ?? false) || r.id.toLowerCase().contains(query);
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
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 650;

    return Container(
      padding: EdgeInsets.all(isNarrow ? 16 : 40),
      decoration: BoxDecoration(
        color: AdminStyles.surface,
        border: Border(bottom: BorderSide(color: AdminStyles.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Archives', style: AdminStyles.headingStyle(fontSize: isNarrow ? 24 : 32)),
          const SizedBox(height: 8),
          Text(
            'Review your historical work requests and declined requests.',
            style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontSize: isNarrow ? 14 : 16),
          ),
          SizedBox(height: isNarrow ? 20 : 32),
          if (isNarrow)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: AdminStyles.cardDecoration(hasShadow: false, borderColor: AdminStyles.border),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() {}),
                    decoration: AdminStyles.searchInputDecoration(
                      hintText: 'Search archived requests...',
                      prefixIcon: Icons.search_rounded,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      const SizedBox(width: 12),
                      _buildFilterChip('Completed'),
                      const SizedBox(width: 12),
                      _buildFilterChip('Declined'),
                    ],
                  ),
                ),
              ],
            )
          else
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
                _buildFilterChip('Declined'),
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
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 650;
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
      padding: EdgeInsets.all(isNarrow ? 16 : 40),
      itemCount: archives.length,
      separatorBuilder: (context, index) => SizedBox(height: isNarrow ? 12 : 16),
      itemBuilder: (context, index) => _buildArchiveItem(archives[index]),
    );
  }

  Widget _buildArchiveItem(WorkRequest request) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 650;
    final isCompleted = request.status.toLowerCase() == 'completed';
    final color = isCompleted ? AdminStyles.success : AdminStyles.error;

    return GestureDetector(
      onTap: () async {
        final roomId = request.roomId;
        bool showComparison = false;
        if (roomId != null && roomId.isNotEmpty) {
          try {
            final response = await Supabase.instance.client
                .from('room_versions')
                .select('id')
                .eq('room_id', roomId);
            if ((response as List).length >= 2) {
              showComparison = true;
            }
          } catch (_) {}
        }

        if (!mounted) return;

        if (showComparison) {
          showDialog(
            context: context,
            builder: (context) => RoomComparisonDialog(roomId: roomId!),
          );
        } else {
          TeacherNavController.of(context)?.navigateTo(3, request: request);
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: EdgeInsets.all(isNarrow ? 16 : 24),
          decoration: AdminStyles.cardDecoration(),
          child: Row(
            children: [
              Container(
                width: isNarrow ? 44 : 56,
                height: isNarrow ? 44 : 56,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: isNarrow ? 20 : 28),
              ),
              SizedBox(width: isNarrow ? 16 : 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.title,
                      style: AdminStyles.headingStyle(fontSize: isNarrow ? 14 : 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_outlined, size: 14, color: AdminStyles.textSecondary),
                            const SizedBox(width: 4),
                            Container(
                              constraints: BoxConstraints(maxWidth: isNarrow ? 120 : 180),
                              child: Text(
                                request.roomName ?? 'N/A',
                                style: AdminStyles.bodyStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 14, color: AdminStyles.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM dd, yyyy').format(request.dateSubmitted),
                              style: AdminStyles.bodyStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildStatusPill(request.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    final isCompleted = status.toLowerCase() == 'completed';
    final color = isCompleted ? AdminStyles.success : AdminStyles.error;
    final displayStatus = (status.toLowerCase() == 'cancelled' || status.toLowerCase() == 'declined') ? 'DECLINED' : status.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: AdminStyles.pillDecoration(color: color, isSecondary: true),
      child: Text(displayStatus, style: AdminStyles.headingStyle(fontSize: 10, color: color)),
    );
  }
}

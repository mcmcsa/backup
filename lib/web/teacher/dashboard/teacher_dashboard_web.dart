import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import 'package:intl/intl.dart';
import '../../admin/shared/admin_styles.dart';
import '../teacher_nav_controller.dart';

class TeacherDashboardWeb extends StatefulWidget {
  const TeacherDashboardWeb({super.key});

  @override
  State<TeacherDashboardWeb> createState() => _TeacherDashboardWebState();
}

class _TeacherDashboardWebState extends State<TeacherDashboardWeb> {
  List<WorkRequest> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final data = await WorkRequestService.fetchByRequestor(user.id);
      if (mounted) {
        setState(() {
          _requests = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _getCountByStatus(String status) {
    return _requests.where((r) => r.status.toLowerCase() == status.toLowerCase()).length;
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    final pendingCount = _getCountByStatus('pending');
    final activeCount = _requests.where((r) => ['in_progress', 'under_maintenance'].contains(r.status.toLowerCase())).length;
    final completedCount = _getCountByStatus('completed');

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AdminStyles.primary));
    }

    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 900;

    return Container(
      color: AdminStyles.bg,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isCompact ? 16 : 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(user?.name ?? 'Teacher', isCompact),
            SizedBox(height: isCompact ? 24 : 40),
            _buildRequestsSection(isCompact),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String userName, bool isCompact) {
    final titleWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome back, $userName', style: AdminStyles.headingStyle(fontSize: isCompact ? 24 : 32)),
        const SizedBox(height: 8),
        Text('Here is what is happening with your maintenance requests today.', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontSize: isCompact ? 14 : 16)),
      ],
    );

    final buttonWidget = ElevatedButton.icon(
      onPressed: () => TeacherNavController.of(context)?.navigateTo(2),
      icon: const Icon(Icons.add_rounded),
      label: const Text('New Request'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminStyles.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget,
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: buttonWidget),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: titleWidget),
        const SizedBox(width: 16),
        buttonWidget,
      ],
    );
  }

  Widget _buildQuickStats(int pending, int active, int completed, bool isCompact) {
    final cards = [
      _StatCard(title: 'Pending Review', value: pending, icon: Icons.schedule_rounded, color: AdminStyles.warning),
      _StatCard(title: 'In Progress', value: active, icon: Icons.engineering_rounded, color: AdminStyles.info),
      _StatCard(title: 'Recently Completed', value: completed, icon: Icons.check_circle_rounded, color: AdminStyles.success),
    ];

    if (isCompact) {
      return Column(
        children: cards.map((card) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: card,
        )).toList(),
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 24),
        Expanded(child: cards[1]),
        const SizedBox(width: 24),
        Expanded(child: cards[2]),
      ],
    );
  }

  Widget _buildRequestsSection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('My Work Requests', style: AdminStyles.headingStyle(fontSize: 20)),
            TextButton.icon(
              onPressed: () => TeacherNavController.of(context)?.navigateTo(3),
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('View All'),
              style: TextButton.styleFrom(foregroundColor: AdminStyles.primary),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_requests.isEmpty)
          _buildEmptyState()
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isCompact ? 1 : 2,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              mainAxisExtent: isCompact ? 130 : 140,
            ),
            itemCount: _requests.take(4).length,
            itemBuilder: (context, index) => _buildRequestCard(_requests[index], isCompact),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80),
      decoration: AdminStyles.cardDecoration(hasShadow: false, borderColor: AdminStyles.border),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: AdminStyles.textMuted.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No work requests yet', style: AdminStyles.headingStyle(fontSize: 18, color: AdminStyles.textMuted)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => TeacherNavController.of(context)?.navigateTo(11),
            child: const Text('Create Your First Request'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(WorkRequest request, bool isCompact) {
    final statusColor = _getStatusColor(request.status);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => TeacherNavController.of(context)?.navigateTo(3),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isCompact ? 16 : 24),
          decoration: AdminStyles.cardDecoration(hasShadow: true),
          child: Row(
            children: [
              Container(
                width: isCompact ? 44 : 56,
                height: isCompact ? 44 : 56,
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.assignment_rounded, color: statusColor, size: isCompact ? 20 : 28),
              ),
              SizedBox(width: isCompact ? 12 : 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(request.title, style: AdminStyles.headingStyle(fontSize: isCompact ? 14 : 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    if (isCompact)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 12, color: AdminStyles.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(child: Text(request.roomName ?? 'Unknown Room', style: AdminStyles.bodyStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 12, color: AdminStyles.textSecondary),
                              const SizedBox(width: 4),
                              Text(DateFormat('MMM dd').format(request.dateSubmitted), style: AdminStyles.bodyStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: AdminStyles.textSecondary),
                          const SizedBox(width: 4),
                          Text(request.roomName ?? 'Unknown Room', style: AdminStyles.bodyStyle(fontSize: 13)),
                          const SizedBox(width: 16),
                          Icon(Icons.calendar_today_outlined, size: 14, color: AdminStyles.textSecondary),
                          const SizedBox(width: 4),
                          Text(DateFormat('MMM dd').format(request.dateSubmitted), style: AdminStyles.bodyStyle(fontSize: 13)),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusPill(request.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
}

class _StatCard extends StatefulWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});
  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: AdminStyles.cardDecoration(borderColor: _isHovered ? widget.color.withValues(alpha: 0.5) : null),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: AdminStyles.bodyStyle(fontWeight: FontWeight.bold, color: AdminStyles.textSecondary)),
                  const SizedBox(height: 8),
                  Text('${widget.value}', style: AdminStyles.headingStyle(fontSize: 32, color: widget.color)),
                ],
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(widget.icon, color: widget.color, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}

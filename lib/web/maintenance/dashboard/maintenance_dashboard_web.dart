import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/status_selector_widget.dart';
import '../../../shared/services/maintenance_account_service.dart';

class MaintenanceDashboardWeb extends StatefulWidget {
  const MaintenanceDashboardWeb({super.key});

  @override
  State<MaintenanceDashboardWeb> createState() => _MaintenanceDashboardWebState();
}

class _MaintenanceDashboardWebState extends State<MaintenanceDashboardWeb> {
  List<WorkRequest> _requests = [];
  String _currentStatus = 'offline';
  bool _isLoading = true;

  // Professional color palette
  static const Color _primaryBlue = Color(0xFF0EA5E9);
  static const Color _successGreen = Color(0xFF10B981);
  static const Color _warningOrange = Color(0xFFF59E0B);
  static const Color _dangerRed = Color(0xFFEF4444);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _subtleText = Color(0xFF64748B);
  static const Color _pageBg = Color(0xFFF8FAFC);
  static const Color _cardBg = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _loadStatus();
  }
  
  Future<void> _loadStatus() async {
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      try {
        final accounts = await MaintenanceAccountService.fetchCreatedByCurrentAdmin();
        final match = accounts.firstWhere((a) => a.userId == user.id);
        if (mounted) setState(() => _currentStatus = match.availabilityStatus);
      } catch (_) {}
    }
  }

  Future<void> _loadRequests() async {
    try {
      final user = context.read<AuthService>().currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _requests = [];
            _isLoading = false;
          });
        }
        return;
      }

      final data = await WorkRequestService.fetchAssignedTo(user.id);
      if (mounted) {
        setState(() {
          _requests = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int _getCountByStatus(String status) {
    return _requests.where((r) => r.status.toLowerCase() == status.toLowerCase()).length;
  }

  int _getCountByPriority(String priority) {
    return _requests.where((r) => r.priority.toLowerCase() == priority.toLowerCase()).length;
  }

  List<WorkRequest> _getLatestRequests({int limit = 6}) {
    return _requests.take(limit).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _getCountByStatus('pending');
    final inProgressCount = _getCountByStatus('in_progress');
    final completedCount = _getCountByStatus('completed');
    final highPriorityCount = _getCountByPriority('high');

    if (_isLoading) {
      return Container(
        color: _pageBg,
        child: const Center(
          child: CircularProgressIndicator(
            color: _primaryBlue,
            strokeWidth: 3,
          ),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 1024;
    final isMobile = width < 768;

    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 32,
          vertical: isMobile ? 16 : 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            _buildHeader(),
            SizedBox(height: isMobile ? 20 : 32),

            // Stat Cards Row
            _buildStatCardsRow(
              pendingCount,
              inProgressCount,
              highPriorityCount,
              completedCount,
              isMobile,
            ),
            SizedBox(height: isMobile ? 20 : 32),

            // Main Content Layout
            if (isCompact) ...[
              _buildQuickActionsCard(),
              const SizedBox(height: 24),
              _buildWorkStatusBreakdown(),
              const SizedBox(height: 24),
              _buildLatestRequestsCard(),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Stats & Quick Actions
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _buildQuickActionsCard(),
                        const SizedBox(height: 24),
                        _buildWorkStatusBreakdown(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Right Column: Latest Requests
                  Expanded(
                    flex: 7,
                    child: _buildLatestRequestsCard(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = context.read<AuthService>().currentUser;
    final userName = user?.name.split(' ').first ?? 'Maintenance';
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, $userName',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _darkText,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Track and manage all maintenance work requests.',
              style: TextStyle(
                fontSize: 15,
                color: _subtleText.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        StatusSelectorWidget(
          currentStatus: _currentStatus,
          onStatusChanged: (newStatus) {
            setState(() => _currentStatus = newStatus);
          },
        ),
      ],
    );
  }

  Widget _buildStatCardsRow(
    int pendingCount,
    int inProgressCount,
    int highPriorityCount,
    int completedCount,
    bool isMobile,
  ) {
    final cards = [
      _StatCard(
        title: 'Pending',
        value: pendingCount,
        icon: Icons.schedule_rounded,
        color: _warningOrange,
      ),
      _StatCard(
        title: 'In Progress',
        value: inProgressCount,
        icon: Icons.engineering_rounded,
        color: _primaryBlue,
      ),
      _StatCard(
        title: 'High Priority',
        value: highPriorityCount,
        icon: Icons.warning_amber_rounded,
        color: _dangerRed,
      ),
      _StatCard(
        title: 'Completed',
        value: completedCount,
        icon: Icons.check_circle_rounded,
        color: _successGreen,
      ),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.35,
        children: cards,
      );
    }

    return Row(
      children: [
        Expanded(
          child: cards[0],
        ),
        const SizedBox(width: 24),
        Expanded(
          child: cards[1],
        ),
        const SizedBox(width: 24),
        Expanded(
          child: cards[2],
        ),
        const SizedBox(width: 24),
        Expanded(
          child: cards[3],
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _darkText,
              ),
            ),
            const SizedBox(height: 24),
            _buildActionButton(
              icon: Icons.map_rounded,
              title: 'Maintenance Map',
              description: 'View facility layout & active tasks',
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              icon: Icons.assessment_rounded,
              title: 'Daily Report',
              description: 'Generate end-of-day summary',
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Generate QR',
              description: 'Create new facility codes',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title feature coming soon'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _pageBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: _primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _darkText,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: _subtleText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: _subtleText.withValues(alpha: 0.3),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkStatusBreakdown() {
    final total = _requests.length;
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _darkText,
              ),
            ),
            const SizedBox(height: 24),
            _buildStatusItem('Pending', _getCountByStatus('pending'), total, _warningOrange),
            const SizedBox(height: 20),
            _buildStatusItem('In Progress', _getCountByStatus('in_progress'), total, _primaryBlue),
            const SizedBox(height: 20),
            _buildStatusItem('Completed', _getCountByStatus('completed'), total, _successGreen),
            const SizedBox(height: 20),
            _buildStatusItem('Under Review', _getCountByStatus('under_maintenance'), total, _infoBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String status, int count, int total, Color color) {
    final double percentage = total > 0 ? count / total : 0.0;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _darkText,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLatestRequestsCard() {
    final latestRequests = _getLatestRequests(limit: 6);

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Work Requests',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _darkText,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('View all requests feature coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (latestRequests.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_rounded,
                        size: 48,
                        color: _subtleText.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No work requests',
                        style: TextStyle(
                          fontSize: 14,
                          color: _subtleText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: latestRequests.map((request) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RequestRow(
                      request: request,
                      statusColor: _getStatusColor(request.status),
                      priorityColor: _getPriorityColor(request.priority),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // Replaced by _RequestRow class below

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return _successGreen;
      case 'in_progress':
        return _primaryBlue;
      case 'pending':
        return _warningOrange;
      default:
        return _subtleText;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return _dangerRed;
      case 'medium':
        return _warningOrange;
      case 'low':
        return _successGreen;
      default:
        return _subtleText;
    }
  }
}

class _StatCard extends StatefulWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? widget.color.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
            width: _isHovered ? 1.5 : 1.0,
          ),
          gradient: _isHovered ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              widget.color.withValues(alpha: 0.05),
            ],
          ) : null,
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${widget.value}',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: widget.color,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: _isHovered ? 0.2 : 0.0),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.color,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Color constants for reference
const Color _infoBlue = Color(0xFF3B82F6);

class _RequestRow extends StatefulWidget {
  final WorkRequest request;
  final Color statusColor;
  final Color priorityColor;

  const _RequestRow({
    required this.request,
    required this.statusColor,
    required this.priorityColor,
  });

  @override
  State<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends State<_RequestRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isHovered ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered ? const Color(0xFF0EA5E9).withValues(alpha: 0.3) : Colors.transparent,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobileRow = constraints.maxWidth < 600;
            if (isMobileRow) {
              return _buildMobileLayout();
            }
            return _buildDesktopLayout();
          }
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildIcon(),
            const SizedBox(width: 12),
            Expanded(child: _buildDetails()),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildBadge(widget.request.priority, widget.priorityColor),
                const SizedBox(width: 8),
                _buildBadge(widget.request.status.replaceAll('_', ' '), widget.statusColor),
              ],
            ),
            if (_isHovered) _buildActionIcon(),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        _buildIcon(),
        const SizedBox(width: 16),
        Expanded(child: _buildDetails()),
        const SizedBox(width: 16),
        _buildBadge(widget.request.priority, widget.priorityColor),
        const SizedBox(width: 12),
        _buildBadge(widget.request.status.replaceAll('_', ' '), widget.statusColor),
        const SizedBox(width: 16),
        SizedBox(
          width: 40,
          child: _isHovered ? _buildActionIcon() : const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: widget.statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.build_circle_rounded,
        color: widget.statusColor,
        size: 24,
      ),
    );
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.request.roomName ?? 'Unknown Room',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          widget.request.typeOfRequest,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildActionIcon() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0EA5E9),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(6),
      child: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: Colors.white,
        size: 14,
      ),
    );
  }
}

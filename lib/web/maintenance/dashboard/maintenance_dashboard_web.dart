import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/status_selector_widget.dart';
import '../../../shared/services/maintenance_account_service.dart';
import '../maintenance_nav_controller.dart';

// ─── Design Tokens ─────────────────────────────────────────────────────────
const Color _blue = Color(0xFF0EA5E9);
const Color _green = Color(0xFF10B981);
const Color _orange = Color(0xFFF59E0B);
const Color _red = Color(0xFFEF4444);
const Color _indigo = Color(0xFF6366F1);
const Color _ink = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);
const Color _pageBg = Color(0xFFF1F5F9);
const Color _card = Colors.white;
const Color _border = Color(0xFFE2E8F0);

class MaintenanceDashboardWeb extends StatefulWidget {
  const MaintenanceDashboardWeb({super.key});

  @override
  State<MaintenanceDashboardWeb> createState() => _MaintenanceDashboardWebState();
}

class _MaintenanceDashboardWebState extends State<MaintenanceDashboardWeb> {
  List<WorkRequest> _requests = [];
  String _currentStatus = 'offline';
  bool _isLoading = true;

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
        final res = await Supabase.instance.client
            .from('maintenance_users')
            .select('availability_status')
            .eq('user_id', user.id)
            .maybeSingle();

        if (res != null && mounted) {
          setState(() => _currentStatus = res['availability_status'] ?? 'offline');
        }
      } catch (_) {}
    }
  }

  Future<void> _loadRequests() async {
    try {
      final user = context.read<AuthService>().currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final data = await WorkRequestService.fetchAssignedTo(user.id);
      if (mounted) setState(() { _requests = data; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _countByStatus(String s) => _requests.where((r) => r.status.toLowerCase() == s.toLowerCase()).length;
  int _countByPriority(String p) => _requests.where((r) => r.priority.toLowerCase() == p.toLowerCase()).length;
  List<WorkRequest> _latest({int limit = 6}) => _requests.take(limit).toList();

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: _pageBg,
        child: const Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 3)),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 1024;
    final isMobile = width < 768;

    final pending = _countByStatus('pending');
    final inProgress = _countByStatus('in_progress');
    final completed = _countByStatus('completed');
    final highPriority = _countByPriority('high');

    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: isMobile ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Welcome Banner ────────────────────────────────────────────
            _buildWelcomeBanner(isMobile),
            SizedBox(height: isMobile ? 20 : 28),

            // ── Stat Cards ────────────────────────────────────────────────
            _buildStatRow(pending, inProgress, highPriority, completed, isMobile),
            SizedBox(height: isMobile ? 20 : 28),

            // ── Main Content ──────────────────────────────────────────────
            if (isCompact) ...[
              _buildStatusBreakdownCard(),
              const SizedBox(height: 24),
              _buildRecentRequestsCard(),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: Column(
                    children: [
                      _buildQuickActionsCard(),
                      const SizedBox(height: 24),
                      _buildStatusBreakdownCard(),
                    ],
                  )),
                  const SizedBox(width: 28),
                  Expanded(flex: 7, child: _buildRecentRequestsCard()),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(bool isMobile) {
    final user = context.read<AuthService>().currentUser;
    final firstName = (user?.name ?? 'Maintenance').split(' ').first;
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bannerContent(greeting, firstName),
                const SizedBox(height: 16),
                StatusSelectorWidget(currentStatus: _currentStatus, onStatusChanged: (s) => setState(() => _currentStatus = s)),
              ],
            )
          : Row(
              children: [
                Expanded(child: _bannerContent(greeting, firstName)),
                StatusSelectorWidget(currentStatus: _currentStatus, onStatusChanged: (s) => setState(() => _currentStatus = s)),
              ],
            ),
    );
  }

  Widget _bannerContent(String greeting, String firstName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _blue.withValues(alpha: 0.4)),
          ),
          child: Text(
            'PSU MAINTENANCE PORTAL',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _blue, letterSpacing: 1.2),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '$greeting, $firstName 👋',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
        ),
        const SizedBox(height: 6),
        const Text(
          'Track and manage your assigned maintenance work requests.',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildStatRow(int pending, int inProgress, int highPriority, int completed, bool isMobile) {
    final cards = [
      _StatCard(title: 'Pending', value: pending, icon: Icons.schedule_rounded, color: _orange, subtitle: 'Awaiting action'),
      _StatCard(title: 'In Progress', value: inProgress, icon: Icons.engineering_rounded, color: _blue, subtitle: 'Active tasks'),
      _StatCard(title: 'High Priority', value: highPriority, icon: Icons.warning_amber_rounded, color: _red, subtitle: 'Urgent items'),
      _StatCard(title: 'Completed', value: completed, icon: Icons.check_circle_rounded, color: _green, subtitle: 'Resolved'),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: cards,
      );
    }

    return Row(
      children: cards.expand((c) => [Expanded(child: c), if (c != cards.last) const SizedBox(width: 16)]).toList(),
    );
  }

  Widget _buildQuickActionsCard() {
    return _DashCard(
      title: 'Quick Actions',
      child: Column(
        children: [
          _ActionTile(icon: Icons.map_rounded, title: 'Maintenance Map', subtitle: 'View facility layout & active tasks', color: _blue),
          const SizedBox(height: 10),
          _ActionTile(icon: Icons.assessment_rounded, title: 'Daily Report', subtitle: 'Generate end-of-day summary', color: _indigo),
          const SizedBox(height: 10),
          _ActionTile(icon: Icons.qr_code_scanner_rounded, title: 'Scan QR Code', subtitle: 'Identify room or equipment', color: _green),
        ],
      ),
    );
  }

  Widget _buildStatusBreakdownCard() {
    final total = _requests.length;
    return _DashCard(
      title: 'Status Overview',
      child: Column(
        children: [
          _buildProgressRow('Pending', _countByStatus('pending'), total, _orange),
          const SizedBox(height: 18),
          _buildProgressRow('In Progress', _countByStatus('in_progress'), total, _blue),
          const SizedBox(height: 18),
          _buildProgressRow('Under Review', _countByStatus('under_maintenance'), total, _indigo),
          const SizedBox(height: 18),
          _buildProgressRow('Completed', _countByStatus('completed'), total, _green),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)])),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentRequestsCard() {
    final latest = _latest(limit: 6);
    return _DashCard(
      title: 'Recent Work Requests',
      trailing: TextButton(
        onPressed: () => MaintenanceNavController.of(context)?.navigateTo(1),
        child: const Text('View All →', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _blue)),
      ),
      child: latest.isEmpty
          ? const _EmptyState(icon: Icons.inbox_rounded, message: 'No work requests assigned')
          : Column(
              children: latest.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => MaintenanceNavController.of(context)?.navigateTo(0, request: r),
                  child: _RequestRow(request: r),
                ),
              )).toList(),
            ),
    );
  }
}

// ─── Shared Dash Card ─────────────────────────────────────────────────────────
class _DashCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _DashCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
                ?trailing,
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.subtitle, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _muted)),
                const SizedBox(height: 8),
                Text('$value', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: color, letterSpacing: -1)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: _muted)),
              ],
            ),
          ),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ],
      ),
    );
  }
}

// ─── Action Tile ─────────────────────────────────────────────────────────────
class _ActionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.color});

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _hovered ? widget.color.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _hovered ? widget.color.withValues(alpha: 0.3) : Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(widget.icon, color: widget.color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                Text(widget.subtitle, style: const TextStyle(fontSize: 11, color: _muted)),
              ]),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _hovered ? 1.0 : 0.3,
              child: Icon(Icons.arrow_forward_rounded, color: widget.color, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Request Row ─────────────────────────────────────────────────────────────
class _RequestRow extends StatefulWidget {
  final WorkRequest request;

  const _RequestRow({required this.request});

  @override
  State<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends State<_RequestRow> {
  bool _hovered = false;

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return _green;
      case 'in_progress': return _blue;
      case 'pending': return _orange;
      default: return _muted;
    }
  }

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high': return _red;
      case 'medium': return _orange;
      default: return _green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(widget.request.status);
    final pc = _priorityColor(widget.request.priority);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _hovered ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _hovered ? _blue.withValues(alpha: 0.3) : Colors.transparent),
          boxShadow: _hovered
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.build_circle_rounded, color: sc, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.request.roomName ?? 'Unknown Room',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(widget.request.typeOfRequest,
                    style: const TextStyle(fontSize: 12, color: _muted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(width: 12),
            _Pill(widget.request.priority, pc),
            const SizedBox(width: 8),
            _Pill(widget.request.status.replaceAll('_', ' '), sc),
            const SizedBox(width: 8),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _hovered ? 1.0 : 0.0,
              child: Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.3)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: _muted.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(fontSize: 14, color: _muted, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

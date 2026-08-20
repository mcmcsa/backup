import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../authentication/models/user_model.dart';
import '../../../shared/models/building_model.dart';
import '../../../shared/models/room_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/building_service.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../shared/services/qr_code_history_service.dart';
import '../../../shared/services/room_service.dart';
import '../../../shared/services/system_admin_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../admin/shared/admin_styles.dart';

// ---------------------------------------------------------------------------
// Data bundle loaded once on init
// ---------------------------------------------------------------------------
class _DashboardData {
  final List<AppUser> users;
  final List<Building> buildings;
  final List<Room> rooms;
  final List<WorkRequest> requests;
  final int qrCount;
  final List<LoginActivity> recentActivity;

  const _DashboardData({
    required this.users,
    required this.buildings,
    required this.rooms,
    required this.requests,
    required this.qrCount,
    required this.recentActivity,
  });
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------
class SystemAdminDashboardView extends StatefulWidget {
  /// Called when the user taps "Create User" quick action.
  final VoidCallback? onCreateUser;

  const SystemAdminDashboardView({super.key, this.onCreateUser});

  @override
  State<SystemAdminDashboardView> createState() =>
      _SystemAdminDashboardViewState();
}

class _SystemAdminDashboardViewState extends State<SystemAdminDashboardView>
    with SingleTickerProviderStateMixin {
  _DashboardData? _data;
  String? _error;
  bool _loading = true;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        SystemAdminService.fetchAllUsers(),
        BuildingService.fetchAll(),
        RoomService.fetchAll(),
        WorkRequestService.fetchAll(),
        QRCodeHistoryService.getHistoryCount(),
        LoginActivityService.fetchAdminLogs(),
      ]);

      if (!mounted) return;
      setState(() {
        _data = _DashboardData(
          users: results[0] as List<AppUser>,
          buildings: results[1] as List<Building>,
          rooms: results[2] as List<Room>,
          requests: results[3] as List<WorkRequest>,
          qrCount: results[4] as int,
          recentActivity: (results[5] as List<LoginActivity>).take(12).toList(),
        );
        _loading = false;
      });
      _fadeCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Derived stats ─────────────────────────────────────────────────────────

  int get _totalUsers => _data!.users.length;
  int get _activeUsers => _data!.users.where((u) => u.isActive).length;
  int get _facultyCount =>
      _data!.users.where((u) => u.role == UserRole.teacher).length;
  int get _maintenanceCount =>
      _data!.users.where((u) => u.role == UserRole.maintenance).length;
  int get _campAdminCount =>
      _data!.users.where((u) => u.role == UserRole.campadmin).length;
  int get _totalBuildings => _data!.buildings.length;
  int get _totalRooms => _data!.rooms.length;
  int get _totalRequests => _data!.requests.length;
  int get _pendingCount =>
      _data!.requests.where((r) => r.status == 'pending').length;
  int get _approvedCount =>
      _data!.requests.where((r) => r.status == 'approved').length;
  int get _completedCount =>
      _data!.requests.where((r) => r.status == 'completed').length;

  /// Returns map of month-label → count for last 6 months.
  Map<String, int> get _requestsPerMonth {
    final now = DateTime.now();
    final result = <String, int>{};
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    for (int i = 5; i >= 0; i--) {
      final dt = DateTime(now.year, now.month - i, 1);
      final label = months[dt.month - 1];
      result[label] = _data!.requests
          .where((r) =>
              r.dateSubmitted.year == dt.year &&
              r.dateSubmitted.month == dt.month)
          .length;
    }
    return result;
  }

  /// Returns map of category → count (top 5).
  Map<String, int> get _byCategory {
    final map = <String, int>{};
    for (final r in _data!.requests) {
      final key = r.typeOfRequest.isNotEmpty ? r.typeOfRequest : 'Other';
      map[key] = (map[key] ?? 0) + 1;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(5));
  }

  /// Returns map of buildingName → count (top 5).
  Map<String, int> get _topBuildings {
    final map = <String, int>{};
    for (final r in _data!.requests) {
      final key = r.buildingName ?? 'Unknown';
      map[key] = (map[key] ?? 0) + 1;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(5));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isMobile = constraints.maxWidth < 800;
        return FadeTransition(
          opacity: _fadeAnim,
          child: Container(
            color: AdminStyles.bg,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 32,
                vertical: isMobile ? 16 : 28,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isMobile),
                    const SizedBox(height: 24),
                    _buildQuickActions(isMobile),
                    const SizedBox(height: 28),
                    _buildSectionLabel('User Overview'),
                    const SizedBox(height: 14),
                    _buildUserCards(isMobile),
                    const SizedBox(height: 28),
                    _buildSectionLabel('Facilities Overview'),
                    const SizedBox(height: 14),
                    _buildFacilityCards(isMobile),
                    const SizedBox(height: 28),
                    _buildSectionLabel('Maintenance Requests'),
                    const SizedBox(height: 14),
                    _buildRequestCards(isMobile),
                    const SizedBox(height: 28),
                    _buildSectionLabel('Analytics'),
                    const SizedBox(height: 14),
                    isMobile
                        ? _buildChartsColumn()
                        : _buildChartsRow(),
                    const SizedBox(height: 28),
                    _buildSectionLabel('Activity Feed'),
                    const SizedBox(height: 14),
                    _buildActivityFeed(isMobile),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── States ────────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return Container(
      color: AdminStyles.bg,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AdminStyles.primary, strokeWidth: 3),
            SizedBox(height: 20),
            Text(
              'Loading system dashboard…',
              style: TextStyle(
                color: AdminStyles.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: AdminStyles.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AdminStyles.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    size: 40, color: AdminStyles.error),
              ),
              const SizedBox(height: 24),
              Text(
                'Dashboard Unavailable',
                style: AdminStyles.headingStyle(fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text(
                'Unable to load system data. Please check your connection.',
                style: AdminStyles.bodyStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminStyles.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isMobile) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF134E4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AdminStyles.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 48 : 60,
            height: isMobile ? 48 : 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AdminStyles.primary, AdminStyles.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.shield_rounded,
                color: Colors.white, size: isMobile ? 24 : 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, System Admin',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'System Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 20 : 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pangasinan State University — Maintenance Management',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: isMobile ? 11 : 13,
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 16),
            _buildLiveIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AdminStyles.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AdminStyles.success.withValues(alpha: 0.5),
                    blurRadius: 6)
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'System Online',
            style: TextStyle(
                color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions(bool isMobile) {
    final actions = [
      _QuickAction(
        icon: Icons.person_add_alt_1_rounded,
        label: 'Create User',
        color: AdminStyles.primary,
        onTap: widget.onCreateUser ?? () {},
      ),
      _QuickAction(
        icon: Icons.business_rounded,
        label: 'Add Department',
        color: AdminStyles.secondary,
        onTap: () => _snack('Department management coming soon'),
      ),
      _QuickAction(
        icon: Icons.qr_code_2_rounded,
        label: 'Generate QR',
        color: Colors.purple,
        onTap: () => _snack('QR generation available in the Rooms section'),
      ),
      _QuickAction(
        icon: Icons.backup_rounded,
        label: 'Backup Data',
        color: AdminStyles.warning,
        onTap: () => _snack('Database backup feature coming soon'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Quick Actions'),
        const SizedBox(height: 14),
        isMobile
            ? GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.6,
                children: actions.map(_buildQuickActionTile).toList(),
              )
            : Row(
                children: actions
                    .map((a) => Expanded(child: _buildQuickActionTile(a)))
                    .toList()
                    .expand((w) => [w, const SizedBox(width: 12)])
                    .toList()
                  ..removeLast(),
              ),
      ],
    );
  }

  Widget _buildQuickActionTile(_QuickAction action) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AdminStyles.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: action.color, size: 18),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  action.label,
                  style: AdminStyles.bodyStyle(
                    fontWeight: FontWeight.w700,
                    color: AdminStyles.textPrimary,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section Label ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AdminStyles.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: AdminStyles.headingStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  // ── Stat Cards ────────────────────────────────────────────────────────────

  Widget _buildUserCards(bool isMobile) {
    return _buildCardGrid(isMobile, [
      _StatCard(
        label: 'Total Users',
        value: _totalUsers,
        icon: Icons.people_alt_rounded,
        color: AdminStyles.primary,
        subtitle: '$_activeUsers active',
      ),
      _StatCard(
        label: 'Faculty Accounts',
        value: _facultyCount,
        icon: Icons.school_rounded,
        color: AdminStyles.secondary,
        subtitle: 'Teaching staff',
      ),
      _StatCard(
        label: 'Maintenance Staff',
        value: _maintenanceCount,
        icon: Icons.handyman_rounded,
        color: Colors.deepPurple,
        subtitle: 'Field personnel',
      ),
      _StatCard(
        label: 'Campus Admins',
        value: _campAdminCount,
        icon: Icons.admin_panel_settings_rounded,
        color: AdminStyles.warning,
        subtitle: 'Admin accounts',
      ),
    ]);
  }

  Widget _buildFacilityCards(bool isMobile) {
    return _buildCardGrid(isMobile, [
      _StatCard(
        label: 'Total Buildings',
        value: _totalBuildings,
        icon: Icons.apartment_rounded,
        color: const Color(0xFF7C3AED),
        subtitle: 'Campus facilities',
      ),
      _StatCard(
        label: 'Total Rooms',
        value: _totalRooms,
        icon: Icons.meeting_room_rounded,
        color: const Color(0xFF0369A1),
        subtitle: 'Registered rooms',
      ),
      _StatCard(
        label: 'Active QR Codes',
        value: _data!.qrCount,
        icon: Icons.qr_code_2_rounded,
        color: const Color(0xFF059669),
        subtitle: 'Deployed codes',
      ),
      _StatCard(
        label: 'Departments',
        value: _data!.buildings
            .map((b) => b.departmentId)
            .whereType<String>()
            .toSet()
            .length,
        icon: Icons.business_rounded,
        color: const Color(0xFFB45309),
        subtitle: 'Academic units',
      ),
    ]);
  }

  Widget _buildRequestCards(bool isMobile) {
    return _buildCardGrid(isMobile, [
      _StatCard(
        label: 'Total Requests',
        value: _totalRequests,
        icon: Icons.assignment_rounded,
        color: AdminStyles.textPrimary,
        subtitle: 'All time',
      ),
      _StatCard(
        label: 'Pending',
        value: _pendingCount,
        icon: Icons.hourglass_top_rounded,
        color: AdminStyles.warning,
        subtitle: 'Awaiting action',
        isPulse: _pendingCount > 0,
      ),
      _StatCard(
        label: 'Approved',
        value: _approvedCount,
        icon: Icons.check_circle_outline_rounded,
        color: AdminStyles.info,
        subtitle: 'In progress',
      ),
      _StatCard(
        label: 'Completed',
        value: _completedCount,
        icon: Icons.task_alt_rounded,
        color: AdminStyles.success,
        subtitle: 'Resolved',
      ),
    ]);
  }

  Widget _buildCardGrid(bool isMobile, List<_StatCard> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < 550) {
          return GridView.count(
            crossAxisCount: 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 3.5,
            children: cards.map(_buildStatCardWidget).toList(),
          );
        } else if (width < 800) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: cards.map(_buildStatCardWidget).toList(),
          );
        }
        return Row(
          children: cards
              .map((c) => Expanded(child: _buildStatCardWidget(c)))
              .toList()
              .expand((w) => [w, const SizedBox(width: 14)])
              .toList()
            ..removeLast(),
        );
      }
    );
  }

  Widget _buildStatCardWidget(_StatCard card) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: card.isPulse
              ? card.color.withValues(alpha: 0.4)
              : AdminStyles.border,
          width: card.isPulse ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: card.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(card.icon, color: card.color, size: 20),
              ),
              if (card.isPulse)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: card.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: card.color.withValues(alpha: 0.5),
                        blurRadius: 6,
                      )
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${card.value}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: card.color,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            card.label,
            style: AdminStyles.bodyStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AdminStyles.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            card.subtitle,
            style: AdminStyles.bodyStyle(
              fontSize: 11,
              color: AdminStyles.textMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Charts ────────────────────────────────────────────────────────────────

  Widget _buildChartsRow() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: _buildMonthlyChart()),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: _buildCategoryChart()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: _buildRoleDonut()),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: _buildTopBuildingsChart()),
          ],
        ),
      ],
    );
  }

  Widget _buildChartsColumn() {
    return Column(
      children: [
        _buildMonthlyChart(),
        const SizedBox(height: 16),
        _buildCategoryChart(),
        const SizedBox(height: 16),
        _buildRoleDonut(),
        const SizedBox(height: 16),
        _buildTopBuildingsChart(),
      ],
    );
  }

  // Requests per Month bar chart
  Widget _buildMonthlyChart() {
    final data = _requestsPerMonth;
    final maxVal = data.values.isEmpty ? 1 : data.values.reduce(math.max);

    return _ChartCard(
      title: 'Requests per Month',
      icon: Icons.bar_chart_rounded,
      child: data.isEmpty
          ? _emptyChart('No request data')
          : Column(
              children: [
                SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: data.entries.map((e) {
                      final ratio = maxVal == 0 ? 0.0 : e.value / maxVal;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (e.value > 0)
                                Text(
                                  '${e.value}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AdminStyles.textPrimary,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 800),
                                height: 120 * ratio,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AdminStyles.primary,
                                      AdminStyles.primaryLight,
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: data.keys
                      .map(
                        (k) => Expanded(
                          child: Text(
                            k,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AdminStyles.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
    );
  }

  // Requests by Category horizontal bars
  Widget _buildCategoryChart() {
    final data = _byCategory;
    final maxVal = data.values.isEmpty ? 1 : data.values.reduce(math.max);
    final colors = [
      AdminStyles.primary,
      AdminStyles.secondary,
      Colors.deepPurple,
      AdminStyles.warning,
      AdminStyles.success,
    ];

    return _ChartCard(
      title: 'Requests by Category',
      icon: Icons.pie_chart_outline_rounded,
      child: data.isEmpty
          ? _emptyChart('No category data')
          : Column(
              children: data.entries.indexed.map((entry) {
                final i = entry.$1;
                final e = entry.$2;
                final ratio = maxVal == 0 ? 0.0 : e.value / maxVal;
                final color = colors[i % colors.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              e.key,
                              style: AdminStyles.bodyStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AdminStyles.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${e.value}',
                            style: AdminStyles.bodyStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor: color.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // Users by Role donut-style breakdown
  Widget _buildRoleDonut() {
    final roles = [
      _RoleItem('Faculty', _facultyCount, AdminStyles.secondary),
      _RoleItem('Maintenance', _maintenanceCount, Colors.deepPurple),
      _RoleItem('Campus Admin', _campAdminCount, AdminStyles.warning),
      _RoleItem('System Admin',
          _data!.users.where((u) => u.role == UserRole.admin).length,
          AdminStyles.error),
    ];
    final total = roles.fold(0, (s, r) => s + r.count);

    return _ChartCard(
      title: 'Users by Role',
      icon: Icons.donut_large_rounded,
      child: total == 0
          ? _emptyChart('No users found')
          : Column(
              children: [
                SizedBox(
                  height: 120,
                  child: CustomPaint(
                    painter: _DonutPainter(roles, total),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$total',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AdminStyles.textPrimary,
                            ),
                          ),
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 11,
                              color: AdminStyles.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ...roles.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: r.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r.label,
                              style: AdminStyles.bodyStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            total > 0
                                ? '${(r.count / total * 100).toStringAsFixed(0)}%'
                                : '0%',
                            style: AdminStyles.bodyStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: r.color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${r.count}',
                            style: AdminStyles.bodyStyle(
                              fontSize: 12,
                              color: AdminStyles.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
    );
  }

  // Top Reported Buildings
  Widget _buildTopBuildingsChart() {
    final data = _topBuildings;
    final maxVal = data.values.isEmpty ? 1 : data.values.reduce(math.max);
    final colors = [
      AdminStyles.primary,
      AdminStyles.secondary,
      Colors.deepPurple,
      AdminStyles.warning,
      AdminStyles.success,
    ];

    return _ChartCard(
      title: 'Top Reported Buildings',
      icon: Icons.apartment_rounded,
      child: data.isEmpty
          ? _emptyChart('No building data')
          : Column(
              children: data.entries.indexed.map((entry) {
                final i = entry.$1;
                final e = entry.$2;
                final ratio = maxVal == 0 ? 0.0 : e.value / maxVal;
                final color = colors[i % colors.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              e.key,
                              style: AdminStyles.bodyStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AdminStyles.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${e.value} requests',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor: color.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _emptyChart(String msg) {
    return SizedBox(
      height: 100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart_rounded,
                size: 32, color: AdminStyles.textMuted),
            const SizedBox(height: 8),
            Text(msg, style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
          ],
        ),
      ),
    );
  }

  // ── Activity Feed ─────────────────────────────────────────────────────────

  Widget _buildActivityFeed(bool isMobile) {
    final activities = _data!.recentActivity;

    return Container(
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                const Icon(Icons.timeline_rounded,
                    size: 20, color: AdminStyles.primary),
                const SizedBox(width: 10),
                Text(
                  'Recent Activity',
                  style: AdminStyles.headingStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AdminStyles.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${activities.length} entries',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AdminStyles.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.history, size: 40, color: AdminStyles.textMuted),
                    const SizedBox(height: 12),
                    Text('No recent activity',
                        style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
                  ],
                ),
              ),
            )
          else
            ...activities.asMap().entries.map((entry) {
              final i = entry.key;
              final log = entry.value;
              return _buildActivityItem(log, i == activities.length - 1);
            }),
        ],
      ),
    );
  }

  Widget _buildActivityItem(LoginActivity log, bool isLast) {
    final isLogin = log.eventType == 'login';
    final color = isLogin ? AdminStyles.primary : AdminStyles.info;
    final icon = isLogin ? Icons.login_rounded : Icons.bolt_rounded;

    final roleLabel = log.role == 'admin'
        ? 'System Admin'
        : log.role == 'campadmin'
            ? 'Campus Admin'
            : log.role.substring(0, 1).toUpperCase() + log.role.substring(1);

    final elapsed = DateTime.now().difference(log.loggedInAt);
    final timeAgo = elapsed.inMinutes < 60
        ? '${elapsed.inMinutes}m ago'
        : elapsed.inHours < 24
            ? '${elapsed.inHours}h ago'
            : '${elapsed.inDays}d ago';

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                    color: AdminStyles.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.title,
                  style: AdminStyles.bodyStyle(
                    fontWeight: FontWeight.w700,
                    color: AdminStyles.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${log.userName} · $roleLabel',
                  style: AdminStyles.bodyStyle(fontSize: 12),
                ),
                if (log.details != null && log.details!.isNotEmpty)
                  Text(
                    log.details!,
                    style: AdminStyles.bodyStyle(
                        fontSize: 11, color: AdminStyles.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeAgo,
            style: AdminStyles.bodyStyle(
                fontSize: 11, color: AdminStyles.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private data models
// ---------------------------------------------------------------------------
class _StatCard {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String subtitle;
  final bool isPulse;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
    this.isPulse = false,
  });
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _RoleItem {
  final String label;
  final int count;
  final Color color;

  const _RoleItem(this.label, this.count, this.color);
}

// ---------------------------------------------------------------------------
// Chart card wrapper
// ---------------------------------------------------------------------------
class _ChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AdminStyles.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: AdminStyles.headingStyle(
                    fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom donut painter
// ---------------------------------------------------------------------------
class _DonutPainter extends CustomPainter {
  final List<_RoleItem> roles;
  final int total;

  _DonutPainter(this.roles, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const strokeWidth = 22.0;

    var startAngle = -math.pi / 2;
    for (final role in roles) {
      if (role.count == 0) continue;
      final sweep = (role.count / total) * 2 * math.pi;
      final paint = Paint()
        ..color = role.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + 0.04,
        sweep - 0.08,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// Extension for indexed iteration
// ---------------------------------------------------------------------------
extension _Indexed<T> on Iterable<T> {
  Iterable<(int, T)> get indexed sync* {
    var i = 0;
    for (final item in this) {
      yield (i++, item);
    }
  }
}

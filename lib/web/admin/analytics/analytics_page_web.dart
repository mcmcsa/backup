import 'package:flutter/material.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/models/room_model.dart';
import '../../../shared/services/room_service.dart';
import 'dart:math' as math;
import '../shared/admin_styles.dart';

class AnalyticsPageWeb extends StatefulWidget {
  const AnalyticsPageWeb({super.key});

  @override
  State<AnalyticsPageWeb> createState() => _AnalyticsPageWebState();
}

class _AnalyticsPageWebState extends State<AnalyticsPageWeb> {
  List<WorkRequest> _requests = [];
  List<Room> _rooms = [];
  bool _isLoading = true;
  String _selectedPeriod = 'This Month';

  // Professional color palette mapping
  static const Color _primaryBlue = AdminStyles.primary;
  static const Color _successGreen = AdminStyles.success;
  static const Color _warningYellow = AdminStyles.warning;
  static const Color _dangerRed = AdminStyles.error;
  static const Color _darkText = AdminStyles.textPrimary;
  static const Color _subtleText = AdminStyles.textSecondary;
  static const Color _pageBg = AdminStyles.bg;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final requests = await WorkRequestService.fetchAll();
      final rooms = await RoomService.fetchAll();
      if (mounted) {
        setState(() {
          _requests = requests;
          _rooms = rooms;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int get _totalRequests => _requests.length;
  int get _completedRequests => _requests.where((r) => r.status.toLowerCase() == 'completed').length;
  int get _pendingRequests => _requests.where((r) => r.status.toLowerCase() == 'pending').length;
  int get _activeRequests => _requests.where((r) {
    final s = r.status.toLowerCase();
    return s == 'in progress' || s == 'confirmed' || s == 'rework';
  }).length;
  int get _highPriority => _requests.where((r) => r.priority.toLowerCase() == 'high').length;
  double get _completionRate => _totalRequests > 0 ? (_completedRequests / _totalRequests * 100) : 0;

  DateTime _periodStart(DateTime now) {
    switch (_selectedPeriod) {
      case 'Today':
        return DateTime(now.year, now.month, now.day);
      case 'This Week':
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
      case 'This Year':
        return DateTime(now.year, 1, 1);
      case 'This Month':
      default:
        return DateTime(now.year, now.month, 1);
    }
  }

  DateTime _previousPeriodStart(DateTime now) {
    final start = _periodStart(now);
    switch (_selectedPeriod) {
      case 'Today':
        return start.subtract(const Duration(days: 1));
      case 'This Week':
        return start.subtract(const Duration(days: 7));
      case 'This Year':
        return DateTime(start.year - 1, 1, 1);
      case 'This Month':
      default:
        return DateTime(start.year, start.month - 1, 1);
    }
  }

  DateTime _previousPeriodEnd(DateTime now) {
    return _periodStart(now).subtract(const Duration(milliseconds: 1));
  }

  DateTime _currentPeriodEnd(DateTime now) {
    switch (_selectedPeriod) {
      case 'Today':
        return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      case 'This Week':
        return _periodStart(now)
            .add(const Duration(days: 7))
            .subtract(const Duration(milliseconds: 1));
      case 'This Year':
        return DateTime(now.year + 1, 1, 1)
            .subtract(const Duration(milliseconds: 1));
      case 'This Month':
      default:
        return DateTime(now.year, now.month + 1, 1)
            .subtract(const Duration(milliseconds: 1));
    }
  }

  int _countInRange(
    DateTime start,
    DateTime end,
    bool Function(WorkRequest request) predicate,
  ) {
    return _requests.where((request) {
      final submitted = request.dateSubmitted;
      return !submitted.isBefore(start) &&
          !submitted.isAfter(end) &&
          predicate(request);
    }).length;
  }

  double _trendPercent(int current, int previous) {
    if (previous == 0) return current > 0 ? 100 : 0;
    return ((current - previous) / previous) * 100;
  }

  List<double> _buildDailySubmissionSeries() {
    final now = DateTime.now();
    final days = List<DateTime>.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      return DateTime(day.year, day.month, day.day);
    });

    return days.map((day) {
      final nextDay = day.add(const Duration(days: 1));
      return _requests.where((request) {
        return !request.dateSubmitted.isBefore(day) &&
            request.dateSubmitted.isBefore(nextDay);
      }).length.toDouble();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _pageBg,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 900;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with period selector
                      _buildHeader(isMobile),
                      const SizedBox(height: 24),

                      // Stats Cards Row
                      _buildStatsRow(isMobile),
                      const SizedBox(height: 24),

                      // Charts Row
                      if (isMobile)
                        Column(
                          children: [
                            _buildPerformanceCard(),
                            const SizedBox(height: 20),
                            _buildStatusDistributionCard(),
                            const SizedBox(height: 20),
                            _buildPriorityCard(),
                            const SizedBox(height: 20),
                            _buildRoomStatsCard(),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column - Performance & Status
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  _buildPerformanceCard(),
                                  const SizedBox(height: 20),
                                  _buildStatusDistributionCard(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            // Right Column - Priority & Rooms
                            Expanded(
                              flex: 3,
                              child: Column(
                                children: [
                                  _buildPriorityCard(),
                                  const SizedBox(height: 20),
                                  _buildRoomStatsCard(),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return isMobile 
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bar_chart_rounded, color: _primaryBlue, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analytics Dashboard',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _darkText, letterSpacing: -0.5),
                    ),
                    Text(
                      'Performance metrics',
                      style: TextStyle(fontSize: 14, color: _subtleText, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPeriodSelector(),
          ],
        )
      : Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bar_chart_rounded, color: _primaryBlue, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analytics Dashboard',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _darkText, letterSpacing: -0.5),
                ),
                Text(
                  'Performance metrics and insights',
                  style: TextStyle(fontSize: 14, color: _subtleText, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Spacer(),
            _buildPeriodSelector(),
          ],
        );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeriod,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _subtleText),
          items: ['Today', 'This Week', 'This Month', 'This Year']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedPeriod = value);
          },
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _darkText),
        ),
      ),
    );
  }

  Widget _buildStatsRow(bool isMobile) {
    final now = DateTime.now();
    final currentStart = _periodStart(now);
    final currentEnd = _currentPeriodEnd(now);
    final previousStart = _previousPeriodStart(now);
    final previousEnd = _previousPeriodEnd(now);

    final currentTotal = _countInRange(currentStart, currentEnd, (_) => true);
    final previousTotal = _countInRange(previousStart, previousEnd, (_) => true);
    final totalTrend = _trendPercent(currentTotal, previousTotal);

    final currentPending = _countInRange(
      currentStart,
      currentEnd,
      (request) => request.status.toLowerCase() == 'pending',
    );
    final previousPending = _countInRange(
      previousStart,
      previousEnd,
      (request) => request.status.toLowerCase() == 'pending',
    );
    final pendingTrend = _trendPercent(currentPending, previousPending);

    final currentHighPriority = _countInRange(
      currentStart,
      currentEnd,
      (request) => request.priority.toLowerCase() == 'high',
    );
    final previousHighPriority = _countInRange(
      previousStart,
      previousEnd,
      (request) => request.priority.toLowerCase() == 'high',
    );
    final highPriorityTrend = _trendPercent(currentHighPriority, previousHighPriority);

    final currentCompleted = _countInRange(
      currentStart,
      currentEnd,
      (request) => request.status.toLowerCase() == 'completed',
    );
    final previousCompleted = _countInRange(
      previousStart,
      previousEnd,
      (request) => request.status.toLowerCase() == 'completed',
    );
    final currentCompletionRate = currentTotal == 0 ? 0 : (currentCompleted / currentTotal) * 100;
    final previousCompletionRate = previousTotal == 0 ? 0 : (previousCompleted / previousTotal) * 100;
    final completionRateTrend = currentCompletionRate - previousCompletionRate;

    final cards = [
      _StatCard(
        title: 'Total Requests',
        value: '$_totalRequests',
        icon: Icons.description_rounded,
        iconColor: _primaryBlue,
        trend: '${totalTrend >= 0 ? '+' : ''}${totalTrend.toStringAsFixed(1)}%',
        trendUp: totalTrend >= 0,
      ),
      _StatCard(
        title: 'Completion Rate',
        value: '${_completionRate.toStringAsFixed(1)}%',
        icon: Icons.check_circle_rounded,
        iconColor: _successGreen,
        trend: '${completionRateTrend >= 0 ? '+' : ''}${completionRateTrend.toStringAsFixed(1)}%',
        trendUp: completionRateTrend >= 0,
      ),
      _StatCard(
        title: 'Pending',
        value: '$_pendingRequests',
        icon: Icons.hourglass_empty_rounded,
        iconColor: _warningYellow,
        trend: '${pendingTrend >= 0 ? '+' : ''}${pendingTrend.toStringAsFixed(1)}%',
        trendUp: pendingTrend <= 0,
      ),
      _StatCard(
        title: 'High Priority',
        value: '$_highPriority',
        icon: Icons.priority_high_rounded,
        iconColor: _dangerRed,
        trend: '${highPriorityTrend >= 0 ? '+' : ''}${highPriorityTrend.toStringAsFixed(1)}%',
        trendUp: highPriorityTrend <= 0,
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards.expand((card) => [card, const SizedBox(height: 16)]).toList()..removeLast(),
      );
    }

    return Row(
      children: cards.expand((card) => [Expanded(child: card), const SizedBox(width: 16)]).toList()..removeLast(),
    );
  }

  Widget _buildPerformanceCard() {
    final chartData = _buildDailySubmissionSeries();

    return _Card(
      title: 'Performance Overview',
      icon: Icons.trending_up_rounded,
      child: SizedBox(
        height: 200,
        child: CustomPaint(
          size: const Size(double.infinity, 200),
          painter: _LineChartPainter(
            data: chartData,
            color: _primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDistributionCard() {
    return _Card(
      title: 'Request Status',
      icon: Icons.pie_chart_rounded,
      child: Row(
        children: [
          // Chart
          SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(
              painter: _DonutChartPainter(
                completed: _completedRequests.toDouble(),
                active: _activeRequests.toDouble(),
                pending: _pendingRequests.toDouble(),
              ),
            ),
          ),
          const SizedBox(width: 32),
          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LegendItem(color: _successGreen, label: 'Completed', value: _completedRequests),
                const SizedBox(height: 12),
                _LegendItem(color: _primaryBlue, label: 'Active', value: _activeRequests),
                const SizedBox(height: 12),
                _LegendItem(color: _warningYellow, label: 'Pending', value: _pendingRequests),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityCard() {
    final high = _requests.where((r) => r.priority.toLowerCase() == 'high').length;
    final medium = _requests.where((r) => r.priority.toLowerCase() == 'medium').length;
    final low = _requests.where((r) => r.priority.toLowerCase() == 'low').length;
    final total = high + medium + low;

    return _Card(
      title: 'Priority Distribution',
      icon: Icons.flag_rounded,
      child: Column(
        children: [
          _PriorityBar(label: 'High', value: high, total: total, color: _dangerRed),
          const SizedBox(height: 16),
          _PriorityBar(label: 'Medium', value: medium, total: total, color: _warningYellow),
          const SizedBox(height: 16),
          _PriorityBar(label: 'Low', value: low, total: total, color: _successGreen),
        ],
      ),
    );
  }

  Widget _buildRoomStatsCard() {
    final available = _rooms.where((r) => r.status.toLowerCase() == 'available').length;
    final reserved = _rooms.where((r) => r.status.toLowerCase() == 'reserved').length;
    final maintenance = _rooms.where((r) => r.status.toLowerCase() == 'maintenance').length;

    return _Card(
      title: 'Room Status',
      icon: Icons.meeting_room_rounded,
      child: Column(
        children: [
          _RoomStatRow(icon: Icons.check_circle_rounded, color: _successGreen, label: 'Available', value: available),
          const SizedBox(height: 14),
          _RoomStatRow(icon: Icons.event_busy_rounded, color: _warningYellow, label: 'Reserved', value: reserved),
          const SizedBox(height: 14),
          _RoomStatRow(icon: Icons.build_rounded, color: _dangerRed, label: 'Maintenance', value: maintenance),
        ],
      ),
    );
  }
}

// ==================== WIDGETS ====================

class _StatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String trend;
  final bool trendUp;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.trend,
    required this.trendUp,
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
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(20),
        transform: Matrix4.identity()..setTranslationRaw(0.0, _isHovered ? -2.0 : 0.0, 0.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? widget.iconColor.withValues(alpha: 0.5) : AdminStyles.border,
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? widget.iconColor.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 6 : 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.value,
                    style: AdminStyles.headingStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AdminStyles.textPrimary,
                    ),
                  ),
                  Text(
                    widget.title,
                    style: AdminStyles.bodyStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AdminStyles.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: widget.trendUp
                    ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                    : const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.trendUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    size: 14,
                    color: widget.trendUp ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.trend,
                    style: AdminStyles.dataStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.trendUp ? AdminStyles.success : AdminStyles.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Card({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF3B82F6), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: AdminStyles.headingStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AdminStyles.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _LegendItem({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)))),
        Text(
          '$value',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }
}

class _PriorityBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _PriorityBar({required this.label, required this.value, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? value / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            Text('$value', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage,
            child: Container(
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoomStatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int value;

  const _RoomStatRow({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)))),
        Text(
          '$value',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }
}

// ==================== PAINTERS ====================

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _LineChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final maxVal = data.reduce(math.max);
    final minVal = data.reduce(math.min);
    final range = maxVal - minVal;
    final normalizedRange = range == 0 ? 1.0 : range;
    final stepX = size.width / (data.length - 1);

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - minVal) / normalizedRange * size.height * 0.8 + size.height * 0.1);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw dots
    final dotPaint = Paint()..color = color;
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - minVal) / normalizedRange * size.height * 0.8 + size.height * 0.1);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DonutChartPainter extends CustomPainter {
  final double completed;
  final double active;
  final double pending;

  _DonutChartPainter({required this.completed, required this.active, required this.pending});

  @override
  void paint(Canvas canvas, Size size) {
    final total = completed + active + pending;
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final strokeWidth = 24.0;

    final bgPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    double startAngle = -math.pi / 2;

    // Completed (green)
    _drawArc(canvas, center, radius, strokeWidth, startAngle, completed / total, const Color(0xFF22C55E));
    startAngle += (completed / total) * 2 * math.pi;

    // Active (blue)
    _drawArc(canvas, center, radius, strokeWidth, startAngle, active / total, const Color(0xFF3B82F6));
    startAngle += (active / total) * 2 * math.pi;

    // Pending (yellow)
    _drawArc(canvas, center, radius, strokeWidth, startAngle, pending / total, const Color(0xFFFBBF24));
  }

  void _drawArc(Canvas canvas, Offset center, double radius, double strokeWidth, double startAngle, double fraction, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      fraction * 2 * math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

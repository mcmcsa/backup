import 'package:flutter/material.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/models/room_model.dart';
import '../../../shared/services/room_service.dart';
import 'dart:math' as math;

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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading analytics...',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final totalRequests = _requests.length;
    final pendingRequests = _requests.where((r) => r.status == 'pending').length;
    final ongoingRequests = _requests.where((r) => r.status == 'ongoing').length;
    final completedRequests = _requests.where((r) => r.status == 'done').length;
    final highPriorityRequests = _requests.where((r) => r.priority == 'high').length;
    final mediumPriorityRequests = _requests.where((r) => r.priority == 'medium').length;
    final lowPriorityRequests = _requests.where((r) => r.priority == 'low').length;

    final totalRooms = _rooms.length;
    final availableRooms = _rooms.where((r) => r.status == 'available').length;
    final maintenanceRooms = _rooms.where((r) => r.status == 'maintenance').length;

    final completionRate = totalRequests > 0
        ? (completedRequests / totalRequests * 100).round()
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analytics Overview',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Track performance and monitor key metrics',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Period Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPeriod,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF475569),
                        ),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                        items: ['Today', 'This Week', 'This Month', 'This Year']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedPeriod = v!),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export Report'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Key Metrics Row
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Total Requests',
                  value: totalRequests.toString(),
                  subtitle: '${pendingRequests + ongoingRequests} active',
                  icon: Icons.assignment_rounded,
                  iconBgColor: const Color(0xFFDBEAFE),
                  iconColor: const Color(0xFF2563EB),
                  change: '+12%',
                  isPositive: true,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _MetricCard(
                  title: 'Completion Rate',
                  value: '$completionRate%',
                  subtitle: '$completedRequests completed',
                  icon: Icons.check_circle_rounded,
                  iconBgColor: const Color(0xFFD1FAE5),
                  iconColor: const Color(0xFF059669),
                  change: '+5%',
                  isPositive: true,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _MetricCard(
                  title: 'Avg. Resolution Time',
                  value: '2.4d',
                  subtitle: 'Average days',
                  icon: Icons.timer_rounded,
                  iconBgColor: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFFD97706),
                  change: '-8%',
                  isPositive: true,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _MetricCard(
                  title: 'Room Utilization',
                  value: '${totalRooms > 0 ? ((totalRooms - maintenanceRooms) / totalRooms * 100).round() : 0}%',
                  subtitle: '$availableRooms available',
                  icon: Icons.meeting_room_rounded,
                  iconBgColor: const Color(0xFFF5F3FF),
                  iconColor: const Color(0xFF7C3AED),
                  change: '+3%',
                  isPositive: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Charts Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Request Status Chart
              Expanded(
                flex: 3,
                child: _ChartCard(
                  title: 'Request Status Overview',
                  subtitle: 'Distribution of maintenance requests',
                  child: Row(
                    children: [
                      // Donut Chart
                      Expanded(
                        child: SizedBox(
                          height: 200,
                          child: CustomPaint(
                            painter: _DonutChartPainter(
                              segments: [
                                _ChartSegment('Completed', completedRequests, const Color(0xFF059669)),
                                _ChartSegment('In Progress', ongoingRequests, const Color(0xFF2563EB)),
                                _ChartSegment('Pending', pendingRequests, const Color(0xFFD97706)),
                              ],
                              total: totalRequests,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                      // Legend
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ChartLegend(
                            label: 'Completed',
                            value: completedRequests,
                            percentage: totalRequests > 0 ? (completedRequests / totalRequests * 100).round() : 0,
                            color: const Color(0xFF059669),
                          ),
                          const SizedBox(height: 16),
                          _ChartLegend(
                            label: 'In Progress',
                            value: ongoingRequests,
                            percentage: totalRequests > 0 ? (ongoingRequests / totalRequests * 100).round() : 0,
                            color: const Color(0xFF2563EB),
                          ),
                          const SizedBox(height: 16),
                          _ChartLegend(
                            label: 'Pending',
                            value: pendingRequests,
                            percentage: totalRequests > 0 ? (pendingRequests / totalRequests * 100).round() : 0,
                            color: const Color(0xFFD97706),
                          ),
                        ],
                      ),
                      const SizedBox(width: 32),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Priority Breakdown
              Expanded(
                flex: 2,
                child: _ChartCard(
                  title: 'Priority Breakdown',
                  subtitle: 'Requests by urgency level',
                  child: Column(
                    children: [
                      _PriorityBar(
                        label: 'High Priority',
                        count: highPriorityRequests,
                        total: totalRequests,
                        color: const Color(0xFFDC2626),
                      ),
                      const SizedBox(height: 20),
                      _PriorityBar(
                        label: 'Medium Priority',
                        count: mediumPriorityRequests,
                        total: totalRequests,
                        color: const Color(0xFFD97706),
                      ),
                      const SizedBox(height: 20),
                      _PriorityBar(
                        label: 'Low Priority',
                        count: lowPriorityRequests,
                        total: totalRequests,
                        color: const Color(0xFF059669),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Room Analytics Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room Status
              Expanded(
                child: _ChartCard(
                  title: 'Room Status',
                  subtitle: 'Current availability status',
                  child: Row(
                    children: [
                      Expanded(
                        child: _RoomStatusIndicator(
                          label: 'Available',
                          value: availableRooms,
                          total: totalRooms,
                          color: const Color(0xFF059669),
                          icon: Icons.check_circle_rounded,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 80,
                        color: const Color(0xFFF1F5F9),
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      Expanded(
                        child: _RoomStatusIndicator(
                          label: 'Under Maintenance',
                          value: maintenanceRooms,
                          total: totalRooms,
                          color: const Color(0xFFD97706),
                          icon: Icons.build_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Quick Stats
              Expanded(
                child: _ChartCard(
                  title: 'Quick Stats',
                  subtitle: 'Key performance indicators',
                  child: Row(
                    children: [
                      Expanded(
                        child: _QuickStatItem(
                          label: 'Avg. Requests/Day',
                          value: '3.2',
                          icon: Icons.trending_up_rounded,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 60,
                        color: const Color(0xFFF1F5F9),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      Expanded(
                        child: _QuickStatItem(
                          label: 'Pending > 3 Days',
                          value: '${pendingRequests > 2 ? pendingRequests - 2 : 0}',
                          icon: Icons.warning_rounded,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 60,
                        color: const Color(0xFFF1F5F9),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      Expanded(
                        child: _QuickStatItem(
                          label: 'Resolution Rate',
                          value: '${completionRate}%',
                          icon: Icons.verified_rounded,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Trends Section
          _ChartCard(
            title: 'Request Trends',
            subtitle: 'Weekly request volume over the past month',
            child: SizedBox(
              height: 200,
              child: CustomPaint(
                size: const Size(double.infinity, 200),
                painter: _LineChartPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String change;
  final bool isPositive;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.change,
    required this.isPositive,
  });

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? 0.06 : 0.03),
              blurRadius: _isHovered ? 20 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        transform: _isHovered
            ? (Matrix4.identity()..translate(0.0, -2.0))
            : Matrix4.identity(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        widget.value,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.isPositive
                              ? const Color(0xFF059669).withValues(alpha: 0.1)
                              : const Color(0xFFDC2626).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isPositive
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 14,
                              color: widget.isPositive
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.change,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.isPositive
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
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

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_horiz_rounded),
                color: const Color(0xFF94A3B8),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _ChartSegment {
  final String label;
  final int value;
  final Color color;

  _ChartSegment(this.label, this.value, this.color);
}

class _DonutChartPainter extends CustomPainter {
  final List<_ChartSegment> segments;
  final int total;

  _DonutChartPainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    const strokeWidth = 24.0;

    double startAngle = -math.pi / 2;

    for (final segment in segments) {
      if (total == 0) continue;
      final sweepAngle = (segment.value / total) * 2 * math.pi;

      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle - 0.02,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Center text
    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: total.toString(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const TextSpan(
            text: '\nTotal',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ChartLegend extends StatelessWidget {
  final String label;
  final int value;
  final int percentage;
  final Color color;

  const _ChartLegend({
    required this.label,
    required this.value,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$value ($percentage%)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PriorityBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _PriorityBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (count / total * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? count / total : 0,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _RoomStatusIndicator extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  final IconData icon;

  const _RoomStatusIndicator({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (value / total * 100).round() : 0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$percentage% of total',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _QuickStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF3B82F6).withValues(alpha: 0.2),
          const Color(0xFF3B82F6).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Sample data points
    final points = [
      Offset(0, size.height * 0.6),
      Offset(size.width * 0.15, size.height * 0.4),
      Offset(size.width * 0.3, size.height * 0.5),
      Offset(size.width * 0.45, size.height * 0.3),
      Offset(size.width * 0.6, size.height * 0.45),
      Offset(size.width * 0.75, size.height * 0.25),
      Offset(size.width, size.height * 0.2),
    ];

    // Draw fill
    final fillPath = Path()..moveTo(0, size.height);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }
    canvas.drawPath(path, paint);

    // Draw dots
    final dotPaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 6, dotBorderPaint);
      canvas.drawCircle(point, 4, dotPaint);
    }

    // Draw grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;

    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw x-axis labels
    final labels = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
    for (int i = 0; i < labels.length; i++) {
      final x = size.width * (i + 0.5) / labels.length;
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF94A3B8),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height + 8));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

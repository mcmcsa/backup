import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/work_request_provider.dart';
import '../models/work_request_model.dart';
import '../models/room_model.dart';
import '../services/room_service.dart';
import '../widgets/app_date_range_dialog.dart';
import 'dart:math' as math;
import '../../web/admin/shared/admin_styles.dart';
import '../../mobile/admin/shared/admin_app_bar.dart';

class UnifiedAnalyticsPage extends StatefulWidget {
  final VoidCallback? openDrawer;
  
  const UnifiedAnalyticsPage({super.key, this.openDrawer});

  @override
  State<UnifiedAnalyticsPage> createState() => _UnifiedAnalyticsPageState();
}

class _UnifiedAnalyticsPageState extends State<UnifiedAnalyticsPage> {
  List<Room> _rooms = [];
  bool _isLoading = true;
  String _selectedPeriod = 'This Month';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Professional color palette mapping
  static const Color _primaryBlue = AdminStyles.primary;
  static const Color _successGreen = AdminStyles.success;
  static const Color _warningYellow = AdminStyles.warning;
  static const Color _dangerRed = AdminStyles.error;
  static const Color _infoBlue = AdminStyles.info;
  static const Color _confirmedIndigo = Color(0xFF6366F1);
  static const Color _reworkOrange = Color(0xFFEA580C);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _customStartDate = now.subtract(const Duration(days: 7));
    _customEndDate = now;
    _loadRooms();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<WorkRequestProvider>().refreshRequests();
      }
    });
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await RoomService.fetchAll();
      if (mounted) {
        setState(() {
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


  List<WorkRequest> get _requests {
    return Provider.of<WorkRequestProvider>(context)
        .requests
        .where((r) =>
            !r.isPendingDeptHead &&
            !r.isAcknowledged &&
            !r.status.toLowerCase().contains('acknowledged'))
        .toList();
  }
  
  bool get _isRequestsLoading {
    return Provider.of<WorkRequestProvider>(context).isLoading;
  }
  
  String? get _error {
    return Provider.of<WorkRequestProvider>(context).error;
  }

  List<WorkRequest> get _periodRequests {
    final now = DateTime.now();
    final start = _periodStart(now);
    final end = _currentPeriodEnd(now);
    return _requests.where((r) {
      final s = r.dateSubmitted;
      return !s.isBefore(start) && !s.isAfter(end);
    }).toList();
  }

  int get _totalRequests => _periodRequests.length;
  int get _completedRequests =>
      _periodRequests.where((r) => r.status.toLowerCase() == 'completed').length;
  int get _pendingRequests => _periodRequests.where((r) {
        final s = r.status.toLowerCase().trim();
        return s == 'pending' ||
            s == 'pending campus admin' ||
            s == 'pending assignment' ||
            s == 'pending review';
      }).length;
  int get _inProgressRequests => _periodRequests.where((r) {
        final s = r.status.toLowerCase();
        return s == 'in progress' ||
            s == 'in_progress' ||
            s == 'assigned' ||
            s == 'accepted by maintenance' ||
            s == 'pre-inspection submitted';
      }).length;
  int get _confirmedRequests => _periodRequests.where((r) {
        final s = r.status.toLowerCase();
        return s == 'confirmed' ||
            s == 'pre-inspection approved' ||
            s == 'post-repair submitted' ||
            s == 'in progress (post-repair)' ||
            s == 'under_maintenance';
      }).length;
  int get _reworkRequests => _periodRequests.where((r) {
        final s = r.status.toLowerCase();
        return s == 'rework' ||
            s == 'for rework' ||
            s == 'rework needed' ||
            s == 'under evaluation';
      }).length;
  int get _declinedRequests => _periodRequests.where((r) {
        final s = r.status.toLowerCase();
        return s == 'declined' ||
            s == 'cancelled' ||
            s == 'declined/cancelled' ||
            s == 'pre-inspection declined';
      }).length;

  DateTime _periodStart(DateTime now) {
    switch (_selectedPeriod) {
      case 'Today':
        return DateTime(now.year, now.month, now.day);
      case 'This Week':
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
      case 'This Year':
        return DateTime(now.year, 1, 1);
      case 'Custom Range':
        if (_customStartDate != null) {
          return DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
        }
        return DateTime(now.year, now.month, 1);
      case 'This Month':
      default:
        return DateTime(now.year, now.month, 1);
    }
  }

  DateTime _previousPeriodStart(DateTime now) {
    final start = _periodStart(now);
    final end = _currentPeriodEnd(now);
    final duration = end.difference(start);
    return start.subtract(duration).subtract(const Duration(seconds: 1));
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
      case 'Custom Range':
        if (_customEndDate != null) {
          return DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59, 999);
        }
        return DateTime(now.year, now.month + 1, 1)
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
    final start = _periodStart(now);
    final end = _currentPeriodEnd(now);
    final diffDays = end.difference(start).inDays;

    if (diffDays <= 7) {
      final count = math.max(1, diffDays + 1);
      final days = List<DateTime>.generate(count, (index) {
        return DateTime(start.year, start.month, start.day + index);
      });

      return days.map<double>((day) {
        final nextDay = day.add(const Duration(days: 1));
        return _requests.where((request) {
          return !request.dateSubmitted.isBefore(day) &&
              request.dateSubmitted.isBefore(nextDay);
        }).length.toDouble();
      }).toList();
    } else {
      const pointsCount = 7;
      final totalMs = end.difference(start).inMilliseconds;
      final stepMs = totalMs / (pointsCount - 1);

      return List.generate(pointsCount, (i) {
        final bucketStart = start.add(Duration(milliseconds: (stepMs * i).round()));
        final bucketEnd = i == pointsCount - 1
            ? end
            : start.add(Duration(milliseconds: (stepMs * (i + 1)).round()));

        return _requests.where((request) {
          final s = request.dateSubmitted;
          if (i == pointsCount - 1) {
            return !s.isBefore(bucketStart) && !s.isAfter(bucketEnd);
          }
          return !s.isBefore(bucketStart) && s.isBefore(bucketEnd);
        }).length.toDouble();
      });
    }
  }

  List<String> _buildDailySubmissionLabels() {
    final now = DateTime.now();
    final start = _periodStart(now);
    final end = _currentPeriodEnd(now);
    final diffDays = end.difference(start).inDays;

    if (diffDays <= 7) {
      final count = math.max(1, diffDays + 1);
      final days = List<DateTime>.generate(count, (index) {
        return DateTime(start.year, start.month, start.day + index);
      });
      return days.map((day) => DateFormat('E').format(day)).toList();
    } else if (diffDays <= 60) {
      const pointsCount = 7;
      final totalMs = end.difference(start).inMilliseconds;
      final stepMs = totalMs / (pointsCount - 1);
      return List.generate(pointsCount, (i) {
        final date = start.add(Duration(milliseconds: (stepMs * i).round()));
        return DateFormat('MMM d').format(date);
      });
    } else {
      const pointsCount = 7;
      final totalMs = end.difference(start).inMilliseconds;
      final stepMs = totalMs / (pointsCount - 1);
      return List.generate(pointsCount, (i) {
        final date = start.add(Duration(milliseconds: (stepMs * i).round()));
        return DateFormat('MMM yy').format(date);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDarkMode;

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: theme.subtitleColor),
            const SizedBox(height: 16),
            Text(
              'Failed to load analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: theme.textColor),
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t sync with the server.',
              style: TextStyle(fontSize: 14, color: theme.subtitleColor),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Provider.of<WorkRequestProvider>(context, listen: false).refreshRequests();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        
        Widget content = Container(
          color: theme.backgroundColor,
          child: (_isLoading || _isRequestsLoading)
              ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with period selector
                      _buildHeader(isMobile, theme),
                      const SizedBox(height: 24),

                      // Stats Cards Row
                      _buildStatsRow(isMobile),
                      const SizedBox(height: 24),

                      // Charts Row
                      if (isMobile) ...[
                        _buildPerformanceCard(isDark),
                        const SizedBox(height: 16),
                        _buildStatusDistributionCard(isMobile: true, theme: theme),
                        const SizedBox(height: 16),
                        _buildPriorityCard(),
                        const SizedBox(height: 16),
                        _buildRoomStatsCard(),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column - Performance & Status
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  _buildPerformanceCard(isDark),
                                  const SizedBox(height: 20),
                                  _buildStatusDistributionCard(isMobile: false, theme: theme),
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
                ),
        );
        if (widget.openDrawer != null) {
          return Scaffold(
            backgroundColor: theme.backgroundColor,
            appBar: AdminAppBar(
              openDrawer: widget.openDrawer!,
              subtitle: 'Campus Administrator',
            ),
            body: content,
          );
        }

        return content;
      },
    );
  }

  Widget _buildHeader(bool isMobile, ThemeProvider theme) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryBlue.withValues(alpha: theme.isDarkMode ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: _primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analytics Dashboard',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: theme.textColor, letterSpacing: -0.5),
                    ),
                    Text(
                      'Performance metrics and insights',
                      style: TextStyle(fontSize: 13, color: theme.subtitleColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPeriodSelector(theme),
        ],
      );
    }
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primaryBlue.withValues(alpha: theme.isDarkMode ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.bar_chart_rounded, color: _primaryBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics Dashboard',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: theme.textColor, letterSpacing: -0.5),
            ),
            Text(
              'Performance metrics and insights',
              style: TextStyle(fontSize: 14, color: theme.subtitleColor, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const Spacer(),
        _buildPeriodSelector(theme),
      ],
    );
  }

  Widget _buildPeriodSelector(ThemeProvider theme) {
    final periods = ['Today', 'This Week', 'This Month', 'This Year'];
    final isCustom = _selectedPeriod == 'Custom Range';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.borderColor),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...periods.map((p) {
                final isSelected = _selectedPeriod == p;
                return InkWell(
                  onTap: () => setState(() => _selectedPeriod = p),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? _primaryBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _primaryBlue.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      p,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : theme.textColor,
                      ),
                    ),
                  ),
                );
              }),
              InkWell(
                onTap: () async {
                  await _pickCustomDateRange(context);
                },
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCustom ? _primaryBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isCustom
                        ? [
                            BoxShadow(
                              color: _primaryBlue.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.date_range_rounded,
                        size: 15,
                        color: isCustom ? Colors.white : theme.subtitleColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Custom Range',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCustom ? FontWeight.w700 : FontWeight.w600,
                          color: isCustom ? Colors.white : theme.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isCustom) ...[
          const SizedBox(height: 8),
          _buildCustomDateRangeBar(theme),
        ],
      ],
    );
  }

  Widget _buildCustomDateRangeBar(ThemeProvider theme) {
    final startStr = _customStartDate != null
        ? DateFormat('MMM dd, yyyy').format(_customStartDate!)
        : 'Select';
    final endStr = _customEndDate != null
        ? DateFormat('MMM dd, yyyy').format(_customEndDate!)
        : 'Select';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.borderColor),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(
            onTap: () => _pickFromDate(context),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.isDarkMode ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'From: ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.subtitleColor),
                  ),
                  Text(
                    startStr,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryBlue),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.calendar_today_rounded, size: 13, color: _primaryBlue),
                ],
              ),
            ),
          ),
          Text(
            '–',
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.subtitleColor),
          ),
          InkWell(
            onTap: () => _pickToDate(context),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.isDarkMode ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'To: ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.subtitleColor),
                  ),
                  Text(
                    endStr,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryBlue),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.calendar_today_rounded, size: 13, color: _primaryBlue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customStartDate ?? now.subtract(const Duration(days: 7)),
      firstDate: DateTime(2020),
      lastDate: _customEndDate ?? DateTime(2035),
      helpText: 'Select From Date',
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked;
        if (_customEndDate != null && _customEndDate!.isBefore(picked)) {
          _customEndDate = picked;
        }
        _selectedPeriod = 'Custom Range';
      });
    }
  }

  Future<void> _pickToDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customEndDate ?? now,
      firstDate: _customStartDate ?? DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Select To Date',
    );
    if (picked != null) {
      setState(() {
        _customEndDate = picked;
        if (_customStartDate != null && _customStartDate!.isAfter(picked)) {
          _customStartDate = picked;
        }
        _selectedPeriod = 'Custom Range';
      });
    }
  }

  Future<void> _pickCustomDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialStartDate: _customStartDate ?? now.subtract(const Duration(days: 7)),
      initialEndDate: _customEndDate ?? now,
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedPeriod = 'Custom Range';
      });
    }
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
    final currentCompletionRate = currentTotal == 0 ? 0.0 : (currentCompleted / currentTotal) * 100;
    final previousCompletionRate = previousTotal == 0 ? 0.0 : (previousCompleted / previousTotal) * 100;
    final completionRateTrend = currentCompletionRate - previousCompletionRate;

    final cards = [
      _StatCard(
        title: 'Total Requests',
        value: '$currentTotal',
        icon: Icons.description_rounded,
        iconColor: _primaryBlue,
        trend: '${totalTrend >= 0 ? '+' : ''}${totalTrend.toStringAsFixed(1)}%',
        trendUp: totalTrend >= 0,
        isMobile: isMobile,
      ),
      _StatCard(
        title: 'Completion Rate',
        value: '${currentCompletionRate.toStringAsFixed(1)}%',
        icon: Icons.check_circle_rounded,
        iconColor: _successGreen,
        trend: '${completionRateTrend >= 0 ? '+' : ''}${completionRateTrend.toStringAsFixed(1)}%',
        trendUp: completionRateTrend >= 0,
        isMobile: isMobile,
      ),
      _StatCard(
        title: 'Pending',
        value: '$currentPending',
        icon: Icons.hourglass_empty_rounded,
        iconColor: _warningYellow,
        trend: '${pendingTrend >= 0 ? '+' : ''}${pendingTrend.toStringAsFixed(1)}%',
        trendUp: pendingTrend <= 0,
        isMobile: isMobile,
      ),
      _StatCard(
        title: 'High Priority',
        value: '$currentHighPriority',
        icon: Icons.priority_high_rounded,
        iconColor: _dangerRed,
        trend: '${highPriorityTrend >= 0 ? '+' : ''}${highPriorityTrend.toStringAsFixed(1)}%',
        trendUp: highPriorityTrend <= 0,
        isMobile: isMobile,
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: 12),
                Expanded(child: cards[3]),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 16),
        Expanded(child: cards[1]),
        const SizedBox(width: 16),
        Expanded(child: cards[2]),
        const SizedBox(width: 16),
        Expanded(child: cards[3]),
      ],
    );
  }

  Widget _buildPerformanceCard(bool isDark) {
    final chartData = _buildDailySubmissionSeries();
    final labels = _buildDailySubmissionLabels();

    return _Card(
      title: 'Performance Overview',
      icon: Icons.trending_up_rounded,
      child: SizedBox(
        height: 200,
        child: CustomPaint(
          size: const Size(double.infinity, 200),
          painter: _LineChartPainter(
            data: chartData,
            labels: labels,
            color: _primaryBlue,
            isDark: isDark,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDistributionCard({required bool isMobile, required ThemeProvider theme}) {
    final segments = [
      _StatusChartSegment(
        label: 'Pending',
        value: _pendingRequests,
        color: _warningYellow,
      ),
      _StatusChartSegment(
        label: 'In Progress',
        value: _inProgressRequests,
        color: _infoBlue,
      ),
      _StatusChartSegment(
        label: 'Confirmed',
        value: _confirmedRequests,
        color: _confirmedIndigo,
      ),
      _StatusChartSegment(
        label: 'Rework',
        value: _reworkRequests,
        color: _reworkOrange,
      ),
      _StatusChartSegment(
        label: 'Completed',
        value: _completedRequests,
        color: _successGreen,
      ),
      _StatusChartSegment(
        label: 'Declined',
        value: _declinedRequests,
        color: _dangerRed,
      ),
    ];

    final chart = SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(160, 160),
            painter: _DonutChartPainter(
              segments: segments,
              trackColor: theme.isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_totalRequests',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.subtitleColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < segments.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _LegendItem(
            color: segments[i].color,
            label: segments[i].label,
            value: segments[i].value,
          ),
        ],
      ],
    );

    return _Card(
      title: 'Request Status',
      icon: Icons.pie_chart_rounded,
      child: isMobile
          ? Column(children: [chart, const SizedBox(height: 24), legend])
          : Row(
              children: [
                chart,
                const SizedBox(width: 32),
                Expanded(child: legend),
              ],
            ),
    );
  }

  Widget _buildPriorityCard() {
    final reqs = _periodRequests;
    final high = reqs.where((r) => r.priority.toLowerCase() == 'high').length;
    final medium = reqs.where((r) => r.priority.toLowerCase() == 'medium').length;
    final low = reqs.where((r) => r.priority.toLowerCase() == 'low').length;
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
    final unavailable = _rooms.where((r) {
      final s = r.status.toLowerCase();
      return s == 'unavailable' || s == 'maintenance' || s == 'inactive' || s == 'reserved';
    }).length;

    return _Card(
      title: 'Room Status',
      icon: Icons.meeting_room_rounded,
      child: Column(
        children: [
          _RoomStatRow(icon: Icons.check_circle_rounded, color: _successGreen, label: 'Available', value: available),
          const SizedBox(height: 14),
          _RoomStatRow(icon: Icons.cancel_rounded, color: _dangerRed, label: 'Unavailable', value: unavailable),
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
  final bool isMobile;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.trend,
    required this.trendUp,
    required this.isMobile,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isMobile = widget.isMobile;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        transform: Matrix4.identity()..setTranslationRaw(0.0, _isHovered ? -2.0 : 0.0, 0.0),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? widget.iconColor.withValues(alpha: 0.5) : theme.borderColor,
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? widget.iconColor.withValues(alpha: 0.12)
                  : theme.shadowColor,
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 6 : 4),
            ),
          ],
        ),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: widget.iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(widget.icon, color: widget.iconColor, size: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                              size: 11,
                              color: widget.trendUp ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              widget.trend,
                              style: AdminStyles.dataStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: widget.trendUp ? AdminStyles.success : AdminStyles.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.value,
                    style: AdminStyles.headingStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminStyles.bodyStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.subtitleColor,
                    ),
                  ),
                ],
              )
            : Row(
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
                            color: theme.textColor,
                          ),
                        ),
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AdminStyles.bodyStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.subtitleColor,
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
    final theme = Provider.of<ThemeProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor,
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: theme.isDarkMode ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF14B8A6), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: AdminStyles.headingStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor,
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
    final theme = Provider.of<ThemeProvider>(context);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: theme.subtitleColor))),
        Text(
          '$value',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.textColor),
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
    final theme = Provider.of<ThemeProvider>(context);
    final percentage = total > 0 ? value / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.subtitleColor)),
            Text('$value', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: theme.isDarkMode ? 0.2 : 0.15),
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
    final theme = Provider.of<ThemeProvider>(context);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: theme.isDarkMode ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: theme.subtitleColor))),
        Text(
          '$value',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: theme.textColor),
        ),
      ],
    );
  }
}

// ==================== PAINTERS ====================

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final Color color;
  final bool isDark;

  _LineChartPainter({
    required this.data,
    required this.color,
    this.labels = const [],
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final bottomPadding = labels.isNotEmpty ? 26.0 : 0.0;
    final topPadding = 12.0;
    final horizontalPadding = 16.0;
    final chartHeight = size.height - bottomPadding - topPadding;
    final usableWidth = size.width - (horizontalPadding * 2);

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
      ).createShader(Rect.fromLTWH(0, 0, size.width, topPadding + chartHeight));

    final maxVal = data.reduce(math.max);
    final minVal = data.reduce(math.min);
    final range = maxVal - minVal;
    final normalizedRange = range == 0 ? 1.0 : range;
    final stepX = data.length > 1 ? usableWidth / (data.length - 1) : 0.0;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = horizontalPadding + i * stepX;
      final y = topPadding + chartHeight - ((data[i] - minVal) / normalizedRange * chartHeight * 0.8 + chartHeight * 0.1);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, topPadding + chartHeight);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(horizontalPadding + (data.length - 1) * stepX, topPadding + chartHeight);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw dots
    final dotPaint = Paint()..color = color;
    for (int i = 0; i < data.length; i++) {
      final x = horizontalPadding + i * stepX;
      final y = topPadding + chartHeight - ((data[i] - minVal) / normalizedRange * chartHeight * 0.8 + chartHeight * 0.1);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = isDark ? const Color(0xFF1E293B) : Colors.white);
    }

    // Draw day labels beneath dots
    if (labels.length == data.length) {
      for (int i = 0; i < labels.length; i++) {
        final x = horizontalPadding + i * stepX;
        final tp = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();

        double labelX = x - (tp.width / 2);
        if (labelX < 0) labelX = 0;
        if (labelX + tp.width > size.width) labelX = size.width - tp.width;

        tp.paint(canvas, Offset(labelX, size.height - 18));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _StatusChartSegment {
  final String label;
  final int value;
  final Color color;

  const _StatusChartSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _DonutChartPainter extends CustomPainter {
  final List<_StatusChartSegment> segments;
  final Color trackColor;

  _DonutChartPainter({
    required this.segments,
    this.trackColor = const Color(0xFFF1F5F9),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    const strokeWidth = 22.0;

    final bgPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    final total = segments.fold<int>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;

    final nonZeroSegments = segments.where((s) => s.value > 0).toList();
    if (nonZeroSegments.isEmpty) return;

    if (nonZeroSegments.length == 1) {
      final single = nonZeroSegments.first;
      final paint = Paint()
        ..color = single.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double startAngle = -math.pi / 2;
    const double gap = 0.05;

    for (final segment in nonZeroSegments) {
      final sweepFraction = segment.value / total;
      final totalSweep = sweepFraction * 2 * math.pi;
      final sweep = (totalSweep - gap).clamp(0.01, totalSweep);

      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + (gap / 2),
        sweep,
        false,
        paint,
      );

      startAngle += totalSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    if (oldDelegate.segments.length != segments.length) return true;
    for (int i = 0; i < segments.length; i++) {
      if (oldDelegate.segments[i].value != segments[i].value ||
          oldDelegate.segments[i].color != segments[i].color) {
        return true;
      }
    }
    return false;
  }
}

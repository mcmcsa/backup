import 'package:flutter/material.dart';
import '../../../shared/models/room_model.dart';
import '../../../shared/models/schedule_model.dart';
import '../../../shared/services/schedule_service.dart';
import 'add_schedule_page.dart';
import 'edit_schedule_page.dart';

class ViewSchedulePage extends StatefulWidget {
  final Room room;

  const ViewSchedulePage({super.key, required this.room});

  @override
  State<ViewSchedulePage> createState() => _ViewSchedulePageState();
}

class _ViewSchedulePageState extends State<ViewSchedulePage> {
  bool _isDayView = true;
  DateTime _selectedDate = DateTime.now();
  List<RoomSchedule> _schedules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    try {
      final data = await ScheduleService.fetchByRoom(widget.room.id);
      if (mounted) setState(() { _schedules = data; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; });
    }
}

  final List<String> _timeSlots = [
    '07:00 AM',
    '08:00 AM',
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F4F6),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.room.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              'Room Schedule',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('Add Schedule'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddSchedulePage(room: widget.room),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Selector & View Toggle
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                // View Toggle
                Row(
                  children: [
                    _buildToggleButton('Day', _isDayView, () {
                      setState(() => _isDayView = true);
                    }),
                    const SizedBox(width: 8),
                    _buildToggleButton('Month', !_isDayView, () {
                      setState(() => _isDayView = false);
                    }),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Weekly view coming soon'), duration: Duration(seconds: 1)),
                        );
                      },
                      icon: const Icon(
                        Icons.view_week_outlined,
                        size: 18,
                        color: Color(0xFF4169E1),
                      ),
                      label: const Text(
                        'Weekly View',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4169E1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Date Row
                _buildDateSelector(),
              ],
            ),
          ),
          // Legend
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _buildLegendItem(const Color(0xFF22C55E), 'Available'),
                const SizedBox(width: 16),
                _buildLegendItem(const Color(0xFFEF4444), 'Maintenance'),
                const SizedBox(width: 16),
                _buildLegendItem(const Color(0xFFF59E0B), 'Reserved'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Schedule Timeline
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _timeSlots.length,
              itemBuilder: (context, index) {
                return _buildTimeSlotRow(_timeSlots[index], index);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(left: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              onPressed: () {
                // Navigate to edit first schedule if available
                if (_schedules.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditSchedulePage(
                        room: widget.room,
                        schedule: _schedules[0],
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No schedules available to edit'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              heroTag: 'edit',
              backgroundColor: Colors.white,
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF4169E1)),
              label: const Text(
                'Edit Schedule',
                style: TextStyle(
                  color: Color(0xFF4169E1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddSchedulePage(room: widget.room),
                  ),
                );
              },
              heroTag: 'add',
              backgroundColor: const Color(0xFF4169E1),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Schedule',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF4169E1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF4169E1) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    final today = DateTime.now();
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = today.add(Duration(days: index - 1));
          final isSelected = date.day == _selectedDate.day &&
              date.month == _selectedDate.month;
          final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          final dayName = dayNames[date.weekday - 1];

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 48,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4169E1) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF4169E1)
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white70 : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlotRow(String time, int index) {
    // Find schedule that overlaps with this time slot
    final schedule = _getScheduleForSlot(index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time label
          SizedBox(
            width: 65,
            child: Text(
              time,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          // Schedule block or empty
          Expanded(
            child: schedule != null
                ? _buildScheduleBlock(schedule)
                : _buildEmptySlot(),
          ),
        ],
      ),
    );
  }

  RoomSchedule? _getScheduleForSlot(int index) {
    final slotTime = _timeSlots[index];
    try {
      return _schedules.firstWhere((s) => s.startTime == slotTime);
    } catch (_) {
      return null;
    }
  }

  Widget _buildScheduleBlock(RoomSchedule schedule) {
    Color blockColor;
    Color textColor;
    Color bgColor;

    if (schedule.isMaintenanceWindow) {
      blockColor = const Color(0xFFEF4444);
      textColor = const Color(0xFFEF4444);
      bgColor = const Color(0xFFFEE2E2);
    } else if (schedule.status == 'confirmed') {
      blockColor = const Color(0xFF22C55E);
      textColor = const Color(0xFF166534);
      bgColor = const Color(0xFFDCFCE7);
    } else {
      blockColor = const Color(0xFFF59E0B);
      textColor = const Color(0xFF92400E);
      bgColor = const Color(0xFFFEF3C7);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditSchedulePage(
              room: widget.room,
              schedule: schedule,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: blockColor, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              schedule.subjectName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${schedule.instructor} • ${schedule.formattedTimeSlot}',
              style: TextStyle(
                fontSize: 11,
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySlot() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }
}


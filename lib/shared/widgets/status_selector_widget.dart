import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/maintenance_status_service.dart';
import 'availability_status_badge.dart';

class StatusSelectorWidget extends StatefulWidget {
  final String currentStatus;
  final Function(String newStatus) onStatusChanged;
  final BadgeSize badgeSize;

  const StatusSelectorWidget({
    super.key,
    required this.currentStatus,
    required this.onStatusChanged,
    this.badgeSize = BadgeSize.medium,
  });

  @override
  State<StatusSelectorWidget> createState() => _StatusSelectorWidgetState();
}

class _StatusSelectorWidgetState extends State<StatusSelectorWidget> {
  bool _isUpdating = false;
  
  final List<String> _availableStatuses = [
    'online',
    'busy',
    'offline',
  ];

  Future<void> _updateStatus(String newStatus) async {
    if (newStatus == widget.currentStatus) return;
    
    setState(() => _isUpdating = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await MaintenanceStatusService.updateStatus(user.id, newStatus);
        widget.onStatusChanged(newStatus);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  void _showStatusPicker(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + renderBox.size.height,
        offset.dx + renderBox.size.width,
        0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: _availableStatuses.map((status) {
        return PopupMenuItem<String>(
          value: status,
          child: Row(
            children: [
              AvailabilityStatusBadge(
                status: status,
                showLabel: false,
                size: BadgeSize.small,
              ),
              const SizedBox(width: 8),
              Text(
                status.replaceAll('_', ' ').split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              if (status == widget.currentStatus) ...[
                const Spacer(),
                const Icon(Icons.check_rounded, size: 16, color: Color(0xFF4169E1)),
              ]
            ],
          ),
        );
      }).toList(),
    ).then((selectedStatus) {
      if (selectedStatus != null) {
        _updateStatus(selectedStatus);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isUpdating) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    
    return AvailabilityStatusBadge(
      status: widget.currentStatus,
      size: widget.badgeSize,
      isInteractive: true,
      onTap: () => _showStatusPicker(context),
    );
  }
}

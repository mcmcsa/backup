import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/room_model.dart';
import '../services/room_service.dart';
import '../../web/admin/shared/admin_styles.dart';

class RoomComparisonDialog extends StatefulWidget {
  final String roomId;

  const RoomComparisonDialog({super.key, required this.roomId});

  @override
  State<RoomComparisonDialog> createState() => _RoomComparisonDialogState();
}

class _RoomComparisonDialogState extends State<RoomComparisonDialog> {
  static SupabaseClient get _db => Supabase.instance.client;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _versions = [];
  Map<String, dynamic>? _selectedVersionA;
  Map<String, dynamic>? _selectedVersionB;
  bool _showTimeline = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchVersions();
  }

  Future<void> _fetchVersions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _db
          .from('room_versions')
          .select('*, edited_by_user:users!room_versions_edited_by_fkey(name)')
          .eq('room_id', widget.roomId)
          .order('version', ascending: true);

      final list = List<Map<String, dynamic>>.from(response as List);

      if (list.isEmpty) {
        // Fallback: If no versions exist yet, we can create a mock v1 version from the room's current state
        final currentRoom = await RoomService.fetchById(widget.roomId);
        if (currentRoom != null) {
          _versions = [
            {
              'version': 1,
              'room_data': currentRoom.toMap(),
              'created_at': DateTime.now().toIso8601String(),
            }
          ];
        }
      } else {
        _versions = list;
      }

      if (_versions.isNotEmpty) {
        if (_versions.length >= 2) {
          // Compare last two versions by default (e.g. Previous v(N-1) vs Current vN)
          _selectedVersionA = _versions[_versions.length - 2];
          _selectedVersionB = _versions[_versions.length - 1];
        } else {
          // Only one version exists
          _selectedVersionA = _versions[0];
          _selectedVersionB = _versions[0];
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to load room versions: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? screenWidth * 0.95 : 750,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              )
            : _errorMessage != null
                ? Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  )
                : _versions.isEmpty
                    ? const SizedBox(
                        height: 200,
                        child: Center(child: Text('No version history found for this room.')),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const Divider(height: 24),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_showTimeline) ...[
                                    _buildTimelineSelectors(),
                                    const SizedBox(height: 16),
                                  ],
                                  _buildComparisonView(isMobile),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 24),
                          _buildFooter(),
                        ],
                      ),
      ),
    );
  }

  Widget _buildHeader() {
    final roomName = _selectedVersionB?['room_data']?['name'] ?? 'Room';
    final roomCode = _selectedVersionB?['room_data']?['code'] ?? '';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Room Update Comparison',
                style: AdminStyles.headingStyle(fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(
                '$roomCode — $roomName',
                style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildTimelineSelectors() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminStyles.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Versions to Compare',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminStyles.textPrimary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedVersionA,
                  decoration: const InputDecoration(
                    labelText: 'Compare Version',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _selectedVersionA = val),
                  items: _versions.map((v) {
                    final verNum = v['version'];
                    final dateStr = _formatDate(v['created_at']);
                    return DropdownMenuItem(
                      value: v,
                      child: Text('Version $verNum ($dateStr)', style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 12),
              const Text('vs', style: TextStyle(fontWeight: FontWeight.bold, color: AdminStyles.textSecondary)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedVersionB,
                  decoration: const InputDecoration(
                    labelText: 'With Version',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _selectedVersionB = val),
                  items: _versions.map((v) {
                    final verNum = v['version'];
                    final dateStr = _formatDate(v['created_at']);
                    return DropdownMenuItem(
                      value: v,
                      child: Text('Version $verNum ($dateStr)', style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonView(bool isMobile) {
    final dataA = _selectedVersionA?['room_data'] as Map<String, dynamic>? ?? {};
    final dataB = _selectedVersionB?['room_data'] as Map<String, dynamic>? ?? {};

    final verNumA = _selectedVersionA?['version'] ?? 1;
    final verNumB = _selectedVersionB?['version'] ?? 1;

    final String editorB = _selectedVersionB?['edited_by_user']?['name']?.toString() ?? 'System Admin';
    final String dateB = _formatDate(_selectedVersionB?['created_at']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedVersionB != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Showing changes in Version $verNumB (updated on $dateB by $editorB)',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AdminStyles.textSecondary),
            ),
          ),
        ],
        Table(
          border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.shade100)),
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(2.0),
            2: FlexColumnWidth(2.0),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: AdminStyles.bg),
              children: [
                _buildTableCell('FIELD', isHeader: true),
                _buildTableCell('VERSION $verNumA (PREVIOUS)', isHeader: true),
                _buildTableCell('VERSION $verNumB (CURRENT)', isHeader: true),
              ],
            ),
            _buildCompareRow('Room Code', dataA['code']?.toString(), dataB['code']?.toString()),
            _buildCompareRow('Room Name', dataA['name']?.toString(), dataB['name']?.toString()),
            _buildCompareRow('Building', dataA['building']?.toString() ?? dataA['building_id']?.toString(), dataB['building']?.toString() ?? dataB['building_id']?.toString()),
            _buildCompareRow('Floor', dataA['floor']?.toString(), dataB['floor']?.toString()),
            _buildCompareRow('Department', dataA['department']?.toString() ?? dataA['department_id']?.toString(), dataB['department']?.toString() ?? dataB['department_id']?.toString()),
            _buildCompareRow('Room Type', dataA['room_type']?.toString() ?? dataA['room_type_id']?.toString(), dataB['room_type']?.toString() ?? dataB['room_type_id']?.toString()),
            _buildCompareRow('Seats', dataA['seats']?.toString(), dataB['seats']?.toString()),
            _buildCompareRow('Status', dataA['status']?.toString(), dataB['status']?.toString()),
          ],
        ),
      ],
    );
  }

  TableRow _buildCompareRow(String fieldLabel, String? valA, String? valB) {
    final vA = (valA ?? '-').trim();
    final vB = (valB ?? '-').trim();
    final isChanged = vA.toLowerCase() != vB.toLowerCase();

    final highlightBg = isChanged ? Colors.blue.shade50.withValues(alpha: 0.5) : null;

    return TableRow(
      decoration: highlightBg != null ? BoxDecoration(color: highlightBg) : null,
      children: [
        _buildTableCell(fieldLabel, isBold: isChanged, isFieldName: true),
        _buildTableCell(vA, isBold: isChanged),
        _buildTableCell(vB, isBold: isChanged, isValueCurrent: isChanged),
      ],
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, bool isBold = false, bool isFieldName = false, bool isValueCurrent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 11 : 12,
          fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.normal,
          color: isHeader
              ? AdminStyles.textMuted
              : isFieldName
                  ? AdminStyles.textPrimary
                  : isValueCurrent
                      ? Colors.blue.shade800
                      : AdminStyles.textSecondary,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_versions.length >= 2)
          TextButton.icon(
            onPressed: () => setState(() => _showTimeline = !_showTimeline),
            icon: Icon(_showTimeline ? Icons.expand_less_rounded : Icons.history_rounded, size: 18),
            label: Text(_showTimeline ? 'Hide full history' : 'View full edit history'),
            style: TextButton.styleFrom(foregroundColor: AdminStyles.primary),
          )
        else
          const SizedBox.shrink(),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminStyles.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  String _formatDate(dynamic dateObj) {
    if (dateObj == null) return '-';
    try {
      final date = DateTime.parse(dateObj.toString());
      return DateFormat('MMM dd, yyyy HH:mm').format(date.toLocal());
    } catch (_) {
      return dateObj.toString();
    }
  }
}

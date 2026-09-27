import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/building_model.dart';
import '../models/department_model.dart';
import '../models/room_type_model.dart';
import '../providers/theme_provider.dart';
import '../services/room_service.dart';
import '../services/building_service.dart';
import '../services/department_service.dart';
import '../services/room_type_service.dart';

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

  Map<String, String> _buildingNames = {};
  Map<String, String> _departmentNames = {};
  Map<String, String> _roomTypeNames = {};

  @override
  void initState() {
    super.initState();
    _fetchVersions();
    _fetchLookups();
  }

  Future<void> _fetchLookups() async {
    try {
      final results = await Future.wait([
        BuildingService.fetchAll().catchError((_) => <Building>[]),
        DepartmentService.fetchAll().catchError((_) => <Department>[]),
        RoomTypeService.fetchAll().catchError((_) => <RoomType>[]),
      ]);
      final buildings = results[0] as List<Building>;
      final departments = results[1] as List<Department>;
      final roomTypes = results[2] as List<RoomType>;

      if (mounted) {
        setState(() {
          _buildingNames = {for (final b in buildings) b.id: b.name};
          _departmentNames = {for (final d in departments) d.id: d.name};
          _roomTypeNames = {for (final r in roomTypes) r.id: r.name};
        });
      }
    } catch (_) {}
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
          _selectedVersionA = _versions[_versions.length - 2];
          _selectedVersionB = _versions[_versions.length - 1];
        } else {
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

  String _resolveBuilding(dynamic val) {
    if (val == null || val.toString().isEmpty) return '-';
    final str = val.toString().trim();
    return _buildingNames[str] ?? str;
  }

  String _resolveDepartment(dynamic val) {
    if (val == null || val.toString().isEmpty) return '-';
    final str = val.toString().trim();
    return _departmentNames[str] ?? str;
  }

  String _resolveRoomType(dynamic val) {
    if (val == null || val.toString().isEmpty) return '-';
    final str = val.toString().trim();
    return _roomTypeNames[str] ?? str;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    final dialogBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final headerBg = isDark ? const Color(0xFF252535) : const Color(0xFFF0FDFA);
    final borderColor = isDark ? Colors.grey.shade700 : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF134E4A);
    final textSecondary = isDark ? Colors.grey.shade300 : const Color(0xFF475569);
    final textMuted = isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8);
    const accentColor = Color(0xFF0F766E);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: isMobile ? screenWidth : 750,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.92 : 0.85),
        ),
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        decoration: BoxDecoration(
          color: dialogBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: _isLoading
            ? SizedBox(
                height: 300,
                child: Center(
                  child: CircularProgressIndicator(color: accentColor),
                ),
              )
            : _errorMessage != null
                ? Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  )
                : _versions.isEmpty
                    ? SizedBox(
                        height: 200,
                        child: Center(
                          child: Text(
                            'No version history found for this room.',
                            style: TextStyle(color: textSecondary),
                          ),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(textPrimary, textSecondary, accentColor),
                          Divider(height: 24, color: borderColor),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_showTimeline) ...[
                                    _buildTimelineSelectors(isMobile, headerBg, borderColor, textPrimary, textSecondary),
                                    const SizedBox(height: 16),
                                  ],
                                  _buildComparisonView(isMobile, isDark, headerBg, borderColor, textPrimary, textSecondary, textMuted),
                                ],
                              ),
                            ),
                          ),
                          Divider(height: 24, color: borderColor),
                          _buildFooter(isMobile, accentColor),
                        ],
                      ),
      ),
    );
  }

  Widget _buildHeader(Color textPrimary, Color textSecondary, Color accentColor) {
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$roomCode — $roomName',
                style: TextStyle(color: textSecondary, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close_rounded, color: textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildTimelineSelectors(bool isMobile, Color headerBg, Color borderColor, Color textPrimary, Color textSecondary) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 14),
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Versions to Compare',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
          ),
          const SizedBox(height: 10),
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDropdown(
                  label: 'Compare Version',
                  value: _selectedVersionA,
                  onChanged: (val) => setState(() => _selectedVersionA = val),
                  textPrimary: textPrimary,
                  borderColor: borderColor,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Center(
                    child: Text('vs', style: TextStyle(fontWeight: FontWeight.bold, color: textSecondary, fontSize: 12)),
                  ),
                ),
                _buildDropdown(
                  label: 'With Version',
                  value: _selectedVersionB,
                  onChanged: (val) => setState(() => _selectedVersionB = val),
                  textPrimary: textPrimary,
                  borderColor: borderColor,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'Compare Version',
                    value: _selectedVersionA,
                    onChanged: (val) => setState(() => _selectedVersionA = val),
                    textPrimary: textPrimary,
                    borderColor: borderColor,
                  ),
                ),
                const SizedBox(width: 12),
                Text('vs', style: TextStyle(fontWeight: FontWeight.bold, color: textSecondary)),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    label: 'With Version',
                    value: _selectedVersionB,
                    onChanged: (val) => setState(() => _selectedVersionB = val),
                    textPrimary: textPrimary,
                    borderColor: borderColor,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required Map<String, dynamic>? value,
    required ValueChanged<Map<String, dynamic>?> onChanged,
    required Color textPrimary,
    required Color borderColor,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: textPrimary.withValues(alpha: 0.7)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        border: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: value,
          isExpanded: true,
          isDense: true,
          onChanged: onChanged,
          style: TextStyle(fontSize: 12, color: textPrimary),
          items: _versions.map((v) {
            final verNum = v['version'];
            final dateStr = _formatDate(v['created_at']);
            return DropdownMenuItem(
              value: v,
              child: Text(
                'Version $verNum ($dateStr)',
                style: TextStyle(fontSize: 12, color: textPrimary),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildComparisonView(bool isMobile, bool isDark, Color headerBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted) {
    final dataA = _selectedVersionA?['room_data'] as Map<String, dynamic>? ?? {};
    final dataB = _selectedVersionB?['room_data'] as Map<String, dynamic>? ?? {};

    final verNumA = _selectedVersionA?['version'] ?? 1;
    final verNumB = _selectedVersionB?['version'] ?? 1;

    final String editorB = _selectedVersionB?['edited_by_user']?['name']?.toString() ?? 'System Admin';
    final String dateB = _formatDate(_selectedVersionB?['created_at']);

    final changedHighlight = isDark
        ? Colors.blue.shade900.withValues(alpha: 0.35)
        : Colors.blue.shade50.withValues(alpha: 0.5);
    final changedValueColor = isDark ? Colors.blue.shade300 : Colors.blue.shade800;

    final table = Table(
      border: TableBorder.symmetric(inside: BorderSide(color: borderColor)),
      columnWidths: isMobile
          ? const {
              0: FixedColumnWidth(100),
              1: FixedColumnWidth(150),
              2: FixedColumnWidth(150),
            }
          : const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(2.0),
              2: FlexColumnWidth(2.0),
            },
      children: [
        TableRow(
          decoration: BoxDecoration(color: headerBg),
          children: [
            _buildTableCell('FIELD', isHeader: true, isMobile: isMobile, textMuted: textMuted, textPrimary: textPrimary, textSecondary: textSecondary, changedValueColor: changedValueColor),
            _buildTableCell('VERSION $verNumA (PREVIOUS)', isHeader: true, isMobile: isMobile, textMuted: textMuted, textPrimary: textPrimary, textSecondary: textSecondary, changedValueColor: changedValueColor),
            _buildTableCell('VERSION $verNumB (CURRENT)', isHeader: true, isMobile: isMobile, textMuted: textMuted, textPrimary: textPrimary, textSecondary: textSecondary, changedValueColor: changedValueColor),
          ],
        ),
        _buildCompareRow('Room Code', dataA['code']?.toString(), dataB['code']?.toString(), isMobile, changedHighlight, changedValueColor, textPrimary, textSecondary),
        _buildCompareRow('Room Name', dataA['name']?.toString(), dataB['name']?.toString(), isMobile, changedHighlight, changedValueColor, textPrimary, textSecondary),
        _buildCompareRow('Building', _resolveBuilding(dataA['building'] ?? dataA['building_id']), _resolveBuilding(dataB['building'] ?? dataB['building_id']), isMobile, changedHighlight, changedValueColor, textPrimary, textSecondary),
        _buildCompareRow('Floor', dataA['floor']?.toString(), dataB['floor']?.toString(), isMobile, changedHighlight, changedValueColor, textPrimary, textSecondary),
        _buildCompareRow('Department', _resolveDepartment(dataA['department'] ?? dataA['department_id']), _resolveDepartment(dataB['department'] ?? dataB['department_id']), isMobile, changedHighlight, changedValueColor, textPrimary, textSecondary),
        _buildCompareRow('Room Type', _resolveRoomType(dataA['room_type'] ?? dataA['room_type_id']), _resolveRoomType(dataB['room_type'] ?? dataB['room_type_id']), isMobile, changedHighlight, changedValueColor, textPrimary, textSecondary),
        _buildCompareRow('Seats', dataA['seats']?.toString(), dataB['seats']?.toString(), isMobile, changedHighlight, changedValueColor, textPrimary, textSecondary),
        _buildCompareRow('Status', dataA['status']?.toString(), dataB['status']?.toString(), isMobile, changedHighlight, changedValueColor, textPrimary, textSecondary),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedVersionB != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Showing changes in Version $verNumB (updated on $dateB by $editorB)',
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                fontStyle: FontStyle.italic,
                color: textSecondary,
              ),
            ),
          ),
        ],
        if (isMobile)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 400,
              child: table,
            ),
          )
        else
          table,
      ],
    );
  }

  TableRow _buildCompareRow(String fieldLabel, String? valA, String? valB, bool isMobile, Color changedHighlight, Color changedValueColor, Color textPrimary, Color textSecondary) {
    final vA = (valA ?? '-').trim();
    final vB = (valB ?? '-').trim();
    final isChanged = vA.toLowerCase() != vB.toLowerCase();

    return TableRow(
      decoration: isChanged ? BoxDecoration(color: changedHighlight) : null,
      children: [
        _buildTableCell(fieldLabel, isBold: isChanged, isFieldName: true, isMobile: isMobile, textMuted: textPrimary.withValues(alpha: 0.5), textPrimary: textPrimary, textSecondary: textSecondary, changedValueColor: changedValueColor),
        _buildTableCell(vA, isBold: isChanged, isMobile: isMobile, textMuted: textPrimary.withValues(alpha: 0.5), textPrimary: textPrimary, textSecondary: textSecondary, changedValueColor: changedValueColor),
        _buildTableCell(vB, isBold: isChanged, isValueCurrent: isChanged, isMobile: isMobile, textMuted: textPrimary.withValues(alpha: 0.5), textPrimary: textPrimary, textSecondary: textSecondary, changedValueColor: changedValueColor),
      ],
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, bool isBold = false, bool isFieldName = false, bool isValueCurrent = false, bool isMobile = false, required Color textMuted, required Color textPrimary, required Color textSecondary, required Color changedValueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: isMobile ? 8 : 10,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? (isMobile ? 10 : 11) : (isMobile ? 11 : 12),
          fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.normal,
          color: isHeader
              ? textMuted
              : isFieldName
                  ? textPrimary
                  : isValueCurrent
                      ? changedValueColor
                      : textSecondary,
        ),
      ),
    );
  }

  Widget _buildFooter(bool isMobile, Color accentColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_versions.length >= 2)
          TextButton.icon(
            onPressed: () => setState(() => _showTimeline = !_showTimeline),
            icon: Icon(_showTimeline ? Icons.expand_less_rounded : Icons.history_rounded, size: isMobile ? 16 : 18),
            label: Text(
              _showTimeline ? 'Hide full history' : (isMobile ? 'Edit history' : 'View full edit history'),
              style: TextStyle(fontSize: isMobile ? 12 : 14),
            ),
            style: TextButton.styleFrom(
              foregroundColor: accentColor,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 12, vertical: 8),
            ),
          )
        else
          const SizedBox.shrink(),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: isMobile ? 8 : 10),
          ),
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 12 : 14,
            ),
          ),
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

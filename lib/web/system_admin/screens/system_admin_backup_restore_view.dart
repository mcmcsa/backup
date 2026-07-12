import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/system_backup_model.dart';
import '../../../shared/services/system_backup_service.dart';
import '../../admin/shared/admin_styles.dart';

class SystemAdminBackupRestoreView extends StatefulWidget {
  const SystemAdminBackupRestoreView({super.key});

  @override
  State<SystemAdminBackupRestoreView> createState() => _SystemAdminBackupRestoreViewState();
}

class _SystemAdminBackupRestoreViewState extends State<SystemAdminBackupRestoreView> {
  bool _loading = true;
  String? _error;
  List<SystemBackup> _backups = [];

  bool _isActionRunning = false;
  String _progressText = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await SystemBackupService.fetchHistory();
      if (mounted) {
        setState(() {
          _backups = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _createBackup() async {
    final confirmed = await _confirm(
      title: 'Create System Backup',
      message: 'Are you sure you want to trigger a manual database backup? This will generate a full snapshot of the system.',
    );
    if (!confirmed) return;

    setState(() {
      _isActionRunning = true;
      _progressText = 'Generating database snapshot...';
    });

    // Simulate real world wait
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() => _progressText = 'Compressing SQL dump...');
    await Future.delayed(const Duration(seconds: 2));

    final backup = await SystemBackupService.createBackup();

    if (mounted) {
      setState(() {
        _isActionRunning = false;
      });

      if (backup != null) {
        _toast('Backup successfully generated');
        _loadData();
      } else {
        _toast('Failed to generate backup', isError: true);
      }
    }
  }

  Future<void> _restoreBackup(SystemBackup b) async {
    final confirmed = await _confirm(
      title: 'RESTORE DATABASE',
      message: 'CRITICAL WARNING: Restoring this backup (${b.filename}) will OVERWRITE all current database records. Any data entered since this backup was created WILL BE LOST. Proceed with extreme caution.',
      danger: true,
    );
    if (!confirmed) return;

    setState(() {
      _isActionRunning = true;
      _progressText = 'Restoring database from snapshot... (DO NOT CLOSE BROWSER)';
    });

    final success = await SystemBackupService.restoreBackup(b.id, b.filename);

    if (mounted) {
      setState(() => _isActionRunning = false);
      if (success) {
        _toast('Database successfully restored');
      } else {
        _toast('Database restoration failed', isError: true);
      }
    }
  }

  Future<void> _deleteBackup(SystemBackup b) async {
    final confirmed = await _confirm(
      title: 'Delete Backup',
      message: 'Permanently delete this backup snapshot? This cannot be undone.',
      danger: true,
    );
    if (!confirmed) return;

    setState(() {
      _isActionRunning = true;
      _progressText = 'Deleting backup file...';
    });

    final err = await SystemBackupService.deleteBackup(b.id, b.filename);

    if (mounted) {
      setState(() => _isActionRunning = false);
      if (err == null) {
        _toast('Backup deleted');
        _loadData();
      } else {
        _toast('Failed to delete backup: $err', isError: true);
      }
    }
  }

  void _downloadBackup(SystemBackup b) {
    // Simulated download action
    _toast('Download started for ${b.filename}');
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Flexible(child: Text(msg)),
      ]),
      backgroundColor: isError ? AdminStyles.error : AdminStyles.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<bool> _confirm({required String title, required String message, bool danger = false}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(danger ? Icons.warning_rounded : Icons.info_outline_rounded, color: danger ? AdminStyles.error : AdminStyles.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: AdminStyles.headingStyle(fontSize: 18))),
        ]),
        content: Text(message, style: AdminStyles.bodyStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? AdminStyles.error : AdminStyles.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result == true;
  }

  // ── UI Building ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AdminStyles.primary));
    if (_error != null) return Center(child: Text('Error: $_error', style: const TextStyle(color: AdminStyles.error)));

    return LayoutBuilder(builder: (ctx, constraints) {
      final isMobile = constraints.maxWidth < 800;
      return Stack(
        children: [
          Container(
            color: AdminStyles.bg,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(isMobile ? 16 : 32, isMobile ? 16 : 28, isMobile ? 16 : 32, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(isMobile),
                      const SizedBox(height: 24),
                      _buildStatCards(isMobile),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
                    child: _backups.isEmpty ? _buildEmpty() : _buildHistoryTable(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          
          if (_isActionRunning)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AdminStyles.primary),
                      const SizedBox(height: 20),
                      Text('System Busy', style: AdminStyles.headingStyle(fontSize: 18)),
                      const SizedBox(height: 8),
                      Text(_progressText, style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Backup & Restore', style: AdminStyles.headingStyle(fontSize: isMobile ? 22 : 28)),
              const SizedBox(height: 4),
              Text('Manage system snapshots and data redundancy.', style: AdminStyles.bodyStyle(fontSize: 13)),
            ],
          ),
        ),
        if (!isMobile) ...[
          ElevatedButton.icon(
            onPressed: _createBackup,
            icon: const Icon(Icons.cloud_upload_rounded, size: 18),
            label: const Text('Create Backup Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCards(bool isMobile) {
    SystemBackup? latest;
    if (_backups.isNotEmpty) latest = _backups.first;

    final totalSize = _backups.fold<int>(0, (sum, b) => sum + b.sizeBytes);
    
    // Calculate formatted total size
    String formatSize(int b) {
      if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
      if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(2)} MB';
      return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }

    final cards = [
      _StatCard(
        label: 'Last Backup',
        value: latest != null ? DateFormat('MMM d, yyyy').format(latest.createdAt) : 'Never',
        subValue: latest != null ? DateFormat('h:mm a').format(latest.createdAt) : '-',
        icon: Icons.history_rounded,
        color: AdminStyles.success,
      ),
      _StatCard(
        label: 'Total Backup Size',
        value: formatSize(totalSize),
        subValue: 'Across ${_backups.length} snapshots',
        icon: Icons.sd_storage_rounded,
        color: AdminStyles.primary,
      ),
      _StatCard(
        label: 'Total Snapshots',
        value: '${_backups.length}',
        subValue: 'Healthy backups',
        icon: Icons.library_books_rounded,
        color: AdminStyles.warning,
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _createBackup,
              icon: const Icon(Icons.cloud_upload_rounded, size: 18),
              label: const Text('Create Backup Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminStyles.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: cards.map((c) => _buildStatTile(c)).toList(),
          ),
        ],
      );
    }

    return Row(
      children: cards.map((c) => Expanded(child: _buildStatTile(c))).expand((w) => [w, const SizedBox(width: 16)]).toList()..removeLast(),
    );
  }

  Widget _buildStatTile(_StatCard s) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: s.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(s.icon, color: s.color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(s.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: s.color, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(s.label, style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
          if (s.subValue != null) Text(s.subValue!, style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 60, color: AdminStyles.textMuted),
          const SizedBox(height: 16),
          Text('No backups found', style: AdminStyles.headingStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text('Generate your first database snapshot to keep your data safe.', style: AdminStyles.bodyStyle()),
        ],
      ),
    );
  }

  Widget _buildHistoryTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  _th('Backup File', flex: 3),
                  _th('Created At', flex: 2),
                  _th('Size', flex: 1),
                  _th('Status', flex: 1),
                  _th('Actions', flex: 2, center: true),
                ],
              ),
            ),
            const Divider(height: 1, color: AdminStyles.border),
            Expanded(
              child: ListView.separated(
                itemCount: _backups.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AdminStyles.border),
                itemBuilder: (_, i) => _buildRow(_backups[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _th(String label, {int flex = 1, bool center = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AdminStyles.textMuted, letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildRow(SystemBackup b) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const Icon(Icons.description_rounded, size: 20, color: AdminStyles.textSecondary),
                const SizedBox(width: 10),
                Expanded(child: Text(b.filename, style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AdminStyles.textPrimary), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('MMM d, yyyy').format(b.createdAt), style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(DateFormat('h:mm a').format(b.createdAt), style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted)),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(b.formattedSize, style: AdminStyles.bodyStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AdminStyles.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(b.status.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AdminStyles.success)),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Download',
                  icon: const Icon(Icons.download_rounded, size: 18, color: AdminStyles.primary),
                  onPressed: () => _downloadBackup(b),
                ),
                IconButton(
                  tooltip: 'Restore',
                  icon: const Icon(Icons.restore_rounded, size: 18, color: AdminStyles.warning),
                  onPressed: () => _restoreBackup(b),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AdminStyles.error),
                  onPressed: () => _deleteBackup(b),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard {
  final String label;
  final String value;
  final String? subValue;
  final IconData icon;
  final Color color;

  _StatCard({required this.label, required this.value, this.subValue, required this.icon, required this.color});
}

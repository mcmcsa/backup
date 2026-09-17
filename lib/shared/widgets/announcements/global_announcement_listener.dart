import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../authentication/services/auth_service.dart';
import '../../models/system_announcement_model.dart';
import '../../services/system_announcement_service.dart';
import '../../../web/admin/shared/admin_styles.dart';
import '../offline_banner_widget.dart';

class GlobalAnnouncementListener extends StatefulWidget {
  final Widget child;
  
  const GlobalAnnouncementListener({super.key, required this.child});

  @override
  State<GlobalAnnouncementListener> createState() => _GlobalAnnouncementListenerState();
}

class _GlobalAnnouncementListenerState extends State<GlobalAnnouncementListener> {
  List<SystemAnnouncement> _banners = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;
  final Set<String> _shownPopups = {};

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
    _setupRealtime();
  }

  void _setupRealtime() {
    try {
      _realtimeChannel = Supabase.instance.client
          .channel('global_announcements_channel_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'system_announcements',
            callback: (_) {
              if (mounted) _fetchAnnouncements();
            },
          )
          .subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      _realtimeChannel?.unsubscribe();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _fetchAnnouncements() async {
    final auth = context.read<AuthService>();
    final role = auth.currentUser?.role.name; // e.g., 'teacher', 'maintenance', 'admin', 'campadmin'
    
    final announcements = await SystemAnnouncementService.fetchActive(userRole: role);
    
    if (!mounted) return;
    
    final banners = announcements.where((a) => a.displayType == 'banner').toList();
    final popups = announcements.where((a) => a.displayType == 'popup').toList();
    
    setState(() {
      _banners = banners;
      _isLoading = false;
    });

    // Show popups after build
    if (popups.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (var p in popups) {
          if (!_shownPopups.contains(p.id)) {
            _shownPopups.add(p.id);
            _showPopup(p);
          }
        }
      });
    }
  }

  void _showPopup(SystemAnnouncement announcement) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: AdminStyles.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(announcement.title, style: AdminStyles.headingStyle(fontSize: 20))),
          ],
        ),
        content: Text(announcement.content, style: AdminStyles.bodyStyle(fontSize: 15)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AdminStyles.primary, foregroundColor: Colors.white),
            child: const Text('Acknowledge'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;
    
    if (_banners.isNotEmpty && !_isLoading) {
      content = Column(
        children: [
          ..._banners.map((b) => _buildBanner(b)),
          Expanded(child: content),
        ],
      );
    }
    
    return OfflineBannerWidget(child: content);
  }

  Widget _buildBanner(SystemAnnouncement announcement) {
    Color bg; Color fg;
    switch (announcement.priority.toLowerCase()) {
      case 'urgent': bg = AdminStyles.error; fg = Colors.white; break;
      case 'high': bg = AdminStyles.warning; fg = Colors.black87; break;
      case 'normal': bg = AdminStyles.primary; fg = Colors.white; break;
      case 'low': bg = const Color(0xFFE2E8F0); fg = const Color(0xFF475569); break;
      default: bg = AdminStyles.primary; fg = Colors.white; break;
    }

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(Icons.announcement_rounded, color: fg, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(announcement.title, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(announcement.content, style: TextStyle(color: fg.withValues(alpha: 0.9), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, color: fg, size: 20),
              onPressed: () {
                setState(() => _banners.remove(announcement));
              },
            )
          ],
        ),
      ),
    );
  }
}

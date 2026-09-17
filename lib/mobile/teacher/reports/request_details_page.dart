import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/models/pre_inspection_model.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/services/pre_inspection_service.dart';
import '../../../shared/services/post_repair_service.dart';
import '../../../shared/services/user_service.dart';
import '../../../web/teacher/reports/teacher_official_form_web.dart';
import '../../../shared/widgets/attachment_image_widget.dart';

import 'package:printing/printing.dart';
import '../../../shared/services/iso_pdf_service.dart';

class RequestDetailsPage extends StatefulWidget {
  final String trackingNumber;
  final String status;

  const RequestDetailsPage({
    super.key,
    required this.trackingNumber,
    required this.status,
  });

  @override
  State<RequestDetailsPage> createState() => _RequestDetailsPageState();
}

class _RequestDetailsPageState extends State<RequestDetailsPage>
    with WidgetsBindingObserver {
  WorkRequest? _request;
  List<ESignature> _signatures = [];
  Timer? _autoRefreshTimer;

  PreInspectionReport? _preInspectionReport;
  List<PostRepairReport> _postRepairReports = [];
  final Map<String, String> _userNames = {};

  RealtimeChannel? _realtimeChannel;
  String _selectedFilter = 'Timeline';
  List<String> _recoveredAttachments = [];

  List<String> get _attachments {
    final list = <String>[];
    if (_request?.attachmentUrls != null && _request!.attachmentUrls!.isNotEmpty) {
      for (final u in _request!.attachmentUrls!) {
        final trimmed = u.trim();
        if (trimmed.isNotEmpty && !list.contains(trimmed)) {
          list.add(trimmed);
        }
      }
    }
    if (_request?.workEvidence != null && _request!.workEvidence!.trim().isNotEmpty) {
      final ev = _request!.workEvidence!.trim();
      try {
        final decoded = jsonDecode(ev);
        if (decoded is List) {
          for (final item in decoded) {
            final s = item?.toString().trim() ?? '';
            if (s.isNotEmpty && !list.contains(s)) {
              list.add(s);
            }
          }
        }
      } catch (_) {
        if (ev.startsWith('data:image')) {
          if (!list.contains(ev)) list.add(ev);
        } else {
          for (final part in ev.split(',')) {
            final s = part.trim();
            if (s.isNotEmpty && !list.contains(s)) {
              list.add(s);
            }
          }
        }
      }
    }
    for (final r in _recoveredAttachments) {
      final trimmed = r.trim();
      if (trimmed.isNotEmpty && !list.contains(trimmed)) {
        list.add(trimmed);
      }
    }
    return list;
  }

  Future<List<String>> _recoverStorageAttachments(String requestId) async {
    final results = <String>[];
    try {
      final client = Supabase.instance.client;
      final candidateBuckets = ['work-evidence', 'evidence', 'work_evidence', 'attachments'];
      for (final b in candidateBuckets) {
        try {
          final files = await client.storage.from(b).list(path: requestId);
          for (final f in files) {
            if (f.name.isNotEmpty && !f.name.startsWith('.')) {
              final pubUrl = client.storage.from(b).getPublicUrl('$requestId/${f.name}');
              if (!results.contains(pubUrl)) {
                results.add(pubUrl);
              }
            }
          }
          final subFiles = await client.storage.from(b).list(path: 'work-evidence/$requestId');
          for (final f in subFiles) {
            if (f.name.isNotEmpty && !f.name.startsWith('.')) {
              final pubUrl = client.storage.from(b).getPublicUrl('work-evidence/$requestId/${f.name}');
              if (!results.contains(pubUrl)) {
                results.add(pubUrl);
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return results;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRequest();
    _startAutoRefresh();
    _setupRealtime();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRequest();
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('public:mobile_request_details_${widget.trackingNumber}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'work_requests',
          callback: (_) => _loadRequest(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'e_signatures',
          callback: (_) => _loadRequest(),
        )
        .subscribe();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _loadRequest();
    });
  }

  Future<void> _loadRequest() async {
    try {
      final request = await WorkRequestService.fetchById(widget.trackingNumber);
      final signatures = request != null
          ? await ESignatureService.fetchByWorkRequest(request.id)
          : <ESignature>[];
          
      // Populate cache of user names from signatures to bypass RLS issues
      for (final sig in signatures) {
        if (sig.signerId.isNotEmpty && sig.signerName.isNotEmpty) {
          final isAdm = sig.signerRole.toLowerCase() == 'campadmin';
          _userNames[sig.signerId] = isAdm ? 'Campus Admin - ${sig.signerName}' : sig.signerName;
        }
      }

      final preInspection = request != null
          ? await PreInspectionService.fetchLatestByWorkRequest(request.id)
          : null;
      final postRepairs = request != null
          ? await PostRepairService.fetchByWorkRequest(request.id)
          : <PostRepairReport>[];

      List<String> recoveredAttachments = _recoveredAttachments;
      if (request != null &&
          (request.attachmentUrls == null || request.attachmentUrls!.isEmpty) &&
          (request.workEvidence == null || request.workEvidence!.trim().isEmpty)) {
        final found = await _recoverStorageAttachments(request.id);
        if (found.isNotEmpty) {
          recoveredAttachments = found;
        }
      }

      final userIds = <String>{};
      if (preInspection?.adminApprovedBy != null) userIds.add(preInspection!.adminApprovedBy!);
      for (final report in postRepairs) {
        if (report.adminEvaluatedBy != null) userIds.add(report.adminEvaluatedBy!);
      }
      final missingIds = userIds.where((id) => !_userNames.containsKey(id)).toList();
      if (missingIds.isNotEmpty) {
        final names = await UserService.fetchNamesByIds(missingIds);
        if (names.isNotEmpty) {
          _userNames.addAll(names);
        }
      }

      if (mounted) {
        setState(() {
          _request = request;
          _signatures = signatures;
          _preInspectionReport = preInspection;
          _postRepairReports = postRepairs;
          _recoveredAttachments = recoveredAttachments;
        });
      }
      await _markRelatedNotificationsRead();
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _markRelatedNotificationsRead() async {
    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      if (user == null) return;

      await AppNotificationService.markWorkRequestAsRead(
        role: user.role.name,
        userId: user.id,
        workRequestId: widget.trackingNumber,
      );
    } catch (_) {}
  }


  void _openOfficialForm() {
    if (_request == null) return;
    showDialog(
      context: context,
      useSafeArea: true,
      barrierDismissible: true,
      builder: (context) => TeacherOfficialFormWeb(request: _request!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Request Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'View Official ISO Form',
            icon: const Icon(Icons.assignment_rounded, color: Colors.black87),
            onPressed: _openOfficialForm,
          ),
          IconButton(
            tooltip: 'Print Form',
            icon: const Icon(Icons.print_rounded, color: Colors.black87),
            onPressed: () async {
              if (_request != null) {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final pdfBytes = await IsoPdfService.generateWorkRequestPdf(_request!);
                  await Printing.layoutPdf(
                    onLayout: (_) => pdfBytes,
                    name: 'Work_Request_Form_${_request!.formattedId}',
                    format: IsoPdfService.standardPortraitFormat,
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to generate PDF: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BFA5).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          (_request?.status ?? widget.status).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Icon(Icons.menu, color: Colors.white, size: 20),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'TRACKING NUMBER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.trackingNumber,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Segmented Filter Tabs
            _buildFilterButtons(),
            const SizedBox(height: 16),
            // Active Tab Content
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(_selectedFilter),
                child: _selectedFilter == 'Timeline'
                    ? _buildTimelineSection()
                    : (_selectedFilter == 'Details'
                        ? _buildDetailsSection()
                        : _buildSignaturesCard()),
              ),
            ),
            const SizedBox(height: 24),
            // Maintenance Office Contact Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.headset_mic,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Maintenance Office',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'For corrections, assistance or safety concerns',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.phone, size: 18),
                          label: const Text(
                            'Call: 8422',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF00BFA5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.email, size: 18),
                          label: const Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF00BFA5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButtons() {
    final filters = [
      {'label': 'Timeline', 'icon': Icons.timeline_rounded},
      {'label': 'Details', 'icon': Icons.description_outlined},
      {'label': 'Signature', 'icon': Icons.draw_outlined},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: filters.map((f) {
          final label = f['label'] as String;
          final icon = f['icon'] as IconData;
          final isSelected = _selectedFilter == label;

          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (_selectedFilter != label) {
                    setState(() => _selectedFilter = label);
                  }
                },
                borderRadius: BorderRadius.circular(9),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF00BFA5) : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00BFA5).withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                      if (label == 'Signature' && _requestorSignatures.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : const Color(0xFF00BFA5).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_requestorSignatures.length}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : const Color(0xFF00BFA5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Workflow Timeline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton.icon(
              onPressed: _openOfficialForm,
              icon: const Icon(
                Icons.description,
                size: 16,
                color: Color(0xFF00BFA5),
              ),
              label: const Text(
                'View Official Form',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00BFA5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildWorkflowTimeline(),
      ],
    );
  }

  Widget _buildDetailsSection() {
    final isPendingReview = _request?.status.toLowerCase() == 'pending';
    final priorityDisplay = isPendingReview
        ? '--'
        : (_request?.priority.isNotEmpty == true ? _request!.priority : 'Normal');
    final prioritySub = isPendingReview ? 'Pending Review' : 'Assigned';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Location and Priority Row
        Row(
          children: [
            Expanded(
              child: _buildInfoBox(
                icon: Icons.place_outlined,
                label: 'LOCATION',
                value1: _request?.officeRoom ?? _request?.roomName ?? 'N/A',
                value2: _request?.buildingName ?? 'N/A',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoBox(
                icon: Icons.flag_outlined,
                label: 'PRIORITY',
                value1: priorityDisplay,
                value2: prioritySub,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Additional details card (Dates, Requestor)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF00BFA5)),
                  const SizedBox(width: 8),
                  Text(
                    'Date Submitted',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  Text(
                    _request != null
                        ? DateFormat('MMM dd, yyyy • hh:mm a').format(_request!.dateSubmitted)
                        : 'N/A',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ],
              ),
              if (_request != null && (_request!.requestorName.isNotEmpty || _request!.displayRequestorName.isNotEmpty)) ...[
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF00BFA5)),
                    const SizedBox(width: 8),
                    Text(
                      'Requested By',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const Spacer(),
                    Text(
                      _request!.requestorName.isNotEmpty
                          ? _request!.requestorName
                          : _request!.displayRequestorName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Problem Description
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Problem Description',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _request?.description ?? 'No description provided.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Attached Photos Carousel
        _buildAttachedPhotosCard(),
        const SizedBox(height: 12),
        // View Digital Form Link
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _openOfficialForm,
            icon: const Icon(
              Icons.assignment_rounded,
              size: 16,
              color: Color(0xFF00BFA5),
            ),
            label: const Text(
              'View Digital Form',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00BFA5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachedPhotosCard() {
    final photos = _attachments;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_rounded, size: 18, color: Color(0xFF00BFA5)),
              const SizedBox(width: 8),
              const Text(
                'Attached Photos',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (photos.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFA5).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${photos.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00BFA5),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (photos.isNotEmpty)
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final url = photos[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => showAttachmentZoomDialog(context, url),
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          color: const Color(0xFFF8FAFC),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: AppAttachmentImage(
                                url: url,
                                fit: BoxFit.cover,
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.zoom_in_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Text(
                    'No photos attached to this request.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String label,
    required String value1,
    required String value2,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF00BFA5)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value1,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value2,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }



  bool _isUnassigned(String? staffId) {
    final normalized = staffId?.trim().toLowerCase();
    return normalized == null || normalized.isEmpty || normalized == 'null';
  }

  String _assignedMaintenanceName(String? staffId) {
    if (_isUnassigned(staffId)) return 'Unassigned';
    return _request?.acceptedByName ?? 'Assigned Staff';
  }

  Widget _buildWorkflowTimelineItem({
    required String title,
    required bool isDone,
    bool isRework = false,
    String? subtitle,
    Widget? details,
    ESignature? signature,
    bool isLast = false,
  }) {
    final circleColor = isRework
        ? const Color(0xFFD97706)
        : (isDone ? const Color(0xFF059669) : Colors.grey.shade300);
    final iconData = isRework
        ? Icons.refresh_rounded
        : (isDone ? Icons.check : Icons.circle);
    final iconSize = (isRework || isDone) ? 14.0 : 8.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                size: iconSize,
                color: Colors.white,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 48,
                color: circleColor,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isRework
                      ? const Color(0xFFD97706)
                      : (isDone ? const Color(0xFF111827) : Colors.grey.shade600),
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
              if (details != null) ...[
                const SizedBox(height: 6),
                details,
              ],
              if (signature != null && signature.signatureData.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildWorkflowTimelineSignatureImage(signature.signatureData),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkflowTimelineSignatureImage(String base64Str) {
    try {
      final cleaned = base64Str.trim().replaceAll(RegExp(r'\s+'), '');
      final base64Data = cleaned.contains(',') ? cleaned.split(',')[1] : cleaned;
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Image.memory(
          base64Decode(base64Data),
          height: 35,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.gesture, size: 25, color: Colors.grey),
        ),
      );
    } catch (_) {
      return const Icon(Icons.gesture, size: 25, color: Colors.grey);
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildWorkflowTimeline() {
    final request = _request;
    if (request == null) return const SizedBox.shrink();

    final List<Widget> items = [];

    // 1. Submission
    final reqSig = _signatures.firstWhere(
      (s) => s.signatureType == 'requestor',
      orElse: () => ESignature(
        id: '',
        workRequestId: '',
        signerId: '',
        signerName: '',
        signerRole: '',
        signatureType: '',
        signatureData: '',
        signedAt: DateTime.now(),
      ),
    );
    items.add(
      _buildWorkflowTimelineItem(
        title: 'Work Request Submitted',
        isDone: true,
        subtitle: 'By ${request.requestorName} on ${_formatDateTime(request.dateSubmitted)}',
        signature: reqSig.signatureData.isNotEmpty ? reqSig : null,
      ),
    );

    // 2. Assignment
    final isAssigned = !_isUnassigned(request.assignedToId);
    final assignSig = _signatures.firstWhere(
      (s) => s.signatureType == 'approval',
      orElse: () => ESignature(
        id: '',
        workRequestId: '',
        signerId: '',
        signerName: '',
        signerRole: '',
        signatureType: '',
        signatureData: '',
        signedAt: DateTime.now(),
      ),
    );
    items.add(
      _buildWorkflowTimelineItem(
        title: 'Admin Approved & Assigned',
        isDone: isAssigned,
        subtitle: isAssigned
            ? 'Approved and assigned to ${_assignedMaintenanceName(request.assignedToId)}'
            : 'Awaiting admin review & assignment',
        signature: assignSig.signatureData.isNotEmpty ? assignSig : null,
      ),
    );

    // 3. Acceptance
    final acceptSig = _signatures.firstWhere(
      (s) => s.signatureType == 'acceptance',
      orElse: () => ESignature(
        id: '',
        workRequestId: '',
        signerId: '',
        signerName: '',
        signerRole: '',
        signatureType: '',
        signatureData: '',
        signedAt: DateTime.now(),
      ),
    );
    final isAccepted = acceptSig.signatureData.isNotEmpty ||
        (request.status != 'Pending Assignment' && request.status != 'Assigned');
    items.add(
      _buildWorkflowTimelineItem(
        title: 'Technician Accepted Task',
        isDone: isAccepted,
        subtitle: isAccepted
            ? 'Accepted by ${request.acceptedByName ?? _assignedMaintenanceName(request.assignedToId)} on ${_formatDateTime(request.acceptedDate ?? acceptSig.signedAt)}'
            : 'Awaiting technician acceptance',
        signature: acceptSig.signatureData.isNotEmpty ? acceptSig : null,
      ),
    );

    // 4. Pre-Inspection
    final preInspection = _preInspectionReport;
    final preInspSig = _signatures.firstWhere(
      (s) => s.signatureType == 'pre_inspection',
      orElse: () => ESignature(
        id: '',
        workRequestId: '',
        signerId: '',
        signerName: '',
        signerRole: '',
        signatureType: '',
        signatureData: '',
        signedAt: DateTime.now(),
      ),
    );
    final isPreInspectionSubmitted = preInspection != null;
    items.add(
      _buildWorkflowTimelineItem(
        title: 'Pre-Inspection Report Filed',
        isDone: isPreInspectionSubmitted,
        subtitle: isPreInspectionSubmitted
            ? 'Submitted by ${preInspection.inspectorName}'
            : 'Awaiting pre-inspection submission',
        signature: preInspSig.signatureData.isNotEmpty ? preInspSig : null,
        details: null,
      ),
    );

    // 5. Pre-Inspection Approval/Decline
    final preInspApprovalSig = _signatures.firstWhere(
      (s) => s.signatureType == 'pre_inspection_admin' || s.signatureType == 'pre_inspection_approval',
      orElse: () => ESignature(
        id: '',
        workRequestId: '',
        signerId: '',
        signerName: '',
        signerRole: '',
        signatureType: '',
        signatureData: '',
        signedAt: DateTime.now(),
      ),
    );
    final isPreInspectionReviewed = preInspection != null &&
        (preInspection.status == 'Approved' || preInspection.status == 'Declined');
    final isPreInspApproved = preInspection?.status == 'Approved';
    final approvedByName = preInspection?.adminApprovedBy != null
        ? (_userNames[preInspection!.adminApprovedBy] ?? preInspection.adminApprovedBy)
        : "Admin";
    items.add(
      _buildWorkflowTimelineItem(
        title: preInspection?.status == 'Approved'
            ? 'Pre-Inspection Approved'
            : (preInspection?.status == 'Declined' ? 'Pre-Inspection Declined' : 'Pre-Inspection Review'),
        isDone: isPreInspectionReviewed,
        subtitle: isPreInspectionReviewed
            ? '${preInspection.status} by $approvedByName'
            : (preInspection != null ? 'Awaiting admin pre-inspection decision' : 'Pending pre-inspection submission'),
        signature: preInspApprovalSig.signatureData.isNotEmpty ? preInspApprovalSig : null,
        details: null,
      ),
    );

    final sortedAttempts = List<PostRepairReport>.from(_postRepairReports)
      ..sort((a, b) {
        int cmp = a.repairDate.compareTo(b.repairDate);
        if (cmp != 0) return cmp;
        return a.attemptNumber.compareTo(b.attemptNumber);
      });
    final hasPostRepair = sortedAttempts.isNotEmpty;
    final isCompleted = request.status.toLowerCase() == 'completed';

    // 6. Post-Repair Attempts & Evaluations
    if (hasPostRepair) {
      for (int i = 0; i < sortedAttempts.length; i++) {
        final report = sortedAttempts[i];
        final attemptTechSig = _signatures.firstWhere(
          (s) => s.signatureType == 'post_repair' && s.signerId == report.technicianId,
          orElse: () => ESignature(
            id: '',
            workRequestId: '',
            signerId: '',
            signerName: '',
            signerRole: '',
            signatureType: '',
            signatureData: '',
            signedAt: DateTime.now(),
          ),
        );
        final attemptSuffix = sortedAttempts.length > 1 ? ' (Attempt #${report.attemptNumber})' : '';
        items.add(
          _buildWorkflowTimelineItem(
            title: 'Post-Repair Report$attemptSuffix',
            isDone: true,
            subtitle: 'Submitted by ${report.technicianName}',
            signature: attemptTechSig.signatureData.isNotEmpty ? attemptTechSig : null,
            details: null,
          ),
        );

        final isEvaluated = report.adminEvaluation != null;
        final attemptAdminSig = _signatures.firstWhere(
          (s) => s.signatureType == 'completion' && s.signerId == report.adminEvaluatedBy,
          orElse: () => ESignature(
            id: '',
            workRequestId: '',
            signerId: '',
            signerName: '',
            signerRole: '',
            signatureType: '',
            signatureData: '',
            signedAt: DateTime.now(),
          ),
        );
        final isRework = report.adminEvaluation == 'rework';
        final evaluatedByName = report.adminEvaluatedBy != null
            ? (_userNames[report.adminEvaluatedBy] ?? report.adminEvaluatedBy)
            : "Admin";
        
        final isLatestReport = i == sortedAttempts.length - 1;
        if (isEvaluated || isLatestReport) {
          items.add(
            _buildWorkflowTimelineItem(
              title: isRework
                  ? 'Post-Repair Evaluation - Rework Required'
                  : 'Post-Repair Evaluation',
              isDone: isEvaluated && !isRework,
              isRework: isRework,
              subtitle: isEvaluated
                  ? '${isRework ? "REWORK REQUIRED" : "SATISFIED (Approved)"} by $evaluatedByName'
                  : 'Awaiting admin post-repair evaluation',
              signature: attemptAdminSig.signatureData.isNotEmpty ? attemptAdminSig : null,
              details: null,
            ),
          );
        }
      }

      // If the latest evaluation was rework, append a pending Post-Repair Report step
      if (sortedAttempts.last.adminEvaluation == 'rework') {
        final nextAttempt = sortedAttempts.length + 1;
        items.add(
          _buildWorkflowTimelineItem(
            title: 'Post-Repair Report (Attempt #$nextAttempt)',
            isDone: false,
            subtitle: 'Awaiting post-repair submission (Rework).',
            signature: null,
            details: null,
          ),
        );
      }
    } else {
      // Keep Post-Repair Report and Post-Repair Evaluation visible even before first report submission!
      items.add(
        _buildWorkflowTimelineItem(
          title: 'Post-Repair Report',
          isDone: false,
          subtitle: isPreInspApproved
              ? 'Awaiting post-repair submission from technician.'
              : 'Pending repair completion.',
          signature: null,
          details: null,
        ),
      );

      items.add(
        _buildWorkflowTimelineItem(
          title: 'Post-Repair Evaluation',
          isDone: false,
          subtitle: 'Pending post-repair report submission.',
          signature: null,
          details: null,
        ),
      );
    }

    // 8. Final Completion
    final hasSatisfiedEval = hasPostRepair && sortedAttempts.last.adminEvaluation == 'satisfied';
    items.add(
      _buildWorkflowTimelineItem(
        title: 'Completed & Verified',
        isDone: isCompleted,
        subtitle: isCompleted
            ? 'Completed on ${_formatDateTime(request.updatedAt)}'
            : (hasSatisfiedEval
                ? 'Awaiting final verification and close out.'
                : 'Pending work completion and evaluation.'),
        isLast: true,
      ),
    );

    return Column(
      children: items,
    );
  }

  bool _isRequestorSignature(ESignature s) {
    final role = s.signerRole.trim().toLowerCase();
    final type = s.signatureType.trim().toLowerCase();
    if (role == 'admin' || role == 'campadmin' || role == 'campus admin' ||
        role == 'maintenance' || role == 'technician') {
      return false;
    }
    if (type.contains('pre_inspection') || type.contains('post_repair')) {
      return false;
    }

    final reqId = _request?.requestorId?.trim();
    if (reqId != null && reqId.isNotEmpty && s.signerId.trim() == reqId) {
      return true;
    }
    final reportedId = _request?.reportedById?.trim();
    if (reportedId != null && reportedId.isNotEmpty && s.signerId.trim() == reportedId) {
      return true;
    }

    final signerName = s.signerName.trim().toLowerCase();
    final reqName = (_request?.requestorName ?? '').trim().toLowerCase();
    final dispName = (_request?.displayRequestorName ?? '').trim().toLowerCase();
    final reportedName = (_request?.reportedByName ?? '').trim().toLowerCase();
    
    if (signerName.isNotEmpty) {
      if (reqName.isNotEmpty && signerName == reqName) return true;
      if (dispName.isNotEmpty && signerName == dispName) return true;
      if (reportedName.isNotEmpty && signerName == reportedName) return true;
    }

    if (role == 'teacher' || role == 'requestor') {
      return true;
    }

    return false;
  }

  List<ESignature> get _requestorSignatures {
    return _signatures.where(_isRequestorSignature).toList();
  }

  Widget _buildSignaturesCard() {
    final sigs = _requestorSignatures;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                  color: const Color(0xFF059669).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Requestor Signature',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sigs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.draw_rounded, size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No Requestor Signature Recorded',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your signature as the requestor will appear here once attached to this work request.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
          else
            ...sigs.map((s) => _buildSignatureItem(s)),
        ],
      ),
    );
  }

  Widget _buildSignatureItem(ESignature s) {
    final initials = s.signerName.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    Uint8List? signatureBytes;
    if (s.signatureData.isNotEmpty) {
      try {
        final cleanBase64 = s.signatureData.contains(',')
            ? s.signatureData.split(',').last
            : s.signatureData;
        signatureBytes = base64Decode(cleanBase64.trim());
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF059669).withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials.isNotEmpty ? initials : 'RQ',
                  style: const TextStyle(
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.signerName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    () {
                      final type = s.signatureType.trim().toLowerCase();
                      if (type == 'completion') {
                        return 'Requestor (Completion Confirmation)';
                      }
                      return 'Requestor (Submission)';
                    }(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (signatureBytes != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 50,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Image.memory(
                        signatureBytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 18),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd').format(s.signedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

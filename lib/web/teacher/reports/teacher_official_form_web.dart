import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/iso_pdf_service.dart';
import '../../admin/shared/admin_styles.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/utils/signature_image_helper.dart';

class TeacherOfficialFormWeb extends StatefulWidget {
  final WorkRequest request;

  const TeacherOfficialFormWeb({super.key, required this.request});

  @override
  State<TeacherOfficialFormWeb> createState() => _TeacherOfficialFormWebState();
}

class _TeacherOfficialFormWebState extends State<TeacherOfficialFormWeb> {
  late WorkRequest _currentRequest;
  List<ESignature> _signatures = [];
  Map<String, Uint8List> _transparentSignatureCache = {};
  bool _isLoading = true;
  int _selectedPage = 0; // 0: Work Request Form, 1: Confirmation Form
  RealtimeChannel? _realtimeChannel;
  String? _requestorLivePosition;

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
    _loadData();
    _setupRealtime();
  }

  @override
  void didUpdateWidget(covariant TeacherOfficialFormWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id) {
      _realtimeChannel?.unsubscribe();
      _currentRequest = widget.request;
      _loadData();
      _setupRealtime();
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    final reqId = widget.request.id;
    _realtimeChannel = Supabase.instance.client
        .channel('public:official_form_${reqId}_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'work_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: reqId,
          ),
          callback: (_) => _loadData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'e_signatures',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'work_request_id',
            value: reqId,
          ),
          callback: (_) => _loadData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pre_inspection_reports',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'work_request_id',
            value: reqId,
          ),
          callback: (_) => _loadData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'post_repair_reports',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'work_request_id',
            value: reqId,
          ),
          callback: (_) => _loadData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          callback: (_) => _loadData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'teacher_users',
          callback: (_) => _loadData(),
        )
        .subscribe();
  }

  Future<void> _loadData() async {
    try {
      final updated = await WorkRequestService.fetchById(widget.request.id);
      final sigs = await ESignatureService.fetchByWorkRequest(widget.request.id);

      // Process signatures into transparent versions in background
      final Map<String, Uint8List> cleanSigs = {};
      for (final s in sigs) {
        if (s.signatureData.isNotEmpty) {
          try {
            final cleanBase64 = s.signatureData.contains(',')
                ? s.signatureData.split(',').last.trim()
                : s.signatureData.trim();
            final rawBytes = base64Decode(cleanBase64);
            final cleanBytes = await SignatureImageHelper.removeBackground(rawBytes);
            cleanSigs[s.id] = cleanBytes;
          } catch (_) {}
        }
      }
      
      String? livePos;
      final reqId = updated?.requestorId ?? widget.request.requestorId;
      final reqName = updated?.requestorName ?? widget.request.requestorName;

      if (reqId != null && reqId.isNotEmpty) {
        try {
          final tRes = await Supabase.instance.client
              .from('teacher_users')
              .select('position')
              .eq('user_id', reqId)
              .maybeSingle();
          if (tRes != null && tRes['position'] != null && tRes['position'].toString().trim().isNotEmpty) {
            livePos = tRes['position'].toString().trim();
          }
        } catch (_) {}

        if (livePos == null) {
          try {
            final uRes = await Supabase.instance.client
                .from('users')
                .select('position, role')
                .eq('id', reqId)
                .maybeSingle();
            if (uRes != null) {
              if (uRes['position'] != null && uRes['position'].toString().trim().isNotEmpty) {
                livePos = uRes['position'].toString().trim();
              } else if (uRes['role'] != null) {
                final role = uRes['role'].toString().toLowerCase().trim();
                if (role == 'campadmin' || role == 'campus admin') {
                  livePos = 'Campus Administrator';
                } else if (role == 'admin') {
                  livePos = 'System Administrator';
                }
              }
            }
          } catch (_) {}
        }
      }

      // If still not resolved, attempt lookup by requestor name
      if (livePos == null && reqName.trim().isNotEmpty) {
        try {
          final uRes = await Supabase.instance.client
              .from('users')
              .select('position, role')
              .ilike('name', reqName.trim())
              .maybeSingle();
          if (uRes != null) {
            if (uRes['position'] != null && uRes['position'].toString().trim().isNotEmpty) {
              livePos = uRes['position'].toString().trim();
            } else if (uRes['role'] != null) {
              final role = uRes['role'].toString().toLowerCase().trim();
              if (role == 'campadmin' || role == 'campus admin') {
                livePos = 'Campus Administrator';
              } else if (role == 'admin') {
                livePos = 'System Administrator';
              }
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          if (updated != null) {
            _currentRequest = updated;
          }
          _signatures = sigs;
          _transparentSignatureCache = cleanSigs;
          _requestorLivePosition = livePos;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _effectiveRequestorPosition {
    if (_requestorLivePosition != null && _requestorLivePosition!.trim().isNotEmpty) {
      return _requestorLivePosition!.trim();
    }
    final reqPos = _currentRequest.requestorPosition.trim();
    if (reqPos.isNotEmpty && reqPos != 'Faculty Member / Requestor') {
      return reqPos;
    }
    final reqName = _currentRequest.requestorName.toLowerCase();
    if (reqName.contains('campus admin') || reqName.contains('campadmin')) {
      return 'Campus Administrator';
    }
    if (reqName.contains('system admin') || reqName.contains('admin')) {
      return 'Campus Administrator';
    }
    return reqPos.isNotEmpty ? reqPos : 'Faculty Member / Requestor';
  }

  void _printForm() async {
    try {
      final pdfBytes = await IsoPdfService.generateWorkRequestPdf(_currentRequest);
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'Work_Request_Forms_${_currentRequest.formattedId}',
        format: IsoPdfService.standardPortraitFormat,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing form: $e'), backgroundColor: AdminStyles.error),
        );
      }
    }
  }

  void _savePdfFile() async {
    try {
      final pdfBytes = await IsoPdfService.generateWorkRequestPdf(_currentRequest);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Work_Request_Forms_${_currentRequest.formattedId}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PDF file: $e'), backgroundColor: AdminStyles.error),
        );
      }
    }
  }

  Widget _buildSignatureColumn(
    String roleKey,
    String headerLabel,
    String footerLabel, {
    String? extraLabel,
    String? extraVal,
    String? dateLabel,
    DateTime? dateVal,
  }) {
    final request = _currentRequest;
    final isCompleted = request.status.trim().toLowerCase() == 'completed';
    
    ESignature? sig;
    String printName = '';
    DateTime? effectiveDate;
    
    if (roleKey == 'requestor') {
      sig = _signatures.where((s) {
        final role = s.signerRole.toLowerCase();
        final type = s.signatureType.toLowerCase();
        return (role == 'teacher' || role == 'faculty' || role == 'requestor') ||
               (type == 'requestor' || type == 'request' || type == 'submission');
      }).firstOrNull;
      printName = sig?.signerName ?? request.requestorName;
      effectiveDate = dateVal ?? sig?.signedAt ?? request.createdAt ?? request.dateSubmitted;
    } else if (roleKey == 'admin' || roleKey == 'approved' || roleKey == 'admin_approval') {
      sig = _signatures.where((s) =>
        (s.signerRole.toLowerCase() == 'admin' || s.signerRole.toLowerCase() == 'campadmin' || s.signerRole.toLowerCase() == 'campus admin') &&
        (s.signatureType.toLowerCase() == 'approval' || s.signatureType.toLowerCase() == 'admin')
      ).firstOrNull;
      final isApproved = sig != null || (request.approvedDate != null) || (request.approvedByName != null && request.approvedByName!.isNotEmpty);
      if (isApproved) {
        printName = sig?.signerName ?? request.approvedByName ?? '';
        effectiveDate = dateVal ?? sig?.signedAt ?? request.approvedDate;
      } else {
        printName = '';
        effectiveDate = null;
      }
    } else if (roleKey == 'monitored_evaluated' || roleKey == 'admin_confirmation') {
      // Campus admin pre-inspection review & evaluation signature on Confirm Form (Form 2)
      // 1. Check for explicit pre-inspection approval / review signature by admin
      sig = _signatures.where((s) {
        final role = s.signerRole.toLowerCase();
        final type = s.signatureType.toLowerCase();
        final isAdmin = role == 'admin' || role == 'campadmin' || role == 'campus admin';
        final isPreAdmin = type == 'pre_inspection_approval' ||
            type == 'pre_inspection_admin' ||
            type == 'pre_inspection_review' ||
            (type == 'pre_inspection' && isAdmin);
        final hasPreNotes = s.notes?.toLowerCase().contains('pre') == true &&
            s.notes?.toLowerCase().contains('inspect') == true;
        return isAdmin && (isPreAdmin || hasPreNotes);
      }).firstOrNull;

      // 2. Check for completion / confirmation / evaluation signature
      sig ??= _signatures.where((s) {
        final role = s.signerRole.toLowerCase();
        final type = s.signatureType.toLowerCase();
        final isAdmin = role == 'admin' || role == 'campadmin' || role == 'campus admin';
        final isConfirm = type == 'completion' || type == 'confirmation' || type == 'evaluation';
        return isAdmin && isConfirm;
      }).firstOrNull;

      // 3. If pre-inspection review approval was saved as 'approval' by admin
      if (sig == null) {
        final adminApprovals = _signatures.where((s) {
          final role = s.signerRole.toLowerCase();
          final type = s.signatureType.toLowerCase();
          final isAdmin = role == 'admin' || role == 'campadmin' || role == 'campus admin';
          return isAdmin && (type == 'approval' || type == 'admin');
        }).toList();

        if (adminApprovals.length > 1) {
          // Later approval is from pre-inspection review
          sig = adminApprovals.last;
        } else if (adminApprovals.length == 1) {
          // If 1 approval exists, check if request is in maintenance / pre-inspection reviewed / completed
          final statusLower = request.status.trim().toLowerCase();
          final hasPreInspection = request.preInspectionId != null;
          final isPastApproval = statusLower != 'pending' && statusLower != 'approved';
          if (hasPreInspection || isPastApproval || isCompleted) {
            sig = adminApprovals.first;
          }
        }
      }

      if (sig != null) {
        printName = sig.signerName;
        effectiveDate = dateVal ?? sig.signedAt;
      } else if (request.approvedByName != null && request.approvedByName!.isNotEmpty) {
        printName = request.approvedByName!;
        effectiveDate = dateVal ?? request.dateCompleted ?? request.approvedDate;
      } else {
        printName = '';
        effectiveDate = null;
      }
    } else if (roleKey == 'form1_maintenance' || roleKey == 'acceptance' || (roleKey == 'accomplished' && _selectedPage == 0)) {
      // Form 1 (Work Request Form): Maintenance task acceptance signature
      // Displayed when the maintenance technician accepts the work request
      sig = _signatures.where((s) {
        final role = s.signerRole.toLowerCase();
        final type = s.signatureType.toLowerCase();
        final isMaint = role == 'maintenance' || role == 'technician' || role == 'staff';
        final isAccept = type == 'acceptance' || type == 'task_acceptance';
        return isAccept && (isMaint || role.isNotEmpty);
      }).firstOrNull;

      if (sig != null) {
        printName = sig.signerName;
        effectiveDate = dateVal ?? sig.signedAt;
      } else if (request.acceptedByName != null && request.acceptedByName!.trim().isNotEmpty) {
        printName = request.acceptedByName!.trim();
        effectiveDate = dateVal ?? request.acceptedDate;
      } else {
        printName = '';
        effectiveDate = null;
      }
    } else if (roleKey == 'form2_maintenance' || roleKey == 'pre_inspection' || (roleKey == 'accomplished' && _selectedPage == 1)) {
      // Form 2 (Confirm Form): Maintenance pre-inspection signature
      // Displayed when the maintenance technician submits the pre-inspection report
      sig = _signatures.where((s) {
        final role = s.signerRole.toLowerCase();
        final type = s.signatureType.toLowerCase();
        final isMaint = role == 'maintenance' || role == 'technician' || role == 'staff';
        final isPre = type == 'pre_inspection';
        return isPre && (isMaint || role.isNotEmpty);
      }).firstOrNull;

      // Fallback: If pre-inspection signature not found, check post-repair / completion accomplishment
      sig ??= _signatures.where((s) {
        final role = s.signerRole.toLowerCase();
        final type = s.signatureType.toLowerCase();
        final isMaint = role == 'maintenance' || role == 'technician' || role == 'staff';
        final isAccomplished = type == 'completion' || type == 'accomplished' || type == 'post_repair';
        return isMaint && isAccomplished;
      }).firstOrNull;

      if (sig != null) {
        printName = sig.signerName;
        effectiveDate = dateVal ?? sig.signedAt;
      } else if (request.acceptedByName != null && request.acceptedByName!.trim().isNotEmpty) {
        printName = request.acceptedByName!.trim();
        effectiveDate = dateVal ?? (isCompleted ? (request.dateCompleted ?? request.maintenanceEndTime) : request.acceptedDate);
      } else {
        printName = '';
        effectiveDate = null;
      }
    }

    Uint8List? bytes;
    if (sig != null) {
      bytes = _transparentSignatureCache[sig.id];
      if (bytes == null && sig.signatureData.isNotEmpty) {
        try {
          final cleanBase64 = sig.signatureData.contains(',')
              ? sig.signatureData.split(',').last
              : sig.signatureData;
          bytes = base64Decode(cleanBase64.trim());
        } catch (_) {}
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            headerLabel,
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 30,
                  alignment: Alignment.bottomCenter,
                  child: bytes != null
                      ? Image.memory(bytes, fit: BoxFit.contain)
                      : const SizedBox(),
                ),
                const SizedBox(height: 2),
                Text(
                  printName.isNotEmpty ? printName : ' ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 165,
                  height: 1.5,
                  color: Colors.black,
                ),
                const SizedBox(height: 2),
                Text(
                  footerLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 8,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          if (dateLabel != null)
            Row(
              children: [
                Text(
                  '$dateLabel: ',
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 1),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
                    ),
                    child: Text(
                      effectiveDate != null ? DateFormat('dd-MMM-yyyy').format(effectiveDate) : '',
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (extraLabel != null)
            Row(
              children: [
                Text(
                  '$extraLabel: ',
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 1),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
                    ),
                    child: Text(
                      extraVal ?? '',
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCheckline(String label, bool isChecked, String underlineText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1.5),
            ),
            child: isChecked
                ? const Center(
                    child: Text(
                      'X',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 175,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'Courier',
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(bottom: 2),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
              ),
              child: Text(
                isChecked ? underlineText : '',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkRequestForm(WorkRequest request, bool isOcular, bool isInstall, bool isRepair, bool isReplace, bool isOthers, String specifyVal) {
    return Container(
      width: 1040,
      height: 650,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ROW 1: Header Row (Logo, Title, ISO Code)
          Container(
            height: 90,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo cell
                Container(
                  width: 140,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.black, width: 2)),
                  ),
                  child: Image.asset(
                    'assets/images/PsuLogo.png',
                    width: 68,
                    height: 68,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.school, size: 48, color: Colors.black),
                  ),
                ),
                // Title cell
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.black, width: 2)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'WORK REQUEST FORM',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'PANGASINAN STATE UNIVERSITY',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ISO cell
                Container(
                  width: 180,
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('FM-AD-ENG-02', style: TextStyle(fontFamily: 'Courier', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                      Text('Rev. 0', style: TextStyle(fontFamily: 'Courier', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                      Text('03-Oct-2017', style: TextStyle(fontFamily: 'Courier', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ROW 2: Date Row
          Container(
            height: 38,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Text('DATE :', style: TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(width: 12),
                Text(
                  DateFormat('dd-MMM-yyyy').format(request.createdAt ?? request.dateSubmitted),
                  style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const Spacer(),
                Text(
                  '20${DateFormat('yy - MM - dd').format(request.createdAt ?? request.dateSubmitted)}',
                  style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          // ROW 3: Campus & Department Row
          Container(
            height: 38,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12),
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.black, width: 2)),
                    ),
                    child: const Text(
                      'CAMPUS : SAN CARLOS CITY',
                      style: TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'DEPARTMENT: ${request.departmentName ?? ""}',
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ROW 4: Building & Room Row
          Container(
            height: 38,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12),
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.black, width: 2)),
                    ),
                    child: Text(
                      'BUILDING NAME : ${request.buildingName ?? ""}',
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'NAME OF OFFICE / ROOM : ${request.roomName ?? ""}',
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ROW 5: Work Request Details Row (Checklist)
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WORK REQUEST :',
                    style: TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 620,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCheckline('Ocular inspection of', isOcular, specifyVal),
                            _buildCheckline('Installation of', isInstall, specifyVal),
                            _buildCheckline('Repair of', isRepair, specifyVal),
                            _buildCheckline('Replacement of', isReplace, specifyVal),
                            _buildCheckline('Others (specify)', isOthers, specifyVal),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ROW 6: Footer Signatures Row
          Expanded(
            flex: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Requestor Column
                Expanded(
                  flex: 6,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.black, width: 2)),
                    ),
                    child: _buildSignatureColumn(
                      'requestor',
                      'Requestor :',
                      'Signature over Printed Name',
                      extraLabel: 'Position / Designation',
                      extraVal: _effectiveRequestorPosition,
                    ),
                  ),
                ),
                // Approved by Column
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.black, width: 2)),
                    ),
                    child: _buildSignatureColumn(
                      'admin',
                      'Approved by :',
                      'Signature over Printed Name',
                      dateLabel: 'Date',
                      dateVal: request.approvedDate,
                    ),
                  ),
                ),
                // Accomplished by Column
                Expanded(
                  flex: 5,
                  child: _buildSignatureColumn(
                    'form1_maintenance',
                    'Work Request Accomplished by:',
                    'Signature over Printed Name',
                    dateLabel: 'Date',
                    dateVal: request.acceptedDate,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationForm(WorkRequest request, bool isOcular, bool isInstall, bool isRepair, bool isReplace, bool isOthers, String specifyVal) {
    return Container(
      width: 1040,
      height: 650,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ROW 1: Header Row
          Container(
            height: 90,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 140,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.black, width: 2)),
                  ),
                  child: Image.asset(
                    'assets/images/PsuLogo.png',
                    width: 68,
                    height: 68,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.school, size: 48, color: Colors.black),
                  ),
                ),
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'CONFIRM WORK REQUEST FORM',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'PANGASINAN STATE UNIVERSITY',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Office of the Physical Plant and Facilities',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ROW 2: Date Row
          Container(
            height: 38,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Text('DATE :', style: TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(width: 12),
                Text(
                  DateFormat('dd-MMM-yyyy').format(request.dateCompleted ?? request.createdAt ?? request.dateSubmitted),
                  style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const Spacer(),
                Text(
                  '20${DateFormat('yy - MM - dd').format(request.dateCompleted ?? request.createdAt ?? request.dateSubmitted)}',
                  style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          // ROW 3: Campus & Department Row
          Container(
            height: 38,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12),
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.black, width: 2)),
                    ),
                    child: const Text(
                      'CAMPUS : SAN CARLOS CITY',
                      style: TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'DEPARTMENT: ${request.departmentName ?? ""}',
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ROW 4: Building & Room Row
          Container(
            height: 38,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12),
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.black, width: 2)),
                    ),
                    child: Text(
                      'BUILDING NAME : ${request.buildingName ?? ""}',
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'NAME OF OFFICE / ROOM : ${request.roomName ?? ""}',
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ROW 5: Work Request Details Row (Checklist)
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WORK REQUEST :',
                    style: TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 620,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCheckline('Ocular inspection of', isOcular, specifyVal),
                            _buildCheckline('Installation of', isInstall, specifyVal),
                            _buildCheckline('Repair of', isRepair, specifyVal),
                            _buildCheckline('Replacement of', isReplace, specifyVal),
                            _buildCheckline('Others (specify)', isOthers, specifyVal),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ROW 6: Footer Signatures Row
          Expanded(
            flex: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.black, width: 2)),
                    ),
                    child: _buildSignatureColumn(
                      'form2_maintenance',
                      'Work Request Accomplished by:',
                      'Signature over Printed Name',
                      dateLabel: 'Date',
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.black, width: 2)),
                    ),
                    child: _buildSignatureColumn(
                      'requestor',
                      'Requestor:',
                      'Signature over Printed Name',
                      extraLabel: 'Position / Designation',
                      extraVal: _effectiveRequestorPosition,
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: _buildSignatureColumn(
                    'monitored_evaluated',
                    'Monitored and Evaluated by:',
                    'Signature over Printed Name',
                    dateLabel: 'Date',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _resolveFormChecklist(WorkRequest request) {
    String primaryType = request.typeDisplay.trim();
    if (primaryType.isEmpty) {
      primaryType = request.typeOfRequest.trim();
    }
    final rawTitle = request.title.trim();

    String strippedTitle = rawTitle;
    if (strippedTitle.toLowerCase().startsWith('maintenance:')) {
      strippedTitle = strippedTitle.substring('maintenance:'.length).trim();
    }

    final pLower = primaryType.toLowerCase();
    final tLower = strippedTitle.toLowerCase();

    bool isOcular = false;
    bool isInstall = false;
    bool isRepair = false;
    bool isReplace = false;

    // Check primaryType first (e.g. "Replacement of", "Installation of", "Repair of", "Ocular inspection of")
    if (pLower.contains('ocular') || pLower.contains('inspection')) {
      isOcular = true;
    } else if (pLower.contains('install')) {
      isInstall = true;
    } else if (pLower.contains('repair') || pLower.contains('fix')) {
      isRepair = true;
    } else if (pLower.contains('replace')) {
      isReplace = true;
    } else if (tLower.startsWith('ocular') || tLower.contains('inspection of')) {
      isOcular = true;
    } else if (tLower.startsWith('installation') || tLower.contains('installation of')) {
      isInstall = true;
    } else if (tLower.startsWith('repair') || tLower.contains('repair of')) {
      isRepair = true;
    } else if (tLower.startsWith('replacement') || tLower.contains('replacement of')) {
      isReplace = true;
    }

    final isOthers = !isOcular && !isInstall && !isRepair && !isReplace;

    // Resolve specifyVal to put on the active line
    String specifyVal = request.specifyText.trim();
    if (specifyVal.isEmpty && strippedTitle.contains(':')) {
      specifyVal = strippedTitle.split(':').last.trim();
    }
    if (specifyVal.isEmpty && request.typeOfRequest.contains(':')) {
      specifyVal = request.typeOfRequest.split(':').last.trim();
    }
    if (specifyVal.isEmpty && isOthers) {
      if (primaryType.isNotEmpty && primaryType.toLowerCase() != 'others') {
        specifyVal = primaryType;
      } else {
        specifyVal = request.description.trim();
      }
    }
    if (specifyVal.isEmpty) {
      specifyVal = request.description.trim();
    }

    return {
      'isOcular': isOcular,
      'isInstall': isInstall,
      'isRepair': isRepair,
      'isReplace': isReplace,
      'isOthers': isOthers,
      'specifyVal': specifyVal,
    };
  }

  @override
  Widget build(BuildContext context) {
    final request = _currentRequest;
    final checklist = _resolveFormChecklist(request);
    final bool isOcular = checklist['isOcular'] as bool;
    final bool isInstall = checklist['isInstall'] as bool;
    final bool isRepair = checklist['isRepair'] as bool;
    final bool isReplace = checklist['isReplace'] as bool;
    final bool isOthers = checklist['isOthers'] as bool;
    final String specifyVal = checklist['specifyVal'] as String;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1150, maxHeight: 850),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Toolbar header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded, color: Color(0xFF00BFA5), size: 20),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _selectedPage = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedPage == 0 ? const Color(0xFF00BFA5) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '1. Work Request Form',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => setState(() => _selectedPage = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedPage == 1 ? const Color(0xFF00BFA5) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '2. Confirm Form',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _savePdfFile,
                    icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                    label: const Text('Save / Download PDF File', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF00BFA5), width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _printForm,
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Print Form', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // The sheet container
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BFA5)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: FittedBox(
                          child: _selectedPage == 0
                              ? _buildWorkRequestForm(request, isOcular, isInstall, isRepair, isReplace, isOthers, specifyVal)
                              : _buildConfirmationForm(request, isOcular, isInstall, isRepair, isReplace, isOthers, specifyVal),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

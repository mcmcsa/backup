import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../shared/services/post_repair_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/inspection_pdf_service.dart';
import '../../../shared/services/user_service.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/signature_pad_widget.dart';

/// Admin screen to evaluate post-repair report - mark completed or rework
class AdminPostRepairEvaluationPage extends StatefulWidget {
  final WorkRequest request;
  const AdminPostRepairEvaluationPage({super.key, required this.request});
  @override
  State<AdminPostRepairEvaluationPage> createState() =>
      _AdminPostRepairEvaluationPageState();
}

class _AdminPostRepairEvaluationPageState
    extends State<AdminPostRepairEvaluationPage> {
  bool _isLoading = true;
  bool _isProcessing = false;
  // ignore: unused_field
  PostRepairReport? _report;
  final _reworkNotesController = TextEditingController();
  int _selectedAttemptIndex = 0;
  bool _showReworkInput = false;
  List<PostRepairReport> _history = [];
  List<ESignature> _signatures = [];
  final Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final history = await PostRepairService.fetchByWorkRequest(widget.request.id);
      final signatures = await ESignatureService.fetchByWorkRequest(widget.request.id);
      for (final sig in signatures) {
        if (sig.signerId.isNotEmpty && sig.signerName.isNotEmpty) {
          _userNames[sig.signerId] = sig.signerName;
        }
      }
      final userIds = <String>{};
      for (final r in history) {
        if (r.adminEvaluatedBy != null && r.adminEvaluatedBy!.isNotEmpty) userIds.add(r.adminEvaluatedBy!);
        if (r.technicianId.isNotEmpty) userIds.add(r.technicianId);
      }
      final missing = userIds.where((id) => !_userNames.containsKey(id)).toList();
      if (missing.isNotEmpty) { final names = await UserService.fetchNamesByIds(missing); _userNames.addAll(names); }
      if (mounted) {
        final sorted = List<PostRepairReport>.from(history)..sort((a, b) => b.attemptNumber.compareTo(a.attemptNumber));
        setState(() { _history = sorted; _report = sorted.isNotEmpty ? sorted.first : null; _signatures = signatures; _isLoading = false; _selectedAttemptIndex = 0; });
      }
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  void dispose() { _reworkNotesController.dispose(); super.dispose(); }

  void _openCompletionSignatureDialog(PostRepairReport report) {
    showDialog<String>(context: context, barrierDismissible: false, builder: (ctx) => Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [SignaturePadWidget(title: 'E-Signature Required', subtitle: 'Sign to confirm work completion approval', onSignatureComplete: (base64) { Navigator.pop(ctx, base64); }), TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))))]))))
        .then((signature) { if (signature != null && signature.isNotEmpty) { _markCompletedWithSignature(report, signature); } });
  }

  Future<void> _markCompletedWithSignature(PostRepairReport report, String signatureData) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;
    setState(() => _isProcessing = true);
    try {
      await ESignatureService.insert(ESignature(id: '', workRequestId: widget.request.id, signerId: user.id, signerName: user.name, signerRole: 'campadmin', signatureType: 'completion', signatureData: signatureData, signedAt: DateTime.now()));
      await PostRepairService.markSatisfied(report.id, user.id);
      await WorkRequestService.updateStatus(widget.request.id, 'Completed');
      await AppNotificationService.notifyAdminCompletionSubmittedToRequestor(workRequestId: widget.request.id, adminName: user.name, requestorId: widget.request.requestorId);
      await AppNotificationService.notifyPostRepairCompleted(workRequestId: widget.request.id, maintenanceId: widget.request.assignedToId ?? report.technicianId, adminName: user.name);
      await LoginActivityService.recordAdminAction(user: user, title: 'Post-Repair Completed', details: 'Marked request as completed with signature for ', workRequestId: widget.request.id);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post-repair approved. Work request completed successfully.'), backgroundColor: Color(0xFF059669))); Navigator.pop(context, 'completed'); }
    } catch (e) { if (mounted) { setState(() => _isProcessing = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: '), backgroundColor: Colors.red)); } }
  }

  Future<void> _markRework(PostRepairReport report) async {
    final notes = _reworkNotesController.text.trim();
    if (notes.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide rework notes'), backgroundColor: Colors.orange)); return; }
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;
    setState(() => _isProcessing = true);
    try {
      await PostRepairService.markRework(report.id, user.id, notes);
      await WorkRequestService.setRework(widget.request.id, notes);
      await AppNotificationService.notifyPostRepairRework(workRequestId: widget.request.id, maintenanceId: widget.request.assignedToId ?? report.technicianId, adminName: user.name);
      await LoginActivityService.recordAdminAction(user: user, title: 'Post-Repair Rework', details: 'Returned request to rework for ', workRequestId: widget.request.id);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work request sent back for rework'), backgroundColor: Color(0xFFDC2626))); Navigator.pop(context, 'rework'); }
    } catch (e) { if (mounted) { setState(() => _isProcessing = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: '), backgroundColor: Colors.red)); } }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: themeProvider.backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Post-Repair Evaluation',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4169E1)))
          : _history.isEmpty
              ? _buildWaitingState(themeProvider)
              : Column(
                  children: [
                    if (_history.length > 1)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: themeProvider.cardColor,
                          border: Border(
                            bottom: BorderSide(color: themeProvider.borderColor, width: 1),
                          ),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: List.generate(_history.length, (i) {
                              final rep = _history[i];
                              final isSel = _selectedAttemptIndex == i;
                              final isCompleted = rep.status.toLowerCase() == 'completed' ||
                                  rep.adminEvaluation == 'satisfied';
                              final isRework = rep.status.toLowerCase() == 'rework' ||
                                  rep.adminEvaluation == 'rework';
                              final badgeColor = isCompleted
                                  ? const Color(0xFF059669)
                                  : (isRework ? const Color(0xFFDC2626) : Colors.orange);
                              return Padding(
                                padding: EdgeInsets.only(right: i < _history.length - 1 ? 10 : 0),
                                child: InkWell(
                                  onTap: () => setState(() {
                                    _selectedAttemptIndex = i;
                                    _showReworkInput = false;
                                    _reworkNotesController.clear();
                                  }),
                                  borderRadius: BorderRadius.circular(24),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSel
                                          ? const Color(0xFF4169E1)
                                          : (themeProvider.isDarkMode
                                              ? Colors.white.withValues(alpha: 0.06)
                                              : Colors.grey.shade100),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isSel ? const Color(0xFF4169E1) : themeProvider.borderColor,
                                        width: 1.5,
                                      ),
                                      boxShadow: isSel
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF4169E1).withValues(alpha: 0.3),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Attempt #${rep.attemptNumber}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                                            color: isSel ? Colors.white : themeProvider.textColor,
                                          ),
                                        ),
                                        if (i == 0) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isSel ? Colors.white.withValues(alpha: 0.25) : badgeColor,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'LATEST',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    Expanded(child: _buildAttemptCard(_history[_selectedAttemptIndex], themeProvider)),
                  ],
                ),
    );
  }

  Widget _buildWaitingState(ThemeProvider themeProvider) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: themeProvider.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: themeProvider.borderColor),
              ),
              child: Column(
                children: [
                  const Icon(Icons.hourglass_top_rounded, size: 48, color: Color(0xFF4169E1)),
                  const SizedBox(height: 16),
                  Text(
                    'Waiting for Post Inspection Report',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The assigned maintenance technician has not yet submitted a post-repair inspection report for this request. Please check back once repairs are completed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: themeProvider.subtitleColor,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'PENDING SUBMISSION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSection('WORK REQUEST DETAILS', [
              _buildInfoRow('Request ID', '#${widget.request.id.split('-').last}', themeProvider),
              _buildInfoRow('Title', widget.request.title, themeProvider),
              _buildInfoRow('Location', widget.request.officeRoom ?? 'N/A', themeProvider),
              _buildInfoRow('Status', widget.request.statusLabel, themeProvider),
            ], themeProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildAttemptCard(PostRepairReport report, ThemeProvider themeProvider) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final isAdmin = user?.role.name == 'campadmin' || user?.role.name == 'admin';
    final showActions = _selectedAttemptIndex == 0 && isAdmin && report.status.toLowerCase() == 'pending';
    final adminSig = _signatures.firstWhere(
      (sig) => sig.signatureType == 'completion' && sig.signerId == report.adminEvaluatedBy,
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
    final evaluationSatisfied = report.adminEvaluation == 'satisfied';
    final isEvaluationMade = report.adminEvaluation != null;
    final rawEval = _userNames[report.adminEvaluatedBy] ?? report.adminEvaluatedBy;
    final evaluatorName = adminSig.signerName.isNotEmpty
        ? adminSig.signerName
        : ((rawEval != null && rawEval.length < 25 && !rawEval.contains('-'))
            ? rawEval
            : (_userNames[report.adminEvaluatedBy] ?? 'Campus Administrator'));
    final isCompletedReport = report.status.toLowerCase() == 'completed' || report.adminEvaluation == 'satisfied';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ATTEMPT #${report.attemptNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: report.status.toLowerCase() == 'completed'
                        ? const Color(0xFF059669)
                        : report.status.toLowerCase() == 'rework'
                            ? const Color(0xFFDC2626)
                            : Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    report.statusLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeProvider.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeProvider.borderColor),
            ),
            child: Column(
              children: [
                _buildInfoRow('Technician', report.technicianName, themeProvider),
                _buildInfoRow('Repair Date', _formatDate(report.repairDate), themeProvider),
                _buildInfoRow('Duration', report.repairDuration ?? 'Not recorded', themeProvider),
                _buildInfoRow('Repair Outcome Status', report.repairStatusLabel, themeProvider),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildSection(
            'WORK PERFORMED',
            [
              Text(
                report.workPerformed,
                style: TextStyle(
                  fontSize: 13,
                  color: themeProvider.textColor,
                  height: 1.5,
                ),
              ),
            ],
            themeProvider,
          ),
          const SizedBox(height: 12),
          _buildSection(
            'MATERIALS USED',
            [
              Text(
                report.materialsUsed?.isNotEmpty == true
                    ? report.materialsUsed!
                    : 'No materials recorded',
                style: TextStyle(
                  fontSize: 13,
                  color: themeProvider.textColor,
                  height: 1.5,
                ),
              ),
            ],
            themeProvider,
          ),
          const SizedBox(height: 12),
          if (report.technicianNotes?.isNotEmpty == true) ...[
            _buildSection(
              'TECHNICIAN NOTES',
              [
                Text(
                  report.technicianNotes!,
                  style: TextStyle(
                    fontSize: 13,
                    color: themeProvider.textColor,
                    height: 1.5,
                  ),
                ),
              ],
              themeProvider,
            ),
            const SizedBox(height: 12),
          ],
          if (showActions) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _report = report);
                      _openCompletionSignatureDialog(report);
                    },
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text(
                      'Work Completed',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _report = report;
                        _showReworkInput = !_showReworkInput;
                        if (!_showReworkInput) _reworkNotesController.clear();
                      });
                    },
                    icon: Icon(_showReworkInput ? Icons.close : Icons.refresh, size: 18),
                    label: Text(
                      _showReworkInput ? 'Cancel' : 'Rework',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            if (_showReworkInput) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REWORK NOTES *',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: themeProvider.subtitleColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reworkNotesController,
                      maxLines: 3,
                      autofocus: true,
                      style: TextStyle(color: themeProvider.textColor, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Describe what needs to be reworked...',
                        hintStyle: TextStyle(fontSize: 13, color: themeProvider.subtitleColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: themeProvider.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: themeProvider.borderColor),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                        filled: true,
                        fillColor: themeProvider.inputFillColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _report = report);
                          _markRework(report);
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text(
                          'Confirm Rework',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else if (isEvaluationMade) ...[
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: evaluationSatisfied
                    ? (themeProvider.isDarkMode
                        ? Colors.green.shade900.withValues(alpha: 0.2)
                        : Colors.green.shade50)
                    : (themeProvider.isDarkMode
                        ? Colors.red.shade900.withValues(alpha: 0.2)
                        : Colors.red.shade50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: evaluationSatisfied ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    evaluationSatisfied ? 'EVALUATION: SATISFIED' : 'EVALUATION: REWORK REQUIRED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: evaluationSatisfied ? Colors.green : Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('Evaluated By', evaluatorName, themeProvider),
                  _buildInfoRow(
                    'Evaluated Date',
                    _formatDate(report.adminEvaluatedDate ?? report.updatedAt),
                    themeProvider,
                  ),
                  if (report.adminEvaluationNotes != null)
                    _buildInfoRow('Evaluation Notes', report.adminEvaluationNotes!, themeProvider),
                  if (evaluationSatisfied && adminSig.signatureData.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Admin E-Signature:',
                      style: TextStyle(fontSize: 12, color: themeProvider.subtitleColor),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Center(
                        child: _buildSignatureImage(adminSig.signatureData),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (isCompletedReport) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  InspectionPdfService.printPostRepair(
                    context: context,
                    request: widget.request,
                    report: report,
                  );
                },
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text(
                  'Print Post-Repair Report',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSignatureImage(String base64Str) {
    try {
      final cleaned = base64Str.trim().replaceAll(RegExp(r'\s+'), '');
      final base64Data = cleaned.contains(',') ? cleaned.split(',')[1] : cleaned;
      return Image.memory(
        base64Decode(base64Data),
        height: 60,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.gesture, size: 40, color: Colors.grey),
      );
    } catch (_) {
      return const Icon(Icons.gesture, size: 40, color: Colors.grey);
    }
  }

  Widget _buildSection(String title, List<Widget> children, [ThemeProvider? themeProvider]) {
    final tp = themeProvider ?? Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tp.isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tp.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: tp.subtitleColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [ThemeProvider? themeProvider]) {
    final tp = themeProvider ?? Provider.of<ThemeProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: TextStyle(fontSize: 12, color: tp.subtitleColor)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tp.textColor),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }
}

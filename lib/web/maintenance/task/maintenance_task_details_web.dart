import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/signature_pad_widget.dart';
import '../../admin/shared/admin_styles.dart';
import 'maintenance_accept_task_web.dart';

class MaintenanceTaskDetailsWeb extends StatefulWidget {
  final WorkRequest task;

  const MaintenanceTaskDetailsWeb({super.key, required this.task});

  @override
  State<MaintenanceTaskDetailsWeb> createState() => _MaintenanceTaskDetailsWebState();
}

class _MaintenanceTaskDetailsWebState extends State<MaintenanceTaskDetailsWeb> {
  WorkRequest? _currentTask;
  List<ESignature> _signatures = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  
  // Confirmation form state
  final _noteController = TextEditingController();
  XFile? _evidenceImage;
  bool _isUploadingEvidence = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final task = await WorkRequestService.fetchById(widget.task.id);
      final sigs = await ESignatureService.fetchByWorkRequest(widget.task.id);
      if (mounted) {
        setState(() {
          _currentTask = task ?? widget.task;
          _signatures = sigs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // --- LOGIC PORTED FROM MOBILE ---

  bool get _isAssignedToMe {
    final user = context.read<AuthService>().currentUser;
    return _currentTask?.assignedToId == user?.id;
  }

  bool get _canStart {
    if (_currentTask == null) return false;
    final status = _currentTask!.status.toLowerCase();
    return _isAssignedToMe && 
           _currentTask!.acceptedDate == null && 
           (status == 'approved' || status == 'under_maintenance');
  }

  bool get _canComplete {
    if (_currentTask == null) return false;
    final status = _currentTask!.status.toLowerCase();
    return _isAssignedToMe && 
           _currentTask!.acceptedDate != null && 
           status != 'completed';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _evidenceImage = image);
    }
  }

  Future<String> _uploadWorkEvidenceImage({
    required String requestId,
    required XFile imageFile,
  }) async {
    final client = Supabase.instance.client;
    final bytes = await imageFile.readAsBytes();
    final extension = imageFile.name.contains('.')
        ? imageFile.name.split('.').last
        : 'jpg';
    final path =
        'work-evidence/$requestId/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await client.storage.from('work-evidence').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return client.storage.from('work-evidence').getPublicUrl(path);
  }

  Future<void> _handleCompletion(String signatureData) async {
    if (_evidenceImage == null && _currentTask?.workEvidence == null) {
      _showWarning('Please attach a work evidence image first.');
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null || _currentTask == null) return;

    setState(() => _isProcessing = true);

    try {
      String? evidenceUrl = _currentTask!.workEvidence;
      
      // 1. Upload image if new
      if (_evidenceImage != null) {
        setState(() => _isUploadingEvidence = true);
        try {
          evidenceUrl = await _uploadWorkEvidenceImage(
            requestId: _currentTask!.id,
            imageFile: _evidenceImage!,
          );
          await WorkRequestService.updateWorkEvidence(_currentTask!.id, evidenceUrl);
        } finally {
          if (mounted) setState(() => _isUploadingEvidence = false);
        }
      }

      // 2. Update note
      if (_noteController.text.isNotEmpty) {
        await WorkRequestService.updateMaintenanceNote(_currentTask!.id, _noteController.text);
      }

      // 3. Save signature
      final signature = ESignature(
        id: '',
        workRequestId: _currentTask!.id,
        signerId: user.id,
        signerName: user.name,
        signerRole: 'maintenance',
        signatureType: 'completion',
        signatureData: signatureData,
        signedAt: DateTime.now(),
      );
      await ESignatureService.insert(signature);

      // 4. Update status and notify
      await WorkRequestService.updateStatus(_currentTask!.id, 'under_maintenance');
      await AppNotificationService.notifyCompletionSubmittedToAdmin(
        workRequestId: _currentTask!.id,
        maintenanceName: user.name,
        adminId: _currentTask!.approvedById,
      );

      _showSuccess('Work completion report submitted.');
      _loadData();
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminStyles.bg,
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary))
              : _isProcessing
                ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Task info
                        Expanded(flex: 6, child: _buildTaskDetailedView()),
                        const SizedBox(width: 32),
                        // Right: Actions & Flow
                        Expanded(flex: 4, child: _buildActionColumn()),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: AdminStyles.surface,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AdminStyles.border))),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AdminStyles.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          Text('Task Execution', style: AdminStyles.headingStyle(fontSize: 20)),
          const Spacer(),
          _buildStatusBadge(),
        ],
      ),
    );
  }

  Widget _buildTaskDetailedView() {
    final task = _currentTask!;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: AdminStyles.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Problem Description', style: AdminStyles.headingStyle(fontSize: 18)),
                  if (task.reworkCount > 0) 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AdminStyles.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('${task.reworkCount} REWORK(S)', style: AdminStyles.headingStyle(fontSize: 11, color: AdminStyles.error)),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: AdminStyles.bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AdminStyles.border)),
                child: Text(task.description, style: AdminStyles.bodyStyle(fontSize: 15, height: 1.6)),
              ),
              const SizedBox(height: 40),
              Text('Location Details', style: AdminStyles.headingStyle(fontSize: 18)),
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildLocationChip(Icons.business_rounded, task.buildingName ?? 'Main Building'),
                  const SizedBox(width: 16),
                  _buildLocationChip(Icons.meeting_room_rounded, task.roomName ?? 'Room N/A'),
                  const SizedBox(width: 16),
                  _buildLocationChip(Icons.category_rounded, task.typeOfRequest),
                ],
              ),
              if (task.workEvidence != null) ...[
                const SizedBox(height: 40),
                Text('Work Evidence', style: AdminStyles.headingStyle(fontSize: 18)),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(task.workEvidence!, height: 300, width: double.infinity, fit: BoxFit.cover),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildSignaturesCard(),
      ],
    );
  }

  Widget _buildLocationChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: AdminStyles.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminStyles.primary.withValues(alpha: 0.1))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AdminStyles.primary),
          const SizedBox(width: 10),
          Text(label, style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminStyles.primary)),
        ],
      ),
    );
  }

  Widget _buildSignaturesCard() {
    if (_signatures.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Process Signatures', style: AdminStyles.headingStyle(fontSize: 18)),
          const SizedBox(height: 24),
          ..._signatures.map((sig) => _buildSignatureListItem(sig)),
        ],
      ),
    );
  }

  Widget _buildSignatureListItem(ESignature sig) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AdminStyles.success.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.verified_rounded, color: AdminStyles.success, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sig.signerName, style: AdminStyles.headingStyle(fontSize: 14)),
                Text('${sig.signatureType.toUpperCase()} • ${DateFormat('MMM dd, yyyy HH:mm').format(sig.signedAt)}', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionColumn() {
    return Column(
      children: [
        if (_canStart) _buildStartActionCard(),
        if (_canComplete) _buildCompletionActionCard(),
        if (!_canStart && !_canComplete) _buildCurrentStatusCard(),
        const SizedBox(height: 24),
        _buildTaskSummaryCard(),
      ],
    );
  }

  Widget _buildStartActionCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.not_started_rounded, color: AdminStyles.primary, size: 48),
          const SizedBox(height: 24),
          Text('Ready to Start?', style: AdminStyles.headingStyle(fontSize: 18)),
          const SizedBox(height: 12),
          Text('You are assigned to this task. Please acknowledge and sign to officially begin the maintenance work.', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => MaintenanceAcceptTaskWeb(task: _currentTask!)));
                if (result == true) _loadData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AdminStyles.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Go to Acceptance Page'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionActionCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Submit Completion Report', style: AdminStyles.headingStyle(fontSize: 18)),
          const SizedBox(height: 24),
          _buildEvidencePicker(),
          if (_isUploadingEvidence) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(color: AdminStyles.primary),
          ],
          const SizedBox(height: 24),
          _buildWebTextField(_noteController, 'Maintenance Notes', 'Describe findings or work performed...', maxLines: 4),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 32),
          SignaturePadWidget(
            title: 'Completion Signature',
            subtitle: 'Sign to confirm work is finished',
            onSignatureComplete: _handleCompletion,
          ),
        ],
      ),
    );
  }

  Widget _buildEvidencePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Work Evidence Photo (Mandatory)', style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_evidenceImage != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _evidenceImage!.path,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(top: 8, right: 8, child: IconButton(onPressed: () => setState(() => _evidenceImage = null), icon: const Icon(Icons.cancel_rounded, color: Colors.white))),
            ],
          )
        else
          InkWell(
            onTap: _pickImage,
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(color: AdminStyles.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminStyles.border, style: BorderStyle.solid)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_rounded, color: AdminStyles.primary),
                  const SizedBox(height: 8),
                  Text('Upload Evidence Image', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.primary)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentStatusCard() {
    final status = _currentTask!.status;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusIcon(status),
          const SizedBox(height: 24),
          Text(_getStatusTitle(status), style: AdminStyles.headingStyle(fontSize: 18)),
          const SizedBox(height: 12),
          Text(_getStatusDesc(status), style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTaskSummaryCard() {
    final task = _currentTask!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reference Data', style: AdminStyles.headingStyle(fontSize: 14, color: AdminStyles.textSecondary)),
          const SizedBox(height: 24),
          _buildSummaryRow('Requestor', task.requestorName),
          _buildSummaryRow('Submitted', DateFormat('MMM dd, yyyy').format(task.dateSubmitted)),
          if (task.acceptedDate != null) _buildSummaryRow('Started', DateFormat('MMM dd, HH:mm').format(task.acceptedDate!)),
          if (task.dateCompleted != null) _buildSummaryRow('Completed', DateFormat('MMM dd, HH:mm').format(task.dateCompleted!)),
        ],
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildWebTextField(TextEditingController controller, String label, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminStyles.textPrimary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: AdminStyles.bodyStyle(fontSize: 14),
          decoration: InputDecoration(hintText: hint, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AdminStyles.border))),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: AdminStyles.bodyStyle(fontSize: 13)), Text(value, style: AdminStyles.dataStyle(fontSize: 13))]),
    );
  }

  Widget _buildStatusBadge() {
    final status = _currentTask!.status;
    Color color = AdminStyles.warning;
    if (status == 'completed') color = AdminStyles.success;
    if (status == 'rework') color = AdminStyles.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(status.toUpperCase(), style: AdminStyles.headingStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatusIcon(String status) {
    if (status == 'completed') return const Icon(Icons.verified_rounded, color: AdminStyles.success, size: 48);
    if (status == 'rework') return const Icon(Icons.history_rounded, color: AdminStyles.error, size: 48);
    return const Icon(Icons.hourglass_bottom_rounded, color: AdminStyles.warning, size: 48);
  }

  String _getStatusTitle(String status) {
    if (status == 'completed') return 'Work Finalized';
    if (status == 'rework') return 'Rework in Progress';
    return 'Waiting for Review';
  }

  String _getStatusDesc(String status) {
    if (status == 'completed') return 'This task is fully closed and verified.';
    if (status == 'rework') return 'Admin has requested changes. Please check the rework notes and update work.';
    return 'Work completion submitted. Awaiting administrative review and final requestor signature.';
  }

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.success));
  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.error));
  void _showWarning(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.warning));
}

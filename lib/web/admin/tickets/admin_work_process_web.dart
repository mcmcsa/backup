import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/pre_inspection_model.dart';
import '../../../shared/models/post_repair_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/pre_inspection_service.dart';
import '../../../shared/services/post_repair_service.dart';
import '../shared/admin_styles.dart';
import 'admin_approval_signature_web.dart';
import 'admin_pre_inspection_review_web.dart';
import 'admin_post_repair_evaluation_web.dart';
import '../../../shared/models/cost_tracking_model.dart';
import '../../../shared/services/cost_tracking_service.dart';
import 'admin_cost_tracking_form.dart';
import '../../../shared/models/collaboration_models.dart';
import '../../../shared/services/collaboration_service.dart';
import '../../teacher/reports/teacher_official_form_web.dart';
import 'admin_collaboration_workspace_widget.dart';
import '../../../shared/widgets/voice_player_widget.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/e_signature_service.dart';

class AdminWorkProcessWeb extends StatefulWidget {
  final WorkRequest request;
  final VoidCallback? onBack;

  const AdminWorkProcessWeb({
    super.key,
    required this.request,
    this.onBack,
  });

  @override
  State<AdminWorkProcessWeb> createState() => _AdminWorkProcessWebState();
}

class _AdminWorkProcessWebState extends State<AdminWorkProcessWeb> {
  WorkRequest? _request;
  PreInspectionReport? _preInspection;
  PostRepairReport? _postRepair;
  WorkRequestCost? _costTracking;
  List<WorkRequestCollaborator> _collaborators = [];
  List<WorkRequestTask> _tasks = [];
  List<WorkRequestNote> _notes = [];
  List<WorkRequestActivity> _activities = [];
  List<ESignature> _signatures = [];
  bool _isLoading = true;
  int _selectedSection = 0;
  String? _activeSubView;
  bool _showCollaboration = false;
  bool _showFinancials = false;

  final ScrollController _contentScrollController = ScrollController();
  final GlobalKey _overviewKey = GlobalKey();
  final GlobalKey _timelineKey = GlobalKey();
  final GlobalKey _detailsKey = GlobalKey();
  final GlobalKey _actionsKey = GlobalKey();
  final GlobalKey _financialsKey = GlobalKey();
  final GlobalKey _collaborationKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _contentScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _request = await WorkRequestService.fetchById(widget.request.id) ?? widget.request;
      _preInspection = await PreInspectionService.fetchLatestByWorkRequest(_request!.id);
      _postRepair = await PostRepairService.fetchLatestByWorkRequest(_request!.id);
      _costTracking = await CostTrackingService.fetchByWorkRequestId(_request!.id);
      _signatures = await ESignatureService.fetchByWorkRequest(_request!.id);
      
      // Load collaboration data
      _collaborators = await CollaborationService.fetchCollaborators(_request!.id);
      _tasks = await CollaborationService.fetchTasks(_request!.id);
      _notes = await CollaborationService.fetchNotes(_request!.id);
      _activities = await CollaborationService.fetchActivities(_request!.id);
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_activeSubView == 'approval' && _request != null) {
      return AdminApprovalSignatureWeb(
        request: _request!,
        onBack: () {
          setState(() => _activeSubView = null);
          _loadData();
        },
      );
    }
    if (_activeSubView == 'preInspection' && _request != null) {
      return AdminPreInspectionReviewWeb(
        request: _request!,
        onBack: () {
          setState(() => _activeSubView = null);
          _loadData();
        },
      );
    }
    if (_activeSubView == 'postRepair' && _request != null) {
      return AdminPostRepairEvaluationWeb(
        request: _request!,
        onBack: () {
          setState(() => _activeSubView = null);
          _loadData();
        },
      );
    }

    return Scaffold(
      backgroundColor: AdminStyles.bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary))
          : _request == null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: Container(
                        color: AdminStyles.bg,
                        child: SingleChildScrollView(
                          controller: _contentScrollController,
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1440),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(key: _overviewKey, child: _buildHeroSummary()),
                                  const SizedBox(height: 24),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isWide = constraints.maxWidth >= 1120;

                                      if (!isWide) {
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Container(key: _timelineKey, child: _buildTimelineSection()),
                                            const SizedBox(height: 24),
                                            Container(key: _detailsKey, child: _buildDetailsColumn()),
                                            const SizedBox(height: 24),
                                            Container(key: _collaborationKey, child: _buildCollaborationCard()),
                                            const SizedBox(height: 24),
                                            Container(key: _financialsKey, child: _buildFinancialsCard()),
                                          ],
                                        );
                                      }

                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(flex: 7, child: Column(
                                            children: [
                                              Container(key: _timelineKey, child: _buildTimelineSection()),
                                              const SizedBox(height: 24),
                                              Container(key: _collaborationKey, child: _buildCollaborationCard()),
                                              const SizedBox(height: 24),
                                              Container(key: _financialsKey, child: _buildFinancialsCard()),
                                            ],
                                          )),
                                          const SizedBox(width: 24),
                                          Expanded(flex: 4, child: Container(key: _detailsKey, child: _buildDetailsColumn())),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCollaborationCard() {
    return Container(
      decoration: AdminStyles.cardDecoration(borderRadius: 24),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminStyles.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.people_alt_rounded, color: AdminStyles.primary, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('COLLABORATION WORKSPACE', style: AdminStyles.headingStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('Staff discussion, shared tasks, team notes, and activity timeline.', style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _showCollaboration = !_showCollaboration);
                  },
                  icon: Icon(
                    _showCollaboration ? Icons.keyboard_arrow_up_rounded : Icons.people_alt_rounded,
                    size: 18,
                  ),
                  label: Text(_showCollaboration ? 'Hide Workspace' : 'Open Collaboration Workspace'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showCollaboration ? AdminStyles.textMuted.withValues(alpha: 0.1) : AdminStyles.primary,
                    foregroundColor: _showCollaboration ? AdminStyles.textPrimary : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          if (_showCollaboration) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(24),
              child: AdminCollaborationWorkspaceWidget(
                workRequestId: _request!.id,
                collaborators: _collaborators,
                tasks: _tasks,
                notes: _notes,
                activities: _activities,
                onDataChanged: _loadData,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialsCard() {
    return Container(
      decoration: AdminStyles.cardDecoration(borderRadius: 24),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminStyles.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: AdminStyles.success, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FINANCIALS & COST TRACKING', style: AdminStyles.headingStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('Labor cost estimates, materials, and total financial logs.', style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _showFinancials = !_showFinancials);
                  },
                  icon: Icon(
                    _showFinancials ? Icons.keyboard_arrow_up_rounded : Icons.account_balance_wallet_rounded,
                    size: 18,
                  ),
                  label: Text(_showFinancials ? 'Hide Financials' : 'Open Financials'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showFinancials ? AdminStyles.textMuted.withValues(alpha: 0.1) : AdminStyles.success,
                    foregroundColor: _showFinancials ? AdminStyles.textPrimary : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          if (_showFinancials) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _buildFinancialsSection(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cost Tracking & Financials', style: AdminStyles.headingStyle(fontSize: 18)),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await showDialog(
                    context: context,
                    builder: (ctx) => AdminCostTrackingForm(
                      workRequest: _request!,
                      existingCost: _costTracking,
                    ),
                  );
                  if (result == true) {
                    _loadData();
                  }
                },
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit Financials'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminStyles.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_costTracking == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text('No financial data recorded yet.', style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildFinancialItem('Estimated Labor', _costTracking!.estimatedLaborCost)),
                    Expanded(child: _buildFinancialItem('Estimated Material', _costTracking!.estimatedMaterialCost)),
                    Expanded(child: _buildFinancialItem('Actual Labor', _costTracking!.actualLaborCost, isActual: true)),
                    Expanded(child: _buildFinancialItem('Actual Material', _costTracking!.actualMaterialCost, isActual: true)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildFinancialItem('Additional Expenses', _costTracking!.additionalExpenses, isActual: true)),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AdminStyles.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AdminStyles.primary.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Cost', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.primary)),
                            const SizedBox(height: 4),
                            Text('₱ ${_costTracking!.totalCost.toStringAsFixed(2)}', style: AdminStyles.headingStyle(fontSize: 18, color: AdminStyles.primary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AdminStyles.border),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Budget Source', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
                          const SizedBox(height: 4),
                          Text(_costTracking!.budgetSource?.isNotEmpty == true ? _costTracking!.budgetSource! : 'N/A', style: AdminStyles.bodyStyle(color: AdminStyles.textPrimary)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Purchase Ref #', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
                          const SizedBox(height: 4),
                          Text(_costTracking!.purchaseReferenceNumber?.isNotEmpty == true ? _costTracking!.purchaseReferenceNumber! : 'N/A', style: AdminStyles.bodyStyle(color: AdminStyles.textPrimary)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Receipt Attachment', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
                          const SizedBox(height: 4),
                          if (_costTracking!.receiptAttachmentUrl != null)
                            InkWell(
                              onTap: () {
                                html.window.open(_costTracking!.receiptAttachmentUrl!, '_blank');
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.attachment_rounded, size: 16, color: AdminStyles.primary),
                                  const SizedBox(width: 4),
                                  Text('View Receipt', style: AdminStyles.bodyStyle(color: AdminStyles.primary, decoration: TextDecoration.underline)),
                                ],
                              ),
                            )
                          else
                            Text('No receipt uploaded', style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFinancialItem(String label, double amount, {bool isActual = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
        const SizedBox(height: 4),
        Text('₱ ${amount.toStringAsFixed(2)}', style: AdminStyles.bodyStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isActual ? AdminStyles.textPrimary : AdminStyles.textSecondary)),
      ],
    );
  }



  Future<void> _scrollToSection(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.02,
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: AdminStyles.glassDecoration(
        color: Colors.white,
        opacity: 1.0,
        borderRadius: 0,
        hasBorder: false,
      ).copyWith(
        border: Border(bottom: BorderSide(color: AdminStyles.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.pop(context);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: AdminStyles.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AdminStyles.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'WORK PROCESS HUB',
                style: AdminStyles.headingStyle(fontSize: 10, color: AdminStyles.textMuted, letterSpacing: 1),
              ),
              const SizedBox(height: 2),
              Text(
                _request?.title ?? 'Request Details',
                style: AdminStyles.headingStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(width: 40),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildHeaderTabItem('Overview', 0, _overviewKey),
                  _buildHeaderTabItem('Timeline', 1, _timelineKey),
                  _buildHeaderTabItem('Details', 2, _detailsKey),
                  _buildHeaderTabItem('Collaboration', 4, _collaborationKey),
                  _buildHeaderTabItem('Financials', 5, _financialsKey),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          _buildStatusPill(),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => TeacherOfficialFormWeb(request: _request!),
              );
            },
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('View Official Form', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
          const SizedBox(width: 12),
          _HeaderIconButton(
            icon: Icons.refresh_rounded,
            onTap: _loadData,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTabItem(String title, int index, GlobalKey key) {
    final isSelected = _selectedSection == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: () {
          setState(() {
            _selectedSection = index;
            if (index == 4) _showCollaboration = true;
            if (index == 5) _showFinancials = true;
          });
          _scrollToSection(key);
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: isSelected ? AdminStyles.primary.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Text(
          title,
          style: AdminStyles.headingStyle(
            fontSize: 13,
            color: isSelected ? AdminStyles.primary : AdminStyles.textSecondary,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: AdminStyles.cardDecoration(borderRadius: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 900;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroTextBlockContent(),
                const SizedBox(height: 16),
                _buildDurationBadge(),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildHeroTextBlockContent()),
              const SizedBox(width: 24),
              _buildDurationBadge(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroTextBlockContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _request!.title,
          style: AdminStyles.headingStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AdminStyles.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          'Track the request lifecycle, review workflow milestones, and manage available actions from a single desktop workspace.',
          style: AdminStyles.bodyStyle(fontSize: 14, color: AdminStyles.textSecondary),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildHeroChip('ID ${_request!.id.substring(0, 8).toUpperCase()}'),
            if (_request!.status.toLowerCase() != 'pending' && _request!.priority.isNotEmpty)
              _buildHeroChip(_request!.priorityLabel.toUpperCase()),
            _buildHeroChip((_request!.status).replaceAll('_', ' ').toUpperCase()),
            if ((_request!.officeRoom ?? '').isNotEmpty) _buildHeroChip(_request!.officeRoom!),
          ],
        ),
      ],
    );
  }

  Widget _buildDurationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AdminStyles.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.timer_outlined, color: AdminStyles.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('SERVICE DURATION', style: AdminStyles.headingStyle(fontSize: 9, color: AdminStyles.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 3),
              Text(
                _request?.maintenanceNotes ?? (_request?.dateDue != null ? DateFormat('MMM dd, HH:mm').format(_request!.dateDue!) : _calculateDuration()),
                style: AdminStyles.headingStyle(fontSize: 14, color: AdminStyles.textPrimary, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildHeroChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AdminStyles.pillDecoration(color: AdminStyles.primary, isSecondary: true),
      child: Text(
        label,
        style: AdminStyles.headingStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AdminStyles.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AdminStyles.pillDecoration(color: AdminStyles.primary, isSecondary: true),
      child: Text(
        _request?.status.replaceAll('_', ' ').toUpperCase() ?? 'PENDING',
        style: AdminStyles.headingStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AdminStyles.primary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 64, color: AdminStyles.error),
          const SizedBox(height: 16),
          Text('Request not found', style: AdminStyles.headingStyle(fontSize: 18)),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminStyles.cardDecoration(borderRadius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AdminStyles.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.route_rounded, color: AdminStyles.primary, size: 24),
              ),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Maintenance Lifecycle', style: AdminStyles.headingStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  Text('Real-time tracking of the work request workflow stages.', style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 36),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              children: _buildTimelineSteps(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTimelineSteps() {
    final steps = <_TimelineStep>[
      _TimelineStep(
        title: 'Report Submitted',
        subtitle: 'Initial request by ${_request!.requestorName}',
        time: DateFormat('MMM dd, HH:mm').format(_request!.dateSubmitted),
        isCompleted: true,
        isActive: _request!.status == 'pending',
      ),
      _TimelineStep(
        title: 'Admin Approval',
        subtitle: _request!.approvedBy != null ? 'Approved by ${_request!.approvedBy}' : 'Awaiting administrative e-signature',
        time: _request!.approvedDate != null ? DateFormat('MMM dd, HH:mm').format(_request!.approvedDate!) : null,
        isCompleted: _request!.approvedDate != null,
        isActive: _request!.status == 'pending',
      ),
      _TimelineStep(
        title: 'Maintenance Acceptance',
        subtitle: _request!.acceptedByName != null ? 'Accepted by ${_request!.acceptedByName}' : 'Awaiting technician assignment',
        time: _request!.acceptedDate != null ? DateFormat('MMM dd, HH:mm').format(_request!.acceptedDate!) : null,
        isCompleted: _request!.acceptedDate != null,
        isActive: _request!.status == 'approved',
      ),
      _TimelineStep(
        title: 'Pre-Inspection',
        subtitle: _preInspection != null ? 'Report Status: ${_preInspection!.status.toUpperCase()}' : 'Pending technical inspection',
        time: _preInspection != null ? DateFormat('MMM dd, HH:mm').format(_preInspection!.inspectionDate) : null,
        isCompleted: _preInspection?.status == 'approved',
        isActive: _request!.status == 'in_progress',
      ),
      _TimelineStep(
        title: 'Under Maintenance',
        subtitle: _request!.status == 'under_maintenance' || _request!.status == 'completed'
            ? 'Active repair work in progress' : _preInspection?.status == 'submitted' ? 'Awaiting inspection approval' : 'Not yet started',
        time: _request!.maintenanceStartTime != null ? DateFormat('MMM dd, HH:mm').format(_request!.maintenanceStartTime!) : null,
        isCompleted: _request!.status == 'completed' || _postRepair != null,
        isActive: _request!.status == 'under_maintenance',
      ),
      _TimelineStep(
        title: 'Post-Repair Report',
        subtitle: _postRepair != null ? 'Evaluation: ${_postRepair!.adminEvaluation ?? 'In Review'}' : 'Awaiting technician completion report',
        time: _postRepair != null ? DateFormat('MMM dd, HH:mm').format(_postRepair!.repairDate) : null,
        isCompleted: _postRepair?.status == 'evaluated',
        isActive: _postRepair?.status == 'submitted',
      ),
      if (_request!.reworkCount > 0) _TimelineStep(
        title: 'Rework Required',
        subtitle: '${_request!.reworkCount} rework request(s) issued',
        isCompleted: _request!.status != 'rework',
        isActive: _request!.status == 'rework',
        isWarning: true,
      ),
      _TimelineStep(
        title: 'Fully Completed',
        subtitle: _request!.status == 'completed' ? 'Final signature obtained' : 'Final administrative closure pending',
        time: _request!.dateCompleted != null ? DateFormat('MMM dd, HH:mm').format(_request!.dateCompleted!) : null,
        isCompleted: _request!.status == 'completed',
        isActive: false,
      ),
    ];

    return steps.asMap().entries.map((e) => _buildTimelineItem(e.value, isLast: e.key == steps.length - 1)).toList();
  }

  Widget _buildTimelineItem(_TimelineStep step, {bool isLast = false}) {
    Color color = AdminStyles.primary;
    if (step.isCompleted) {
      color = AdminStyles.success;
    } else if (step.isActive) color = AdminStyles.primary;
    else if (step.isWarning) color = AdminStyles.error;
    else color = AdminStyles.textMuted.withValues(alpha: 0.3);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.1), border: Border.all(color: color, width: 2)),
                child: Center(child: Icon(step.isCompleted ? Icons.check_rounded : step.isWarning ? Icons.priority_high_rounded : Icons.radio_button_checked_rounded, size: 16, color: color)),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: color.withValues(alpha: 0.2))),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(step.title, style: AdminStyles.headingStyle(fontSize: 15, color: step.isCompleted || step.isActive ? AdminStyles.textPrimary : AdminStyles.textMuted)),
                      if (step.time != null) Text(step.time!, style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(step.subtitle, style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignaturesListCard() {
    final list = <Widget>[];

    final reqName = _request!.requestorName.isNotEmpty
        ? _request!.requestorName
        : (_request!.reportedByName ?? '');

    final hasReqSig = _signatures.any((s) => s.signerRole == 'requestor' || s.signerRole == 'teacher' || s.signatureType == 'request');

    if (!hasReqSig && reqName.isNotEmpty) {
      list.add(
        _buildSignatureItemRow(
          signerName: reqName,
          label: 'Requestor',
          date: _request!.dateSubmitted,
        ),
      );
    }

    for (final sig in _signatures) {
      String label = sig.signatureTypeLabel;
      if (sig.signerRole == 'requestor' || sig.signerRole == 'teacher' || sig.signatureType == 'request') {
        label = 'Requestor';
      } else if (sig.signerRole == 'admin' || sig.signatureType == 'approval') {
        label = 'Admin Approval';
      } else if (sig.signerRole == 'maintenance' || sig.signatureType == 'post_repair' || sig.signatureType == 'acceptance') {
        label = 'Maintenance';
      }

      list.add(
        _buildSignatureItemRow(
          signerName: sig.signerName,
          label: label,
          date: sig.signedAt,
        ),
      );
    }

    if (list.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: AdminStyles.cardDecoration(borderRadius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SIGNATURES CAPTURED',
            style: AdminStyles.headingStyle(fontSize: 10, color: AdminStyles.textMuted, letterSpacing: 1),
          ),
          const SizedBox(height: 18),
          ...list,
        ],
      ),
    );
  }

  Widget _buildSignatureItemRow({
    required String signerName,
    required String label,
    required DateTime date,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AdminStyles.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.verified_rounded, size: 16, color: AdminStyles.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signerName,
                  style: AdminStyles.headingStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminStyles.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '$label • ${DateFormat('MMM dd, yyyy · HH:mm').format(date)}',
                  style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsColumn() {
    final requestor = _request!.requestorName.isNotEmpty
        ? _request!.requestorName
        : (_request!.reportedByName ?? 'N/A');
    final priorityDisplay = _request!.status.toLowerCase() == 'pending'
        ? '--'
        : _request!.priorityLabel;

    return Column(
      children: [
        _buildInfoCard('Information', [
          _buildSummaryRow('Tracking #', _request!.id.substring(0, 8).toUpperCase()),
          _buildSummaryRow('Type', _request!.typeOfRequest),
          _buildSummaryRow('Requestor', requestor),
          _buildSummaryRow('Priority Level', priorityDisplay),
          _buildSummaryRow('Submitted', DateFormat('MMM dd, yyyy · HH:mm').format(_request!.dateSubmitted)),
          if (_request!.voiceNotes != null && _request!.voiceNotes!.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Voice Notes', style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textMuted)),
            const SizedBox(height: 8),
            ..._request!.voiceNotes!.map((url) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: VoicePlayerWidget(audioUrl: url),
                )),
          ],
        ]),
        const SizedBox(height: 20),
        _buildInfoCard('Location', [
          _buildSummaryRow('Building', _request!.buildingName ?? 'N/A'),
          _buildSummaryRow('Room', _request!.officeRoom ?? _request!.roomName ?? 'N/A'),
          _buildSummaryRow('Department', _request!.departmentName ?? 'N/A'),
        ]),
        if (_signatures.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSignaturesListCard(),
        ],
        const SizedBox(height: 20),
        _buildActionCard(),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminStyles.cardDecoration(borderRadius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AdminStyles.primary),
                const SizedBox(width: 8),
              ],
              Text(
                title.toUpperCase(),
                style: AdminStyles.headingStyle(fontSize: 10, color: AdminStyles.textMuted, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textMuted)),
          Text(value, style: AdminStyles.dataStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTimeMetric(String label, String value) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AdminStyles.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.timer_outlined, color: AdminStyles.primary, size: 20)),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
            Text(value, style: AdminStyles.headingStyle(fontSize: 16)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard() {
    final status = _request!.status;

    return Container(
      key: _actionsKey,
      padding: const EdgeInsets.all(24),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Available Actions', style: AdminStyles.headingStyle(fontSize: 14, color: AdminStyles.textSecondary)),
          const SizedBox(height: 20),
          if (status == 'pending') ...[
            _buildActionButton('Approve with Signature', Icons.draw_rounded, AdminStyles.primary, () {
              setState(() => _activeSubView = 'approval');
            }),
          ],
          if (_preInspection != null) ...[
            if (_preInspection!.status == 'submitted')
              _buildActionButton('Review Pre-Inspection', Icons.fact_check_rounded, AdminStyles.warning, () {
                setState(() => _activeSubView = 'preInspection');
              })
            else
              _buildActionButton('View Pre-Inspection', Icons.visibility_rounded, AdminStyles.primary.withValues(alpha: 0.8), () {
                setState(() => _activeSubView = 'preInspection');
              }),
          ],
          if (_postRepair != null) ...[
            if (_postRepair!.status == 'submitted')
              _buildActionButton('Evaluate Post-Repair', Icons.rate_review_rounded, AdminStyles.success, () {
                setState(() => _activeSubView = 'postRepair');
              })
            else
              _buildActionButton('View Post-Repair', Icons.visibility_rounded, AdminStyles.primary.withValues(alpha: 0.8), () {
                setState(() => _activeSubView = 'postRepair');
              }),
          ],
          if (status == 'completed') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AdminStyles.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: AdminStyles.success),
                  const SizedBox(width: 12),
                  Expanded(child: Text('This request has been successfully closed.', style: AdminStyles.bodyStyle(color: AdminStyles.success, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          ] else if (status != 'pending' && !(_preInspection != null && _preInspection!.status == 'submitted') && !(_postRepair != null && _postRepair!.status == 'submitted')) ...[
            const SizedBox(height: 12),
            Text('No administrative actions required at this stage.', style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }



  String _calculateDuration() {
    final start = _request!.maintenanceStartTime;
    final end = _request!.maintenanceEndTime;
    if (start == null) return 'Not started';
    final actualEnd = end ?? DateTime.now();
    final diff = actualEnd.difference(start);
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    return '${diff.inMinutes}m';
  }
}

class _TimelineStep {
  final String title;
  final String subtitle;
  final String? time;
  final bool isCompleted;
  final bool isActive;
  final bool isWarning;

  _TimelineStep({required this.title, required this.subtitle, this.time, required this.isCompleted, required this.isActive, this.isWarning = false});
}

/// Header icon button with professional styling and badge support
class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final int badge;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    this.badge = 0,
    required this.onTap,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: _isHovered
              ? AdminStyles.glassDecoration(
                  color: const Color(0xFFF1F5F9),
                  opacity: 1.0,
                  borderRadius: 12,
                )
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.transparent),
                ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                widget.icon,
                color: _isHovered ? AdminStyles.primary : const Color(0xFF94A3B8),
                size: 22,
              ),
              if (widget.badge > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AdminStyles.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

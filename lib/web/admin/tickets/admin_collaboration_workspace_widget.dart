import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/collaboration_models.dart';
import '../../../shared/services/collaboration_service.dart';
import '../../../authentication/services/auth_service.dart';
import '../shared/admin_styles.dart';
import '../../../shared/widgets/voice_recorder_widget.dart';
import '../../../shared/widgets/voice_player_widget.dart';

class AdminCollaborationWorkspaceWidget extends StatefulWidget {
  final String workRequestId;
  final List<WorkRequestCollaborator> collaborators;
  final List<WorkRequestTask> tasks;
  final List<WorkRequestNote> notes;
  final List<WorkRequestActivity> activities;
  final VoidCallback onDataChanged;

  const AdminCollaborationWorkspaceWidget({
    super.key,
    required this.workRequestId,
    required this.collaborators,
    required this.tasks,
    required this.notes,
    required this.activities,
    required this.onDataChanged,
  });

  @override
  State<AdminCollaborationWorkspaceWidget> createState() => _AdminCollaborationWorkspaceWidgetState();
}

class _AdminCollaborationWorkspaceWidgetState extends State<AdminCollaborationWorkspaceWidget> {
  final TextEditingController _taskCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  bool _isRecordingVoice = false;

  Future<void> _addTask() async {
    final text = _taskCtrl.text.trim();
    if (text.isEmpty) return;

    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    _taskCtrl.clear();
    await CollaborationService.addTask(widget.workRequestId, text, user.id);
    widget.onDataChanged();
  }

  Future<void> _addNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;

    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    _noteCtrl.clear();
    await CollaborationService.addNote(widget.workRequestId, user.id, text);
    widget.onDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: AdminStyles.glassDecoration(color: Colors.white, opacity: 1.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;

                if (!isWide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCollaboratorsList(),
                      const SizedBox(height: 32),
                      _buildTasksSection(),
                      const SizedBox(height: 32),
                      _buildNotesSection(),
                      const SizedBox(height: 32),
                      _buildActivitySection(),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCollaboratorsList(),
                          const SizedBox(height: 32),
                          _buildTasksSection(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNotesSection(),
                          const SizedBox(height: 32),
                          _buildActivitySection(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.group_work_rounded, color: Color(0xFF10B981), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text('Collaboration Workspace', style: AdminStyles.headingStyle(fontSize: 18, color: AdminStyles.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaboratorsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Assigned Personnel', style: AdminStyles.headingStyle(fontSize: 15, color: AdminStyles.textPrimary)),
        const SizedBox(height: 12),
        if (widget.collaborators.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminStyles.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_add_alt_1_rounded, color: AdminStyles.textMuted, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No personnel assigned yet', style: AdminStyles.bodyStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminStyles.textSecondary)),
                      Text('Assign active maintenance staff to collaborate.', style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: widget.collaborators.map((c) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: c.role == 'primary' ? AdminStyles.primary.withValues(alpha: 0.04) : Colors.white,
                  border: Border.all(color: c.role == 'primary' ? AdminStyles.primary.withValues(alpha: 0.2) : AdminStyles.border),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.01),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c.userName ?? 'Unknown User', style: AdminStyles.bodyStyle(fontWeight: FontWeight.bold, color: AdminStyles.textPrimary)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.status == 'accepted' 
                                ? AdminStyles.success.withValues(alpha: 0.1) 
                                : AdminStyles.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: c.status == 'accepted' ? AdminStyles.success : AdminStyles.warning,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${c.role == 'primary' ? 'Primary' : 'Secondary'} • ${c.userSpecialization ?? "General"}', 
                      style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
  Widget _buildTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Shared Checklist', style: AdminStyles.headingStyle(fontSize: 15, color: AdminStyles.textPrimary)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AdminStyles.border),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.fact_check_outlined, color: AdminStyles.textMuted, size: 24),
                        ),
                        const SizedBox(height: 10),
                        Text('No checklist items yet', style: AdminStyles.bodyStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminStyles.textSecondary)),
                        Text('Add checklist items below to track tasks.', style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted)),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.tasks.length,
                  itemBuilder: (context, index) {
                    final t = widget.tasks[index];
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: AdminStyles.border.withValues(alpha: 0.5))),
                      ),
                      child: CheckboxListTile(
                        value: t.isCompleted,
                        activeColor: AdminStyles.primary,
                        onChanged: (val) async {
                          final user = context.read<AuthService>().currentUser;
                          if (val != null && user != null) {
                            await CollaborationService.toggleTaskCompletion(t.id, val, user.id, widget.workRequestId);
                            widget.onDataChanged();
                          }
                        },
                        title: Text(
                          t.taskDescription, 
                          style: AdminStyles.bodyStyle(
                            fontWeight: FontWeight.bold,
                            color: t.isCompleted ? AdminStyles.textMuted : AdminStyles.textPrimary,
                            decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: t.isCompleted 
                            ? Text('Completed by ${t.completedByName ?? "Unknown"}', style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.success, fontWeight: FontWeight.bold)) 
                            : null,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      ),
                    );
                  },
                ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _taskCtrl,
                        decoration: InputDecoration(
                          hintText: 'Add a new task item...',
                          isDense: true,
                          border: InputBorder.none,
                          hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontSize: 13),
                        ),
                        style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textPrimary),
                        onSubmitted: (_) => _addTask(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_rounded, color: AdminStyles.primary, size: 24),
                      onPressed: _addTask,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Collaboration Notes', style: AdminStyles.headingStyle(fontSize: 15, color: AdminStyles.textPrimary)),
        const SizedBox(height: 12),
        Container(
          height: 320,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: AdminStyles.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Expanded(
                child: widget.notes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.forum_outlined, color: AdminStyles.textMuted, size: 24),
                            ),
                            const SizedBox(height: 10),
                            Text('No notes shared yet', style: AdminStyles.bodyStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminStyles.textSecondary)),
                            Text('Start a collaboration thread below.', style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: widget.notes.length,
                        itemBuilder: (context, index) {
                          final n = widget.notes[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: AdminStyles.primary.withValues(alpha: 0.1),
                                      child: Text(
                                        (n.authorName ?? 'U').substring(0, 1).toUpperCase(),
                                        style: AdminStyles.headingStyle(fontSize: 10, color: AdminStyles.primary, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      n.authorName ?? 'Unknown', 
                                      style: AdminStyles.bodyStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminStyles.textPrimary),
                                    ),
                                    const Spacer(),
                                    Text(
                                      DateFormat.jm().format(n.createdAt), 
                                      style: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AdminStyles.border.withValues(alpha: 0.8)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.01),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  child: Text(n.content, style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary)),
                                ),
                                if (n.voiceNotes.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ...n.voiceNotes.map((url) => Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: VoicePlayerWidget(audioUrl: url),
                                      )),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const Divider(height: 1, color: AdminStyles.border),
              if (_isRecordingVoice)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: VoiceRecorderWidget(
                    onRecordingComplete: (bytes, path) async {
                      final user = context.read<AuthService>().currentUser;
                      if (user != null && bytes.isNotEmpty) {
                        final ext = path.isNotEmpty ? path.split('.').last : 'm4a';
                        await CollaborationService.addVoiceNoteBytes(
                          widget.workRequestId,
                          user.id,
                          bytes,
                          ext: ext,
                        );
                        widget.onDataChanged();
                      }
                      setState(() => _isRecordingVoice = false);
                    },
                    onRecordingDeleted: () {
                      setState(() => _isRecordingVoice = false);
                    },
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.mic_rounded, color: AdminStyles.primary),
                        onPressed: () => setState(() => _isRecordingVoice = true),
                        tooltip: 'Record Voice Note',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _noteCtrl,
                          decoration: InputDecoration(
                            hintText: 'Type a message note...',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontSize: 13),
                          ),
                          style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textPrimary),
                          onSubmitted: (_) => _addNote(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: AdminStyles.primary,
                        radius: 18,
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 14),
                          onPressed: _addNote,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Activity Timeline', style: AdminStyles.headingStyle(fontSize: 15, color: AdminStyles.textPrimary)),
        const SizedBox(height: 12),
        Container(
          height: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AdminStyles.border),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: widget.activities.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.history_rounded, color: AdminStyles.textMuted, size: 24),
                        ),
                        const SizedBox(height: 10),
                        Text('No activities logged yet', style: AdminStyles.bodyStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminStyles.textSecondary)),
                        Text('System action events will list here.', style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted)),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: widget.activities.length,
                  itemBuilder: (context, index) {
                    final a = widget.activities[index];
                    final isLast = index == widget.activities.length - 1;
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AdminStyles.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: AdminStyles.border.withValues(alpha: 0.8),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.details ?? a.actionType, 
                                    style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textPrimary, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${a.actorName ?? "System"} • ${DateFormat.yMMMd().add_jm().format(a.createdAt)}',
                                    style: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

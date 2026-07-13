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
            child: Row(
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
          Text('Collaboration Workspace', style: AdminStyles.headingStyle(fontSize: 18, color: AdminStyles.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildCollaboratorsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Assigned Personnel', style: AdminStyles.headingStyle(fontSize: 16)),
        const SizedBox(height: 12),
        if (widget.collaborators.isEmpty)
          Text('No personnel assigned yet.', style: AdminStyles.bodyStyle(color: AdminStyles.textMuted))
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: widget.collaborators.map((c) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: c.role == 'primary' ? AdminStyles.primary.withValues(alpha: 0.05) : Colors.grey.shade50,
                  border: Border.all(color: c.role == 'primary' ? AdminStyles.primary.withValues(alpha: 0.2) : AdminStyles.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c.userName ?? 'Unknown User', style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.status == 'accepted' ? Colors.green.shade100 : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            c.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: c.status == 'accepted' ? Colors.green.shade800 : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${c.role == 'primary' ? 'Primary' : 'Secondary'} • ${c.userSpecialization ?? "General"}', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted)),
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
        Text('Shared Checklist', style: AdminStyles.headingStyle(fontSize: 16)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AdminStyles.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.tasks.length,
                itemBuilder: (context, index) {
                  final t = widget.tasks[index];
                  return CheckboxListTile(
                    value: t.isCompleted,
                    onChanged: (val) async {
                      final user = context.read<AuthService>().currentUser;
                      if (val != null && user != null) {
                        await CollaborationService.toggleTaskCompletion(t.id, val, user.id, widget.workRequestId);
                        widget.onDataChanged();
                      }
                    },
                    title: Text(t.taskDescription, style: AdminStyles.bodyStyle(decoration: t.isCompleted ? TextDecoration.lineThrough : null)),
                    subtitle: t.isCompleted ? Text('Completed by ${t.completedByName ?? "Unknown"}', style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted)) : null,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  );
                },
              ),
              if (widget.tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No tasks created yet.', style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
                ),
              const Divider(height: 1, color: AdminStyles.border),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _taskCtrl,
                        decoration: InputDecoration(
                          hintText: 'Add a new task...',
                          isDense: true,
                          border: InputBorder.none,
                          hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted),
                        ),
                        onSubmitted: (_) => _addTask(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_rounded, color: AdminStyles.primary),
                      onPressed: _addTask,
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
        Text('Collaboration Notes', style: AdminStyles.headingStyle(fontSize: 16)),
        const SizedBox(height: 12),
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: AdminStyles.bg,
            border: Border.all(color: AdminStyles.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.notes.length,
                  itemBuilder: (context, index) {
                    final n = widget.notes[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(n.authorName ?? 'Unknown', style: AdminStyles.bodyStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              Text(DateFormat.jm().format(n.createdAt), style: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AdminStyles.border),
                            ),
                            child: Text(n.content, style: AdminStyles.bodyStyle(fontSize: 14)),
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
                    onRecordingComplete: (path) async {
                      final user = context.read<AuthService>().currentUser;
                      if (user != null) {
                        await CollaborationService.addVoiceNote(widget.workRequestId, user.id, path);
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
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.mic_rounded, color: AdminStyles.primary),
                        onPressed: () => setState(() => _isRecordingVoice = true),
                        tooltip: 'Record Voice Note',
                      ),
                      Expanded(
                        child: TextField(
                          controller: _noteCtrl,
                          decoration: InputDecoration(
                            hintText: 'Type a note...',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onSubmitted: (_) => _addNote(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: AdminStyles.primary,
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          onPressed: _addNote,
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
        Text('Activity Timeline', style: AdminStyles.headingStyle(fontSize: 16)),
        const SizedBox(height: 12),
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: AdminStyles.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.activities.length,
            separatorBuilder: (context, index) => const Divider(height: 16, color: AdminStyles.border),
            itemBuilder: (context, index) {
              final a = widget.activities[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.history_rounded, size: 16, color: AdminStyles.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.details ?? a.actionType, style: AdminStyles.bodyStyle(fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                          '${a.actorName ?? "System"} • ${DateFormat.yMMMd().add_jm().format(a.createdAt)}',
                          style: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

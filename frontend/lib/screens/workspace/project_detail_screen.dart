// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/workspace/project_detail_screen.dart
// PURPOSE: Full screen showing project details + linked tasks
// FIXES: Real-time updates using providers
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/priority_badge.dart';
import 'edit_project_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Project project;
  final Function(Project) onProjectUpdated;
  final Function(String) onProjectDeleted;

  const ProjectDetailScreen({
    super.key,
    required this.project,
    required this.onProjectUpdated,
    required this.onProjectDeleted,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late Project _project;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
  }

  void _goToEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProjectScreen(
          project: _project,
          allTasks: context.read<TaskProvider>().tasks,
          onProjectUpdated: (updated) async {
            setState(() => _project = updated);
            await widget.onProjectUpdated(updated);
          },
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Project',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure? All linked tasks will be unlinked.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onProjectDeleted(_project.id);
              if (mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _statusColor(ProjectStatus s) {
    switch (s) {
      case ProjectStatus.active:
        return const Color(0xFF4CAF50);
      case ProjectStatus.completed:
        return const Color(0xFF1360E2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ✅ Watch both providers for real-time updates
    final taskProvider = context.watch<TaskProvider>();
    final projectProvider = context.watch<ProjectProvider>();

    // Always prefer provider data; _project acts as fallback until provider syncs
    final currentProject = projectProvider.projects.firstWhere(
      (p) => p.id == _project.id,
      orElse: () => _project,
    );

    final linkedTasks = taskProvider.tasks
        .where((t) => currentProject.taskIds.contains(t.id))
        .toList();

    // ✅ Recalculate progress in real-time
    final progress = linkedTasks.isEmpty
        ? 0.0
        : linkedTasks.where((t) => t.isCompleted).length / linkedTasks.length;
    final progressPercent = (progress * 100).round();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Project Detail',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Project overview card ────────────────────────────
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  currentProject.title,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              PriorityBadge(priority: currentProject.priority),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (currentProject.description.isNotEmpty)
                            Text(
                              currentProject.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.textTheme.bodySmall?.color,
                                height: 1.5,
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _statusColor(currentProject.status)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  currentProject.status.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _statusColor(currentProject.status),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.calendar_today_outlined,
                                  size: 13,
                                  color: theme.textTheme.bodySmall?.color),
                              const SizedBox(width: 4),
                              Text(
                                currentProject.dueDateDisplay,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: currentProject.isOverdue
                                      ? Colors.red
                                      : theme.textTheme.bodySmall?.color,
                                  fontWeight: currentProject.isOverdue
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Progress',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme
                                                  .textTheme.bodySmall?.color,
                                            )),
                                        Text('$progressPercent%',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: theme
                                                  .textTheme.bodyLarge?.color,
                                            )),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 10,
                                        backgroundColor: theme.dividerColor,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          progress == 1.0
                                              ? Colors.green
                                              : theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Linked Tasks (${linkedTasks.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (linkedTasks.isEmpty)
                      AppCard(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No tasks linked to this project yet.',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      ...linkedTasks.map((task) => _LinkedTaskRow(task: task)),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _goToEdit,
                        icon: const Icon(Icons.edit_outlined,
                            size: 16, color: Colors.white),
                        label: const Text('Edit Project',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _confirmDelete,
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 16, color: Colors.red),
                        label: const Text('Delete Project',
                            style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Linked task row inside project detail
// ─────────────────────────────────────────────────────────────────────────────

class _LinkedTaskRow extends StatelessWidget {
  final Task task;
  const _LinkedTaskRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: task.isCompleted
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: task.isCompleted
                    ? theme.colorScheme.primary
                    : theme.dividerColor,
                width: 1.5,
              ),
            ),
            child: task.isCompleted
                ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: task.isCompleted
                        ? theme.textTheme.bodySmall?.color
                        : theme.textTheme.bodyLarge?.color,
                    decoration:
                        task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (task.dueTime != null || task.formattedDueDate.isNotEmpty)
                  Text(
                    task.dueTime ?? task.formattedDueDate,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
              ],
            ),
          ),
          PriorityBadge(priority: task.priority),
        ],
      ),
    );
  }
}

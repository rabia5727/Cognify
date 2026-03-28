// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/workspace/project_detail_screen.dart
// PURPOSE: View full project details with all associated tasks
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../constants/app_constant.dart';
import '../../../models/project_model.dart';
import '../../../models/task_model.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/priority_badge.dart';
import 'edit_project_dialog.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Project project;
  final List<Task> allTasks;
  final Function(Project) onProjectUpdated;
  final Function(String) onProjectDeleted;

  const ProjectDetailScreen({
    super.key,
    required this.project,
    required this.allTasks,
    required this.onProjectUpdated,
    required this.onProjectDeleted,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late Project _project;

  List<Task> get _projectTasks => widget.allTasks
      .where((task) => _project.taskIds.contains(task.id))
      .toList();

  int get _completedTasksCount =>
      _projectTasks.where((task) => task.isCompleted).length;

  double get _progress =>
      _projectTasks.isEmpty ? 0 : _completedTasksCount / _projectTasks.length;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
  }

  void _editProject() async {
    await showEditProjectDialog(
      context: context,
      project: _project,
      allTasks: widget.allTasks,
      onProjectUpdated: (updatedProject) {
        setState(() => _project = updatedProject);
        widget.onProjectUpdated(updatedProject);
      },
    );
  }

  void _deleteProject() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text(
          'Are you sure you want to delete this project?\nAll associated tasks will be unlinked.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.onProjectDeleted(_project.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new,
              color: theme.textTheme.bodyLarge?.color),
        ),
        title: Text(
          _project.title,
          style: theme.textTheme.titleMedium,
        ),
        actions: [
          IconButton(
            onPressed: _editProject,
            icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
          ),
          IconButton(
            onPressed: _deleteProject,
            icon: Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress section
            AppCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Project Progress',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 10,
                      backgroundColor: theme.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _progress == 1.0
                            ? Colors.green
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tasks: ${_project.taskIds.length} total',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        'Completed: $_completedTasksCount',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Project info
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Project Details',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.priority_high,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Priority:', style: theme.textTheme.bodySmall),
                      const SizedBox(width: 8),
                      PriorityBadge(priority: _project.priority),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Due:', style: theme.textTheme.bodySmall),
                      const SizedBox(width: 8),
                      Text(
                        _project.dueDateDisplay,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  if (_project.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Description:',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      _project.description,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tasks list
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tasks',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${_projectTasks.length} items',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_projectTasks.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.task_alt_rounded,
                          size: 48, color: theme.dividerColor),
                      const SizedBox(height: 8),
                      Text(
                        'No tasks in this project yet',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _projectTasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final task = _projectTasks[index];
                  return AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: task.isCompleted
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: task.isCompleted
                                  ? theme.colorScheme.primary
                                  : theme.textTheme.bodySmall?.color ??
                                      Colors.grey,
                              width: 1.5,
                            ),
                          ),
                          child: task.isCompleted
                              ? const Icon(Icons.check_rounded,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  PriorityBadge(priority: task.priority),
                                  const SizedBox(width: 8),
                                  Text(
                                    task.dueTime ?? task.formattedDueDate,
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

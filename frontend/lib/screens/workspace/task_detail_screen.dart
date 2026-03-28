// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/tasks/task_detail_screen.dart
// PURPOSE: View full task details with options to edit/delete
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../constants/app_constant.dart';
import '../../../models/task_model.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/priority_badge.dart';
import 'edit_task_dialog.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  final Function(Task) onTaskUpdated;
  final Function(String) onTaskDeleted;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Task _task;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  void _editTask() async {
    await showEditTaskDialog(
      context: context,
      task: _task,
      onTaskUpdated: (updatedTask) {
        setState(() => _task = updatedTask);
        widget.onTaskUpdated(updatedTask);
      },
    );
  }

  void _deleteTask() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.onTaskDeleted(_task.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleComplete() {
    final newStatus =
        _task.isCompleted ? TaskStatus.todo : TaskStatus.completed;
    final updatedTask = _task.copyWith(status: newStatus);
    setState(() => _task = updatedTask);
    widget.onTaskUpdated(updatedTask);
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
        actions: [
          IconButton(
            onPressed: _editTask,
            icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
          ),
          IconButton(
            onPressed: _deleteTask,
            icon: Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status chip with toggle
            GestureDetector(
              onTap: _toggleComplete,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _task.isCompleted
                      ? Colors.green.withOpacity(0.1)
                      : theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _task.isCompleted ? Icons.check_circle : Icons.pending,
                      size: 18,
                      color: _task.isCompleted
                          ? Colors.green
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _task.isCompleted
                          ? 'Mark as Incomplete'
                          : 'Mark as Complete',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _task.isCompleted
                            ? Colors.green
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              _task.title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                decoration:
                    _task.isCompleted ? TextDecoration.lineThrough : null,
                color:
                    _task.isCompleted ? theme.textTheme.bodySmall?.color : null,
              ),
            ),
            const SizedBox(height: 16),

            // Priority badge
            PriorityBadge(priority: _task.priority, fontSize: 12),
            const SizedBox(height: 24),

            // Subtitle
            if (_task.subtitle.isNotEmpty) ...[
              const Text(
                'Description',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _task.subtitle,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
            ],

            // Due date card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Due Date & Time',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        AppConstants.formatDate(_task.dueDate),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  if (_task.dueTime != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          _task.dueTime!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                  if (_task.isOverdue && !_task.isCompleted) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text(
                            'This task is overdue!',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Project info (if linked to project)
            if (_task.projectId != null) ...[
              const Text(
                'Project',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              AppCard(
                child: ListTile(
                  leading: Icon(Icons.folder, color: theme.colorScheme.primary),
                  title: const Text('View Project'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to project detail
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

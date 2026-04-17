// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/workspace/task_detail_screen.dart
// PURPOSE: Full screen showing task details with Edit and Delete
// FIXES:
//   - Now accepts taskId instead of Task object
//   - Watches provider for live data (no stale snapshots)
//   - Category section removed
//   - Uses priority.color getter
//   - Fixed stale data when task is updated from edit screen
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/priority_badge.dart';
import 'edit_task_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  final Function(Task) onTaskUpdated;
  final Function(String) onTaskDeleted;

  const TaskDetailScreen({
    super.key,
    required this.taskId,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Future<void> _goToEdit(Task task) async {
    final result = await Navigator.push<Task>(
      context,
      MaterialPageRoute(
        builder: (_) => EditTaskScreen(
          task: task,
          onTaskUpdated: (updated) async {
            // Update the provider
            await context.read<TaskProvider>().updateTask(updated);
            // Notify parent
            widget.onTaskUpdated(updated);
          },
        ),
      ),
    );

    // No need to do anything else - the Consumer will automatically
    // show the updated task from the provider
  }

  void _confirmDelete(String taskId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Task',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Delete from provider
              await context.read<TaskProvider>().deleteTask(taskId);
              // Notify parent
              widget.onTaskDeleted(taskId);
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

  void _showAIPrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'How would you like to\ncontinue ?',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              _AIOption(
                icon: Icons.auto_awesome_rounded,
                title: 'User AI Assistant',
                subtitle: 'Get smart suggestions or next step',
                isPrimary: true,
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('AI Assistant coming soon!')),
                  );
                },
              ),
              const SizedBox(height: 12),
              _AIOption(
                icon: Icons.edit_outlined,
                title: 'Manual Edit',
                subtitle: 'Update progress or add notes',
                isPrimary: false,
                onTap: () {
                  Navigator.pop(ctx);
                  // Get fresh task from provider before editing
                  final freshTask = context
                      .read<TaskProvider>()
                      .tasks
                      .firstWhere((t) => t.id == widget.taskId);
                  _goToEdit(freshTask);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Consumer<TaskProvider>(
          builder: (context, taskProvider, _) {
            // Find the task by ID - always fresh from provider
            final task = taskProvider.tasks.firstWhere(
              (t) => t.id == widget.taskId,
              orElse: () => throw Exception('Task not found'),
            );

            return Column(
              children: [
                AppHeader(
                  title: 'Task Detail',
                  onBack: () => Navigator.pop(context),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Column(
                            children: [
                              _DetailRow(
                                icon: Icons.title_rounded,
                                iconColor: theme.colorScheme.primary,
                                label: 'Title',
                                value: task.title,
                              ),
                              _DetailDivider(),

                              _DetailRow(
                                icon: Icons.notes_rounded,
                                iconColor: const Color(0xFFEFA535),
                                label: 'Description',
                                value: task.subtitle.isNotEmpty
                                    ? task.subtitle
                                    : 'No description',
                              ),
                              _DetailDivider(),

                              _DetailRow(
                                icon: Icons.calendar_today_outlined,
                                iconColor: theme.colorScheme.primary,
                                label: 'Due Date',
                                value: task.dueTime != null
                                    ? '${task.formattedDueDate} at ${task.dueTime}'
                                    : task.formattedDueDate,
                              ),
                              _DetailDivider(),

                              // Priority
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color:
                                          task.priority.color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.flag_outlined,
                                        size: 18, color: task.priority.color),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Priority',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme
                                                  .textTheme.bodySmall?.color,
                                            )),
                                        const SizedBox(height: 4),
                                        PriorityBadge(priority: task.priority),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showAIPrompt,
                            icon: Icon(Icons.auto_awesome_rounded,
                                size: 16, color: theme.colorScheme.primary),
                            label: Text('Continue with AI',
                                style: TextStyle(
                                    color: theme.colorScheme.primary)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side:
                                  BorderSide(color: theme.colorScheme.primary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _goToEdit(task);
                            },
                            icon: const Icon(Icons.edit_outlined,
                                size: 16, color: Colors.white),
                            label: const Text('Edit',
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
                            onPressed: () => _confirmDelete(task.id),
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 16, color: Colors.red),
                            label: const Text('Delete Task',
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
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Detail row (icon + label + value)
// ─────────────────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color,
                    )),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.textTheme.bodyLarge?.color,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: Theme.of(context).dividerColor);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: AI continue option button
// ─────────────────────────────────────────────────────────────────────────────

class _AIOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPrimary;
  final VoidCallback onTap;

  const _AIOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isPrimary ? theme.colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPrimary ? Colors.transparent : theme.dividerColor,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: isPrimary ? Colors.white : theme.colorScheme.primary),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isPrimary
                          ? Colors.white
                          : theme.textTheme.bodyLarge?.color,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isPrimary
                          ? Colors.white70
                          : theme.textTheme.bodySmall?.color,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

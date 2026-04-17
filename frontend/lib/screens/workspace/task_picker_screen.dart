// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/workspace/task_picker_screen.dart
// PURPOSE: Full screen for selecting tasks to link to a project
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../widgets/common/app_header.dart';
import 'add_task_screen.dart';

class TaskPickerScreen extends StatefulWidget {
  final List<Task> allTasks;
  final List<String> initialSelected;
  final Function(Task)? onTaskCreated; // Callback when a new task is created

  const TaskPickerScreen({
    super.key,
    required this.allTasks,
    required this.initialSelected,
    this.onTaskCreated,
  });

  @override
  State<TaskPickerScreen> createState() => _TaskPickerScreenState();
}

class _TaskPickerScreenState extends State<TaskPickerScreen> {
  late List<String> _selected;
  late List<Task> _tasks;

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.initialSelected);
    _tasks = List.from(widget.allTasks);
  }

  Color _priorityColor(Priority p) {
    switch (p) {
      case Priority.high:
        return const Color(0xFFFF5252);
      case Priority.medium:
        return const Color(0xFFEFA535);
      case Priority.low:
        return const Color(0xFF4CAF50);
    }
  }

  void _refreshTasks() {
    // This will be called when a new task is created
    setState(() {});
  }

  Future<void> _createNewTask() async {
    // AddTaskScreen pops itself with the new task as the result (Navigator.pop(context, newTask))
    final result = await Navigator.push<Task>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(
          onTaskAdded: (_) {
            // Task is captured via Navigator.push result below
          },
        ),
      ),
    );

    if (result != null && mounted) {
      // Persist to global TaskProvider so it appears on the workspace task screen
      context.read<TaskProvider>().addTask(result);

      // Add to the local picker list and auto-select it
      setState(() {
        _tasks.add(result);
        _selected.add(result.id);
      });

      if (widget.onTaskCreated != null) {
        widget.onTaskCreated!(result);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "${result.title}" created and linked'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            AppHeader(
              title: 'Select Tasks',
              onBack: () => Navigator.pop(context, _selected),
            ),

            // Task list
            Expanded(
              child: _tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.task_alt_rounded,
                            size: 56,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No tasks available',
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _createNewTask,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Create a task'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      itemCount: _tasks.length,
                      itemBuilder: (_, i) {
                        final task = _tasks[i];
                        final isSelected = _selected.contains(task.id);
                        final pColor = _priorityColor(task.priority);

                        return GestureDetector(
                          onTap: () => setState(() {
                            if (isSelected) {
                              _selected.remove(task.id);
                            } else {
                              _selected.add(task.id);
                            }
                          }),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.dividerColor,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Checkbox
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_box_rounded
                                        : Icons.check_box_outline_blank_rounded,
                                    size: 20,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.textTheme.bodySmall?.color,
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Task info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              theme.textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      if (task.subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          task.subtitle,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme
                                                .textTheme.bodySmall?.color,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time_rounded,
                                            size: 12,
                                            color: theme
                                                .textTheme.bodySmall?.color,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            task.dueTime ??
                                                task.formattedDueDate,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: theme
                                                  .textTheme.bodySmall?.color,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              task.category.label,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Priority badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: pColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: pColor.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    task.priority.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: pColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Create new task button (when tasks exist)
            if (_tasks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: GestureDetector(
                  onTap: _createNewTask,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Create New Task',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Done button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _selected.isEmpty
                        ? 'Done'
                        : 'Done (${_selected.length} selected)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
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

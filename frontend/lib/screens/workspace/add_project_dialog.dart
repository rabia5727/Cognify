// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/workspace/add_project_dialog.dart
// PURPOSE: Dialog for creating a new project
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../constants/app_constant.dart';
import '../../../models/project_model.dart';
import '../../../models/task_model.dart';

Future<void> showAddProjectDialog({
  required BuildContext context,
  required Function(Project) onProjectAdded,
}) async {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
  Priority selectedPriority = Priority.medium;

  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final theme = Theme.of(ctx);

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Add New Project'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title field
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Project Title *',
                      hintText: 'e.g., HCI Assignment',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description field
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'e.g., Complete all tasks for HCI course',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Due Date picker
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => selectedDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Due Date',
                                    style: theme.textTheme.labelSmall),
                                Text(
                                  AppConstants.formatDate(selectedDate),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Priority selector
                  const Text('Priority',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: Priority.values.map((priority) {
                      final isSelected = selectedPriority == priority;
                      final color =
                          AppConstants.priorityColorFromEnum(priority);
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => selectedPriority = priority),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? color : theme.dividerColor,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              priority.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? color
                                    : theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a project title')),
                  );
                  return;
                }

                final newProject = Project(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim(),
                  taskIds: [],
                  dueDate: selectedDate,
                  priority: selectedPriority,
                );

                onProjectAdded(newProject);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
              ),
              child: const Text('Create Project'),
            ),
          ],
        );
      },
    ),
  );
}

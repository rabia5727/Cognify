// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/tasks/edit_task_dialog.dart
// PURPOSE: Dialog for editing an existing task
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../constants/app_constant.dart';
import '../../../models/task_model.dart';

// Helper function moved outside
TimeOfDay _parseTimeOfDay(String timeString) {
  try {
    final period = timeString.substring(timeString.length - 2);
    final timeParts = timeString.substring(0, timeString.length - 2).split(':');
    int hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    if (period == 'pm' && hour != 12) hour += 12;
    if (period == 'am' && hour == 12) hour = 0;

    return TimeOfDay(hour: hour, minute: minute);
  } catch (_) {
    return TimeOfDay.now();
  }
}

Future<void> showEditTaskDialog({
  required BuildContext context,
  required Task task,
  required Function(Task) onTaskUpdated,
}) async {
  final titleController = TextEditingController(text: task.title);
  final subtitleController = TextEditingController(text: task.subtitle);
  DateTime selectedDate = task.dueDate;
  TimeOfDay? selectedTime =
      task.dueTime != null ? _parseTimeOfDay(task.dueTime!) : null;
  Priority selectedPriority = task.priority;

  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final theme = Theme.of(ctx);

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Edit Task'),
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
                      labelText: 'Task Title *',
                      hintText: 'e.g., Complete Math Assignment',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subtitle field
                  TextField(
                    controller: subtitleController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Subtitle (optional)',
                      hintText: 'e.g., for HCI assignment',
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
                  const SizedBox(height: 12),

                  // Due Time picker
                  GestureDetector(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() => selectedTime = time);
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
                          Icon(Icons.access_time,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Due Time (optional)',
                                    style: theme.textTheme.labelSmall),
                                Text(
                                  selectedTime != null
                                      ? selectedTime!.format(ctx)
                                      : 'No time set',
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
                    const SnackBar(content: Text('Please enter a task title')),
                  );
                  return;
                }

                final updatedTask = Task(
                  id: task.id,
                  title: titleController.text.trim(),
                  subtitle: subtitleController.text.trim(),
                  dueDate: selectedDate,
                  dueTime: selectedTime != null
                      ? '${selectedTime!.hourOfPeriod}:${selectedTime!.minute.toString().padLeft(2, '0')}${selectedTime!.period == DayPeriod.am ? 'am' : 'pm'}'
                      : null,
                  priority: selectedPriority,
                  status: task.status,
                  projectId: task.projectId,
                );

                onTaskUpdated(updatedTask);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
              ),
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    ),
  );
}

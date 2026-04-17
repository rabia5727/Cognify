// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/workspace/edit_task_screen.dart
// PURPOSE: Full screen for editing an existing task
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../../widgets/common/app_header.dart';

class EditTaskScreen extends StatefulWidget {
  final Task task;
  final Function(Task) onTaskUpdated;

  const EditTaskScreen({
    super.key,
    required this.task,
    required this.onTaskUpdated,
  });

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;

  late Priority _priority;
  late DateTime _dueDate;
  TimeOfDay? _dueTime;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task.title);
    _descCtrl = TextEditingController(text: widget.task.subtitle);
    _priority = widget.task.priority;
    _dueDate = widget.task.dueDate;

    if (widget.task.dueTime != null && widget.task.dueTime!.isNotEmpty) {
      _dueTime = _parseTimeString(widget.task.dueTime!);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTimeString(String timeStr) {
    try {
      final isPm = timeStr.toLowerCase().contains('pm');
      final clean =
          timeStr.toLowerCase().replaceAll(RegExp(r'[ap]m'), '').trim();
      final parts = clean.split(':');
      var hour = int.parse(parts[0]);
      final min = int.parse(parts[1]);
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: min);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  String get _dateDisplay =>
      '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}';

  String get _timeDisplay {
    if (_dueTime == null) return 'Select due time';
    final h = _dueTime!.hourOfPeriod == 0 ? 12 : _dueTime!.hourOfPeriod;
    final m = _dueTime!.minute.toString().padLeft(2, '0');
    final period = _dueTime!.period == DayPeriod.am ? 'am' : 'pm';
    return '$h:$m$period';
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final updated = widget.task.copyWith(
      title: _titleCtrl.text.trim(),
      subtitle: _descCtrl.text.trim(),
      dueDate: _dueDate,
      dueTime: _dueTime != null ? _timeDisplay : widget.task.dueTime,
      priority: _priority,
      category: widget.task.category,
    );

    widget.onTaskUpdated(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Edit Task',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      _Label('Title'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: _inputDecoration(context, 'Task title'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Title is required'
                            : null,
                      ),

                      const SizedBox(height: 20),

                      // Description
                      _Label('Description'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 4,
                        decoration:
                            _inputDecoration(context, 'Add a description...'),
                      ),

                      const SizedBox(height: 20),

                      // Due Date
                      _Label('Due Date'),
                      const SizedBox(height: 8),
                      _PickerRow(
                        icon: Icons.calendar_today_outlined,
                        label: _dateDisplay,
                        hasValue: true,
                        onTap: _pickDate,
                      ),

                      const SizedBox(height: 12),

                      // Due Time
                      _Label('Due Time'),
                      const SizedBox(height: 8),
                      _PickerRow(
                        icon: Icons.access_time_rounded,
                        label: _timeDisplay,
                        hasValue: _dueTime != null,
                        onTap: _pickTime,
                      ),

                      const SizedBox(height: 20),

                      // Priority
                      _Label('Priority'),
                      const SizedBox(height: 8),
                      _PrioritySelector(
                        selected: _priority,
                        onSelected: (p) => setState(() => _priority = p),
                      ),

                      const SizedBox(height: 32),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: theme.dividerColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

// =============================================================
// HELPER WIDGETS
// =============================================================

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: theme.textTheme.bodyLarge?.color,
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasValue;
  final VoidCallback onTap;

  const _PickerRow({
    required this.icon,
    required this.label,
    required this.hasValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2130) : const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: hasValue
                    ? theme.colorScheme.primary
                    : theme.textTheme.bodySmall?.color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: hasValue
                    ? theme.textTheme.bodyLarge?.color
                    : theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  final Priority selected;
  final Function(Priority) onSelected;

  const _PrioritySelector({
    required this.selected,
    required this.onSelected,
  });

  Color _color(Priority p) {
    switch (p) {
      case Priority.high:
        return const Color(0xFFFF5252);
      case Priority.medium:
        return const Color(0xFFEFA535);
      case Priority.low:
        return const Color(0xFF4CAF50);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: Priority.values.map((p) {
        final isSelected = selected == p;
        final color = _color(p);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : theme.dividerColor,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  p.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : theme.textTheme.bodySmall?.color,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

InputDecoration _inputDecoration(BuildContext context, String hint) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color),
    filled: true,
    fillColor: isDark ? const Color(0xFF1E2130) : const Color(0xFFF0F4FF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.dividerColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.dividerColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
    ),
  );
}

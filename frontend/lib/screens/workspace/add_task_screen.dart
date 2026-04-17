// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/workspace/add_task_screen.dart
// PURPOSE: Full screen for creating a new task
// FIXES: Added loading state (Save button shows loader, disabled while saving)
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../../widgets/common/app_header.dart';

class AddTaskScreen extends StatefulWidget {
  // Callback — called with the new task when user taps Save
  final Function(Task) onTaskAdded;

  const AddTaskScreen({super.key, required this.onTaskAdded});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  Priority _priority = Priority.medium;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Pick due date ──────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  // ── Pick due time ──────────────────────────────────────────────────
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  // ── Format display strings ────────────────────────────────────────
  String get _dateDisplay {
    if (_dueDate == null) return 'Select due date';
    return '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}';
  }

  String get _timeDisplay {
    if (_dueTime == null) return 'Select due time';
    final h = _dueTime!.hourOfPeriod == 0 ? 12 : _dueTime!.hourOfPeriod;
    final m = _dueTime!.minute.toString().padLeft(2, '0');
    final period = _dueTime!.period == DayPeriod.am ? 'am' : 'pm';
    return '$h:$m$period';
  }

  // ── Save ───────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a due date')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim(),
      subtitle: _descCtrl.text.trim(),
      dueDate: _dueDate!,
      dueTime: _dueTime != null ? _timeDisplay : null,
      priority: _priority,
      status: TaskStatus.todo,
      category: TaskCategory.general,
    );

    try {
      await widget.onTaskAdded(newTask);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create task: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
            // ── Header ───────────────────────────────────────────────
            AppHeader(
              title: 'New Task',
              onBack: () => Navigator.pop(context),
            ),

            // ── Form ─────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task Name
                      _Label('Task Name'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleCtrl,
                        autofocus: true,
                        decoration:
                            _inputDecoration(context, 'e.g. send an email'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Task name is required'
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
                            _inputDecoration(context, 'Add a description....'),
                      ),

                      const SizedBox(height: 20),

                      // Due Date
                      _Label('Due Date'),
                      const SizedBox(height: 8),
                      _PickerRow(
                        icon: Icons.calendar_today_outlined,
                        label: _dateDisplay,
                        hasValue: _dueDate != null,
                        onTap: _pickDate,
                        context: context,
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
                        context: context,
                      ),

                      const SizedBox(height: 20),

                      // Priority
                      _Label('Priority'),
                      const SizedBox(height: 8),
                      _PrioritySelector(
                        selected: _priority,
                        onSelected: (p) => setState(() => _priority = p),
                      ),

                      const SizedBox(height: 28),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: theme.dividerColor),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Save',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
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

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Section label
// ─────────────────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).textTheme.bodyLarge?.color,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Date/Time picker row
// ─────────────────────────────────────────────────────────────────────────────

class _PickerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasValue;
  final VoidCallback onTap;
  final BuildContext context;

  const _PickerRow({
    required this.icon,
    required this.label,
    required this.hasValue,
    required this.onTap,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    final theme = Theme.of(ctx);
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

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Priority selector (Low / Medium / High pills)
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Input decoration
// ─────────────────────────────────────────────────────────────────────────────

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

// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/workspace/add_project_screen.dart
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../widgets/common/app_header.dart';
import 'task_picker_screen.dart';

class AddProjectScreen extends StatefulWidget {
  final List<Task> allTasks;
  final Function(Project) onProjectAdded;

  const AddProjectScreen({
    super.key,
    required this.allTasks,
    required this.onProjectAdded,
  });

  @override
  State<AddProjectScreen> createState() => _AddProjectScreenState();
}

class _AddProjectScreenState extends State<AddProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  Priority _priority = Priority.medium;
  ProjectCategory _category = ProjectCategory.academic;
  DateTime? _dueDate;
  List<String> _selectedTaskIds = [];

  // ✅ KEY FIX: local mutable task list — grows as new tasks are created
  late List<Task> _localAllTasks;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // ✅ Initialize from prop
    _localAllTasks = List.from(widget.allTasks);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  String get _dateDisplay {
    if (_dueDate == null) return 'Select due date';
    return '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}';
  }

  Future<void> _openTaskPicker() async {
    if (_isSaving) return;

    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskPickerScreen(
          // ✅ Use local list so newly created tasks are included
          allTasks: _localAllTasks,
          initialSelected: _selectedTaskIds,
          onTaskCreated: (newTask) {
            // ✅ Append new task to local list immediately
            setState(() {
              if (!_localAllTasks.any((t) => t.id == newTask.id)) {
                _localAllTasks.add(newTask);
              }
              if (!_selectedTaskIds.contains(newTask.id)) {
                _selectedTaskIds.add(newTask.id);
              }
            });
          },
        ),
      ),
    );

    if (!mounted) return;

    // ✅ Refresh provider after picker closes
    await context.read<TaskProvider>().refreshTasks();

    if (!mounted) return;

    if (result != null) {
      // ✅ Ensure all returned IDs have task objects in local list
      final freshTasks = context.read<TaskProvider>().tasks;
      for (final id in result) {
        if (!_localAllTasks.any((t) => t.id == id)) {
          final match = freshTasks.where((t) => t.id == id).firstOrNull;
          if (match != null) _localAllTasks.add(match);
        }
      }
      setState(() => _selectedTaskIds = result);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a due date')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final project = Project(
      id: '',
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      taskIds: _selectedTaskIds,
      dueDate: _dueDate!,
      priority: _priority,
      status: ProjectStatus.active,
      category: _category,
    );

    try {
      await widget.onProjectAdded(project);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create project: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ✅ Linked tasks resolved from local list (has newly created tasks)
    final linkedTasks = _selectedTaskIds
        .map((id) => _localAllTasks.where((t) => t.id == id).firstOrNull)
        .whereType<Task>()
        .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'New Project',
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
                      const _Label('Project Title'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleCtrl,
                        autofocus: true,
                        decoration:
                            _inputDecoration(context, 'e.g. HCI Assignment'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Project title is required'
                            : null,
                      ),

                      const SizedBox(height: 20),

                      const _Label('Description'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 3,
                        decoration: _inputDecoration(
                            context, 'What is this project about?'),
                      ),

                      const SizedBox(height: 20),

                      const _Label('Due Date'),
                      const SizedBox(height: 8),
                      _PickerRow(
                        icon: Icons.calendar_today_outlined,
                        label: _dateDisplay,
                        hasValue: _dueDate != null,
                        onTap: _pickDate,
                      ),

                      const SizedBox(height: 20),

                      const _Label('Priority'),
                      const SizedBox(height: 8),
                      _PrioritySelector(
                        selected: _priority,
                        onSelected: (p) => setState(() => _priority = p),
                      ),

                      const SizedBox(height: 20),

                      const _Label('Category'),
                      const SizedBox(height: 8),
                      _CategorySelector(
                        selected: _category,
                        onSelected: (c) => setState(() => _category = c),
                      ),

                      const SizedBox(height: 20),

                      // ✅ Use linkedTasks derived from _localAllTasks
                      if (linkedTasks.isNotEmpty) ...[
                        const _Label('Linked Tasks'),
                        const SizedBox(height: 8),
                        _LinkedTasksList(
                          tasks: linkedTasks,
                          onRemove: (id) =>
                              setState(() => _selectedTaskIds.remove(id)),
                        ),
                        const SizedBox(height: 12),
                      ],

                      GestureDetector(
                        onTap: _openTaskPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                size: 18,
                                color: _isSaving
                                    ? theme.textTheme.bodySmall?.color
                                    : theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Link Tasks',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _isSaving
                                      ? theme.textTheme.bodySmall?.color
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

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
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
                                  : const Text(
                                      'Create Project',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: Priority.values.map((p) {
        final isSelected = selected == p;
        final color = p.color;
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

class _CategorySelector extends StatelessWidget {
  final ProjectCategory selected;
  final Function(ProjectCategory) onSelected;

  const _CategorySelector({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: ProjectCategory.values.map((c) {
        final isSelected = selected == c;
        final color = c.color;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color:
                      isSelected ? color.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : theme.dividerColor,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  c.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        isSelected ? color : theme.textTheme.bodySmall?.color,
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

class _LinkedTasksList extends StatelessWidget {
  final List<Task> tasks;
  final Function(String) onRemove;

  const _LinkedTasksList({required this.tasks, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: tasks.map((task) {
        final color = task.priority.color;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Icon(Icons.check_box_rounded,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    if (task.dueTime != null && task.dueTime!.isNotEmpty)
                      Text(
                        task.dueTime!,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Text(
                  task.priority.label,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: color),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onRemove(task.id),
                child: Icon(Icons.close_rounded,
                    size: 18, color: theme.textTheme.bodySmall?.color),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// =============================================================
// INPUT DECORATION
// =============================================================

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

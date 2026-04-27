// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/workspace/edit_project_screen.dart
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../widgets/common/app_header.dart';
import 'task_picker_screen.dart';

class EditProjectScreen extends StatefulWidget {
  final Project project;
  final List<Task> allTasks;
  final Function(Project) onProjectUpdated;

  const EditProjectScreen({
    super.key,
    required this.project,
    required this.allTasks,
    required this.onProjectUpdated,
  });

  @override
  State<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends State<EditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;

  late Priority _priority;
  late ProjectCategory _category;
  late DateTime _dueDate;
  late List<String> _selectedTaskIds;

  // ✅ KEY FIX: local mutable copy of tasks — grows as new tasks are created
  late List<Task> _localAllTasks;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.project.title);
    _descCtrl = TextEditingController(text: widget.project.description);
    _priority = widget.project.priority;
    _category = widget.project.category;
    _dueDate = widget.project.dueDate;
    _selectedTaskIds = List.from(widget.project.taskIds);
    // ✅ Initialize local task list from prop
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
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  String get _dateDisplay =>
      '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updated = widget.project.copyWith(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      dueDate: _dueDate,
      priority: _priority,
      status: widget.project.status,
      category: _category,
      taskIds: _selectedTaskIds,
    );

    try {
      await widget.onProjectUpdated(updated);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update project: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openTaskPicker() async {
    if (_isSaving) return;

    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskPickerScreen(
          // ✅ Pass the local list (includes any newly created tasks)
          allTasks: _localAllTasks,
          initialSelected: _selectedTaskIds,
          projectId: widget.project.id,
          onTaskCreated: (newTask) {
            // ✅ When a task is created inside picker, add it to local list
            // so that when picker returns, we can find the task object by ID
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

    // ✅ After picker closes, refresh provider so liveTasks is up to date
    await context.read<TaskProvider>().refreshTasks();

    if (!mounted) return;

    if (result != null) {
      // ✅ Merge any IDs from result that we might not have locally yet
      final freshTasks = context.read<TaskProvider>().tasks;
      for (final id in result) {
        if (!_localAllTasks.any((t) => t.id == id)) {
          final match = freshTasks.where((t) => t.id == id).firstOrNull
              ?? _localAllTasks.where((t) => t.id == id).firstOrNull;
          if (match != null) _localAllTasks.add(match);
        }
      }
      setState(() => _selectedTaskIds = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ✅ Still watch provider for completion toggles — but use _localAllTasks
    // to resolve task objects, falling back to provider for completion state
    final providerTasks = context.watch<TaskProvider>().tasks;

    // ✅ Build linkedTasks from _localAllTasks first, then merge completion
    // state from provider so toggles reflect live
    final linkedTasks = _selectedTaskIds
        .map((id) {
          // Try provider first (has latest completion state)
          final fromProvider =
              providerTasks.where((t) => t.id == id).firstOrNull;
          // Fall back to local list (has newly created tasks not yet in provider)
          final fromLocal = _localAllTasks.where((t) => t.id == id).firstOrNull;
          return fromProvider ?? fromLocal;
        })
        .whereType<Task>()
        .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Edit Project',
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
                        decoration: _inputDecoration(context, 'Project title'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Title is required'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      const _Label('Description'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 3,
                        decoration: _inputDecoration(context, 'No description'),
                      ),
                      const SizedBox(height: 20),
                      const _Label('Due Date'),
                      const SizedBox(height: 8),
                      _PickerRow(
                        icon: Icons.calendar_today_outlined,
                        label: _dateDisplay,
                        hasValue: true,
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
                      const _Label('Linked Tasks'),
                      const SizedBox(height: 8),
                      if (linkedTasks.isNotEmpty) ...[
                        _LinkedTasksEditor(
                          tasks: linkedTasks,
                          onToggleComplete: (id) {
                            context.read<TaskProvider>().toggleComplete(id);
                          },
                          onRemove: (id) =>
                              setState(() => _selectedTaskIds.remove(id)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      GestureDetector(
                        onTap: _isSaving ? null : _openTaskPicker,
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
                                'Link Existing Tasks',
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
                                      'Save Changes',
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

class _LinkedTasksEditor extends StatelessWidget {
  final List<Task> tasks;
  final Function(String id) onToggleComplete;
  final Function(String id) onRemove;

  const _LinkedTasksEditor({
    required this.tasks,
    required this.onToggleComplete,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: tasks.map((task) {
        final color = task.priority.color;
        final isCompleted = task.isCompleted;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isCompleted
                ? theme.colorScheme.primary.withOpacity(0.05)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCompleted
                  ? theme.colorScheme.primary.withOpacity(0.4)
                  : theme.dividerColor,
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => onToggleComplete(task.id),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    key: ValueKey(isCompleted),
                    size: 22,
                    color: isCompleted
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodySmall?.color,
                  ),
                ),
              ),
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
                        color: isCompleted
                            ? theme.textTheme.bodySmall?.color
                            : theme.textTheme.bodyLarge?.color,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    if (task.dueTime != null && task.dueTime!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        task.dueTime!,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
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

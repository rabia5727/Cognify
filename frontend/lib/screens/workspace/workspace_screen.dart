// lib/screens/workspace/workspace_screen.dart
// ONLY Task-related changes - Projects section remains EXACTLY as before

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../../models/task_model.dart';
import '../../models/project_model.dart';
import '../../providers/task_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/ui_feedback.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/empty_states/empty_workspace.dart';
import '../../widgets/loading/shimmer_loading.dart';
import 'add_task_screen.dart';
import 'edit_task_screen.dart';
import 'task_detail_screen.dart';
import 'add_project_screen.dart';
import 'edit_project_screen.dart';
import 'project_detail_screen.dart';

class WorkSpaceScreen extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const WorkSpaceScreen({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<WorkSpaceScreen> createState() => _WorkSpaceScreenState();
}

class _WorkSpaceScreenState extends State<WorkSpaceScreen> {
  // ─── UI-only state ──────────────────────────────────────────────
  int _selectedDayIndex = -1;
  int _filterIndex = 0;
  int _priorityFilterIndex = 0;
  int _categoryFilterIndex = 0; // 0: All, 1: Email, 2: Classroom
  int _innerTabIndex = 0;
  int _projectFilterIndex = 0;
  int _projectPriorityFilterIndex = 0;
  int _projectCategoryFilterIndex = 0; // Keep as is for projects
  List<Map<String, dynamic>> _calendarDays = [];
  String? _animatingTaskId;
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _generateCalendarDays();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _generateCalendarDays() {
    final now = DateTime.now();
    _calendarDays = List.generate(7, (i) {
      final date = now.add(Duration(days: i));
      return {
        'day': _dayAbbr(date.weekday),
        'date': date.day.toString().padLeft(2, '0'),
        'fullDate': date,
      };
    });
  }

  static String _dayAbbr(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  // ─── Task actions ────────────────────────────────────────────────

  Future<void> _toggleTask(String id) async {
    HapticFeedback.lightImpact();
    final taskProvider = context.read<TaskProvider>();
    final task = taskProvider.tasks.firstWhere((t) => t.id == id);
    final isCompleting = !task.isCompleted;

    setState(() => _animatingTaskId = id);
    await Future.delayed(const Duration(milliseconds: 150));

    try {
      await taskProvider.toggleComplete(id);
    } catch (_) {
      if (mounted) UIFeedback.showError(context, 'Could not update task.');
    }

    setState(() => _animatingTaskId = null);

    if (isCompleting && mounted) {
      _confettiController.play();
      UIFeedback.showSuccess(context, '🎉 Task completed! Great job!');
    }
  }

  void _goToAddTask() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(
          onTaskAdded: (newTask) async {
            try {
              await context.read<TaskProvider>().addTask(newTask);
              if (mounted) {
                UIFeedback.showSuccess(context, 'Task added successfully!');
              }
            } catch (_) {
              if (mounted) {
                UIFeedback.showError(context, 'Failed to add task.');
              }
            }
          },
        ),
      ),
    );
  }

  void _goToEditTask(String id) {
    final task =
        context.read<TaskProvider>().tasks.firstWhere((t) => t.id == id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditTaskScreen(
          task: task,
          onTaskUpdated: (updated) async {
            try {
              await context.read<TaskProvider>().updateTask(updated);
              if (mounted) {
                UIFeedback.showSuccess(context, 'Task updated successfully!');
              }
            } catch (_) {
              if (mounted) {
                UIFeedback.showError(context, 'Failed to update task.');
              }
            }
          },
        ),
      ),
    );
  }

  void _goToTaskDetail(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          taskId: id,
          onTaskUpdated: (updated) async {
            try {
              await context.read<TaskProvider>().updateTask(updated);
            } catch (_) {}
          },
          onTaskDeleted: (taskId) async {
            try {
              await context.read<TaskProvider>().deleteTask(taskId);
              if (mounted) UIFeedback.showSuccess(context, 'Task deleted');
            } catch (_) {}
          },
        ),
      ),
    );
  }

  Future<void> _deleteTask(String id) async {
    final confirmed = await UIFeedback.showConfirmDialog(
      context,
      title: 'Delete Task',
      message: 'Are you sure you want to delete this task?',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await context.read<TaskProvider>().deleteTask(id);
      if (mounted) UIFeedback.showSuccess(context, 'Task deleted');
    } catch (_) {
      if (mounted) UIFeedback.showError(context, 'Failed to delete task.');
    }
  }

  // ─── Project actions (UNCHANGED) ─────────────────────────────────

  void _goToAddProject() {
    final allTasks = context.read<TaskProvider>().tasks;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProjectScreen(
          allTasks: allTasks,
          onProjectAdded: (newProject) async {
            try {
              await context.read<ProjectProvider>().addProject(newProject);
              if (mounted) {
                UIFeedback.showSuccess(
                    context, 'Project created successfully!');
              }
            } catch (_) {
              if (mounted) {
                UIFeedback.showError(context, 'Failed to create project.');
              }
            }
          },
        ),
      ),
    );
  }

  void _goToEditProject(String id) {
    final project =
        context.read<ProjectProvider>().projects.firstWhere((p) => p.id == id);
    final allTasks = context.read<TaskProvider>().tasks;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProjectScreen(
          project: project,
          allTasks: allTasks,
          onProjectUpdated: (updated) async {
            try {
              await context.read<ProjectProvider>().updateProject(updated);
              if (mounted) {
                UIFeedback.showSuccess(
                    context, 'Project updated successfully!');
              }
            } catch (_) {
              if (mounted) {
                UIFeedback.showError(context, 'Failed to update project.');
              }
            }
          },
        ),
      ),
    );
  }

  void _goToProjectDetail(String id) {
    final project =
        context.read<ProjectProvider>().projects.firstWhere((p) => p.id == id);
    final allTasks = context.read<TaskProvider>().tasks;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(
          project: project,
          allTasks: allTasks,
          onProjectUpdated: (updated) async {
            try {
              await context.read<ProjectProvider>().updateProject(updated);
            } catch (_) {}
          },
          onProjectDeleted: (projectId) async {
            try {
              await context.read<ProjectProvider>().deleteProject(projectId);
              if (mounted) UIFeedback.showSuccess(context, 'Project deleted');
            } catch (_) {}
          },
        ),
      ),
    );
  }

  Future<void> _deleteProject(String id) async {
    final confirmed = await UIFeedback.showConfirmDialog(
      context,
      title: 'Delete Project',
      message: 'Are you sure? Linked tasks will be unlinked.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await context.read<ProjectProvider>().deleteProject(id);
      if (mounted) UIFeedback.showSuccess(context, 'Project deleted');
    } catch (_) {
      if (mounted) UIFeedback.showError(context, 'Failed to delete project.');
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _priorityFilterIndex = 0;
      _categoryFilterIndex = 0;
      _filterIndex = 0;
      _selectedDayIndex = -1;
      _projectPriorityFilterIndex = 0;
      _projectCategoryFilterIndex = 0;
      _projectFilterIndex = 0;
    });
    try {
      await Future.wait([
        context.read<TaskProvider>().refreshTasks(),
        context.read<ProjectProvider>().refreshProjects(),
      ]);
    } catch (_) {}
    if (mounted) UIFeedback.showInfo(context, 'Workspace refreshed!');
  }

  bool get hasTaskSortActive =>
      _priorityFilterIndex != 0 || _categoryFilterIndex != 0;

  bool get hasProjectSortActive =>
      _projectPriorityFilterIndex != 0 || _projectCategoryFilterIndex != 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Consumer2<TaskProvider, ProjectProvider>(
      builder: (context, taskProvider, projectProvider, _) {
        final tasks = taskProvider.tasks;
        final projects = projectProvider.projects;

        var filteredTasks = taskProvider.filtered(
          statusIndex: _filterIndex,
          priorityIndex: _priorityFilterIndex,
          categoryIndex: _categoryFilterIndex,
          date: (_selectedDayIndex >= 0 && _calendarDays.isNotEmpty)
              ? _calendarDays[_selectedDayIndex]['fullDate'] as DateTime
              : null,
        );

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: theme.colorScheme.primary,
              child: Column(
                children: [
                  AppHeader(
                    title: 'Workspace',
                    onBack: () => widget.onTabSelected(0),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _PillToggle(
                      labels: const ['Tasks', 'Projects'],
                      selectedIndex: _innerTabIndex,
                      onToggle: (i) => setState(() => _innerTabIndex = i),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_innerTabIndex == 0 && _calendarDays.isNotEmpty)
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _calendarDays.length + 1,
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return _AllDayChip(
                              isSelected: _selectedDayIndex == -1,
                              onTap: () =>
                                  setState(() => _selectedDayIndex = -1),
                            );
                          }
                          final di = i - 1;
                          return _CalendarDay(
                            day: _calendarDays[di]['day'] as String,
                            date: _calendarDays[di]['date'] as String,
                            isSelected: di == _selectedDayIndex,
                            hasTask: taskProvider
                                .tasksForDate(
                                  _calendarDays[di]['fullDate'] as DateTime,
                                )
                                .isNotEmpty,
                            onTap: () => setState(() => _selectedDayIndex = di),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (_innerTabIndex == 0) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _FilterChip(
                                    label: 'All',
                                    isSelected: _filterIndex == 0,
                                    onTap: () =>
                                        setState(() => _filterIndex = 0),
                                    color: const Color(0xFF1360E2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _FilterChip(
                                    label: 'Completed',
                                    isSelected: _filterIndex == 1,
                                    onTap: () =>
                                        setState(() => _filterIndex = 1),
                                    color: const Color(0xFF4CAF50),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _SortButton(
                            isActive: hasTaskSortActive,
                            priorityIndex: _priorityFilterIndex,
                            categoryIndex: _categoryFilterIndex,
                            onPriorityChanged: (i) {
                              setState(() => _priorityFilterIndex = i);
                            },
                            onCategoryChanged: (i) {
                              setState(() => _categoryFilterIndex = i);
                            },
                            onReset: () {
                              setState(() {
                                _priorityFilterIndex = 0;
                                _categoryFilterIndex = 0;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_innerTabIndex == 1) ...[
                    // PROJECTS SECTION - KEPT EXACTLY AS ORIGINAL
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _FilterChip(
                                    label: 'All',
                                    isSelected: _projectFilterIndex == 0,
                                    onTap: () =>
                                        setState(() => _projectFilterIndex = 0),
                                    color: const Color(0xFF1360E2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _FilterChip(
                                    label: 'In Progress',
                                    isSelected: _projectFilterIndex == 1,
                                    onTap: () =>
                                        setState(() => _projectFilterIndex = 1),
                                    color: const Color(0xFFEFA535),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _FilterChip(
                                    label: 'Completed',
                                    isSelected: _projectFilterIndex == 2,
                                    onTap: () =>
                                        setState(() => _projectFilterIndex = 2),
                                    color: const Color(0xFF4CAF50),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _SortButton(
                            isActive: hasProjectSortActive,
                            priorityIndex: _projectPriorityFilterIndex,
                            categoryIndex: _projectCategoryFilterIndex,
                            onPriorityChanged: (i) {
                              setState(() => _projectPriorityFilterIndex = i);
                            },
                            onCategoryChanged: (i) {
                              setState(() => _projectCategoryFilterIndex = i);
                            },
                            onReset: () {
                              setState(() {
                                _projectPriorityFilterIndex = 0;
                                _projectCategoryFilterIndex = 0;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: _innerTabIndex == 0
                        ? _TasksList(
                            tasks: filteredTasks,
                            onToggle: _toggleTask,
                            onEdit: _goToEditTask,
                            onDelete: _deleteTask,
                            onTap: _goToTaskDetail,
                            animatingTaskId: _animatingTaskId,
                          )
                        : _ProjectsList(
                            projects: projects,
                            allTasks: tasks,
                            filterIndex: _projectFilterIndex,
                            priorityFilterIndex: _projectPriorityFilterIndex,
                            categoryFilterIndex: _projectCategoryFilterIndex,
                            onTap: _goToProjectDetail,
                            onEdit: _goToEditProject,
                            onDelete: _deleteProject,
                          ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: SizedBox(
            width: 64,
            height: 64,
            child: FloatingActionButton(
              onPressed: _innerTabIndex == 0 ? _goToAddTask : _goToAddProject,
              backgroundColor: theme.colorScheme.primary,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: BottomNavBar(
            currentIndex: widget.currentIndex,
            userName: auth.userName,
            onTabSelected: widget.onTabSelected,
          ),
        );
      },
    );
  }
}

// ================================================================
// FILTER CHIP WIDGET (UNCHANGED)
// ================================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : theme.dividerColor,
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? color : theme.textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// SORT BUTTON (UPDATED CATEGORIES to Email/Classroom)
// ================================================================

class _SortButton extends StatefulWidget {
  final bool isActive;
  final int priorityIndex;
  final int categoryIndex;
  final ValueChanged<int> onPriorityChanged;
  final ValueChanged<int> onCategoryChanged;
  final VoidCallback onReset;

  const _SortButton({
    required this.isActive,
    required this.priorityIndex,
    required this.categoryIndex,
    required this.onPriorityChanged,
    required this.onCategoryChanged,
    required this.onReset,
  });

  @override
  State<_SortButton> createState() => _SortButtonState();
}

class _SortButtonState extends State<_SortButton> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggleDropdown() {
    if (_isOpen) {
      _hideDropdown();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    final RenderBox renderBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _hideDropdown,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
            Positioned(
              top: offset.dy + size.height + 4,
              right:
                  MediaQuery.of(context).size.width - (offset.dx + size.width),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 220,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Filter & Sort',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            if (widget.isActive)
                              GestureDetector(
                                onTap: () {
                                  widget.onReset();
                                  _hideDropdown();
                                },
                                child: Text(
                                  'Reset',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text(
                          'Priority',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      ...['All', 'High', 'Medium', 'Low']
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final label = entry.value;
                        final isSelected = widget.priorityIndex == index;
                        final colors = [
                          const Color(0xFF1360E2),
                          const Color(0xFFFF5252),
                          const Color(0xFFEFA535),
                          const Color(0xFF4CAF50)
                        ];
                        final color = colors[index];
                        return _DropdownMenuItem(
                          label: label,
                          isSelected: isSelected,
                          color: color,
                          onTap: () {
                            widget.onPriorityChanged(index);
                            _hideDropdown();
                          },
                        );
                      }).toList(),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text(
                          'Category',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      ...['All', 'Email', 'Classroom', 'General']
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final label = entry.value;
                        final isSelected = widget.categoryIndex == index;
                        final colors = [
                          const Color(0xFF1360E2),
                          const Color(0xFF7B61FF),
                          const Color(0xFF1360E2),
                          const Color(0xFF9E9E9E),
                        ];
                        final color = colors[index];
                        return _DropdownMenuItem(
                          label: label,
                          isSelected: isSelected,
                          color: color,
                          onTap: () {
                            widget.onCategoryChanged(index);
                            _hideDropdown();
                          },
                        );
                      }).toList(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _hideDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  @override
  void dispose() {
    _hideDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.isActive
        ? theme.colorScheme.primary
        : theme.textTheme.bodySmall?.color;

    return GestureDetector(
      key: _buttonKey,
      onTap: _toggleDropdown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isActive
              ? theme.colorScheme.primary.withOpacity(0.1)
              : theme.dividerColor,
          borderRadius: BorderRadius.circular(20),
          border: widget.isActive
              ? Border.all(color: theme.colorScheme.primary, width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              'Sort',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              size: 18,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownMenuItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _DropdownMenuItem({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? color.withOpacity(0.08) : Colors.transparent,
        child: Row(
          children: [
            if (isSelected) Icon(Icons.check_rounded, size: 16, color: color),
            if (isSelected) const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// PILL TOGGLE (UNCHANGED)
// ================================================================

class _PillToggle extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onToggle;

  const _PillToggle({
    required this.labels,
    required this.selectedIndex,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
          color: theme.dividerColor, borderRadius: BorderRadius.circular(30)),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: labels.asMap().entries.map((e) {
          final isSelected = selectedIndex == e.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => onToggle(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Text(e.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : theme.textTheme.bodySmall?.color)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ================================================================
// CALENDAR DAY (UNCHANGED)
// ================================================================

class _AllDayChip extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  const _AllDayChip({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
          ),
        ),
        child: Center(
          child: Text(
            'All',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color:
                  isSelected ? Colors.white : theme.textTheme.bodySmall?.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  final String day, date;
  final bool isSelected, hasTask;
  final VoidCallback onTap;
  const _CalendarDay(
      {required this.day,
      required this.date,
      required this.isSelected,
      required this.hasTask,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  isSelected ? theme.colorScheme.primary : theme.dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(day,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? Colors.white70
                        : theme.textTheme.bodySmall?.color)),
            const SizedBox(height: 4),
            Text(date,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? Colors.white
                        : theme.textTheme.bodyLarge?.color)),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: hasTask
                    ? (isSelected ? Colors.white : theme.colorScheme.primary)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// TASKS LIST - UPDATED CARD DESIGN
// ================================================================

class _TasksList extends StatelessWidget {
  final List<Task> tasks;
  final Function(String) onToggle, onEdit, onTap;
  final Future<void> Function(String) onDelete;
  final String? animatingTaskId;

  const _TasksList({
    required this.tasks,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
    this.animatingTaskId,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<TaskProvider>().isLoading;

    if (isLoading && tasks.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: 3,
        itemBuilder: (_, i) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: TaskCardShimmer(),
        ),
      );
    }

    if (tasks.isEmpty) {
      return const EmptyTasksFilter();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: tasks.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AnimatedOpacity(
          opacity: animatingTaskId == tasks[i].id ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: _TaskCard(
            task: tasks[i],
            onTap: () => onTap(tasks[i].id),
            onToggle: () => onToggle(tasks[i].id),
            onEdit: () => onEdit(tasks[i].id),
            onDelete: () => onDelete(tasks[i].id),
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap, onToggle, onEdit, onDelete;

  const _TaskCard({
    required this.task,
    required this.onTap,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatDueDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate =
        DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    if (dueDate == today) return 'Today';
    if (dueDate == today.add(const Duration(days: 1))) return 'Tomorrow';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dueDate.day} ${months[dueDate.month - 1]}';
  }

  String _formatDueTime() {
    if (task.dueTime != null && task.dueTime!.isNotEmpty) {
      return task.dueTime!;
    }
    final hour = task.dueDate.hour;
    final minute = task.dueDate.minute;
    final period = hour >= 12 ? 'pm' : 'am';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')}$period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = task.isCompleted;
    final priorityColor = task.priority.color;

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== TOP ROW: Checkbox + Title + Priority Badge ==========
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Checkbox
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCompleted
                            ? theme.colorScheme.primary
                            : theme.textTheme.bodySmall?.color ?? Colors.grey,
                        width: 1.5,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                // Title
                Expanded(
                  child: Text(
                    task.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted
                          ? theme.textTheme.bodySmall?.color
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Priority Badge (outlined pill)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: priorityColor, width: 1.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    task.priority.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),

            // Subtitle
            if (task.subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Text(
                  task.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            Divider(height: 1, color: theme.dividerColor),
            const SizedBox(height: 10),

            // ========== BOTTOM ROW: Due Time + Category + Edit/Delete ==========
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 14, color: theme.textTheme.bodySmall?.color),
                const SizedBox(width: 5),
                Text(
                  'Due ${_formatDueDate()} · ${_formatDueTime()}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
                // Category Tag
                _buildCategoryTag(task.category),
                const Spacer(),
                // Edit Icon
                GestureDetector(
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                // Delete Icon
                GestureDetector(
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: Color(0xFFFF5252),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTag(TaskCategory category) {
    final color = category.color;
    final label = category.label;
    final icon = category == TaskCategory.email
        ? Icons.email_outlined
        : category == TaskCategory.classroom
            ? Icons.class_outlined
            : Icons.label_outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// PROJECTS LIST - COMPLETELY UNCHANGED (KEEP YOUR ORIGINAL)
// ================================================================

class _ProjectsList extends StatelessWidget {
  final List<Project> projects;
  final List<Task> allTasks;
  final int filterIndex;
  final int priorityFilterIndex;
  final int categoryFilterIndex;
  final Function(String) onTap, onEdit;
  final Future<void> Function(String) onDelete;

  const _ProjectsList({
    required this.projects,
    required this.allTasks,
    required this.filterIndex,
    required this.priorityFilterIndex,
    required this.categoryFilterIndex,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  List<Project> get _filteredProjects {
    var filtered = projects;

    int getCompletedCount(Project p) {
      final linkedTasks =
          allTasks.where((t) => p.taskIds.contains(t.id)).toList();
      if (linkedTasks.isEmpty) return 0;
      return linkedTasks.where((t) => t.isCompleted).length;
    }

    int getTotalCount(Project p) {
      return allTasks.where((t) => p.taskIds.contains(t.id)).toList().length;
    }

    if (filterIndex == 1) {
      filtered = filtered.where((p) {
        final total = getTotalCount(p);
        if (total == 0) return false;
        final completed = getCompletedCount(p);
        return completed > 0 && completed < total;
      }).toList();
    } else if (filterIndex == 2) {
      filtered = filtered.where((p) {
        final total = getTotalCount(p);
        if (total == 0) return false;
        final completed = getCompletedCount(p);
        return completed == total;
      }).toList();
    }

    if (priorityFilterIndex == 1) {
      filtered = filtered.where((p) => p.priority == Priority.high).toList();
    } else if (priorityFilterIndex == 2) {
      filtered = filtered.where((p) => p.priority == Priority.medium).toList();
    } else if (priorityFilterIndex == 3) {
      filtered = filtered.where((p) => p.priority == Priority.low).toList();
    }

    // Keep original category filter for projects (Freelance/Academic)
    if (categoryFilterIndex == 1) {
      filtered = filtered
          .where((p) => p.category == ProjectCategory.freelance)
          .toList();
    } else if (categoryFilterIndex == 2) {
      filtered = filtered
          .where((p) => p.category == ProjectCategory.academic)
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<ProjectProvider>().isLoading;
    final filtered = _filteredProjects;

    if (isLoading && projects.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: 3,
        itemBuilder: (_, i) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ProjectCardShimmer(),
        ),
      );
    }

    if (filtered.isEmpty) {
      return const EmptyProjects();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: filtered.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _ProjectCard(
          project: filtered[i],
          allTasks: allTasks,
          onTap: () => onTap(filtered[i].id),
          onEdit: () => onEdit(filtered[i].id),
          onDelete: () => onDelete(filtered[i].id),
        ),
      ),
    );
  }
}

// ================================================================
// PROJECT CARD - COMPLETELY UNCHANGED (KEEP YOUR ORIGINAL)
// ================================================================

class _ProjectCard extends StatelessWidget {
  final Project project;
  final List<Task> allTasks;
  final VoidCallback onTap, onEdit, onDelete;
  const _ProjectCard({
    required this.project,
    required this.allTasks,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  List<Task> get _linkedTasks =>
      allTasks.where((t) => project.taskIds.contains(t.id)).toList();

  double get _progress {
    final linked = _linkedTasks;
    if (linked.isEmpty) return 0.0;
    return linked.where((t) => t.isCompleted).length / linked.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linked = _linkedTasks;
    final completedCount = linked.where((t) => t.isCompleted).length;
    final totalCount = linked.length;
    final percent = (_progress * 100).round();

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  project.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: project.priority.color,
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  project.priority.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: project.priority.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: project.category.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              project.category.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: project.category.color,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 7,
                    backgroundColor: theme.brightness == Brightness.dark
                        ? const Color(0xFF2A2D3E)
                        : const Color(0xFFE8ECF4),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _progress >= 1.0
                          ? const Color(0xFF4CAF50)
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$percent%',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.description_outlined,
                  size: 14, color: theme.textTheme.bodySmall?.color),
              const SizedBox(width: 6),
              Text(
                '$completedCount/$totalCount tasks done',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                child: Icon(Icons.edit_outlined,
                    size: 18, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: Color(0xFFFF5252)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

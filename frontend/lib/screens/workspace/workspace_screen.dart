// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/workspace/workspace_screen.dart
// CHANGES FROM REVIEW:
//   - All _showSuccessSnackBar replaced with UIFeedback
//   - _getDayAbbreviation removed (it's a top-level helper in dummy_data.dart,
//     but since we want workspace to be self-contained, it stays as a private
//     static method here — the one in dummy_data.dart is also private so
//     there's no public duplication)
//   - Delete dialogs now use UIFeedback.showConfirmDialog
//   - _confettiController nullable check cleaned up
//   - No UI or feature changes
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import '../../constants/app_constant.dart';
import '../../models/task_model.dart';
import '../../models/project_model.dart';
import '../../data/dummy_data.dart';
import '../../utils/ui_feedback.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_header.dart';
import '../../widgets/priority_badge.dart';
import 'add_task_screen.dart';
import 'edit_task_screen.dart';
import 'task_detail_screen.dart';
import 'add_project_screen.dart';
import 'edit_project_screen.dart';
import 'project_detail_screen.dart';

class WorkSpaceScreen extends StatefulWidget {
  final String userName;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const WorkSpaceScreen({
    super.key,
    required this.userName,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<WorkSpaceScreen> createState() => _WorkSpaceScreenState();
}

class _WorkSpaceScreenState extends State<WorkSpaceScreen> {
  int _selectedDayIndex = 0;
  int _filterIndex = 0;
  int _priorityFilterIndex = 0;
  int _innerTabIndex = 0;

  late List<Task> _tasks;
  late List<Project> _projects;
  String? _animatingTaskId;
  List<Map<String, dynamic>> _calendarDays = [];
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _tasks = List.from(DummyData.tasks);
    _projects = List.from(DummyData.projects);
    _generateCalendarDays();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  // =============================================================
  // CALENDAR
  // =============================================================

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

  bool _hasTasksOnDate(DateTime date) => _tasks.any(
        (t) =>
            t.dueDate.year == date.year &&
            t.dueDate.month == date.month &&
            t.dueDate.day == date.day,
      );

  // =============================================================
  // FILTER LOGIC
  // =============================================================

  List<Task> get _filteredTasks {
    List<Task> result = List.from(_tasks);

    // Status filter
    switch (_filterIndex) {
      case 1:
        result =
            result.where((t) => t.status == TaskStatus.inProgress).toList();
        break;
      case 2:
        result = result.where((t) => t.isCompleted).toList();
        break;
    }

    // Priority filter
    if (_priorityFilterIndex > 0) {
      const map = {1: Priority.high, 2: Priority.medium, 3: Priority.low};
      final p = map[_priorityFilterIndex]!;
      result = result.where((t) => t.priority == p).toList();
    }

    // Date filter
    if (_calendarDays.isNotEmpty) {
      final selected = _calendarDays[_selectedDayIndex]['fullDate'] as DateTime;
      result = result
          .where((t) =>
              t.dueDate.year == selected.year &&
              t.dueDate.month == selected.month &&
              t.dueDate.day == selected.day)
          .toList();
    }

    return result;
  }

  // =============================================================
  // TASK ACTIONS
  // =============================================================

  Future<void> _toggleTask(String id) async {
    HapticFeedback.lightImpact();
    final task = _tasks.firstWhere((t) => t.id == id);
    final isCompleting = !task.isCompleted;

    setState(() => _animatingTaskId = id);
    await Future.delayed(const Duration(milliseconds: 150));

    setState(() {
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(
          status: _tasks[index].isCompleted
              ? TaskStatus.todo
              : TaskStatus.completed,
        );
      }
      _animatingTaskId = null;
    });

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
          onTaskAdded: (newTask) {
            setState(() {
              _tasks.add(newTask);
              _generateCalendarDays();
            });
            UIFeedback.showSuccess(context, 'Task added successfully!');
          },
        ),
      ),
    );
  }

  void _goToEditTask(String id) {
    final task = _tasks.firstWhere((t) => t.id == id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditTaskScreen(
          task: task,
          onTaskUpdated: (updated) {
            setState(() {
              final index = _tasks.indexWhere((t) => t.id == id);
              if (index != -1) _tasks[index] = updated;
              _generateCalendarDays();
            });
            UIFeedback.showSuccess(context, 'Task updated successfully!');
          },
        ),
      ),
    );
  }

  void _goToTaskDetail(String id) {
    final task = _tasks.firstWhere((t) => t.id == id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          task: task,
          onTaskUpdated: (updated) {
            setState(() {
              final index = _tasks.indexWhere((t) => t.id == id);
              if (index != -1) _tasks[index] = updated;
              _generateCalendarDays();
            });
          },
          onTaskDeleted: (taskId) {
            setState(() {
              _tasks.removeWhere((t) => t.id == taskId);
              _generateCalendarDays();
            });
            UIFeedback.showSuccess(context, 'Task deleted');
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
    setState(() {
      _tasks.removeWhere((t) => t.id == id);
      _generateCalendarDays();
    });
    if (mounted) UIFeedback.showSuccess(context, 'Task deleted');
  }

  // =============================================================
  // PROJECT ACTIONS
  // =============================================================

  void _goToAddProject() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProjectScreen(
          allTasks: _tasks,
          onProjectAdded: (newProject) {
            setState(() => _projects.add(newProject));
            UIFeedback.showSuccess(context, 'Project created successfully!');
          },
        ),
      ),
    );
  }

  void _goToEditProject(String id) {
    final project = _projects.firstWhere((p) => p.id == id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProjectScreen(
          project: project,
          allTasks: _tasks,
          onProjectUpdated: (updated) {
            setState(() {
              final index = _projects.indexWhere((p) => p.id == id);
              if (index != -1) _projects[index] = updated;
            });
            UIFeedback.showSuccess(context, 'Project updated successfully!');
          },
        ),
      ),
    );
  }

  void _goToProjectDetail(String id) {
    final project = _projects.firstWhere((p) => p.id == id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(
          project: project,
          allTasks: _tasks,
          onProjectUpdated: (updated) {
            setState(() {
              final index = _projects.indexWhere((p) => p.id == id);
              if (index != -1) _projects[index] = updated;
            });
          },
          onProjectDeleted: (projectId) {
            setState(() => _projects.removeWhere((p) => p.id == projectId));
            UIFeedback.showSuccess(context, 'Project deleted');
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
    setState(() => _projects.removeWhere((p) => p.id == id));
    if (mounted) UIFeedback.showSuccess(context, 'Project deleted');
  }

  Future<void> _onRefresh() async {
    setState(() {
      _tasks = List.from(DummyData.tasks);
      _projects = List.from(DummyData.projects);
      _generateCalendarDays();
      _priorityFilterIndex = 0;
      _filterIndex = 0;
      _selectedDayIndex = 0;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) UIFeedback.showInfo(context, 'Workspace refreshed!');
  }

  // =============================================================
  // BUILD
  // =============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
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
                        itemCount: _calendarDays.length,
                        itemBuilder: (_, i) => _CalendarDay(
                          day: _calendarDays[i]['day'] as String,
                          date: _calendarDays[i]['date'] as String,
                          isSelected: i == _selectedDayIndex,
                          hasTask: _hasTasksOnDate(
                              _calendarDays[i]['fullDate'] as DateTime),
                          onTap: () => setState(() => _selectedDayIndex = i),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (_innerTabIndex == 0) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _PillToggle(
                        labels: const ['All', 'In Progress', 'Completed'],
                        selectedIndex: _filterIndex,
                        onToggle: (i) => setState(() => _filterIndex = i),
                        tabFontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _PriorityFilterChips(
                        selectedIndex: _priorityFilterIndex,
                        onSelected: (i) =>
                            setState(() => _priorityFilterIndex = i),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: _innerTabIndex == 0
                        ? _TasksList(
                            tasks: _filteredTasks,
                            onToggle: _toggleTask,
                            onEdit: _goToEditTask,
                            onDelete: _deleteTask,
                            onTap: _goToTaskDetail,
                            animatingTaskId: _animatingTaskId,
                          )
                        : _ProjectsList(
                            projects: _projects,
                            allTasks: _tasks,
                            onTap: _goToProjectDetail,
                            onEdit: _goToEditProject,
                            onDelete: _deleteProject,
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.2,
              shouldLoop: false,
              colors: const [
                Colors.red,
                Colors.green,
                Colors.blue,
                Colors.yellow,
                Colors.purple,
                Colors.orange,
                Colors.pink,
              ],
              strokeWidth: 2,
              strokeColor: Colors.white,
            ),
          ),
        ],
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavBar(
        currentIndex: widget.currentIndex,
        userName: widget.userName,
        onTabSelected: widget.onTabSelected,
      ),
    );
  }
}

// =============================================================
// PRIORITY FILTER CHIPS
// =============================================================

class _PriorityFilterChips extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _PriorityFilterChips({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const labels = ['All', 'High', 'Medium', 'Low'];
    const colors = [
      Color(0xFF1360E2),
      Color(0xFFFF5252),
      Color(0xFFEFA535),
      Color(0xFF4CAF50),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (index) {
          final isSelected = selectedIndex == index;
          final color = colors[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(labels[index]),
              selected: isSelected,
              onSelected: (_) => onSelected(index),
              backgroundColor: theme.cardColor,
              selectedColor: color.withOpacity(0.2),
              checkmarkColor: color,
              labelStyle: TextStyle(
                color: isSelected ? color : theme.textTheme.bodySmall?.color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? color : theme.dividerColor,
                width: 1,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// =============================================================
// PILL TOGGLE
// =============================================================

class _PillToggle extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onToggle;
  final double tabFontSize;

  const _PillToggle({
    required this.labels,
    required this.selectedIndex,
    required this.onToggle,
    this.tabFontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.dividerColor,
        borderRadius: BorderRadius.circular(30),
      ),
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
                child: Text(
                  e.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: tabFontSize,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : theme.textTheme.bodySmall?.color,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// =============================================================
// CALENDAR DAY
// =============================================================

class _CalendarDay extends StatelessWidget {
  final String day, date;
  final bool isSelected, hasTask;
  final VoidCallback onTap;

  const _CalendarDay({
    required this.day,
    required this.date,
    required this.isSelected,
    required this.hasTask,
    required this.onTap,
  });

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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(day,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white70
                      : theme.textTheme.bodySmall?.color,
                )),
            const SizedBox(height: 4),
            Text(date,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Colors.white
                      : theme.textTheme.bodyLarge?.color,
                )),
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

// =============================================================
// TASKS LIST
// =============================================================

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
    final theme = Theme.of(context);

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt_rounded, size: 56, color: theme.dividerColor),
            const SizedBox(height: 12),
            Text('No tasks match your filters',
                style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => AnimatedOpacity(
        opacity: animatingTaskId == tasks[i].id ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: _TaskRow(
          task: tasks[i],
          onTap: () => onTap(tasks[i].id),
          onToggle: () => onToggle(tasks[i].id),
          onEdit: () => onEdit(tasks[i].id),
          onDelete: () => onDelete(tasks[i].id),
        ),
      ),
    );
  }
}

// =============================================================
// TASK ROW
// =============================================================

class _TaskRow extends StatelessWidget {
  final Task task;
  final VoidCallback onTap, onToggle, onEdit;
  final VoidCallback onDelete;

  const _TaskRow({
    required this.task,
    required this.onTap,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: task.isCompleted
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: task.isCompleted
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodySmall?.color ?? Colors.grey,
                    width: 1.5,
                  ),
                ),
                child: task.isCompleted
                    ? const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.isCompleted
                                ? theme.textTheme.bodySmall?.color
                                : theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      PriorityBadge(priority: task.priority),
                    ],
                  ),
                  if (task.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(task.subtitle, style: theme.textTheme.labelSmall),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 12, color: theme.textTheme.bodySmall?.color),
                      const SizedBox(width: 4),
                      Text(task.dueTime ?? task.formattedDueDate,
                          style: theme.textTheme.labelSmall),
                      const Spacer(),
                      GestureDetector(
                        onTap: onEdit,
                        child: Icon(Icons.edit_outlined,
                            size: 16, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: onDelete,
                        child: const Icon(Icons.delete_outline_rounded,
                            size: 16, color: Color(0xFFFF5252)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// PROJECTS LIST
// =============================================================

class _ProjectsList extends StatelessWidget {
  final List<Project> projects;
  final List<Task> allTasks;
  final Function(String) onTap, onEdit;
  final Future<void> Function(String) onDelete;

  const _ProjectsList({
    required this.projects,
    required this.allTasks,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 56, color: theme.dividerColor),
            const SizedBox(height: 12),
            Text('No projects yet!', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text('Tap + to create your first project',
                style: theme.textTheme.labelSmall),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: projects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _ProjectCard(
        project: projects[i],
        allTasks: allTasks,
        onTap: () => onTap(projects[i].id),
        onEdit: () => onEdit(projects[i].id),
        onDelete: () => onDelete(projects[i].id),
      ),
    );
  }
}

// =============================================================
// PROJECT CARD
// =============================================================

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

  double get _progress {
    if (project.taskIds.isEmpty) return 0.0;
    final linked =
        allTasks.where((t) => project.taskIds.contains(t.id)).toList();
    if (linked.isEmpty) return 0.0;
    return linked.where((t) => t.isCompleted).length / linked.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (_progress * 100).round();

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                PriorityBadge(priority: project.priority),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    project.description.isNotEmpty
                        ? project.description
                        : 'General',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.calendar_today_outlined,
                    size: 11, color: theme.textTheme.bodySmall?.color),
                const SizedBox(width: 4),
                Text(project.dueDateDisplay, style: theme.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 8,
                      backgroundColor: theme.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _progress == 1.0
                            ? Colors.green
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('$percent%',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.task_rounded,
                          size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text('${project.taskIds.length} tasks',
                          style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onEdit,
                      child: Icon(Icons.edit_outlined,
                          size: 18, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: Color(0xFFFF5252)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

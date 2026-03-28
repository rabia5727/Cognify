// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/workspace/workspace_screen.dart
// PURPOSE: Main screen for managing both Tasks and Projects
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../constants/app_constant.dart';
import '../../models/task_model.dart';
import '../../models/project_model.dart';
import '../../data/dummy_data.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_header.dart';
import '../../widgets/priority_badge.dart';
import 'add_task_dialog.dart';
import 'edit_task_dialog.dart';
import 'task_detail_screen.dart';
import 'add_project_dialog.dart';
import 'edit_project_dialog.dart';
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
  int _selectedDayIndex = 3;
  int _filterIndex = 0;
  int _innerTabIndex = 0;

  late List<Task> _tasks;
  late List<Project> _projects;

  @override
  void initState() {
    super.initState();
    _tasks = List.from(DummyData.tasks);
    _projects = List.from(DummyData.projects);
  }

  List<Task> get _filteredTasks {
    switch (_filterIndex) {
      case 1:
        return _tasks.where((t) => t.status == TaskStatus.inProgress).toList();
      case 2:
        return _tasks.where((t) => t.isCompleted).toList();
      default:
        return _tasks;
    }
  }

  // =============================================================
  // TASK METHODS
  // =============================================================

  void _toggleTask(String id) {
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        final task = _tasks[index];
        final newStatus =
            task.isCompleted ? TaskStatus.todo : TaskStatus.completed;
        _tasks[index] = task.copyWith(status: newStatus);
      }
    });
  }

  void _showAddTaskDialog() {
    showAddTaskDialog(
      context: context,
      onTaskAdded: (newTask) {
        setState(() {
          _tasks.add(newTask);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task added successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _editTask(String id) {
    final task = _tasks.firstWhere((t) => t.id == id);
    showEditTaskDialog(
      context: context,
      task: task,
      onTaskUpdated: (updatedTask) {
        setState(() {
          final index = _tasks.indexWhere((t) => t.id == id);
          if (index != -1) {
            _tasks[index] = updatedTask;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task updated successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _viewTaskDetail(String id) {
    final task = _tasks.firstWhere((t) => t.id == id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          task: task,
          onTaskUpdated: (updatedTask) {
            setState(() {
              final index = _tasks.indexWhere((t) => t.id == id);
              if (index != -1) {
                _tasks[index] = updatedTask;
              }
            });
          },
          onTaskDeleted: (taskId) {
            setState(() {
              _tasks.removeWhere((t) => t.id == taskId);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Task deleted'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  void _deleteTask(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _tasks.removeWhere((t) => t.id == id);
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Task deleted'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // PROJECT METHODS
  // =============================================================

  void _showAddProjectDialog() {
    showAddProjectDialog(
      context: context,
      onProjectAdded: (newProject) {
        setState(() {
          _projects.add(newProject);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project created successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _editProject(String id) {
    final project = _projects.firstWhere((p) => p.id == id);
    showEditProjectDialog(
      context: context,
      project: project,
      allTasks: _tasks,
      onProjectUpdated: (updatedProject) {
        setState(() {
          final index = _projects.indexWhere((p) => p.id == id);
          if (index != -1) {
            _projects[index] = updatedProject;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project updated successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _viewProjectDetail(String id) {
    final project = _projects.firstWhere((p) => p.id == id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(
          project: project,
          allTasks: _tasks,
          onProjectUpdated: (updatedProject) {
            setState(() {
              final index = _projects.indexWhere((p) => p.id == id);
              if (index != -1) {
                _projects[index] = updatedProject;
              }
            });
          },
          onProjectDeleted: (projectId) {
            setState(() {
              _projects.removeWhere((p) => p.id == projectId);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Project deleted'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  void _deleteProject(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text(
          'Are you sure you want to delete this project?\nAll associated tasks will be unlinked.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _projects.removeWhere((p) => p.id == id);
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Project deleted'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
              title: 'Workspace',
              onBack: () => widget.onTabSelected(0),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _PillToggle(
                labels: ['Tasks', 'Projects'],
                selectedIndex: _innerTabIndex,
                onToggle: (i) => setState(() => _innerTabIndex = i),
              ),
            ),
            const SizedBox(height: 12),
            if (_innerTabIndex == 0)
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: DummyData.calendarDays.length,
                  itemBuilder: (_, i) => _CalendarDay(
                    day: DummyData.calendarDays[i]['day']!,
                    date: DummyData.calendarDays[i]['date']!,
                    isSelected: i == _selectedDayIndex,
                    hasTask: [0, 3, 5].contains(i),
                    onTap: () => setState(() => _selectedDayIndex = i),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (_innerTabIndex == 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _PillToggle(
                  labels: ['All', 'In Progress', 'Completed'],
                  selectedIndex: _filterIndex,
                  onToggle: (i) => setState(() => _filterIndex = i),
                  tabFontSize: 12,
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: _innerTabIndex == 0
                  ? _TasksList(
                      tasks: _filteredTasks,
                      onToggle: _toggleTask,
                      onEdit: _editTask,
                      onDelete: _deleteTask,
                      onTap: _viewTaskDetail,
                    )
                  : _ProjectsList(
                      projects: _projects,
                      allTasks: _tasks,
                      onTap: _viewProjectDetail,
                      onEdit: _editProject,
                      onDelete: _deleteProject,
                    ),
            ),
          ],
        ),
      ),
      // ✅ Single FAB with plus icon for both tabs
      floatingActionButton: SizedBox(
        width: 64,
        height: 64,
        child: FloatingActionButton(
          onPressed:
              _innerTabIndex == 0 ? _showAddTaskDialog : _showAddProjectDialog,
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

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Pill Toggle
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Calendar Day
// ─────────────────────────────────────────────────────────────────────────────

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
      child: Container(
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
            Text(
              day,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white70
                    : theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? Colors.white
                    : theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 4),
            Container(
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

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Tasks List
// ─────────────────────────────────────────────────────────────────────────────

class _TasksList extends StatelessWidget {
  final List<Task> tasks;
  final Function(String) onToggle;
  final Function(String) onEdit;
  final Function(String) onDelete;
  final Function(String) onTap;

  const _TasksList({
    required this.tasks,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
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
            Text(
              'No tasks here!',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TaskRow(
        task: tasks[i],
        onTap: () => onTap(tasks[i].id),
        onToggle: () => onToggle(tasks[i].id),
        onEdit: () => onEdit(tasks[i].id),
        onDelete: () => onDelete(tasks[i].id),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Task Row
// ─────────────────────────────────────────────────────────────────────────────

class _TaskRow extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
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
              child: Container(
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
                    Text(
                      task.subtitle,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 12, color: theme.textTheme.bodySmall?.color),
                      const SizedBox(width: 4),
                      Text(
                        task.dueTime ?? task.formattedDueDate,
                        style: theme.textTheme.labelSmall,
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Projects List
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectsList extends StatelessWidget {
  final List<Project> projects;
  final List<Task> allTasks;
  final Function(String) onTap;
  final Function(String) onEdit;
  final Function(String) onDelete;

  const _ProjectsList({
    required this.projects,
    required this.allTasks,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Project Card
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  final Project project;
  final List<Task> allTasks;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.allTasks,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  double get _progress {
    if (project.taskIds.isEmpty) return 0.0;
    final projectTasks =
        allTasks.where((task) => project.taskIds.contains(task.id)).toList();
    if (projectTasks.isEmpty) return 0.0;
    final completedCount =
        projectTasks.where((task) => task.isCompleted).length;
    return completedCount / projectTasks.length;
  }

  int get _progressPercentage => (_progress * 100).round();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
                Text(
                  project.dueDateDisplay,
                  style: theme.textTheme.labelSmall,
                ),
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
                Text(
                  '$_progressPercentage%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.task_rounded,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${project.taskIds.length} tasks',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onEdit,
                      child: Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Color(0xFFFF5252),
                      ),
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

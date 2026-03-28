// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/tasks/tasks_screen.dart
// CHANGES:
//   - Removed TaskItem + Project models (now in lib/models/)
//   - Removed _priorityColor logic (now in AppConstants)
//   - Uses DummyData for tasks + projects + calendar
//   - Uses AppHeader widget instead of inline top bar
//   - Uses PriorityBadge widget
//   - Uses AddTaskFab widget (specific to tasks screen)
//   - Fixed project progress calculation
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

class TasksScreen extends StatefulWidget {
  final String userName;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const TasksScreen({
    super.key,
    required this.userName,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int _selectedDayIndex = 3;
  int _filterIndex = 0;
  int _innerTabIndex = 0;

  // Load from DummyData (replace with TaskService later)
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
    final titleCtrl = TextEditingController();
    final subtitleCtrl = TextEditingController();
    Priority selectedPriority = Priority.medium;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppConstants.lightGray,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add New Task',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Task title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppConstants.primaryBlue,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subtitleCtrl,
                decoration: InputDecoration(
                  hintText: 'Subtitle (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppConstants.primaryBlue,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Priority',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: Priority.values.map((priority) {
                  final isSelected = selectedPriority == priority;
                  final color = AppConstants.priorityColorFromEnum(priority);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () =>
                          setModalState(() => selectedPriority = priority),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? color : AppConstants.lightGray,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          priority.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? color : AppConstants.grayText,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isNotEmpty) {
                      setState(() {
                        _tasks.add(Task(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleCtrl.text.trim(),
                          subtitle: subtitleCtrl.text.trim(),
                          dueDate: DateTime.now(),
                          dueTime: '—',
                          priority: selectedPriority,
                          status: TaskStatus.todo,
                        ));
                      });
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Add Task',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editTask(String id) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit coming soon!')),
    );
  }

  void _deleteTask(String id) {
    setState(() {
      _tasks.removeWhere((t) => t.id == id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task deleted'),
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Shared header widget ──────────────────────────────────
            AppHeader(
              title: 'Tasks',
              onBack: () => widget.onTabSelected(0),
            ),

            // ── Tasks / Projects toggle ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _PillToggle(
                labels: ['Tasks', 'Projects'],
                selectedIndex: _innerTabIndex,
                onToggle: (i) => setState(() => _innerTabIndex = i),
              ),
            ),

            const SizedBox(height: 12),

            // ── Horizontal calendar ───────────────────────────────────
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

            // ── Filter tabs (Tasks tab only) ──────────────────────────
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

            // ── Content ───────────────────────────────────────────────
            Expanded(
              child: _innerTabIndex == 0
                  ? _TasksList(
                      tasks: _filteredTasks,
                      onToggle: _toggleTask,
                      onEdit: _editTask,
                      onDelete: _deleteTask,
                    )
                  : _ProjectsList(
                      projects: _projects,
                      allTasks: _tasks,
                    ),
            ),
          ],
        ),
      ),
      // ── Add Task FAB (specific to tasks screen) ─────────────────────
      floatingActionButton: SizedBox(
        width: 64,
        height: 64,
        child: FloatingActionButton(
          onPressed: _showAddTaskDialog,
          backgroundColor: AppConstants.primaryBlue,
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
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.lightGray,
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
                      ? AppConstants.primaryBlue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Text(
                  e.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: tabFontSize,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppConstants.grayText,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? AppConstants.primaryBlue : AppConstants.lightGray,
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
                color: isSelected ? Colors.white70 : AppConstants.grayText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : AppConstants.darkText,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: hasTask
                    ? (isSelected ? Colors.white : AppConstants.primaryBlue)
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

  const _TasksList({
    required this.tasks,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt_rounded,
                size: 56, color: AppConstants.lightGray),
            const SizedBox(height: 12),
            Text(
              'No tasks here!',
              style: TextStyle(fontSize: 15, color: AppConstants.grayText),
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
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskRow({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: task.isCompleted
                    ? AppConstants.primaryBlue
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: task.isCompleted
                      ? AppConstants.primaryBlue
                      : AppConstants.grayText,
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: task.isCompleted
                              ? AppConstants.grayText
                              : AppConstants.darkText,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
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
                    style: const TextStyle(
                        fontSize: 11, color: AppConstants.grayText),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 12, color: AppConstants.grayText),
                    const SizedBox(width: 4),
                    Text(
                      task.dueTime ?? task.formattedDueDate,
                      style: const TextStyle(
                          fontSize: 11, color: AppConstants.grayText),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onEdit,
                      child: const Icon(Icons.edit_outlined,
                          size: 16, color: AppConstants.primaryBlue),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Projects List
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectsList extends StatelessWidget {
  final List<Project> projects;
  final List<Task> allTasks;

  const _ProjectsList({
    required this.projects,
    required this.allTasks,
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

  const _ProjectCard({
    required this.project,
    required this.allTasks,
  });

  // Calculate progress from actual tasks
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  project.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppConstants.darkText,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppConstants.inputBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  project.description.isNotEmpty
                      ? project.description
                      : 'General',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.calendar_today_outlined,
                  size: 11, color: AppConstants.grayText),
              const SizedBox(width: 4),
              Text(
                project.dueDateDisplay,
                style:
                    const TextStyle(fontSize: 11, color: AppConstants.grayText),
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
                    backgroundColor: AppConstants.lightGray,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _progress == 1.0
                          ? Colors.green
                          : AppConstants.primaryBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$_progressPercentage%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppConstants.darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppConstants.inputBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.task_rounded,
                  size: 14,
                  color: AppConstants.primaryBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  '${project.taskIds.length} tasks',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppConstants.grayText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

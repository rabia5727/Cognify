// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/dashboard/dashboard_screen.dart
// CHANGES:
//   - Now uses Theme.of(context) for dynamic colors
//   - Dark mode compatible
//   - Uses AppConstants only for non-color values
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../constants/app_constant.dart';
import '../../models/task_model.dart';
import '../../data/dummy_data.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_header.dart';
import '../../widgets/voice_fab.dart';
import '../../widgets/priority_badge.dart';
import '../settings/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showProactiveCard = true;

  late List<Task> _tasks;

  bool get _isNewUser => _tasks.isEmpty;
  int get _completedCount => _tasks.where((t) => t.isCompleted).length;
  double get _productivityScore =>
      _tasks.isEmpty ? 0.0 : _completedCount / _tasks.length;

  @override
  void initState() {
    super.initState();
    _tasks = List.from(DummyData.tasks);
  }

  void _markTaskComplete(String taskId) {
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        final task = _tasks[index];
        _tasks[index] = task.copyWith(status: TaskStatus.completed);
      }
    });
  }

  void _dismissProactiveCard() => setState(() => _showProactiveCard = false);

  void _addTask() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add Task coming soon!')),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(userName: widget.userName),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            DashboardHeader(
              userName: widget.userName,
              isNewUser: _isNewUser,
              showProactiveCard: _showProactiveCard,
              onYes: _dismissProactiveCard,
              onNo: _dismissProactiveCard,
              onProfileTap: _navigateToProfile,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Priorities",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 165,
                      child: _isNewUser
                          ? _EmptyTaskArea(onAddTask: _addTask)
                          : _TaskList(
                              tasks: _tasks,
                              onStartTask: _markTaskComplete,
                            ),
                    ),
                    const SizedBox(height: 16),
                    _ProductivityCard(
                      score: _productivityScore,
                      completedCount: _completedCount,
                      totalCount: _tasks.length,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const VoiceFab(),
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
// WIDGET: Empty Task Area
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyTaskArea extends StatelessWidget {
  final VoidCallback onAddTask;
  const _EmptyTaskArea({required this.onAddTask});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onAddTask,
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              'Add a high-priority task',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Task List (horizontal scroll)
// ─────────────────────────────────────────────────────────────────────────────

class _TaskList extends StatelessWidget {
  final List<Task> tasks;
  final Function(String) onStartTask;

  const _TaskList({required this.tasks, required this.onStartTask});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, i) => _TaskCard(
        task: tasks[i],
        onStart: () => onStartTask(tasks[i].id),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Task Card
// ─────────────────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onStart;

  const _TaskCard({required this.task, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 165,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: PriorityBadge(priority: task.priority),
            ),
            const SizedBox(height: 6),
            Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 13, color: theme.textTheme.bodySmall?.color),
                const SizedBox(width: 4),
                Text(
                  task.dueTime ?? task.formattedDueDate,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: task.isCompleted ? null : onStart,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: task.isCompleted
                      ? Colors.green.withOpacity(0.1)
                      : theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  task.isCompleted ? 'Done ✓' : 'Start Task >',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: task.isCompleted
                        ? Colors.green
                        : theme.colorScheme.primary,
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
// WIDGET: Productivity Card
// ─────────────────────────────────────────────────────────────────────────────

class _ProductivityCard extends StatelessWidget {
  final double score;
  final int completedCount;
  final int totalCount;

  const _ProductivityCard({
    required this.score,
    required this.completedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (score * 100).toInt();

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 11,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.dividerColor,
                    ),
                  ),
                ),
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: score,
                    strokeWidth: 11,
                    strokeCap: StrokeCap.round,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
                Text(
                  '$percentage%',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRODUCTIVITY SCORE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppConstants.productivityMessage(score),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$completedCount/$totalCount Completed',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
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

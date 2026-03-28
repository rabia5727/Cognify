// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/dashboard/dashboard_screen.dart
// CHANGES:
//   - Removed Task model (now in lib/models/task.dart)
//   - Removed _VoiceFAB (now in lib/widgets/voice_fab.dart)
//   - Removed _HeaderBanner (now DashboardHeader in lib/widgets/app_header.dart)
//   - Uses AppConstants for colors, greeting, formatting
//   - Uses DummyData for task list
//   - Uses PriorityBadge widget
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

  // Load tasks from DummyData (replace with TaskService later)
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
    return Scaffold(
      backgroundColor: AppConstants.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Dashboard header (blue gradient) ─────────────────────
            DashboardHeader(
              userName: widget.userName,
              isNewUser: _isNewUser,
              showProactiveCard: _showProactiveCard,
              onYes: _dismissProactiveCard,
              onNo: _dismissProactiveCard,
              onProfileTap: _navigateToProfile,
            ),

            // ── Body ─────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Priorities",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.darkText,
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
              decoration: const BoxDecoration(
                color: AppConstants.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              'Add a high-priority task',
              style: TextStyle(fontSize: 14, color: AppConstants.grayText),
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
    return SizedBox(
      width: 165,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Priority badge (uses shared widget)
            Align(
              alignment: Alignment.topRight,
              child: PriorityBadge(priority: task.priority),
            ),
            const SizedBox(height: 6),
            Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppConstants.darkText,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 13, color: AppConstants.grayText),
                const SizedBox(width: 4),
                Text(
                  task.dueTime ?? task.formattedDueDate,
                  style: TextStyle(fontSize: 12, color: AppConstants.grayText),
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
                      : AppConstants.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  task.isCompleted ? 'Done ✓' : 'Start Task >',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: task.isCompleted
                        ? Colors.green
                        : AppConstants.primaryBlue,
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
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppConstants.lightGray),
                  ),
                ),
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: score,
                    strokeWidth: 11,
                    strokeCap: StrokeCap.round,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppConstants.primaryBlue),
                  ),
                ),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppConstants.darkText,
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
                const Text(
                  'PRODUCTIVITY SCORE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppConstants.darkText,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppConstants.productivityMessage(score),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppConstants.grayText,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppConstants.primaryBlue,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$completedCount/$totalCount Completed',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppConstants.primaryBlue,
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

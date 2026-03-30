// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/dashboard/dashboard_screen.dart
// ENHANCEMENTS:
//   - Task cards clickable to task detail screen
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_constant.dart';
import '../../models/task_model.dart';
import '../../data/dummy_data.dart';
import '../../utils/ui_feedback.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_header.dart';
import '../../widgets/voice_fab.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/refresh_wrapper.dart';
import '../settings/profile_screen.dart';
import '../workspace/task_detail_screen.dart';

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

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _showProactiveCard = true;
  late List<Task> _tasks;
  late AnimationController _scoreController;
  late Animation<double> _scoreAnimation;
  String? _animatingTaskId;

  bool get _hasNoTasks => _tasks.isEmpty;
  int get _completedCount => _tasks.where((t) => t.isCompleted).length;
  double get _productivityScore =>
      _tasks.isEmpty ? 0.0 : _completedCount / _tasks.length;

  List<Task> get _todayTasks {
    final today = DateTime.now();
    return _tasks
        .where((t) =>
            t.dueDate.year == today.year &&
            t.dueDate.month == today.month &&
            t.dueDate.day == today.day)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _tasks = List.from(DummyData.tasks);
    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scoreAnimation = Tween<double>(
      begin: 0,
      end: _productivityScore,
    ).animate(
      CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic),
    );
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scoreController.forward());
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  void _markTaskComplete(String taskId) async {
    HapticFeedback.lightImpact();
    setState(() => _animatingTaskId = taskId);
    await Future.delayed(const Duration(milliseconds: 200));

    setState(() {
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(status: TaskStatus.completed);
      }
      _animatingTaskId = null;
    });

    _scoreAnimation = Tween<double>(
      begin: _scoreAnimation.value,
      end: _productivityScore,
    ).animate(
      CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic),
    );
    _scoreController.forward(from: 0);

    if (mounted) {
      UIFeedback.showSuccess(context, '🎉 Great job! Task completed!');
    }
  }

  void _navigateToTaskDetail(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          task: task,
          onTaskUpdated: (updated) {
            setState(() {
              final index = _tasks.indexWhere((t) => t.id == updated.id);
              if (index != -1) _tasks[index] = updated;
            });
          },
          onTaskDeleted: (taskId) {
            setState(() {
              _tasks.removeWhere((t) => t.id == taskId);
            });
          },
        ),
      ),
    );
  }

  void _dismissProactiveCard() => setState(() => _showProactiveCard = false);

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(userName: widget.userName),
      ),
    );
  }

  Future<void> _onRefresh() async {
    setState(() {
      _tasks = List.from(DummyData.tasks);
      _showProactiveCard = true;
    });
    _scoreAnimation = Tween<double>(
      begin: 0,
      end: _productivityScore,
    ).animate(
      CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic),
    );
    _scoreController.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) UIFeedback.showInfo(context, 'Dashboard refreshed!');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            DashboardHeader(
              userName: widget.userName,
              isNewUser: _hasNoTasks,
              showProactiveCard: _showProactiveCard,
              onYes: _dismissProactiveCard,
              onNo: _dismissProactiveCard,
              onProfileTap: _navigateToProfile,
            ),
            Expanded(
              child: RefreshWrapper(
                onRefresh: _onRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Today's Priorities",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => widget.onTabSelected(2),
                            child: Text(
                              'See All',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Task area — fixed height to prevent overflow
                      SizedBox(
                        height: 165,
                        child: _buildTaskArea(),
                      ),
                      const SizedBox(height: 16),

                      // Productivity section
                      AnimatedBuilder(
                        animation: _scoreAnimation,
                        builder: (context, _) => _buildProductivitySection(),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const VoiceFab(heroTag: 'fab_dashboard'),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavBar(
        currentIndex: widget.currentIndex,
        userName: widget.userName,
        onTabSelected: widget.onTabSelected,
      ),
    );
  }

  Widget _buildTaskArea() {
    if (_hasNoTasks) {
      return _EmptyStateCard(
        icon: Icons.add_task_rounded,
        title: 'No tasks yet',
        subtitle: 'Go to Workspace to add your first task',
        actionLabel: 'Add Task',
        onAction: () => widget.onTabSelected(2),
      );
    }

    if (_todayTasks.isEmpty) {
      return _EmptyStateCard(
        icon: Icons.today_rounded,
        title: 'Nothing due today',
        subtitle: 'Enjoy your free time or plan ahead in Workspace',
        actionLabel: 'View All Tasks',
        onAction: () => widget.onTabSelected(2),
      );
    }

    if (_todayTasks.every((t) => t.isCompleted)) {
      return _AllDoneCard(onViewAll: () => widget.onTabSelected(2));
    }

    return _TaskList(
      tasks: _todayTasks,
      onStartTask: _markTaskComplete,
      onTaskTap: _navigateToTaskDetail,
      animatingTaskId: _animatingTaskId,
    );
  }

  Widget _buildProductivitySection() {
    if (_hasNoTasks) {
      return _ProductivityEmptyState(
        onAddTask: () => widget.onTabSelected(2),
      );
    }

    return _ProductivityCard(
      score: _productivityScore,
      animatedScore: _scoreAnimation.value,
      completedCount: _completedCount,
      totalCount: _tasks.length,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Empty State Card (Fixed height)
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 165,
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
// WIDGET: All Done Card
// ─────────────────────────────────────────────────────────────────────────────

class _AllDoneCard extends StatelessWidget {
  final VoidCallback onViewAll;

  const _AllDoneCard({required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 165,
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              "All done for today!",
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'You completed all your tasks. Great work!',
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onViewAll,
              child: Text(
                'View upcoming tasks →',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
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
// WIDGET: Productivity Empty State (Fixed layout)
// ─────────────────────────────────────────────────────────────────────────────

class _ProductivityEmptyState extends StatelessWidget {
  final VoidCallback onAddTask;

  const _ProductivityEmptyState({required this.onAddTask});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: theme.dividerColor.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.insights_rounded,
              size: 32,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PRODUCTIVITY SCORE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppConstants.productivityMessage(0),
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onAddTask,
                  child: Text(
                    'Add your first task →',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Task List
// ─────────────────────────────────────────────────────────────────────────────

class _TaskList extends StatelessWidget {
  final List<Task> tasks;
  final Function(String) onStartTask;
  final Function(Task) onTaskTap;
  final String? animatingTaskId;

  const _TaskList({
    required this.tasks,
    required this.onStartTask,
    required this.onTaskTap,
    this.animatingTaskId,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, i) => _TaskCard(
        task: tasks[i],
        onStart: () => onStartTask(tasks[i].id),
        onTap: () => onTaskTap(tasks[i]),
        isAnimating: animatingTaskId == tasks[i].id,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Task Card (Clickable)
// ─────────────────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onStart;
  final VoidCallback onTap;
  final bool isAnimating;

  const _TaskCard({
    required this.task,
    required this.onStart,
    required this.onTap,
    this.isAnimating = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isAnimating ? 0.7 : 1.0,
        child: SizedBox(
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
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: task.isCompleted
                        ? Colors.green.withOpacity(0.2)
                        : theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: GestureDetector(
                    onTap: task.isCompleted ? null : onStart,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        task.isCompleted ? '✓ Done' : 'Start Task >',
                        key: ValueKey(task.isCompleted),
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
                ),
              ],
            ),
          ),
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
  final double animatedScore;
  final int completedCount;
  final int totalCount;

  const _ProductivityCard({
    required this.score,
    required this.animatedScore,
    required this.completedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final animatedPercentage = (animatedScore * 100).toInt();

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
                    valueColor:
                        AlwaysStoppedAnimation<Color>(theme.dividerColor),
                  ),
                ),
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: animatedScore,
                    strokeWidth: 11,
                    strokeCap: StrokeCap.round,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary),
                  ),
                ),
                Text(
                  '$animatedPercentage%',
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
                    Icon(Icons.check_circle_rounded,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 5),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: completedCount),
                      duration: const Duration(milliseconds: 800),
                      builder: (_, value, __) => Text(
                        '$value/$totalCount Completed',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
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

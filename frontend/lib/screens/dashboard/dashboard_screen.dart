// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/dashboard/dashboard_screen.dart
// CHANGES:
//   - Removed `userName` constructor param → read from AuthProvider
//   - Removed local `_tasks` list → read from TaskProvider
//   - _markTaskComplete now calls TaskProvider.toggleComplete()
//   - _navigateToTaskDetail passes TaskProvider.updateTask/deleteTask
//   - _onRefresh calls TaskProvider.refreshTasks()
//   - Productivity score derived from TaskProvider computed getters
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constant.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../providers/auth_provider.dart';
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
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const DashboardScreen({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _showProactiveCard = true;
  late AnimationController _scoreController;
  late Animation<double> _scoreAnimation;
  String? _animatingTaskId;

  @override
  void initState() {
    super.initState();
    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scoreAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _animateScore());
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  void _animateScore() {
    final score = context.read<TaskProvider>().completionRate;
    _scoreAnimation = Tween<double>(
      begin: 0,
      end: score,
    ).animate(
      CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic),
    );
    _scoreController.forward(from: 0);
  }

  void _animateScoreFrom(double from, double to) {
    _scoreAnimation = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic),
    );
    _scoreController.forward(from: 0);
  }

  Future<void> _markTaskComplete(String taskId) async {
    HapticFeedback.lightImpact();
    setState(() => _animatingTaskId = taskId);
    await Future.delayed(const Duration(milliseconds: 200));

    final taskProvider = context.read<TaskProvider>();
    final previousScore = taskProvider.completionRate;

    try {
      await taskProvider.toggleComplete(taskId);
    } catch (_) {
      if (mounted) UIFeedback.showError(context, 'Could not update task.');
    }

    setState(() => _animatingTaskId = null);

    if (mounted) {
      _animateScoreFrom(previousScore, taskProvider.completionRate);
      UIFeedback.showSuccess(context, '🎉 Great job! Task completed!');
    }
  }

  void _navigateToTaskDetail(Task task) {
    final taskProvider = context.read<TaskProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          task: task,
          onTaskUpdated: (updated) async {
            try {
              await taskProvider.updateTask(updated);
            } catch (_) {}
          },
          onTaskDeleted: (taskId) async {
            try {
              await taskProvider.deleteTask(taskId);
            } catch (_) {}
          },
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    setState(() => _showProactiveCard = true);
    try {
      await context.read<TaskProvider>().refreshTasks();
    } catch (_) {}
    if (mounted) {
      _animateScore();
      UIFeedback.showInfo(context, 'Dashboard refreshed!');
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Consumer2<AuthProvider, TaskProvider>(
          builder: (context, auth, taskProvider, _) {
            final tasks = taskProvider.tasks;
            final hasNoTasks = tasks.isEmpty;
            final completedCount = taskProvider.completedCount;
            final totalCount = taskProvider.totalCount;
            final score = taskProvider.completionRate;
            final todayTasks = taskProvider.todayTasks;

            return Column(
              children: [
                DashboardHeader(
                  userName: auth.userName,
                  isNewUser: hasNoTasks,
                  showProactiveCard: _showProactiveCard,
                  onYes: () => setState(() => _showProactiveCard = false),
                  onNo: () => setState(() => _showProactiveCard = false),
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
                          SizedBox(
                            height: 180,
                            child: _buildTaskArea(
                              hasNoTasks: hasNoTasks,
                              todayTasks: todayTasks,
                            ),
                          ),
                          const SizedBox(height: 16),
                          AnimatedBuilder(
                            animation: _scoreAnimation,
                            builder: (context, _) => _buildProductivitySection(
                              hasNoTasks: hasNoTasks,
                              score: score,
                              completedCount: completedCount,
                              totalCount: totalCount,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: const VoiceFab(heroTag: 'fab_dashboard'),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Consumer<AuthProvider>(
        builder: (_, auth, __) => BottomNavBar(
          currentIndex: widget.currentIndex,
          userName: auth.userName,
          onTabSelected: widget.onTabSelected,
        ),
      ),
    );
  }

  Widget _buildTaskArea({
    required bool hasNoTasks,
    required List<Task> todayTasks,
  }) {
    if (hasNoTasks) {
      return _EmptyStateCard(
        icon: Icons.add_task_rounded,
        title: 'No tasks yet',
        subtitle: 'Go to Workspace to add your first task',
        actionLabel: 'Add Task',
        onAction: () => widget.onTabSelected(2),
      );
    }

    if (todayTasks.isEmpty) {
      return _EmptyStateCard(
        icon: Icons.today_rounded,
        title: 'Nothing due today',
        subtitle: 'Enjoy your free time or plan ahead in Workspace',
        actionLabel: 'View All Tasks',
        onAction: () => widget.onTabSelected(2),
      );
    }

    if (todayTasks.every((t) => t.isCompleted)) {
      return _AllDoneCard(onViewAll: () => widget.onTabSelected(2));
    }

    return _TaskList(
      tasks: todayTasks,
      onStartTask: _markTaskComplete,
      onTaskTap: _navigateToTaskDetail,
      animatingTaskId: _animatingTaskId,
    );
  }

  Widget _buildProductivitySection({
    required bool hasNoTasks,
    required double score,
    required int completedCount,
    required int totalCount,
  }) {
    if (hasNoTasks) {
      return _ProductivityEmptyState(
        onAddTask: () => widget.onTabSelected(2),
      );
    }

    return _ProductivityCard(
      score: score,
      animatedScore: _scoreAnimation.value,
      completedCount: completedCount,
      totalCount: totalCount,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// All private widgets are identical to original — no changes needed below.
// They receive data via constructor so they stay pure/testable.
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
      height: 180,
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 32, color: theme.colorScheme.primary.withOpacity(0.5)),
            const SizedBox(height: 6),
            Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(actionLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  final VoidCallback onViewAll;
  const _AllDoneCard({required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 180,
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text("All done for today!",
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text('You completed all your tasks. Great work!',
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onViewAll,
              child: Text('View upcoming tasks →',
                  style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

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
                shape: BoxShape.circle),
            child: Icon(Icons.insights_rounded,
                size: 32, color: theme.textTheme.bodySmall?.color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('PRODUCTIVITY SCORE',
                    style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        fontSize: 11)),
                const SizedBox(height: 6),
                Text(AppConstants.productivityMessage(0),
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onAddTask,
                  child: Text('Add your first task →',
                      style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  final List<Task> tasks;
  final Function(String) onStartTask;
  final Function(Task) onTaskTap;
  final String? animatingTaskId;

  const _TaskList(
      {required this.tasks,
      required this.onStartTask,
      required this.onTaskTap,
      this.animatingTaskId});

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

class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onStart;
  final VoidCallback onTap;
  final bool isAnimating;

  const _TaskCard(
      {required this.task,
      required this.onStart,
      required this.onTap,
      this.isAnimating = false});

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
                    child: PriorityBadge(priority: task.priority)),
                const SizedBox(height: 6),
                Text(task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700, height: 1.3)),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.access_time_rounded,
                      size: 13, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Text(task.dueTime ?? task.formattedDueDate,
                      style: theme.textTheme.labelSmall),
                ]),
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

class _ProductivityCard extends StatelessWidget {
  final double score;
  final double animatedScore;
  final int completedCount;
  final int totalCount;

  const _ProductivityCard(
      {required this.score,
      required this.animatedScore,
      required this.completedCount,
      required this.totalCount});

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
                            AlwaysStoppedAnimation<Color>(theme.dividerColor))),
                SizedBox(
                    width: 110,
                    height: 110,
                    child: CircularProgressIndicator(
                        value: animatedScore,
                        strokeWidth: 11,
                        strokeCap: StrokeCap.round,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary))),
                Text('$animatedPercentage%',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PRODUCTIVITY SCORE',
                    style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                const SizedBox(height: 8),
                Text(AppConstants.productivityMessage(score),
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                Row(children: [
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
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

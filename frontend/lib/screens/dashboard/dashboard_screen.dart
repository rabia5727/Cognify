// lib/screens/dashboard/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_constant.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/ui_feedback.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/voice_fab.dart';
import '../../widgets/common/priority_badge.dart';
import '../../widgets/common/notification_permission_sheet.dart';
import '../../widgets/empty_states/empty_dashboard.dart';
import '../../widgets/layout/refresh_wrapper.dart';
import '../../widgets/loading/shimmer_loading.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animateScore();
      _maybeShowNotificationPermission();
    });
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _maybeShowNotificationPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('notification_permission_shown') ?? false;
    if (!shown && mounted) {
      await showNotificationPermissionSheet(context);
      await prefs.setBool('notification_permission_shown', true);
    }
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
          taskId: task.id,
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
            final isLoading = taskProvider.isLoading && tasks.isEmpty;

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
                                onPressed: () => widget
                                    .onTabSelected(1), // ✅ Changed from 2 to 1
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
                            child: isLoading
                                ? const TaskCardShimmer()
                                : _buildTaskArea(
                                    hasNoTasks: hasNoTasks,
                                    todayTasks: todayTasks,
                                  ),
                          ),
                          const SizedBox(height: 16),
                          isLoading
                              ? const ProductivityCardShimmer()
                              : AnimatedBuilder(
                                  animation: _scoreAnimation,
                                  builder: (context, _) =>
                                      _buildProductivitySection(
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
      return NoTasksEmptyState(
        onAddTask: () => widget.onTabSelected(1), // ✅ Changed from 2 to 1
      );
    }

    if (todayTasks.isEmpty) {
      return NoTasksDueTodayEmptyState(
        onViewAllTasks: () => widget.onTabSelected(1), // ✅ Changed from 2 to 1
      );
    }

    if (todayTasks.every((t) => t.isCompleted)) {
      return AllDoneEmptyState(
        onViewUpcomingTasks: () =>
            widget.onTabSelected(1), // ✅ Changed from 2 to 1
      );
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
      return ProductivityEmptyState(
        onAddTask: () => widget.onTabSelected(1), // ✅ Changed from 2 to 1
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
// Task List and Task Card Widgets (remain unchanged)
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
                    Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: theme.textTheme.bodySmall?.color,
                    ),
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
                      theme.colorScheme.primary,
                    ),
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
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
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

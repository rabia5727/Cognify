// lib/screens/dashboard/dashboard_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import '../../widgets/empty_states/empty_dashboard.dart';
import '../../widgets/layout/refresh_wrapper.dart';
import '../../widgets/loading/shimmer_loading.dart';
import '../assistant/voice_assistant_screen.dart';
import '../settings/profile_screen.dart';
import '../workspace/task_detail_screen.dart';
import '../../widgets/common/notification_permission_sheet.dart';
import '../../providers/notification_provider.dart';

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

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showProactiveCard = true;
  String? _animatingTaskId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final notifProvider = context.read<NotificationProvider>();

      notifProvider.setCurrentUser(auth.userId);
      await notifProvider.loadEnabledState();

      final asked = await notifProvider.hasAskedPermission();
      if (!asked && mounted) {
        await showNotificationPermissionSheet(context);
      }
    });
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
    if (mounted) UIFeedback.showInfo(context, 'Dashboard refreshed!');
  }

  void _navigateToVoice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VoiceAssistantScreen()),
    );
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
            final todayTasks = taskProvider.todayTasks;
            final score = taskProvider.dailyCompletionRate;
            final completedCount =
                todayTasks.where((t) => t.isCompleted).length;
            final totalCount = todayTasks.length;
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
                            height: 185,
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
                              : _buildProductivitySection(
                                  hasNoTasks: hasNoTasks,
                                  score: score,
                                  completedCount: completedCount,
                                  totalCount: totalCount,
                                ),
                          const SizedBox(height: 8),
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
        onAddTask: () => widget.onTabSelected(1),
      );
    }

    if (todayTasks.isEmpty) {
      return NoTasksDueTodayEmptyState(
        onViewAllTasks: () => widget.onTabSelected(1),
      );
    }

    if (todayTasks.every((t) => t.isCompleted)) {
      return AllDoneEmptyState(
        onViewUpcomingTasks: () => widget.onTabSelected(1),
      );
    }

    final activeTodayTasks = todayTasks.where((t) => !t.isCompleted).toList();
    return _TaskList(
      tasks: activeTodayTasks,
      onStartTask: (_) => _navigateToVoice(),
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
                const SizedBox(height: 4),
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
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
                const Spacer(),
                GestureDetector(
                  onTap: task.isCompleted ? null : onStart,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: task.isCompleted
                          ? Colors.green.withValues(alpha: 0.15)
                          : theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        task.isCompleted ? '✓ Done' : 'Start Task >',
                        key: ValueKey(task.isCompleted),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: task.isCompleted ? Colors.green : Colors.white,
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
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: score),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) {
              final percent = (animated * 100).toInt();
              return SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(120, 120),
                      painter: _GradientArcPainter(
                        progress: animated,
                        strokeWidth: 14,
                        trackColor: theme.dividerColor,
                        startColor: const Color(0xFF1360E2),
                        endColor: const Color(0xFF9B5FFF),
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 20),
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
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppConstants.productivityMessage(score),
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 10),
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

class _GradientArcPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color startColor;
  final Color endColor;

  const _GradientArcPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.startColor,
    required this.endColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    if (progress <= 0) return;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [startColor, endColor, startColor],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(rect)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GradientArcPainter old) =>
      old.progress != progress ||
      old.startColor != startColor ||
      old.endColor != endColor;
}

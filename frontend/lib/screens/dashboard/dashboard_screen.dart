// lib/screens/dashboard/dashboard_screen.dart
//
// FIX: Previously _showProactiveCard was a one-time bool — once set to
// false (after tapping Yes or No), the card's MESSAGE stayed frozen on
// the same task forever, just with buttons hidden. Now we track WHICH
// task's suggestion was dismissed (dismissedTaskId) and pass it to
// DashboardHeader, which uses it to skip that task and surface the next
// relevant suggestion — so the card actually moves forward instead of
// getting stuck.

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
  // ✅ FIX: was `bool _showProactiveCard`. Now tracks the SPECIFIC task id
  // that was dismissed, so DashboardHeader can compute a fresh suggestion
  // that excludes it — rather than freezing the same message with no buttons.
  String? _dismissedTaskId;

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
    // ✅ FIX: refreshing clears the dismissed state so all suggestions
    // are re-evaluated fresh, including the one the user dismissed earlier
    // (e.g. if they want to revisit it).
    setState(() => _dismissedTaskId = null);
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

  /// ✅ FIX: Reads the CURRENT top suggestion's taskId before marking it
  /// dismissed. This is what lets DashboardHeader know exactly which
  /// suggestion to skip on the next build, so a NEW one can surface.
  void _dismissCurrentSuggestion() {
    final taskProvider = context.read<TaskProvider>();
    final currentTaskId = _peekCurrentSuggestionTaskId(taskProvider);
    setState(() => _dismissedTaskId = currentTaskId);
  }

  /// Mirrors the same priority logic used in DashboardHeader so the
  /// dashboard screen knows which task is currently being suggested,
  /// without duplicating the full message-building logic.
  String? _peekCurrentSuggestionTaskId(TaskProvider taskProvider) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activeTasks =
        taskProvider.tasks.where((t) => !t.isCompleted).toList();

    if (activeTasks.isEmpty) return null;

    final overdue = activeTasks.where((t) {
      final due = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      return due.isBefore(today);
    }).toList();
    if (overdue.isNotEmpty) return overdue.first.id;

    final dueToday = activeTasks.where((t) {
      return t.dueDate.year == now.year &&
          t.dueDate.month == now.month &&
          t.dueDate.day == now.day;
    }).toList();
    if (dueToday.isNotEmpty) return dueToday.first.id;

    final highPriority =
        activeTasks.where((t) => t.priority.name == 'high').toList();
    if (highPriority.isNotEmpty) return highPriority.first.id;

    final sorted = List<Task>.of(activeTasks)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    if (sorted.isNotEmpty) return sorted.first.id;

    return null;
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
                  // showProactiveCard kept for backward compatibility with
                  // the "isFreshSuggestion" check inside DashboardHeader —
                  // true means "nothing dismissed yet this session".
                  showProactiveCard: _dismissedTaskId == null,
                  dismissedTaskId: _dismissedTaskId,
                  onYes: () {
                    // capture BEFORE dismissing — dismissing clears the suggestion
                    final taskProvider = context.read<TaskProvider>();
                    final currentTaskId =
                        _peekCurrentSuggestionTaskId(taskProvider);
                    final currentTask = taskProvider.tasks
                        .where((t) => t.id == currentTaskId)
                        .firstOrNull;
                    _dismissCurrentSuggestion();
                    // pass task title up to header via a new callback
                    // handled inside DashboardHeader's Yes button directly
                  },
                  onNo: _dismissCurrentSuggestion,
                  onProfileTap: _navigateToProfile,
                ),
                Expanded(
                  child: RefreshWrapper(
                    onRefresh: _onRefresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
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
                                onPressed: () => widget.onTabSelected(1),
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
                                    allTasks: tasks,
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

  /// ✅ FIX: now also checks overdue tasks, not just todayTasks, so the
  /// task area below the proactive card doesn't contradict it (e.g.
  /// showing "Nothing due today" while the card above says a task is
  /// overdue). If there's nothing due today but there ARE overdue tasks,
  /// show those instead of the generic empty state.
  Widget _buildTaskArea({
    required bool hasNoTasks,
    required List<Task> todayTasks,
    required List<Task> allTasks,
  }) {
    if (hasNoTasks) {
      return NoTasksEmptyState(
        onAddTask: () => widget.onTabSelected(1),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdueTasks = allTasks.where((t) {
      if (t.isCompleted) return false;
      final due = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      return due.isBefore(today);
    }).toList();

    if (todayTasks.isEmpty) {
      // ✅ FIX: show overdue tasks here instead of a contradictory empty state
      if (overdueTasks.isNotEmpty) {
        return _TaskList(
          tasks: overdueTasks,
          onStartTask: (_) => _navigateToVoice(),
          onTaskTap: _navigateToTaskDetail,
          animatingTaskId: _animatingTaskId,
        );
      }
      final upcoming = allTasks.where((t) {
        if (t.isCompleted) return false;
        final due = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
        return !due.isBefore(today); // includes today + future
      }).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

      final nextTask = upcoming.isNotEmpty ? upcoming.first : null;

      return NoTasksDueTodayEmptyState(
        onViewAllTasks: () => widget.onTabSelected(1),
        nextPriorityTask: nextTask,
        onStartTask: _navigateToVoice,
      );
    }

    if (todayTasks.every((t) => t.isCompleted) && overdueTasks.isEmpty) {
      // Find next upcoming task to show below the celebration
      final upcoming = allTasks.where((t) {
        if (t.isCompleted) return false;
        final due = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
        return !due.isBefore(today);
      }).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

      final nextTask = upcoming.isNotEmpty ? upcoming.first : null;

      if (nextTask != null) {
        // Show next priority card instead of generic "all done"
        return NoTasksDueTodayEmptyState(
          onViewAllTasks: () => widget.onTabSelected(1),
          nextPriorityTask: nextTask,
          onStartTask: _navigateToVoice,
        );
      }

      // Truly nothing left — show celebration
      return AllDoneEmptyState(
        onViewUpcomingTasks: () => widget.onTabSelected(1),
      );
    }
    // Combine active today tasks + overdue so both are visible together
    final activeTodayTasks = todayTasks.where((t) => !t.isCompleted).toList();
    final combined = [...overdueTasks, ...activeTodayTasks];

    return _TaskList(
      tasks: combined,
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
        onAddTask: () => widget.onTabSelected(1),
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
// Task List and Task Card Widgets (unchanged)
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Accent bar — red if overdue, gradient otherwise ──
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: task.isOverdue
                            ? [Colors.red, Colors.red.shade300]
                            : const [Color(0xFF1360E2), Color(0xFF7C3AED)],
                      ),
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Label row: overdue/today tag ────────────
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: task.isOverdue
                                      ? Colors.red.withOpacity(0.12)
                                      : theme.colorScheme.primary
                                          .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Icon(
                                  task.isOverdue
                                      ? Icons.warning_amber_rounded
                                      : Icons.north_east_rounded,
                                  size: 10,
                                  color: task.isOverdue
                                      ? Colors.red
                                      : theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                task.isOverdue ? 'Overdue' : 'Due today',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: task.isOverdue
                                      ? Colors.red
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // ── Title ────────────────────────────────────
                          Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // ── Date + priority badge ────────────────────
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 11,
                                color: task.isOverdue
                                    ? Colors.red
                                    : theme.textTheme.bodySmall?.color,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  task.dueTime ?? task.formattedDueDate,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: task.isOverdue ? Colors.red : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          PriorityBadge(priority: task.priority),

                          const Spacer(),

                          // ── Button ───────────────────────────────────
                          GestureDetector(
                            onTap: task.isCompleted ? null : onStart,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: task.isCompleted
                                    ? Colors.green.withOpacity(0.15)
                                    : theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!task.isCompleted) ...[
                                    const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: Text(
                                      task.isCompleted
                                          ? '✓ Done'
                                          : 'Start Task',
                                      key: ValueKey(task.isCompleted),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: task.isCompleted
                                            ? Colors.green
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
                        strokeWidth: 18, // ← thicker
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

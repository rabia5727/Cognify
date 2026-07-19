// lib/widgets/empty_states/empty_dashboard.dart

import 'package:flutter/material.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/priority_badge.dart';
import '../../models/task_model.dart';

/// Empty state shown when no tasks exist at all
class NoTasksEmptyState extends StatelessWidget {
  final VoidCallback onAddTask;

  const NoTasksEmptyState({
    super.key,
    required this.onAddTask,
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
            Icon(
              Icons.add_task_rounded,
              size: 32,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 6),
            Text(
              'Add a high-priority task',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Create your first task to get started',
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onAddTask,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Add Task',
                  style: TextStyle(
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

/// Empty state for when nothing is due today.
/// If [nextPriorityTask] is provided, shows the "Next Priority" card
/// instead of the generic empty state.
class NoTasksDueTodayEmptyState extends StatelessWidget {
  final VoidCallback onViewAllTasks;
  final Task? nextPriorityTask;
  final VoidCallback? onStartTask;

  const NoTasksDueTodayEmptyState({
    super.key,
    required this.onViewAllTasks,
    this.nextPriorityTask,
    this.onStartTask,
  });

  @override
  Widget build(BuildContext context) {
    if (nextPriorityTask != null) {
      return ListView(
        scrollDirection: Axis.horizontal,
        children: [
          SizedBox(
            width: 165,
            child: _NextPriorityCard(
              task: nextPriorityTask!,
              onStart: onStartTask ?? onViewAllTasks,
            ),
          ),
        ],
      );
    }

    // Fallback: nothing due today, nothing upcoming either
    final theme = Theme.of(context);
    return SizedBox(
      height: 180,
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.today_rounded,
              size: 32,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 6),
            Text(
              'Nothing due today',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Enjoy your free time or plan ahead in Workspace',
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onViewAllTasks,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'View All Tasks',
                  style: TextStyle(
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

/// The "Next Priority" card — shown when today is empty but a future task exists.
/// Matches the mockup exactly: top accent bar, label, title, due date, priority badge, button.
class _NextPriorityCard extends StatelessWidget {
  final Task task;
  final VoidCallback onStart;

  const _NextPriorityCard({
    required this.task,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return SizedBox(
      height: 185,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top accent bar (blue → purple gradient) ──────────
              Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1360E2), Color(0xFF7C3AED)],
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── "Next priority" label with icon badge ────
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.north_east_rounded,
                              size: 11,
                              color: primary,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Next priority',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // ── Task title ───────────────────────────────
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // ── Due date row ─────────────────────────────
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 11,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            task.formattedDueDate,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // ── Priority badge ────────────────────────────
                      PriorityBadge(priority: task.priority),

                      const Spacer(),

                      // ── Start Task button ────────────────────────
                      GestureDetector(
                        onTap: onStart,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text(
                              'Start Task >',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
    );
  }
}

/// All tasks completed for today
class AllDoneEmptyState extends StatelessWidget {
  final VoidCallback onViewUpcomingTasks;

  const AllDoneEmptyState({
    super.key,
    required this.onViewUpcomingTasks,
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
            const Text('🎉', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              'All done for today!',
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
              onTap: onViewUpcomingTasks,
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

/// Productivity score empty state
class ProductivityEmptyState extends StatelessWidget {
  final VoidCallback onAddTask;

  const ProductivityEmptyState({
    super.key,
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                const SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: 0.0,
                    strokeWidth: 11,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '0%',
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
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start completing tasks and tracking focus — your score will update as you grow.',
                  style: theme.textTheme.bodySmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onAddTask,
                  child: Text(
                    'Add your first task →',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
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

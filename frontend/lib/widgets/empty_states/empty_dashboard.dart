// lib/widgets/empty_states/empty_dashboard_states.dart

import 'package:flutter/material.dart';
import '../../widgets/common/app_card.dart';

/// Empty state for when no tasks exist - shows "Add a high-priority task"
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

/// Empty state for when no tasks due today
class NoTasksDueTodayEmptyState extends StatelessWidget {
  final VoidCallback onViewAllTasks;

  const NoTasksDueTodayEmptyState({
    super.key,
    required this.onViewAllTasks,
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

/// Productivity score empty state - shows 0% with message from your design
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
          // Circular progress indicator showing 0%
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
                  child: const CircularProgressIndicator(
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
          // Right side content
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

import 'package:flutter/material.dart';

// Empty state for tasks with no matches - MATCHES ORIGINAL UI
class EmptyTasksFilter extends StatelessWidget {
  const EmptyTasksFilter({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 56,
            color: theme.dividerColor,
          ),
          const SizedBox(height: 12),
          Text(
            'No tasks match your filters',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// Empty state for no projects - MATCHES ORIGINAL UI
class EmptyProjects extends StatelessWidget {
  const EmptyProjects({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 56,
            color: theme.dividerColor,
          ),
          const SizedBox(height: 12),
          Text(
            'No projects yet!',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first project',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

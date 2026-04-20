// ═══════════════════════════════════════════════════════════════════
// FILE: lib/widgets/empty_states/analytics_empty_states.dart
// FIXED: Added proper size constraints to prevent "Cannot hit test" errors
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../constants/app_constant.dart';
import '../common/app_card.dart';
import '../common/stat_card.dart';

class AnalyticsWeeklyEmptyState extends StatelessWidget {
  const AnalyticsWeeklyEmptyState({super.key});

  static const List<String> _dayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EmptyCompletionRate(label: 'Weekly Completion Rate'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.bolt_rounded,
                iconColor: theme.colorScheme.primary,
                value: '0.00',
                label: 'Focus Hours',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.access_time_rounded,
                iconColor: AppConstants.orange,
                value: '--',
                label: 'Avg Time',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Productivity Trends',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: AppCard(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
            child: _PlaceholderBarChart(labels: _dayLabels),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Achievements and Insights',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _StartTasksCard(),
      ],
    );
  }
}

class AnalyticsMonthlyEmptyState extends StatelessWidget {
  const AnalyticsMonthlyEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EmptyCompletionRate(label: 'Monthly Completion Rate'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.check_circle_outline_rounded,
                iconColor: Colors.green,
                value: '0',
                label: 'Tasks Completed',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.access_time_rounded,
                iconColor: AppConstants.orange,
                value: '0%',
                label: 'Efficiency',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Productivity Trends',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 40,
                    color: theme.dividerColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No Data',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete tasks to see monthly trends',
                    style: theme.textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyCompletionRate extends StatelessWidget {
  final String label;
  const _EmptyCompletionRate({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '0%',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: 0,
            minHeight: 10,
            backgroundColor: theme.dividerColor,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderBarChart extends StatelessWidget {
  final List<String> labels;
  const _PlaceholderBarChart({required this.labels});

  static const List<double> _decorativeHeights = [
    0.55,
    0.40,
    0.65,
    0.50,
    0.70,
    0.35,
    0.45,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(labels.length, (i) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: _decorativeHeights[i] * 140, // Fixed height
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF2A2D3E)
                        : const Color(0xFFE0E4EF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _StartTasksCard extends StatelessWidget {
  const _StartTasksCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppConstants.orange.withValues(
            alpha: isDark ? 0.4 : 1.0,
          ),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Text('🚀', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start Tasks!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "You don't have any achievements or insights yet.",
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

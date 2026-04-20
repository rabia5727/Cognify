import 'package:flutter/material.dart';
import '../common/app_card.dart'; // your existing AppCard widget
import '../common/stat_card.dart'; // your existing StatCard widget
import '../../constants/app_constant.dart'; // for AppConstants.orange

// ─────────────────────────────────────────────────────────────────
// WEEKLY EMPTY STATE
// Matches your screenshot: placeholder bars + "Start Tasks!" card
// ─────────────────────────────────────────────────────────────────

class AnalyticsWeeklyEmptyState extends StatelessWidget {
  const AnalyticsWeeklyEmptyState({super.key});

  // Day labels shown below the placeholder bars
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Completion rate: 0% ──────────────────────────────────
        _EmptyCompletionRate(label: 'Weekly Completion Rate'),
        const SizedBox(height: 16),

        // ── Stat cards: Focus Hours & Avg Time ───────────────────
        Row(children: [
          Expanded(
            child: StatCard(
              icon: Icons.bolt_rounded,
              iconColor: theme.colorScheme.primary,
              value: '0.00', // zero — no tasks yet
              label: 'Focus Hours',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              icon: Icons.access_time_rounded,
              iconColor: AppConstants.orange,
              value: '--', // unknown — no data to average
              label: 'Avg Time',
            ),
          ),
        ]),
        const SizedBox(height: 24),

        // ── Section heading ───────────────────────────────────────
        Text(
          'Productivity Trends',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),

        // ── Placeholder bar chart ─────────────────────────────────
        // Shows 7 greyed-out bars (one per day) so the chart area
        // is not empty/confusing. Bars are NOT interactive.
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
          child: SizedBox(
            height: 200,
            child: _PlaceholderBarChart(labels: _dayLabels),
          ),
        ),
        const SizedBox(height: 24),

        // ── Achievements section heading ──────────────────────────
        Text(
          'Achievements and Insights',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),

        // ── "Start Tasks!" prompt card ────────────────────────────
        // Orange border to look encouraging, not like an error.
        _StartTasksCard(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// MONTHLY EMPTY STATE
// Matches your screenshot: "No Data" chart, no achievements section
// ─────────────────────────────────────────────────────────────────

class AnalyticsMonthlyEmptyState extends StatelessWidget {
  const AnalyticsMonthlyEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Completion rate: 0% ──────────────────────────────────
        _EmptyCompletionRate(label: 'Monthly Completion Rate'),
        const SizedBox(height: 16),

        // ── Stat cards: Tasks Completed & Efficiency ─────────────
        Row(children: [
          Expanded(
            child: StatCard(
              icon: Icons.check_circle_outline_rounded,
              iconColor: Colors.green,
              value: '0', // zero tasks
              label: 'Tasks Completed',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              icon: Icons.access_time_rounded,
              iconColor: AppConstants.orange,
              value: '0%', // 0% efficiency
              label: 'Efficiency',
            ),
          ),
        ]),
        const SizedBox(height: 24),

        // ── Section heading ───────────────────────────────────────
        Text(
          'Productivity Trends',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),

        // ── "No Data" chart placeholder ───────────────────────────
        // Simple bordered box with centred text — matches screenshot.
        AppCard(
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 200,
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

        // Monthly empty state intentionally has NO achievements section
        // because there is literally nothing to show — keeps UI clean.
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PRIVATE HELPER WIDGETS
// These are only used inside this file — that's why they start with _
// ═══════════════════════════════════════════════════════════════════

// ── Zero-percent completion bar ───────────────────────────────────
// Reused by both weekly and monthly empty states.
// Accepts a [label] so heading text differs between the two.
class _EmptyCompletionRate extends StatelessWidget {
  final String label;
  const _EmptyCompletionRate({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label + "0%" on the same row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              '0%',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Progress bar at value: 0 (completely grey)
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: 0, // no progress yet
            minHeight: 10,
            backgroundColor: theme.dividerColor,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
      ],
    );
  }
}

// ── Greyed-out placeholder bars ───────────────────────────────────
// Draws 7 static grey bars with day labels underneath.
// Does NOT use fl_chart — just plain Containers so no library needed
// and no "data required" errors occur on empty datasets.
class _PlaceholderBarChart extends StatelessWidget {
  final List<String> labels;
  const _PlaceholderBarChart({required this.labels});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Bar height varies slightly so the chart doesn't look like a flat line.
    // These are purely decorative — not real data.
    const List<double> _decorativeHeights = [
      0.55,
      0.40,
      0.65,
      0.50,
      0.70,
      0.35,
      0.45,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(labels.length, (i) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // The bar itself
                FractionallySizedBox(
                  // 160 = chart height minus ~40px for label area
                  heightFactor: _decorativeHeights[i],
                  child: Container(
                    decoration: BoxDecoration(
                      // Slightly darker than divider so bars are visible
                      // in both light and dark mode
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF2A2D3E)
                          : const Color(0xFFE0E4EF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Day label below bar
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

// ── "Start Tasks!" encouragement card ────────────────────────────
// Shown only on the Weekly empty state under Achievements.
// Orange border = warm/encouraging, not an error red.
class _StartTasksCard extends StatelessWidget {
  const _StartTasksCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppConstants.orange.withOpacity(
            theme.brightness == Brightness.dark ? 0.4 : 1.0,
          ),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Emoji icon — using Text widget so no asset needed
          const Text('🚀', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 14),

          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start Tasks!',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
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

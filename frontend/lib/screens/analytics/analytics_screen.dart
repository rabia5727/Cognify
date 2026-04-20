// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/analytics/analytics_screen.dart
//
// CHANGES FROM PREVIOUS VERSION:
//   1. Added import for analytics_empty_states.dart
//   2. Added _hasNoData() helper method
//   3. Consumer2 builder now checks for empty data first and
//      returns the appropriate empty state widget early
//   4. Everything else (charts, stat cards, achievements) unchanged
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../constants/app_constant.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/stat_card.dart';
import '../../widgets/common/voice_fab.dart';

// ─── NEW IMPORT ───────────────────────────────────────────────────
// This is the only new import you need to add
import '../../widgets/empty_states/empty_analytics.dart';

class AnalyticsScreen extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const AnalyticsScreen({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isWeekly = true;

  // ─── NEW HELPER ─────────────────────────────────────────────────
  // Returns true when ALL values in the chart data list are zero.
  // A list like [0, 0, 0, 0, 0, 0, 0] means no tasks were recorded.
  // "every((v) => v == 0)" checks each item — if all are 0, returns true.
  bool _hasNoData(List<double> chartData) {
    if (chartData.isEmpty) return true;
    return chartData.every((value) => value == 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header — unchanged from original
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => widget.onTabSelected(0),
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Statistics',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: Consumer2<AnalyticsProvider, AuthProvider>(
                builder: (context, analytics, auth, _) {
                  // Pick the right chart data depending on tab
                  final chartData = _isWeekly
                      ? analytics.weeklyChartData
                      : analytics.monthlyChartData;

                  // ─── EMPTY STATE CHECK ─────────────────────────
                  // If all chart values are 0, show the appropriate
                  // empty state widget and STOP rendering here.
                  // The _TabToggle is still shown above the empty
                  // state so the user can switch between tabs.
                  if (_hasNoData(chartData)) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tab toggle always visible so user can switch
                          _TabToggle(
                            isWeekly: _isWeekly,
                            onToggle: (val) => setState(() => _isWeekly = val),
                          ),
                          const SizedBox(height: 20),

                          // Show the matching empty state for current tab
                          if (_isWeekly)
                            const AnalyticsWeeklyEmptyState()
                          else
                            const AnalyticsMonthlyEmptyState(),
                        ],
                      ),
                    );
                  }
                  // ─────────────────────────────────────────────────
                  // Beyond this point = user HAS data. Original code
                  // below is completely unchanged.
                  // ─────────────────────────────────────────────────

                  final chartLabels = _isWeekly
                      ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                      : const [
                          'Jan',
                          'Feb',
                          'Mar',
                          'Apr',
                          'May',
                          'Jun',
                          'Jul',
                          'Aug',
                          'Sep',
                          'Oct',
                          'Nov',
                          'Dec'
                        ];
                  final completionRate = _isWeekly
                      ? analytics.weeklyCompletionRate
                      : analytics.monthlyCompletionRate;
                  final stats = _isWeekly
                      ? analytics.weeklyStats
                      : analytics.monthlyStats;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TabToggle(
                          isWeekly: _isWeekly,
                          onToggle: (val) => setState(() => _isWeekly = val),
                        ),
                        const SizedBox(height: 20),
                        _CompletionRate(
                          label: _isWeekly
                              ? 'Weekly Completion Rate'
                              : 'Monthly Completion Rate',
                          rate: completionRate,
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: StatCard(
                              icon: _isWeekly
                                  ? Icons.bolt_rounded
                                  : Icons.check_circle_outline_rounded,
                              iconColor: _isWeekly
                                  ? theme.colorScheme.primary
                                  : Colors.green,
                              value: _isWeekly
                                  ? (stats['focusHours'] ?? '0h')
                                  : (stats['tasksCompleted'] ?? '0'),
                              label:
                                  _isWeekly ? 'Focus Hours' : 'Tasks Completed',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              icon: Icons.access_time_rounded,
                              iconColor: AppConstants.orange,
                              value: _isWeekly
                                  ? (stats['avgTime'] ?? '0h')
                                  : (stats['efficiency'] ?? '0%'),
                              label: _isWeekly ? 'Avg Time' : 'Efficiency',
                            ),
                          ),
                        ]),
                        const SizedBox(height: 24),
                        Text(
                          'Productivity Trends',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        AppCard(
                          padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                          child: SizedBox(
                            height: 200,
                            child: _isWeekly
                                ? _WeeklyBarChart(
                                    data: chartData,
                                    labels: chartLabels,
                                  )
                                : _MonthlyLineChart(
                                    data: chartData,
                                    labels: chartLabels,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Achievements and Insights',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        if (analytics.achievements.isEmpty)
                          _EmptyState(
                            icon: Icons.emoji_events_outlined,
                            title: 'No achievements yet',
                            subtitle:
                                'Complete tasks consistently to earn achievements.',
                          )
                        else
                          ...analytics.achievements.map(
                            (a) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _AchievementCard(
                                icon: a['icon'] as String,
                                iconColor: a['iconColor'] as Color,
                                title: a['title'] as String,
                                subtitle: a['subtitle'] as String,
                                borderColor: a['borderColor'] as Color,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const VoiceFab(),
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
}

// ═══════════════════════════════════════════════════════════════════
// Everything below this line is IDENTICAL to your original file.
// No changes made — kept here so the file stays self-contained.
// ═══════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(children: [
          Icon(icon, size: 52, color: theme.dividerColor),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(subtitle,
              style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _TabToggle extends StatelessWidget {
  final bool isWeekly;
  final ValueChanged<bool> onToggle;
  const _TabToggle({required this.isWeekly, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.dividerColor,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onToggle(true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color:
                    isWeekly ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Text(
                'Weekly',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isWeekly
                      ? Colors.white
                      : theme.textTheme.bodySmall?.color,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => onToggle(false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color:
                    !isWeekly ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Text(
                'Monthly',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: !isWeekly
                      ? Colors.white
                      : theme.textTheme.bodySmall?.color,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _CompletionRate extends StatelessWidget {
  final String label;
  final double rate;
  const _CompletionRate({required this.label, required this.rate});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (rate * 100).toInt();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        Text('$percent%',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: rate,
          minHeight: 10,
          backgroundColor: theme.dividerColor,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      ),
    ]);
  }
}

class _WeeklyBarChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  const _WeeklyBarChart({required this.data, required this.labels});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = data.isEmpty ? 10.0 : data.reduce((a, b) => a > b ? a : b) + 2;
    return BarChart(BarChartData(
      maxY: maxY,
      minY: 0,
      barTouchData: BarTouchData(enabled: true),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= labels.length) {
                return const SizedBox();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(labels[index], style: theme.textTheme.labelSmall),
              );
            },
            reservedSize: 28,
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: theme.dividerColor, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(
        data.length,
        (i) => BarChartGroupData(x: i, barRods: [
          BarChartRodData(
            toY: data[i],
            width: 18,
            borderRadius: BorderRadius.circular(6),
            gradient: i == 4
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF9B8FFF), Color(0xFF1360E2)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
            color: i == 4 ? theme.colorScheme.primary : null,
          )
        ]),
      ),
    ));
  }
}

class _MonthlyLineChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  const _MonthlyLineChart({required this.data, required this.labels});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = data.isEmpty ? 10.0 : data.reduce((a, b) => a > b ? a : b) + 2;
    return LineChart(LineChartData(
      maxY: maxY,
      minY: 0,
      lineTouchData: const LineTouchData(enabled: true),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= labels.length || index % 2 != 0) {
                return const SizedBox();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(labels[index], style: theme.textTheme.labelSmall),
              );
            },
            reservedSize: 28,
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: theme.dividerColor, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots:
              List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i])),
          isCurved: true,
          curveSmoothness: 0.35,
          color: theme.colorScheme.primary,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: theme.colorScheme.primary.withOpacity(0.08),
          ),
        )
      ],
    ));
  }
}

class _AchievementCard extends StatelessWidget {
  final String icon, title, subtitle;
  final Color iconColor, borderColor;
  const _AchievementCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.borderColor,
  });
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
          color: isDark ? theme.dividerColor : borderColor,
          width: 1.5,
        ),
      ),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ]),
    );
  }
}

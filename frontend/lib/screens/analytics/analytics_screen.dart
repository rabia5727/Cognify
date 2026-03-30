// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/analytics/analytics_screen.dart
// CHANGES:
//   - Hardcoded stat values ('24.5', '3.5h' etc) replaced with DummyData
//   - Hardcoded completion rate (0.80) replaced with DummyData
//   - completionRate now switches between weekly/monthly based on toggle
//   - stat cards now switch based on weekly/monthly toggle from DummyData
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../constants/app_constant.dart';
import '../../data/dummy_data.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/voice_fab.dart';

class AnalyticsScreen extends StatefulWidget {
  final String userName;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const AnalyticsScreen({
    super.key,
    required this.userName,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isWeekly = true;

  // All data from DummyData — swap these for service calls when backend ready
  List<double> get _chartData =>
      _isWeekly ? DummyData.weeklyChartData : DummyData.monthlyChartData;
  List<String> get _chartLabels =>
      _isWeekly ? DummyData.weekDays : DummyData.months;
  double get _completionRate => _isWeekly
      ? DummyData.weeklyCompletionRate
      : DummyData.monthlyCompletionRate;
  List<Map<String, dynamic>> get _achievements => DummyData.achievements;

  // Stat card values from DummyData
  String get _stat1Value => _isWeekly
      ? DummyData.weeklyStats['focusHours']!
      : DummyData.monthlyStats['tasksCompleted']!;
  String get _stat1Label => _isWeekly ? 'Focus Hours' : 'Tasks Completed';
  IconData get _stat1Icon =>
      _isWeekly ? Icons.bolt_rounded : Icons.check_circle_outline_rounded;
  Color get _stat1Color =>
      _isWeekly ? Theme.of(context).colorScheme.primary : Colors.green;

  String get _stat2Value => _isWeekly
      ? DummyData.weeklyStats['avgTime']!
      : DummyData.monthlyStats['efficiency']!;
  String get _stat2Label => _isWeekly ? 'Avg Time' : 'Efficiency';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────
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
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TabToggle(
                      isWeekly: _isWeekly,
                      onToggle: (val) => setState(() => _isWeekly = val),
                    ),
                    const SizedBox(height: 20),

                    // Completion rate from DummyData
                    _CompletionRate(
                      label: _isWeekly
                          ? 'Weekly Completion Rate'
                          : 'Monthly Completion Rate',
                      rate: _completionRate,
                    ),
                    const SizedBox(height: 16),

                    // Stat cards from DummyData
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            icon: _stat1Icon,
                            iconColor: _stat1Color,
                            value: _stat1Value,
                            label: _stat1Label,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            icon: Icons.access_time_rounded,
                            iconColor: AppConstants.orange,
                            value: _stat2Value,
                            label: _stat2Label,
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
                    AppCard(
                      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                      child: SizedBox(
                        height: 200,
                        child: _isWeekly
                            ? _WeeklyBarChart(
                                data: _chartData,
                                labels: _chartLabels,
                              )
                            : _MonthlyLineChart(
                                data: _chartData,
                                labels: _chartLabels,
                              ),
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

                    // Empty state
                    if (_achievements.isEmpty)
                      _EmptyState(
                        icon: Icons.emoji_events_outlined,
                        title: 'No achievements yet',
                        subtitle:
                            'Complete tasks consistently to earn achievements.',
                      )
                    else
                      ..._achievements.map(
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
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const VoiceFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavBar(
        currentIndex: widget.currentIndex,
        userName: widget.userName,
        onTabSelected: widget.onTabSelected,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Empty State — reused across analytics sections
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(icon, size: 52, color: theme.dividerColor),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Tab Toggle
// ─────────────────────────────────────────────────────────────────────────────

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
      child: Row(
        children: [
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
                  color: !isWeekly
                      ? theme.colorScheme.primary
                      : Colors.transparent,
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Completion Rate
// ─────────────────────────────────────────────────────────────────────────────

class _CompletionRate extends StatelessWidget {
  final String label;
  final double rate;

  const _CompletionRate({required this.label, required this.rate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (rate * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              '$percent%',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
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
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Weekly Bar Chart
// ─────────────────────────────────────────────────────────────────────────────

class _WeeklyBarChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;

  const _WeeklyBarChart({required this.data, required this.labels});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = data.reduce((a, b) => a > b ? a : b) + 2;

    return BarChart(
      BarChartData(
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
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
        barGroups: List.generate(data.length, (i) {
          final isToday = i == 4;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: data[i],
                width: 18,
                borderRadius: BorderRadius.circular(6),
                gradient: isToday
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF9B8FFF), Color(0xFF1360E2)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                color: isToday ? theme.colorScheme.primary : null,
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Monthly Line Chart
// ─────────────────────────────────────────────────────────────────────────────

class _MonthlyLineChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;

  const _MonthlyLineChart({required this.data, required this.labels});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = data.reduce((a, b) => a > b ? a : b) + 2;

    return LineChart(
      LineChartData(
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
                if (index < 0 || index >= labels.length) {
                  return const SizedBox();
                }
                if (index % 2 != 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labels[index], style: theme.textTheme.labelSmall),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
            spots: List.generate(
                data.length, (i) => FlSpot(i.toDouble(), data[i])),
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
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Achievement Card
// ─────────────────────────────────────────────────────────────────────────────

class _AchievementCard extends StatelessWidget {
  final String icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color borderColor;

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
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

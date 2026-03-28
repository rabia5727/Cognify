// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/analytics/analytics_screen.dart
// CHANGES:
//   - Uses AppConstants for all colors
//   - Uses VoiceFab widget instead of inline _VoiceFAB
//   - Uses DummyData for all chart data and achievements
//   - All colors now from AppConstants
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../constants/app_constant.dart';
import '../../data/dummy_data.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/voice_fab.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ANALYTICS SCREEN
// Shows Weekly (bar chart) and Monthly (line chart) productivity stats
// ─────────────────────────────────────────────────────────────────────────────

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
  // true = Weekly tab, false = Monthly tab
  bool _isWeekly = true;

  // ── Data from DummyData ────────────────────────────────────────────────────
  List<double> get _weeklyData => DummyData.weeklyChartData;
  List<String> get _weekDays => DummyData.weekDays;

  List<double> get _monthlyData => DummyData.monthlyChartData;
  List<String> get _months => DummyData.months;

  List<Map<String, dynamic>> get _achievements => DummyData.achievements;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => widget.onTabSelected(0),
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppConstants.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Statistics',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.darkText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── Scrollable body ────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Weekly / Monthly toggle
                    _TabToggle(
                      isWeekly: _isWeekly,
                      onToggle: (val) => setState(() => _isWeekly = val),
                    ),

                    const SizedBox(height: 20),

                    // 2. Completion rate label + progress bar
                    _CompletionRate(
                      label: _isWeekly
                          ? 'Weekly Completion Rate'
                          : 'Monthly Completion Rate',
                      rate: 0.80,
                    ),

                    const SizedBox(height: 16),

                    // 3. Stat cards row
                    Row(
                      children: _isWeekly
                          ? [
                              Expanded(
                                child: StatCard(
                                  icon: Icons.bolt_rounded,
                                  iconColor: AppConstants.primaryBlue,
                                  value: '24.5',
                                  label: 'Focus Hours',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: StatCard(
                                  icon: Icons.access_time_rounded,
                                  iconColor: AppConstants.orange,
                                  value: '3.5h',
                                  label: 'Avg Time',
                                ),
                              ),
                            ]
                          : [
                              Expanded(
                                child: StatCard(
                                  icon: Icons.check_circle_outline_rounded,
                                  iconColor: Colors.green,
                                  value: '128',
                                  label: 'Tasks Completed',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: StatCard(
                                  icon: Icons.trending_up_rounded,
                                  iconColor: AppConstants.orange,
                                  value: '85%',
                                  label: 'Efficiency',
                                ),
                              ),
                            ],
                    ),

                    const SizedBox(height: 24),

                    // 4. Chart section
                    const Text(
                      'Productivity Trends',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.darkText,
                      ),
                    ),

                    const SizedBox(height: 12),

                    AppCard(
                      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                      child: SizedBox(
                        height: 200,
                        child: _isWeekly
                            ? _WeeklyBarChart(
                                data: _weeklyData,
                                labels: _weekDays,
                              )
                            : _MonthlyLineChart(
                                data: _monthlyData,
                                labels: _months,
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 5. Achievements section
                    const Text(
                      'Achievements and Insights',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.darkText,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Achievement cards from DummyData
                    ..._achievements.map(
                      (achievement) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AchievementCard(
                          icon: achievement['icon'] as String,
                          iconColor: achievement['iconColor'] as Color,
                          title: achievement['title'] as String,
                          subtitle: achievement['subtitle'] as String,
                          borderColor: achievement['borderColor'] as Color,
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
// WIDGET: Tab Toggle (Weekly / Monthly)
// ─────────────────────────────────────────────────────────────────────────────

class _TabToggle extends StatelessWidget {
  final bool isWeekly;
  final ValueChanged<bool> onToggle;

  const _TabToggle({required this.isWeekly, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.lightGray,
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
                      isWeekly ? AppConstants.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Text(
                  'Weekly',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isWeekly ? Colors.white : AppConstants.grayText,
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
                      !isWeekly ? AppConstants.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Text(
                  'Monthly',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: !isWeekly ? Colors.white : AppConstants.grayText,
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
    final percent = (rate * 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppConstants.darkText,
              ),
            ),
            Text(
              '$percent %',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppConstants.darkText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: rate,
            minHeight: 10,
            backgroundColor: AppConstants.lightGray,
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
                if (index < 0 || index >= labels.length)
                  return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[index],
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppConstants.grayText,
                    ),
                  ),
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
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppConstants.lightGray,
            strokeWidth: 1,
          ),
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
                        colors: [Color(0xFF9B8FFF), AppConstants.primaryBlue],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                color: isToday ? AppConstants.primaryBlue : null,
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
    final maxY = data.reduce((a, b) => a > b ? a : b) + 2;

    return LineChart(
      LineChartData(
        maxY: maxY,
        minY: 0,
        lineTouchData: LineTouchData(enabled: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= labels.length)
                  return const SizedBox();
                if (index % 2 != 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[index],
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppConstants.grayText,
                    ),
                  ),
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
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppConstants.lightGray,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              data.length,
              (i) => FlSpot(i.toDouble(), data[i]),
            ),
            isCurved: true,
            curveSmoothness: 0.35,
            color: AppConstants.primaryBlue,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppConstants.primaryBlue.withOpacity(0.08),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppConstants.darkText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppConstants.grayText,
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

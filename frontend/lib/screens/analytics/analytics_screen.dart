import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/stat_card.dart';

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

  // ── Weekly data ────────────────────────────────────────────────────────────
  // Each value = number of tasks completed on that day
  // Later replace with real data from your backend
  final List<double> _weeklyData = [4, 6, 3, 7, 8, 5, 6];
  final List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];

  // ── Monthly data ───────────────────────────────────────────────────────────
  final List<double> _monthlyData = [
    3,
    5,
    4,
    6,
    8,
    7,
    5,
    9,
    10,
    7,
    8,
    6,
  ];
  final List<String> _months = [
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
    'Dec',
  ];

  // ── Achievements ───────────────────────────────────────────────────────────
  // These would come from your AI/backend in the real app
  static const List<_Achievement> _achievements = [
    _Achievement(
      icon: '🔥',
      iconColor: Color(0xFFFF6B35),
      title: '5-day completion streak!',
      subtitle: 'Keep the momentum going',
      borderColor: Color(0xFFFFE8D6),
    ),
    _Achievement(
      icon: '🎯',
      iconColor: Color(0xFF1360E2),
      title: 'Met 90% of weekly goals',
      subtitle: 'Excellent execution this week!',
      borderColor: Color(0xFFDCEAFF),
    ),
    _Achievement(
      icon: '🏆',
      iconColor: Color(0xFF9B59B6),
      title: 'Task backlog reduced by 35%',
      subtitle: "You're closing gaps before deadlines stack up.",
      borderColor: Color(0xFFF0E6FF),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
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
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Statistics',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── Scrollable body ────────────────────────────────────────
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
                      rate: 0.80, // 80%
                    ),

                    const SizedBox(height: 16),

                    // 3. Stat cards row — different metrics per tab
                    Row(
                      children: _isWeekly
                          ? [
                              Expanded(
                                child: StatCard(
                                  icon: Icons.bolt_rounded,
                                  iconColor: AppColors.primaryBlue,
                                  value: '24.5',
                                  label: 'Focus Hours',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: StatCard(
                                  icon: Icons.access_time_rounded,
                                  iconColor: AppColors.orange,
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
                                  iconColor: AppColors.orange,
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
                        color: AppColors.darkText,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Bar chart (weekly) or Line chart (monthly)
                    AppCard(
                      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                      child: SizedBox(
                        height: 200,
                        child: _isWeekly
                            ? _WeeklyBarChart(
                                data: _weeklyData, labels: _weekDays)
                            : _MonthlyLineChart(
                                data: _monthlyData, labels: _months),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 5. Achievements section
                    const Text(
                      'Achievements and Insights',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Achievement cards
                    ..._achievements.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AchievementCard(achievement: a),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const _VoiceFAB(),
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
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          // Weekly tab
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isWeekly ? AppColors.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Text(
                  'Weekly',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isWeekly ? Colors.white : AppColors.grayText,
                  ),
                ),
              ),
            ),
          ),
          // Monthly tab
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !isWeekly ? AppColors.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Text(
                  'Monthly',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: !isWeekly ? Colors.white : AppColors.grayText,
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
// WIDGET: Completion Rate (label + progress bar + percentage)
// ─────────────────────────────────────────────────────────────────────────────

class _CompletionRate extends StatelessWidget {
  final String label;
  final double rate; // 0.0 to 1.0

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
                color: AppColors.darkText,
              ),
            ),
            Text(
              '$percent %',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Green progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: rate,
            minHeight: 10,
            backgroundColor: AppColors.lightGray,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Weekly Bar Chart
// Uses fl_chart BarChart
// ─────────────────────────────────────────────────────────────────────────────

class _WeeklyBarChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;

  const _WeeklyBarChart({required this.data, required this.labels});

  @override
  Widget build(BuildContext context) {
    // Find max value to scale bars correctly
    final maxY = data.reduce((a, b) => a > b ? a : b) + 2;

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          // Bottom labels — day names
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
                      color: AppColors.grayText,
                    ),
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          // Hide all other axis labels
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
            color: AppColors.lightGray,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (i) {
          // Highlight today (index 4 = Friday for demo)
          final isToday = i == 4;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: data[i],
                width: 18,
                borderRadius: BorderRadius.circular(6),
                // Today is solid blue, others are gradient blue/purple
                gradient: isToday
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF9B8FFF), Color(0xFF1360E2)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                color: isToday ? AppColors.primaryBlue : null,
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
// Uses fl_chart LineChart
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
                // Only show every 2nd label to avoid crowding
                if (index % 2 != 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[index],
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.grayText,
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
            color: AppColors.lightGray,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            // Convert list of doubles to FlSpot (x, y) points
            spots: List.generate(
              data.length,
              (i) => FlSpot(i.toDouble(), data[i]),
            ),
            isCurved: true, // smooth curves like the mockup
            curveSmoothness: 0.35,
            color: AppColors.primaryBlue,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false), // hide dots for clean look
            belowBarData: BarAreaData(
              show: true,
              // Light blue fill under the line
              color: AppColors.primaryBlue.withOpacity(0.08),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASS: Achievement
// Holds data for a single achievement card
// ─────────────────────────────────────────────────────────────────────────────

class _Achievement {
  final String icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color borderColor;

  const _Achievement({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.borderColor,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Achievement Card
// ─────────────────────────────────────────────────────────────────────────────

class _AchievementCard extends StatelessWidget {
  final _Achievement achievement;
  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: achievement.borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          // Emoji icon
          Text(achievement.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  achievement.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grayText,
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

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Voice FAB
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceFAB extends StatelessWidget {
  const _VoiceFAB();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: FloatingActionButton(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice recording coming soon!')),
        ),
        backgroundColor: AppColors.primaryBlue,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 32),
      ),
    );
  }
}

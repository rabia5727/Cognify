import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/project_model.dart';
import '../constants/app_constant.dart';

class DummyData {
  DummyData._(); // Prevent instantiation

  // ── Tasks ──────────────────────────────────────────────────────
  // TODO: Replace with TaskService.getTasks()
  static List<Task> get tasks => [
        Task(
          id: '1',
          title: 'Complete Maths Assignment',
          description: 'sir kashif assignment',
          dueDate: DateTime.now().copyWith(hour: 22, minute: 0),
          dueTime: '10:00pm',
          priority: Priority.high,
          status: TaskStatus.inProgress,
          category: TaskCategory.classroom,
        ),
        Task(
          id: '2',
          title: 'ML assignment submit',
          description: 'sir kashif assignment',
          dueDate: DateTime.now().copyWith(hour: 18, minute: 30),
          dueTime: '6:30pm',
          priority: Priority.medium,
          status: TaskStatus.inProgress,
          category: TaskCategory.email,
        ),
        Task(
          id: '3',
          title: 'Email reports',
          description: 'sir kashif assignment',
          dueDate: DateTime.now().copyWith(hour: 19, minute: 0),
          dueTime: '7:00pm',
          priority: Priority.low,
          status: TaskStatus.todo,
          category: TaskCategory.email,
        ),
        Task(
          id: '4',
          title: 'Quiz preparation of AI subject',
          description: 'for ai assignment',
          dueDate: DateTime.now().copyWith(hour: 17, minute: 0),
          dueTime: '5:00pm',
          priority: Priority.high,
          status: TaskStatus.todo,
          category: TaskCategory.classroom,
        ),
        Task(
          id: '5',
          title: 'Design review meeting',
          description: 'with design team',
          dueDate: DateTime.now()
              .add(const Duration(days: 1))
              .copyWith(hour: 14, minute: 0),
          dueTime: '2:00pm',
          priority: Priority.medium,
          status: TaskStatus.todo,
          category: TaskCategory.general,
        ),
        Task(
          id: '6',
          title: 'Update documentation',
          description: 'API documentation',
          dueDate: DateTime.now()
              .add(const Duration(days: 2))
              .copyWith(hour: 23, minute: 59),
          dueTime: '11:59pm',
          priority: Priority.low,
          status: TaskStatus.todo,
          category: TaskCategory.general,
        ),
      ];

  // ── Projects ───────────────────────────────────────────────────
  // TODO: Replace with ProjectService.getProjects()
  static List<Project> get projects => [
        Project(
          id: '1',
          title: 'HCI Assignment',
          description: 'Academic',
          taskIds: ['1', '2'],
          dueDate: DateTime.now().add(const Duration(days: 5)),
          priority: Priority.high,
          category: ProjectCategory.academic,
        ),
        Project(
          id: '2',
          title: 'Freelance Website',
          description: 'Freelance',
          taskIds: ['3', '4'],
          dueDate: DateTime.now().add(const Duration(days: 10)),
          priority: Priority.medium,
          category: ProjectCategory.freelance,
        ),
        Project(
          id: '3',
          title: 'ML Research Paper',
          description: 'Academic',
          taskIds: ['5', '6'],
          dueDate: DateTime.now().add(const Duration(days: 15)),
          priority: Priority.low,
          category: ProjectCategory.academic,
        ),
      ];

  // ── Weekly chart data ──────────────────────────────────────────
  // TODO: Replace with AnalyticsService.getWeeklyData()
  static List<double> get weeklyChartData => [4, 6, 3, 7, 8, 5, 6];
  static List<String> get weekDays =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // ── Monthly chart data ─────────────────────────────────────────
  // TODO: Replace with AnalyticsService.getMonthlyData()
  static List<double> get monthlyChartData =>
      [3, 5, 4, 6, 8, 7, 5, 9, 10, 7, 8, 6];
  static List<String> get months => [
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

  // ── Analytics stats (weekly) ───────────────────────────────────
  // TODO: Replace with AnalyticsService.getWeeklyStats()
  static Map<String, String> get weeklyStats => {
        'focusHours': '24.5',
        'avgTime': '3.5h',
      };

  // ── Analytics stats (monthly) ─────────────────────────────────
  // TODO: Replace with AnalyticsService.getMonthlyStats()
  static Map<String, String> get monthlyStats => {
        'tasksCompleted': '128',
        'efficiency': '85%',
      };

  // ── Completion rates ───────────────────────────────────────────
  // TODO: Replace with AnalyticsService.getCompletionRates()
  static double get weeklyCompletionRate => 0.80;
  static double get monthlyCompletionRate => 0.72;

  // ── Calendar days ──────────────────────────────────────────────
  static List<Map<String, dynamic>> get calendarDays {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final date = now.add(Duration(days: i));
      return {
        'day': _dayAbbr(date.weekday),
        'date': date.day.toString().padLeft(2, '0'),
        'fullDate': date,
      };
    });
  }

  // ── Achievements ───────────────────────────────────────────────
  // TODO: Replace with AnalyticsService.getAchievements()
  static List<Map<String, dynamic>> get achievements => [
        {
          'icon': '🔥',
          'iconColor': AppConstants.highPriority,
          'title': '5-day completion streak!',
          'subtitle': 'Keep the momentum going',
          'borderColor': const Color(0xFFFFE8D6),
        },
        {
          'icon': '🎯',
          'iconColor': AppConstants.primaryBlue,
          'title': 'Met 90% of weekly goals',
          'subtitle': 'Excellent execution this week!',
          'borderColor': const Color(0xFFDCEAFF),
        },
        {
          'icon': '🏆',
          'iconColor': Color(0xFF9B59B6),
          'title': 'Task backlog reduced by 35%',
          'subtitle': "You're closing gaps before deadlines stack up.",
          'borderColor': const Color(0xFFF0E6FF),
        },
      ];

  // ── Dashboard stats ────────────────────────────────────────────
  // TODO: Replace with DashboardService.getStats()
  static Map<String, dynamic> get dashboardStats => {
        'totalTasks': tasks.length,
        'completedTasks': tasks.where((t) => t.isCompleted).length,
        'inProgressTasks':
            tasks.where((t) => t.status == TaskStatus.inProgress).length,
        'productivityScore': 0.75,
      };

  // ── Private helpers ────────────────────────────────────────────
  static String _dayAbbr(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}

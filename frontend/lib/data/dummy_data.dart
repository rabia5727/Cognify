// ═══════════════════════════════════════════════════════════════════
// FILE: lib/data/dummy_data.dart
// WHY: Dummy data was hardcoded inside screen files:
//        - _tasks list inside dashboard_screen.dart
//        - _tasks + _projects lists inside tasks_screen.dart
//        - _weeklyData + _monthlyData inside analytics_screen.dart
//      This makes backend integration hard because data is mixed
//      with UI code.
//
// HOW TO REPLACE WITH REAL DATA:
//      When your backend is ready, replace each getter below with
//      an API call from your service files. The screens won't need
//      to change at all — they just call DummyData.tasks etc.
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/project_model.dart';
import '../constants/app_constant.dart';

class DummyData {
  // ── Tasks (used by dashboard + tasks screen) ───────────────────────
  // TODO: Replace with TaskService.getTasks() when backend is ready
  static List<Task> get tasks => [
        Task(
          id: '1',
          title: 'Complete Maths Assignment',
          subtitle: 'for hci assignment',
          dueDate: DateTime.now().copyWith(hour: 22, minute: 0),
          dueTime: '10:00pm',
          priority: Priority.high,
          status: TaskStatus.inProgress,
        ),
        Task(
          id: '2',
          title: 'ML assignment submit',
          subtitle: 'for hci assignment',
          dueDate: DateTime.now().copyWith(hour: 18, minute: 30),
          dueTime: '10:00pm',
          priority: Priority.medium,
          status: TaskStatus.inProgress,
        ),
        Task(
          id: '3',
          title: 'Email reports',
          subtitle: 'for hci assignment',
          dueDate: DateTime.now().copyWith(hour: 19, minute: 0),
          dueTime: '10:00pm',
          priority: Priority.low,
          status: TaskStatus.todo,
        ),
        Task(
          id: '4',
          title: 'Quiz preparation of AI subject',
          subtitle: 'for ai assignment',
          dueDate: DateTime.now().copyWith(hour: 17, minute: 0),
          dueTime: '5:00pm',
          priority: Priority.high,
          status: TaskStatus.todo,
        ),
        Task(
          id: '5',
          title: 'Design review meeting',
          subtitle: 'with design team',
          dueDate: DateTime.now()
              .add(const Duration(days: 1))
              .copyWith(hour: 14, minute: 0),
          dueTime: '2:00pm',
          priority: Priority.medium,
          status: TaskStatus.todo,
        ),
        Task(
          id: '6',
          title: 'Update documentation',
          subtitle: 'API documentation',
          dueDate: DateTime.now()
              .add(const Duration(days: 2))
              .copyWith(hour: 23, minute: 59),
          dueTime: '11:59pm',
          priority: Priority.low,
          status: TaskStatus.todo,
        ),
      ];

  // ── Projects (used by tasks screen) ───────────────────────────────
  // TODO: Replace with ProjectService.getProjects() when backend is ready
  static List<Project> get projects => [
        Project(
          id: '1',
          title: 'HCI Assignment',
          description: 'Academic',
          taskIds: ['1', '2'],
          dueDate: DateTime.now().add(const Duration(days: 5)),
          priority: Priority.high,
          colorValue: 0xFFFFE8D6,
        ),
        Project(
          id: '2',
          title: 'Freelance Website',
          description: 'Freelance',
          taskIds: ['3', '4'],
          dueDate: DateTime.now().add(const Duration(days: 10)),
          priority: Priority.medium,
          colorValue: 0xFFDCEAFF,
        ),
        Project(
          id: '3',
          title: 'ML Research Paper',
          description: 'Academic',
          taskIds: ['5', '6'],
          dueDate: DateTime.now().add(const Duration(days: 15)),
          priority: Priority.low,
          colorValue: 0xFFF0E6FF,
        ),
      ];

  // ── Weekly chart data (used by analytics screen) ───────────────────
  // TODO: Replace with AnalyticsService.getWeeklyData() when backend is ready
  static List<double> get weeklyChartData => [4, 6, 3, 7, 8, 5, 6];
  static List<String> get weekDays =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // ── Monthly chart data (used by analytics screen) ──────────────────
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

  // ── Calendar days (used by tasks screen) ──────────────────────────
  // Generates 7 days starting from today
  static List<Map<String, dynamic>> get calendarDays {
    final now = DateTime.now();
    final List<Map<String, dynamic>> days = [];

    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      days.add({
        'day': _getDayAbbreviation(date.weekday),
        'date': date.day.toString().padLeft(2, '0'),
        'fullDate': date,
      });
    }
    return days;
  }

  // ── Analytics achievements (used by analytics screen) ─────────────
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
          'iconColor': const Color(0xFF9B59B6),
          'title': 'Task backlog reduced by 35%',
          'subtitle': "You're closing gaps before deadlines stack up.",
          'borderColor': const Color(0xFFF0E6FF),
        },
      ];

  // ── Dashboard stats (used by dashboard screen) ─────────────────────
  static Map<String, dynamic> get dashboardStats => {
        'totalTasks': tasks.length,
        'completedTasks': tasks.where((t) => t.isCompleted).length,
        'inProgressTasks':
            tasks.where((t) => t.status == TaskStatus.inProgress).length,
        'productivityScore': 0.75,
      };
}

// Helper function to get day abbreviation
String _getDayAbbreviation(int weekday) {
  switch (weekday) {
    case 1:
      return 'Mon';
    case 2:
      return 'Tue';
    case 3:
      return 'Wed';
    case 4:
      return 'Thu';
    case 5:
      return 'Fri';
    case 6:
      return 'Sat';
    case 7:
      return 'Sun';
    default:
      return 'Mon';
  }
}

/* PURPOSE: Centralized app constants - colors, styles, strings, helpers
            Single source of truth to eliminate hardcoded values */

import 'package:flutter/material.dart';
import '../models/task_model.dart';

class AppConstants {
  // =============================================================
  // COLORS
  // =============================================================

  // Backgrounds
  static const Color scaffoldBg = Color(0xFFF4F6FA);
  static const Color cardBg = Colors.white;
  static const Color inputBg = Color(0xFFF5F5F5);

  // Brand colors
  static const Color primaryBlue = Color(0xFF1360E2);
  static const Color secondaryPurple = Color(0xFF9B8FFF);
  static const Color orange = Color(0xFFFF6B35);

  // Text colors
  static const Color darkText = Color(0xFF1A1A2E);
  static const Color grayText = Color(0xFF6B7280);
  static const Color lightGray = Color(0xFFE5E7EB);

  // Priority-specific colors
  static const Color highPriority = Color(0xFFFF5252);
  static const Color mediumPriority = Color(0xFFEFA535);
  static const Color lowPriority = Color(0xFF4CAF50);

  // =============================================================
  // TEXT STYLES
  // =============================================================

  static const TextStyle screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: darkText,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: darkText,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: darkText,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: grayText,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    color: grayText,
  );

  static const TextStyle statValue = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: darkText,
  );

  static const TextStyle statLabel = TextStyle(
    fontSize: 11,
    color: grayText,
  );

  // =============================================================
  // STRING CONSTANTS
  // =============================================================

  // App metadata
  static const String appName = 'Co-Tasker';
  static const String appVersion = 'v1.0.0';

  // Priority values (matches backend API)
  static const String priorityHigh = 'high';
  static const String priorityMedium = 'medium';
  static const String priorityLow = 'low';

  // Task status values (matches backend API)
  static const String statusTodo = 'todo';
  static const String statusInProgress = 'inProgress';
  static const String statusCompleted = 'completed';

  // Screen titles
  static const String tasksTitle = 'Tasks';
  static const String statisticsTitle = 'Statistics';
  static const String settingsTitle = 'Settings';
  static const String profileTitle = 'Profile';

  // Common UI text
  static const String addTask = 'Add Task';
  static const String editTask = 'Edit Task';
  static const String deleteTask = 'Delete Task';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String yes = 'Yes';
  static const String no = 'No';

  // Empty states
  static const String noTasks = 'No tasks here!';
  static const String noProjects = 'No projects here!';
  static const String noData = 'No data available';

  // =============================================================
  // LAYOUT CONSTANTS
  // =============================================================

  static const EdgeInsets screenPadding = EdgeInsets.fromLTRB(20, 8, 20, 24);
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets cardInnerPadding =
      EdgeInsets.fromLTRB(12, 12, 12, 12);
  static const EdgeInsets listPadding = EdgeInsets.fromLTRB(20, 4, 20, 20);

  static const double fabSize = 64;
  static const double backButtonSize = 36;
  static const double borderRadius = 16;
  static const double smallBorderRadius = 12;

  // =============================================================
  // HELPER FUNCTIONS
  // =============================================================

  /// Converts API string to Priority enum
  static Priority priorityFromString(String value) {
    switch (value) {
      case priorityHigh:
        return Priority.high;
      case priorityMedium:
        return Priority.medium;
      case priorityLow:
        return Priority.low;
      default:
        return Priority.medium;
    }
  }

  /// Gets color for string priority (used with API data)
  static Color priorityColor(String priority) {
    switch (priority) {
      case priorityHigh:
        return highPriority;
      case priorityMedium:
        return mediumPriority;
      case priorityLow:
        return lowPriority;
      default:
        return lowPriority;
    }
  }

  /// Gets color for Priority enum (used with models)
  static Color priorityColorFromEnum(Priority priority) {
    switch (priority) {
      case Priority.high:
        return highPriority;
      case Priority.medium:
        return mediumPriority;
      case Priority.low:
        return lowPriority;
    }
  }

  /// Simple date formatter: DD/MM/YYYY
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Formats time as "Due 10:00pm"
  static String formatDueTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'pm' : 'am';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return 'Due $displayHour:$minute$period';
  }

  /// Returns greeting based on current time
  static String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  /// Returns motivational message based on productivity score
  static String productivityMessage(double score) {
    if (score == 0) {
      return 'Start completing tasks and tracking focus, your score will update as you grow.';
    } else if (score >= 0.8) {
      return 'Bravo! Keep it up, you are almost done for today.';
    }
    return 'Good progress! Keep going, you are doing great.';
  }
}

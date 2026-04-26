// ═══════════════════════════════════════════════════════════════════
// FILE: lib/providers/analytics_provider.dart
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../data/dummy_data.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/task_model.dart';
import '../data/dummy_data.dart';

// Rename custom Color to avoid conflict

/*class AppColor {
  final int value;
  const AppColor(this.value);
}
*/
class AnalyticsProvider extends ChangeNotifier {
  List<Task> _tasks = [];

  void updateTasks(List<Task> tasks) {
    _tasks = tasks;
    notifyListeners();
  }

  // ─── Completion rates ─────────────────────────────────────────────

  double get weeklyCompletionRate {
    final weekTasks = _tasksInLastDays(7);
    if (weekTasks.isEmpty) return DummyData.weeklyCompletionRate;
    return weekTasks.where((t) => t.isCompleted).length / weekTasks.length;
  }

  double get monthlyCompletionRate {
    final monthTasks = _tasksInLastDays(30);
    if (monthTasks.isEmpty) return DummyData.monthlyCompletionRate;
    return monthTasks.where((t) => t.isCompleted).length / monthTasks.length;
  }

  // ─── Chart data ───────────────────────────────────────────────────

  List<double> get weeklyChartData {
    final now = DateTime.now();
    if (!_hasSufficientData(7)) return DummyData.weeklyChartData;

    return List.generate(7, (i) {
      final date = now.subtract(Duration(days: now.weekday - 1 - i));
      return _tasks
          .where((t) =>
              t.isCompleted &&
              t.dueDate.year == date.year &&
              t.dueDate.month == date.month &&
              t.dueDate.day == date.day)
          .length
          .toDouble();
    });
  }

  List<double> get monthlyChartData {
    final now = DateTime.now();
    return List.generate(12, (i) {
      return _tasks
          .where((t) =>
              t.isCompleted &&
              t.dueDate.year == now.year &&
              t.dueDate.month == i + 1)
          .length
          .toDouble();
    });
  }

  // ─── Stat card values ─────────────────────────────────────────────

  Map<String, String> get weeklyStats {
    final weekTasks = _tasksInLastDays(7);
    final completed = weekTasks.where((t) => t.isCompleted).length;
    return {
      'focusHours': '${(completed * 1.5).toStringAsFixed(1)}h',
      'avgTime': completed > 0 ? '${(7 / completed).toStringAsFixed(1)}h' : '–',
    };
  }

  Map<String, String> get monthlyStats {
    final monthTasks = _tasksInLastDays(30);
    final completed = monthTasks.where((t) => t.isCompleted).length;
    final rate =
        monthTasks.isEmpty ? 0 : (completed / monthTasks.length * 100).round();
    return {
      'tasksCompleted': '$completed',
      'efficiency': '$rate%',
    };
  }

  // ─── Achievements — using Color (custom) for pure Dart ─────────

  List<Map<String, dynamic>> get achievements {
    if (_tasks.isEmpty) return DummyData.achievements;

    final result = <Map<String, dynamic>>[];

    if (completedCount >= 1) {
      result.add({
        'icon': '🎯',
        'iconColor': const Color(0xFF1360E2), // ✅ Using Color
        'title': 'First task completed!',
        'subtitle': 'You\'re on your way.',
        'borderColor': const Color(0xFFB5D4F4), // ✅ Using Color
      });
    } 
    if (weeklyCompletionRate >= 0.8) {
      result.add({
        'icon': '🔥',

        'iconColor': const Color(0xFFEFA535),
        'title': 'Weekly streak',
        'subtitle': '80%+ completion this week.',
        'borderColor': const Color(0xFFFAC775),
      });
    }
    if (completedCount >= 10) {
      result.add({
        'icon': '⭐',
        'iconColor': const Color(0xFF639922),
        'title': 'Power user',
        'subtitle': '10 tasks completed.',
        'borderColor': const Color(0xFFC0DD97),
      });
    }

    return result.isEmpty ? DummyData.achievements : result;
  }

  int get completedCount => _tasks.where((t) => t.isCompleted).length;
  int get totalCount => _tasks.length;

  // ─── Helpers ──────────────────────────────────────────────────────

  List<Task> _tasksInLastDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _tasks.where((t) => t.dueDate.isAfter(cutoff)).toList();
  }

  bool _hasSufficientData(int minTasks) => _tasks.length >= minTasks ~/ 2;
}

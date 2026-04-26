import 'package:flutter/material.dart';
import '../services/analytics_service.dart';

class AnalyticsProvider extends ChangeNotifier {
  AnalyticsSummary? _summary;
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _summary != null;

  // ─── Completion rates ─────────────────────────────────────────────

  double get weeklyCompletionRate => _summary?.weeklyCompletionRate ?? 0.0;
  double get monthlyCompletionRate => _summary?.monthlyCompletionRate ?? 0.0;

  // ─── Chart data ───────────────────────────────────────────────────

  List<double> get weeklyChartData =>
      _summary?.weeklyChartData ?? List.filled(7, 0);

  List<double> get monthlyChartData =>
      _summary?.monthlyChartData ?? List.filled(12, 0);

  // ─── Stat card values ─────────────────────────────────────────────

  Map<String, String> get weeklyStats =>
      _summary != null
          ? {
              'focusHours': _summary!.weeklyStats['focus_hours'] ?? '0h',
              'avgTime': _summary!.weeklyStats['avg_time'] ?? '–',
            }
          : {'focusHours': '0h', 'avgTime': '–'};

  Map<String, String> get monthlyStats =>
      _summary != null
          ? {
              'tasksCompleted':
                  _summary!.monthlyStats['tasks_completed'] ?? '0',
              'efficiency': _summary!.monthlyStats['efficiency'] ?? '0%',
            }
          : {'tasksCompleted': '0', 'efficiency': '0%'};

  // ─── Achievements ─────────────────────────────────────────────────
  // Maps the icon string returned by the backend to the correct Flutter Colors.

  static const _iconColors = {
    '🎯': Color(0xFF1360E2),
    '🔥': Color(0xFFEFA535),
    '⭐': Color(0xFF639922),
  };

  static const _borderColors = {
    '🎯': Color(0xFFB5D4F4),
    '🔥': Color(0xFFFAC775),
    '⭐': Color(0xFFC0DD97),
  };

  List<Map<String, dynamic>> get achievements {
    if (_summary == null) return [];
    return _summary!.achievements.map((a) {
      final icon = a['icon'] ?? '';
      return {
        'icon': icon,
        'iconColor': _iconColors[icon] ?? const Color(0xFF1360E2),
        'title': a['title'] ?? '',
        'subtitle': a['subtitle'] ?? '',
        'borderColor': _borderColors[icon] ?? const Color(0xFFB5D4F4),
      };
    }).toList();
  }

  int get completedCount => _summary?.totalCompleted ?? 0;
  int get totalCount => _summary?.totalTasks ?? 0;

  // ─── Load from backend ────────────────────────────────────────────

  Future<void> loadSummary() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await AnalyticsService.getSummary();

    if (result.isSuccess) {
      _summary = result.data;
      _error = null;
    } else {
      _error = result.error;
    }

    _isLoading = false;
    notifyListeners();
  }
}

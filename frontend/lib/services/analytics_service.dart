import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

class AnalyticsSummary {
  final double weeklyCompletionRate;
  final double monthlyCompletionRate;
  final List<double> weeklyChartData;
  final List<double> monthlyChartData;
  final Map<String, String> weeklyStats;
  final Map<String, String> monthlyStats;
  final List<Map<String, String>> achievements;
  final int totalCompleted;
  final int totalTasks;

  const AnalyticsSummary({
    required this.weeklyCompletionRate,
    required this.monthlyCompletionRate,
    required this.weeklyChartData,
    required this.monthlyChartData,
    required this.weeklyStats,
    required this.monthlyStats,
    required this.achievements,
    required this.totalCompleted,
    required this.totalTasks,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    List<double> toDoubleList(dynamic raw) =>
        (raw as List).map((v) => (v as num).toDouble()).toList();

    Map<String, String> toStringMap(dynamic raw) =>
        (raw as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString()));

    final rawAchievements = json['achievements'] as List;
    final achievements = rawAchievements
        .map((a) => (a as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString())))
        .toList();

    return AnalyticsSummary(
      weeklyCompletionRate: (json['weekly_completion_rate'] as num).toDouble(),
      monthlyCompletionRate: (json['monthly_completion_rate'] as num).toDouble(),
      weeklyChartData: toDoubleList(json['weekly_chart_data']),
      monthlyChartData: toDoubleList(json['monthly_chart_data']),
      weeklyStats: toStringMap(json['weekly_stats']),
      monthlyStats: toStringMap(json['monthly_stats']),
      achievements: achievements,
      totalCompleted: json['total_completed'] as int,
      totalTasks: json['total_tasks'] as int,
    );
  }
}

class AnalyticsResult {
  final AnalyticsSummary? data;
  final String? error;
  bool get isSuccess => error == null;

  AnalyticsResult._({this.data, this.error});
  factory AnalyticsResult.success(AnalyticsSummary data) =>
      AnalyticsResult._(data: data);
  factory AnalyticsResult.failure(String error) =>
      AnalyticsResult._(error: error);
}

class AnalyticsService {
  static const String _base = 'http://127.0.0.1:8000/analytics';

  static Future<Map<String, String>> get _headers async {
    final token = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static String _parseError(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        return body['detail']?.toString() ??
            body['message']?.toString() ??
            'Something went wrong';
      }
    } catch (_) {}
    return 'Error ${res.statusCode}';
  }

  /// GET /analytics/summary — fetch all analytics data in one call
  static Future<AnalyticsResult> getSummary() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/summary'), headers: await _headers)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final summary = AnalyticsSummary.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
        return AnalyticsResult.success(summary);
      }
      return AnalyticsResult.failure(_parseError(res));
    } on SocketException {
      return AnalyticsResult.failure('Cannot connect to server.');
    } catch (e) {
      return AnalyticsResult.failure('Unexpected error: $e');
    }
  }
}

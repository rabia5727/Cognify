import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';
import 'token_storage.dart';

class NotificationService {
  static const String _base = 'http://127.0.0.1:8000/notifications';

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
      if (body is Map)
        return body['detail']?.toString() ?? 'Something went wrong';
    } catch (_) {}
    return 'Error ${res.statusCode}';
  }

  // ── GET /notifications/ ────────────────────────────────────────────────────

  static Future<NotificationResult> getNotifications({
    bool unreadOnly = false,
    String? type,
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      final uri = Uri.parse('$_base/').replace(
        queryParameters: {
          'unread_only': unreadOnly.toString(),
          if (type != null) 'type': type,
          'skip': skip.toString(),
          'limit': limit.toString(),
        },
      );
      final res = await http
          .get(uri, headers: await _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = ((body['notifications'] ?? body) as List)
            .map((e) => AppNotification.fromJson(e))
            .toList();
        return NotificationResult.success(list);
      }
      return NotificationResult.failure(_parseError(res));
    } on SocketException {
      return NotificationResult.failure('Cannot connect to server.');
    } catch (e) {
      return NotificationResult.failure('Unexpected error: $e');
    }
  }

  // ── GET /notifications/unread-count ───────────────────────────────────────

  static Future<int> getUnreadCount() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/unread-count'), headers: await _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200)
        return jsonDecode(res.body)['unread_count'] ?? 0;
    } catch (_) {}
    return 0;
  }

  // ── POST /notifications/ ──────────────────────────────────────────────────

  static Future<NotificationResult> createNotification({
    required String title,
    required String message,
    String type = 'general',
    String? taskId,
    DateTime? remindAt,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/'),
            headers: await _headers,
            body: jsonEncode({
              'title': title,
              'message': message,
              'type': type,
              if (taskId != null) 'task_id': taskId,
              if (remindAt != null) 'remind_at': remindAt.toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 201) {
        return NotificationResult.success(
            [AppNotification.fromJson(jsonDecode(res.body))]);
      }
      return NotificationResult.failure(_parseError(res));
    } on SocketException {
      return NotificationResult.failure('Cannot connect to server.');
    } catch (e) {
      return NotificationResult.failure('Unexpected error: $e');
    }
  }

  // ── PATCH /notifications/{id}/read ────────────────────────────────────────

  static Future<bool> markAsRead(String id) async {
    try {
      final res = await http
          .patch(Uri.parse('$_base/$id/read'), headers: await _headers)
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── PATCH /notifications/read-all ─────────────────────────────────────────

  static Future<bool> markAllRead() async {
    try {
      final res = await http
          .patch(Uri.parse('$_base/read-all'), headers: await _headers)
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── DELETE /notifications/{id} ────────────────────────────────────────────

  static Future<bool> deleteNotification(String id) async {
    try {
      final res = await http
          .delete(Uri.parse('$_base/$id'), headers: await _headers)
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  // ── POST /notifications/refresh ──────────────────────────────────────────

  static Future<int> refresh() async {
    try {
      final res = await http
          .post(Uri.parse('$_base/refresh'), headers: await _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return jsonDecode(res.body)['new_notifications'] ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  // ── Batch Operations ──────────────────────────────────────────────────────

  static Future<bool> deleteMultiple(List<String> ids) async {
    try {
      final res = await http
          .delete(
            Uri.parse('$_base/batch/'),
            headers: await _headers,
            body: jsonEncode({'ids': ids}),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> markMultipleAsRead(List<String> ids) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_base/batch/read'),
            headers: await _headers,
            body: jsonEncode({'ids': ids}),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Reminder Specific ─────────────────────────────────────────────────────

  static Future<NotificationResult> getUpcomingReminders(
      {int hoursAhead = 24}) async {
    try {
      final uri = Uri.parse('$_base/reminders/upcoming').replace(
        queryParameters: {'hours_ahead': hoursAhead.toString()},
      );
      final res = await http
          .get(uri, headers: await _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['reminders'] as List)
            .map((e) => AppNotification.fromJson(e))
            .toList();
        return NotificationResult.success(list);
      }
      return NotificationResult.failure(_parseError(res));
    } on SocketException {
      return NotificationResult.failure('Cannot connect to server.');
    } catch (e) {
      return NotificationResult.failure('Unexpected error: $e');
    }
  }

  static Future<bool> snoozeReminder(String id, {int minutes = 10}) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_base/$id/snooze'),
            headers: await _headers,
            body: jsonEncode({'minutes': minutes}),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// ── Result wrapper ────────────────────────────────────────────────────────────

class NotificationResult {
  final List<AppNotification>? data;
  final String? error;
  bool get isSuccess => error == null;

  NotificationResult._({this.data, this.error});
  factory NotificationResult.success(List<AppNotification> data) =>
      NotificationResult._(data: data);
  factory NotificationResult.failure(String error) =>
      NotificationResult._(error: error);
}

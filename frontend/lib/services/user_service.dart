import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'token_storage.dart';
import '../config/app_config.dart';

class UserService {
  static String get _base => '${AppConfig.baseUrl}/users';

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

  // GET /users/me
  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/me'), headers: await _headers)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } on SocketException {
      print('❌ Network error: Cannot connect to server');
      return null;
    } catch (e) {
      print('❌ Unexpected error: $e');
      return null;
    }
  }

  // PUT /users/me  — update name
  static Future<String?> updateName(String name) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/me'),
            headers: await _headers,
            body: jsonEncode({'name': name}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return null;
      return _parseError(res);
    } on SocketException {
      return 'Cannot connect to server.';
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  // PATCH /users/me/password
  static Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_base/me/password'),
            headers: await _headers,
            body: jsonEncode({
              'current_password': currentPassword,
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return null;
      return _parseError(res);
    } on SocketException {
      return 'Cannot connect to server.';
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  // PATCH /users/me/preferences
// PATCH /users/me/preferences
  static Future<String?> updatePreferences({
    bool? notificationsEnabled,
    bool? notificationPermissionAsked,
    String? theme,
    bool? voicePermission,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (notificationsEnabled != null) {
        body['notifications_enabled'] = notificationsEnabled;
      }
      if (notificationPermissionAsked != null) {
        body['notification_permission_asked'] = notificationPermissionAsked;
      }
      if (theme != null) {
        body['theme'] = theme;
      }
      if (voicePermission != null) {
        body['voice_permission'] = voicePermission;
      }
      if (body.isEmpty) return null;

      final res = await http
          .patch(
            Uri.parse('$_base/me/preferences'),
            headers: await _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) return null;
      return _parseError(res);
    } on SocketException {
      return 'Cannot connect to server.';
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  // DELETE /users/me
  static Future<String?> deleteAccount() async {
    try {
      final res = await http
          .delete(Uri.parse('$_base/me'), headers: await _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return null;
      return _parseError(res);
    } on SocketException {
      return 'Cannot connect to server.';
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  // POST /users/me/quiz — save quiz preferences
  static Future<String?> saveQuizPreferences({
    required List<String> goals,
    required List<String> scheduleType,
    required int dailyTaskLoad,
    required List<String> productivityChallenges,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/me/quiz'),
            headers: await _headers,
            body: jsonEncode({
              'goals': goals,
              'scheduleType':
                  scheduleType.isNotEmpty ? scheduleType.first : null,
              'dailyTaskLoad': dailyTaskLoad,
              'productivityChallenges': productivityChallenges,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return null;
      return _parseError(res);
    } on SocketException {
      return 'Cannot connect to server.';
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }
}

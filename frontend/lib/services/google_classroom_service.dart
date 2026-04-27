// Purpose: Communication between app and your backend's classroom endpoints
// Methods:
//   - connectGoogleAccount() - OAuth flow
//   - fetchCourses() - Get all courses
//   - updateCourseSyncStatus() - Enable/disable specific course
//   - fetchAssignments() - Get assignments for a course
//   - syncAllAssignments() - Trigger manual sync
//   - submitAssignment() - Submit text/file to Classroom
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import './token_storage.dart';

class GoogleClassroomService {
  static const String baseUrl = AppConfig.baseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final token = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get all courses for the user
  static Future<List<Map<String, dynamic>>> getCourses() async {
    final response = await http.get(
      Uri.parse('$baseUrl/classroom/courses'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['courses']);
    } else if (response.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception('Failed to get courses: ${response.body}');
    }
  }

  // Toggle sync status for a course
  static Future<void> toggleCourseSync(String courseId, bool enabled) async {
    final response = await http.put(
      Uri.parse('$baseUrl/classroom/courses/$courseId/toggle'),
      headers: await _getHeaders(),
      body: jsonEncode({'enabled': enabled}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update course sync status');
    }
  }

  // Archive a course (hide from list)
  static Future<void> archiveCourse(String courseId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/classroom/courses/$courseId/archive'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to archive course');
    }
  }

  // Restore an archived course
  static Future<void> restoreCourse(String courseId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/classroom/courses/$courseId/restore'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to restore course');
    }
  }

  // Manual sync - fetch all assignments from enabled courses
  static Future<Map<String, dynamic>> syncAllAssignments() async {
    final response = await http.post(
      Uri.parse('$baseUrl/classroom/sync'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to sync assignments: ${response.body}');
    }
  }

  // Get assignments for a specific course
  static Future<List<Map<String, dynamic>>> getAssignments(String courseId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/classroom/courses/$courseId/assignments'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['assignments']);
    } else {
      throw Exception('Failed to get assignments: ${response.body}');
    }
  }

  // Submit text assignment
  static Future<Map<String, dynamic>> submitTextAssignment({
    required String courseId,
    required String assignmentId,
    required String content,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/classroom/submit/text'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'course_id': courseId,
        'assignment_id': assignmentId,
        'content': content,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to submit assignment: ${response.body}');
    }
  }

  // Submit file assignment
  static Future<Map<String, dynamic>> submitFileAssignment({
    required String courseId,
    required String assignmentId,
    required String fileUrl,
    required String fileName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/classroom/submit/file'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'course_id': courseId,
        'assignment_id': assignmentId,
        'file_url': fileUrl,
        'file_name': fileName,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to submit file: ${response.body}');
    }
  }
  // Connect Google Classroom account
static Future<void> connectGoogleAccount({
  required String accessToken,
  required String refreshToken,
  required String clientId,
  required String clientSecret,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/classroom/connect'),
    headers: await _getHeaders(),
    body: jsonEncode({
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'client_id': clientId,
      'client_secret': clientSecret,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to connect Google Classroom: ${response.body}');
  }
}

}
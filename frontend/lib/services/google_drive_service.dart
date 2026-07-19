import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import './token_storage.dart';

class GoogleDriveService {
  static const String baseUrl = AppConfig.baseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final token = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get OAuth URL for mobile
  static Future<Map<String, String>> getMobileAuthUrl() async {
    final response = await http.get(
      Uri.parse('$baseUrl/drive/oauth/mobile-auth'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'auth_url': data['auth_url'] as String,
        'state': data['state'] as String,
      };
    } else {
      throw Exception('Failed to get OAuth URL: ${response.body}');
    }
  }

  // Check connection status
  static Future<Map<String, dynamic>> getHealth() async {
    final response = await http.get(
      Uri.parse('$baseUrl/drive/health'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get Drive status: ${response.body}');
    }
  }

  // Check if connected (simple bool)
  static Future<bool> isConnected() async {
    try {
      final result = await getHealth();
      return result['connected'] ?? false;
    } catch (e) {
      return false;
    }
  }

  // Disconnect Drive
  static Future<void> disconnect() async {
    final response = await http.post(
      Uri.parse('$baseUrl/drive/disconnect'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to disconnect Drive: ${response.body}');
    }
  }

  // Upload text as PDF
  static Future<Map<String, dynamic>> uploadText({
    required String content,
    required String fileName,
    required String assignmentId,
    required String courseId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/drive/upload/text'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'content': content,
        'file_name': fileName,
        'assignment_id': assignmentId,
        'course_id': courseId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to upload file: ${response.body}');
    }
  }
}

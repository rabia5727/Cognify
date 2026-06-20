// Purpose: Communication between app and your backend's Gmail endpoints
// Methods:
//   - getMobileAuthUrl() - Get OAuth URL for Gmail connection
//   - getHealth() - Check connection status
//   - disconnect() - Remove Gmail integration
//   - syncEmails() - Fetch and sync emails from Gmail
//   - getEmails() - Get stored emails from database
//   - createTaskFromEmail() - Create a task from an email
//   - archiveEmail() - Archive email in Gmail
//   - markEmailRead() - Mark email as read

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import './token_storage.dart';

class GmailService {
  static const String baseUrl = AppConfig.baseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final token = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ─────────────────────────────────────────────────────────────────
  // OAUTH ENDPOINTS
  // ─────────────────────────────────────────────────────────────────

  // Get OAuth URL for mobile
  static Future<Map<String, String>> getMobileAuthUrl() async {
    final response = await http.get(
      Uri.parse('$baseUrl/gmail/oauth/mobile-auth'),
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

  // ─────────────────────────────────────────────────────────────────
  // CONNECTION STATUS ENDPOINTS
  // ─────────────────────────────────────────────────────────────────

  // Check if user is connected to Gmail
  static Future<bool> isConnected() async {
    final response = await http.get(
      Uri.parse('$baseUrl/gmail/health'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['connected'] ?? false;
    }
    return false;
  }

  // Get connection health status (detailed)
  static Future<Map<String, dynamic>> getHealth() async {
    final response = await http.get(
      Uri.parse('$baseUrl/gmail/health'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get Gmail status: ${response.body}');
    }
  }

  // Disconnect Gmail (remove tokens)
  static Future<void> disconnect() async {
    final response = await http.post(
      Uri.parse('$baseUrl/gmail/disconnect'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to disconnect Gmail: ${response.body}');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // EMAIL SYNC ENDPOINTS
  // ─────────────────────────────────────────────────────────────────

  // Sync emails from Gmail
  static Future<Map<String, dynamic>> syncEmails({int maxResults = 50}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/gmail/sync?max_results=$maxResults'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to sync emails: ${response.body}');
    }
  }

  // Get stored emails from database
  static Future<Map<String, dynamic>> getEmails({int limit = 50}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/gmail/emails?limit=$limit'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get emails: ${response.body}');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // EMAIL ACTION ENDPOINTS
  // ─────────────────────────────────────────────────────────────────

  // Create task from email
  static Future<Map<String, dynamic>> createTaskFromEmail({
    required String emailId,
    required String title,
    String? description,
    String priority = 'medium',
    String category = 'email',
    DateTime? dueDate,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/gmail/emails/$emailId/task'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'title': title,
        'description': description,
        'priority': priority,
        'category': category,
        'due_date': dueDate?.toIso8601String(),
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create task: ${response.body}');
    }
  }

  // Archive email
  static Future<Map<String, dynamic>> archiveEmail(String emailId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/gmail/emails/$emailId/archive'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to archive email: ${response.body}');
    }
  }

  // Mark email as read
  static Future<Map<String, dynamic>> markEmailRead(String emailId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/gmail/emails/$emailId/read'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to mark email as read: ${response.body}');
    }
  }
}

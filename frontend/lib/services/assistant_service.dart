// lib/services/assistant_service.dart
// Handles all API calls for voice + AI assistant
// Follows the exact same pattern as your existing ApiService

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/assistant_model.dart';
import 'token_storage.dart';

class AssistantService {
  static String get baseUrl => AppConfig.baseUrl;

  // ── Auth header helper — same pattern as ApiService ──────────────────────
  static Future<Map<String, String>> get _authHeaders async {
    final token = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Send text message to AI ───────────────────────────────────────────────
  // POST /assistant/chat
  // Returns AI reply string
  static Future<String?> sendMessage(String message,
      {String source = 'text'}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/assistant/chat'),
            headers: await _authHeaders,
            body: jsonEncode({
              'message': message,
              'source': source, // "text" or "voice"
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'] as String?;
      }
      return null;
    } on SocketException {
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Load full conversation history ────────────────────────────────────────
  // GET /assistant/history
  // Returns list of all messages for this user
  static Future<List<AssistantMessage>> getHistory() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/assistant/history'),
            headers: await _authHeaders,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List messages = data['messages'] ?? [];
        return messages.map((m) => AssistantMessage.fromJson(m)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Transcribe audio file ─────────────────────────────────────────────────
  // POST /voice/transcribe
  // Sends audio file, returns transcribed text
  static Future<String?> transcribeAudio(String filePath) async {
    try {
      final token = await TokenStorage.getToken();

      // multipart/form-data request — audio file upload
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/voice/transcribe'),
      );

      // Add auth header
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Attach the audio file
      request.files.add(await http.MultipartFile.fromPath(
        'audio', // field name — must match FastAPI parameter name
        filePath,
      ));

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['transcript'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

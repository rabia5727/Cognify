// lib/services/assistant_service.dart
//
// ✅ SESSION REWRITE: backend now requires a session_id for chat and
// history, and exposes new endpoints for listing/creating/deleting
// chat sessions. This service layer mirrors those changes exactly.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/assistant_model.dart';
import '../config/app_config.dart';
import 'token_storage.dart';

/// ✅ NEW: lightweight summary of one chat session, for the sidebar.
class ChatSession {
  final String sessionId;
  final String title;
  final String lastMessagePreview;
  final int messageCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChatSession({
    required this.sessionId,
    required this.title,
    this.lastMessagePreview = '',
    this.messageCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      sessionId: json['session_id'] ?? '',
      title: json['title'] ?? 'New Chat',
      lastMessagePreview: json['last_message_preview'] ?? '',
      messageCount: json['message_count'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }
}

/// ✅ NEW: result of sending a chat message — now includes session_id,
/// since the backend may auto-create a new session on the first message.
class ChatSendResult {
  final String reply;
  final String intent;
  final String sessionId;

  ChatSendResult({
    required this.reply,
    required this.intent,
    required this.sessionId,
  });
}

/// ✅ NEW: result of loading history — includes which session + its title.
class HistoryResult {
  final List<AssistantMessage> messages;
  final String sessionId;
  final String title;

  HistoryResult({
    required this.messages,
    required this.sessionId,
    required this.title,
  });
}

class AssistantService {
  static String get _base => '${AppConfig.baseUrl}/assistant';

  static Future<Map<String, String>> get _headers async {
    final token = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// POST /assistant/chat — now passes session_id, returns it too.
  /// If sessionId is null/empty, backend auto-creates a new session.
  static Future<ChatSendResult?> sendMessage(
    String message, {
    String source = 'text',
    String? sessionId,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/chat'),
            headers: await _headers,
            body: jsonEncode({
              'message': message,
              'source': source,
              'session_id': sessionId ?? '',
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return ChatSendResult(
          reply: body['reply'] ?? '',
          intent: body['intent'] ?? 'chat',
          sessionId: body['session_id'] ?? '',
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// GET /assistant/history?session_id=... — now REQUIRES a session_id.
  static Future<HistoryResult> getHistory(String sessionId) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_base/history?session_id=$sessionId'),
            headers: await _headers,
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final messages = (body['messages'] as List)
            .map((m) => AssistantMessage.fromJson(m as Map<String, dynamic>))
            .toList();
        return HistoryResult(
          messages: messages,
          sessionId: body['session_id'] ?? sessionId,
          title: body['title'] ?? 'New Chat',
        );
      }
      return HistoryResult(
          messages: [], sessionId: sessionId, title: 'New Chat');
    } catch (_) {
      return HistoryResult(
          messages: [], sessionId: sessionId, title: 'New Chat');
    }
  }

  /// ✅ NEW: GET /assistant/sessions — list all chats for the sidebar.
  static Future<List<ChatSession>> getSessions() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/sessions'), headers: await _headers)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return (body['sessions'] as List)
            .map((s) => ChatSession.fromJson(s as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// ✅ NEW: POST /assistant/sessions — start a brand new empty chat.
  /// Returns the new session_id, or null on failure.
  static Future<String?> createNewSession() async {
    try {
      final res = await http
          .post(Uri.parse('$_base/sessions'), headers: await _headers)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['session_id'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// ✅ NEW: DELETE /assistant/sessions/{id} — delete a chat permanently.
  static Future<bool> deleteSession(String sessionId) async {
    try {
      final res = await http
          .delete(
            Uri.parse('$_base/sessions/$sessionId'),
            headers: await _headers,
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Unchanged — transcribe audio for voice messages.
  /// (Kept here so AssistantProvider's existing call site still works;
  /// adjust if your real implementation differs — paste it and I'll
  /// reconcile.)
  static Future<String?> transcribeAudio(String audioFilePath) async {
    try {
      final token = await TokenStorage.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/voice/transcribe'),
      );
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files
          .add(await http.MultipartFile.fromPath('file', audioFilePath));

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamedResponse);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['transcript'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

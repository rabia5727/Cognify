// lib/providers/assistant_provider.dart
//
// ✅ SESSION REWRITE: previously this provider only ever knew about ONE
// flat message list for the whole user. Now it tracks:
//   - currentSessionId: which chat is currently open
//   - sessions: the list of all the user's chats (for the sidebar)
//   - messages: scoped to ONLY the current session
//
// This is what makes "history of chat should show in separate chats"
// actually work end-to-end.

import 'package:flutter/material.dart';
import '../models/assistant_model.dart';
import '../services/assistant_service.dart';

class AssistantProvider extends ChangeNotifier {
  // ── State ─────────────────────────────────────────────────────────
  List<AssistantMessage> _messages = [];
  List<ChatSession> _sessions = [];
  String? _currentSessionId;
  String _currentTitle = 'New Chat';

  bool _isLoading = false; // loading a session's history
  bool _isLoadingSessions = false; // loading the sidebar list
  bool _isTyping = false;
  String? _error;

  // ── Getters ───────────────────────────────────────────────────────
  List<AssistantMessage> get messages => _messages;
  List<ChatSession> get sessions => _sessions;
  String? get currentSessionId => _currentSessionId;
  String get currentTitle => _currentTitle;
  bool get isLoading => _isLoading;
  bool get isLoadingSessions => _isLoadingSessions;
  bool get isTyping => _isTyping;
  String? get error => _error;

  // ── Load ONE session's history (called when opening a specific chat) ─
  Future<void> loadHistory({String? sessionId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // If no sessionId given, this is a fresh/new chat with nothing to load.
    if (sessionId == null || sessionId.isEmpty) {
      _messages = [];
      _currentSessionId = null;
      _currentTitle = 'New Chat';
      _isLoading = false;
      notifyListeners();
      return;
    }

    final result = await AssistantService.getHistory(sessionId);
    _messages = result.messages;
    _currentSessionId = result.sessionId;
    _currentTitle = result.title;

    _isLoading = false;
    notifyListeners();
  }

  // ── ✅ NEW: Load the sidebar list of all chat sessions ────────────────
  Future<void> loadSessions() async {
    _isLoadingSessions = true;
    notifyListeners();

    _sessions = await AssistantService.getSessions();

    _isLoadingSessions = false;
    notifyListeners();
  }

  // ── ✅ NEW: Switch to a different existing chat ───────────────────────
  Future<void> switchToSession(String sessionId) async {
    await loadHistory(sessionId: sessionId);
  }

  // ── ✅ NEW: Start a brand new empty chat ──────────────────────────────
  Future<void> startNewChat() async {
    _messages = [];
    _currentSessionId = null; // null = next sendMessage() will auto-create one
    _currentTitle = 'New Chat';
    _error = null;
    notifyListeners();
  }

  // ── ✅ NEW: Delete a chat session ──────────────────────────────────────
  Future<bool> deleteSession(String sessionId) async {
    final success = await AssistantService.deleteSession(sessionId);
    if (success) {
      _sessions.removeWhere((s) => s.sessionId == sessionId);
      // If the deleted session was the one currently open, reset to new chat
      if (_currentSessionId == sessionId) {
        await startNewChat();
      }
      notifyListeners();
    }
    return success;
  }

  // ── Send text message — now session-aware ────────────────────────────
  Future<void> sendMessage(String text, {String source = 'text'}) async {
    if (text.trim().isEmpty) return;

    _messages.add(AssistantMessage(
      role: 'user',
      content: text.trim(),
      source: source,
      timestamp: DateTime.now(),
    ));

    _isTyping = true;
    notifyListeners();

    final result = await AssistantService.sendMessage(
      text.trim(),
      source: source,
      sessionId:
          _currentSessionId, // null on first message — backend auto-creates
    );

    _isTyping = false;

    if (result != null) {
      _messages.add(AssistantMessage(
        role: 'assistant',
        content: result.reply,
        source: 'assistant',
        timestamp: DateTime.now(),
      ));

      // ✅ CRITICAL: capture the session_id the backend assigned/used.
      // On the very first message of a new chat, this is the moment we
      // learn the real session_id — without storing it here, every
      // subsequent message would try to auto-create ANOTHER new session,
      // silently fragmenting what should be one continuous chat.
      if (_currentSessionId == null || _currentSessionId != result.sessionId) {
        _currentSessionId = result.sessionId;
        // Refresh the sidebar list in the background so the new chat
        // appears there too, with its auto-generated title.
        loadSessions();
      }
    } else {
      _messages.add(AssistantMessage(
        role: 'assistant',
        content: 'Sorry, I\'m having trouble connecting. Please try again.',
        source: 'assistant',
        timestamp: DateTime.now(),
      ));
    }

    notifyListeners();
  }

  // ── Send voice message — unchanged flow, just delegates to sendMessage ─
  Future<void> sendVoiceMessage(String audioFilePath) async {
    _isTyping = true;
    notifyListeners();

    final transcript = await AssistantService.transcribeAudio(audioFilePath);

    if (transcript == null || transcript.isEmpty) {
      _isTyping = false;
      _messages.add(AssistantMessage(
        role: 'assistant',
        content: 'I couldn\'t understand that. Please try again.',
        source: 'assistant',
        timestamp: DateTime.now(),
      ));
      notifyListeners();
      return;
    }

    _isTyping = false;
    await sendMessage(transcript, source: 'voice');
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

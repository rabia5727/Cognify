// lib/providers/assistant_provider.dart
// State management for the AI assistant
// Follows your existing provider pattern

import 'package:flutter/material.dart';
import '../models/assistant_model.dart';
import '../services/assistant_service.dart';

class AssistantProvider extends ChangeNotifier {
  // ── State ─────────────────────────────────────────────────────────────────
  List<AssistantMessage> _messages = [];
  bool _isLoading = false; // loading history on screen open
  bool _isTyping = false; // AI is generating a reply
  String? _error;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<AssistantMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isTyping => _isTyping;
  String? get error => _error;

  // ── Load history when AssistantScreen opens ───────────────────────────────
  Future<void> loadHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final history = await AssistantService.getHistory();
    _messages = history;

    _isLoading = false;
    notifyListeners();
  }

  // ── Send text message ─────────────────────────────────────────────────────
  Future<void> sendMessage(String text, {String source = 'text'}) async {
    if (text.trim().isEmpty) return;

    // Immediately add user message to UI — feels instant
    _messages.add(AssistantMessage(
      role: 'user',
      content: text.trim(),
      source: source,
      timestamp: DateTime.now(),
    ));

    // Show typing indicator
    _isTyping = true;
    notifyListeners();

    // Call API
    final reply =
        await AssistantService.sendMessage(text.trim(), source: source);

    // Hide typing indicator
    _isTyping = false;

    if (reply != null) {
      // Add AI reply to UI
      _messages.add(AssistantMessage(
        role: 'assistant',
        content: reply,
        source: 'assistant',
        timestamp: DateTime.now(),
      ));
    } else {
      // Show error message as a bubble
      _messages.add(AssistantMessage(
        role: 'assistant',
        content: 'Sorry, I\'m having trouble connecting. Please try again.',
        source: 'assistant',
        timestamp: DateTime.now(),
      ));
    }

    notifyListeners();
  }

  // ── Send voice message ────────────────────────────────────────────────────
  // Called from VoiceListeningScreen after recording
  Future<void> sendVoiceMessage(String audioFilePath) async {
    // Show transcribing indicator
    _isTyping = true;
    notifyListeners();

    // Step 1 — transcribe audio
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

    // Step 2 — send transcript to AI (source = "voice")
    // sendMessage handles adding user bubble + AI reply
    _isTyping = false;
    await sendMessage(transcript, source: 'voice');
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

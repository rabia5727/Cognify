// lib/models/assistant_model.dart

class AssistantMessage {
  final String role; // "user" or "assistant"
  final String content; // message text
  final String source; // "voice", "text", or "assistant"
  final String intent; // "chat", "create_task", etc.
  final DateTime? timestamp;

  AssistantMessage({
    required this.role,
    required this.content,
    this.source = "text",
    this.intent = "chat",
    this.timestamp,
  });

  factory AssistantMessage.fromJson(Map<String, dynamic> json) {
    return AssistantMessage(
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      source: json['source'] ?? 'text',
      intent: json['intent'] ?? 'chat',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'])
          : null,
    );
  }

  bool get isUser => role == 'user';
  bool get isVoice => source == 'voice';
}

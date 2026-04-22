class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String? taskId;
  final DateTime? remindAt;
  final DateTime createdAt;
  final bool isTriggered; // ← ADDED
  final DateTime? triggeredAt; // ← ADDED

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.taskId,
    this.remindAt,
    required this.createdAt,
    this.isTriggered = false, // ← ADDED
    this.triggeredAt, // ← ADDED
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      message: json['message'],
      type: json['type'] ?? 'general',
      isRead: json['is_read'] ?? false,
      taskId: json['task_id'],
      remindAt:
          json['remind_at'] != null ? DateTime.parse(json['remind_at']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      isTriggered: json['is_triggered'] ?? false, // ← ADDED
      triggeredAt: json['triggered_at'] != null // ← ADDED
          ? DateTime.parse(json['triggered_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'is_read': isRead,
        'task_id': taskId,
        'remind_at': remindAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'is_triggered': isTriggered, // ← ADDED
        'triggered_at': triggeredAt?.toIso8601String(), // ← ADDED
      };

  AppNotification copyWith({
    bool? isRead,
    bool? isTriggered, // ← ADDED
    DateTime? triggeredAt, // ← ADDED
  }) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      taskId: taskId,
      remindAt: remindAt,
      createdAt: createdAt,
      isTriggered: isTriggered ?? this.isTriggered, // ← ADDED
      triggeredAt: triggeredAt ?? this.triggeredAt, // ← ADDED
    );
  }
}

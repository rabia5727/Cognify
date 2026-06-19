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
  final bool isTriggered;
  final DateTime? triggeredAt;

  // ─── Notification Type Constants ─────────────────────────────────────────
  static const String typeGeneral = 'general';
  static const String typeClassroomAssignment = 'classroom_assignment';
  static const String typeClassroomBatch = 'classroom_batch';
  static const String typeDeadlineReminder = 'deadline_reminder';
  static const String typeSubmissionSuccess = 'submission_success';
  static const String typeSyncComplete = 'sync_complete';

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
    this.isTriggered = false,
    this.triggeredAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      message: json['message'],
      type: json['type'] ?? typeGeneral,
      isRead: json['is_read'] ?? false,
      taskId: json['task_id'],
      remindAt:
          json['remind_at'] != null ? DateTime.parse(json['remind_at']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      isTriggered: json['is_triggered'] ?? false,
      triggeredAt: json['triggered_at'] != null
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
        'is_triggered': isTriggered,
        'triggered_at': triggeredAt?.toIso8601String(),
      };

  AppNotification copyWith({
    bool? isRead,
    bool? isTriggered,
    DateTime? triggeredAt,
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
      isTriggered: isTriggered ?? this.isTriggered,
      triggeredAt: triggeredAt ?? this.triggeredAt,
    );
  }
}

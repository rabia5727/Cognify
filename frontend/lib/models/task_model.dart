import 'package:flutter/material.dart';

// =============================================================
// PRIORITY ENUM
// =============================================================

enum Priority { high, medium, low }

extension PriorityExtension on Priority {
  String get label {
    switch (this) {
      case Priority.high:
        return 'High';
      case Priority.medium:
        return 'Medium';
      case Priority.low:
        return 'Low';
    }
  }

  String get stringValue {
    switch (this) {
      case Priority.high:
        return 'high';
      case Priority.medium:
        return 'medium';
      case Priority.low:
        return 'low';
    }
  }

  Color get color {
    switch (this) {
      case Priority.high:
        return const Color(0xFFFF5252);
      case Priority.medium:
        return const Color(0xFFEFA535);
      case Priority.low:
        return const Color(0xFF4CAF50);
    }
  }

  static Priority fromString(String value) {
    switch (value.toLowerCase()) {
      case 'high':
        return Priority.high;
      case 'medium':
        return Priority.medium;
      case 'low':
        return Priority.low;
      default:
        return Priority.medium;
    }
  }
}

// =============================================================
// TASK CATEGORY ENUM
// =============================================================

enum TaskCategory { general, email, classroom, freelance, academic }

extension TaskCategoryExtension on TaskCategory {
  String get label {
    switch (this) {
      case TaskCategory.general:
        return 'General';
      case TaskCategory.email:
        return 'Email';
      case TaskCategory.classroom:
        return 'Classroom';
      case TaskCategory.freelance:
        return 'Freelance';
      case TaskCategory.academic:
        return 'Academic';
    }
  }

  String get stringValue {
    switch (this) {
      case TaskCategory.general:
        return 'general';
      case TaskCategory.email:
        return 'email';
      case TaskCategory.classroom:
        return 'classroom';
      case TaskCategory.freelance:
        return 'freelance';
      case TaskCategory.academic:
        return 'academic';
    }
  }

  Color get color {
    switch (this) {
      case TaskCategory.academic:
        return const Color(0xFF1360E2);
      case TaskCategory.freelance:
        return const Color(0xFF7B61FF);
      case TaskCategory.email:
        return const Color(0xFF7B61FF);
      case TaskCategory.classroom:
        return const Color(0xFF1360E2);
      case TaskCategory.general:
        return const Color(0xFF9E9E9E);
    }
  }

  static TaskCategory fromString(String value) {
    switch (value.toLowerCase()) {
      case 'email':
        return TaskCategory.email;
      case 'classroom':
        return TaskCategory.classroom;
      case 'freelance':
        return TaskCategory.freelance;
      case 'academic':
        return TaskCategory.academic;
      default:
        return TaskCategory.general;
    }
  }
}

// =============================================================
// TASK STATUS ENUM
// =============================================================

enum TaskStatus { todo, inProgress, completed }

extension TaskStatusExtension on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.todo:
        return 'To Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
    }
  }

  // Values sent to and received from the backend
  String get stringValue {
    switch (this) {
      case TaskStatus.todo:
        return 'pending';
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.completed:
        return 'completed';
    }
  }

  static TaskStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
      case 'todo':
        return TaskStatus.todo;
      case 'in_progress':
      case 'inprogress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      default:
        return TaskStatus.todo;
    }
  }

  bool get isCompleted => this == TaskStatus.completed;
}

// =============================================================
// TASK MODEL
// =============================================================

class Task {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final String? dueTime;
  final Priority priority;
  final TaskStatus status;
  final String? projectId;
  final TaskCategory category;
  final DateTime? completedAt;

  const Task({
    required this.id,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.dueTime,
    required this.priority,
    this.status = TaskStatus.todo,
    this.projectId,
    this.category = TaskCategory.general,
    this.completedAt,
  });

  bool get isCompleted => status.isCompleted;

  bool get isOverdue {
    if (isCompleted) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    // Due date is before today → always overdue
    if (due.isBefore(today)) return true;

    // Due date is today → overdue only if the due time has passed
    if (due.isAtSameMomentAs(today) && dueTime != null && dueTime!.isNotEmpty) {
      final parts = RegExp(r'(\d+):(\d+)\s*(am|pm)?', caseSensitive: false)
          .firstMatch(dueTime!);
      if (parts != null) {
        int hour = int.parse(parts.group(1)!);
        final minute = int.parse(parts.group(2)!);
        final ampm = parts.group(3)?.toLowerCase();
        if (ampm == 'pm' && hour != 12) hour += 12;
        if (ampm == 'am' && hour == 12) hour = 0;
        final dueDateTime = DateTime(now.year, now.month, now.day, hour, minute);
        return now.isAfter(dueDateTime);
      }
    }

    return false;
  }

  String get formattedDueDate =>
      '${dueDate.day}/${dueDate.month}/${dueDate.year}';

  String get fullDueDateTime {
    if (dueTime == null || dueTime!.isEmpty) return formattedDueDate;
    return '$formattedDueDate at $dueTime';
  }

  // =============================================================
  // JSON SERIALIZATION — matches backend field names exactly
  // =============================================================

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String).toLocal()
          : DateTime.now().add(const Duration(days: 1)),
      dueTime: json['due_time'] as String?,
      priority:
          PriorityExtension.fromString(json['priority'] as String? ?? 'medium'),
      status: TaskStatusExtension.fromString(
          json['status'] as String? ?? 'pending'),
      projectId: json['project_id'] as String?,
      category: TaskCategoryExtension.fromString(
          json['category'] as String? ?? 'general'),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description.isEmpty ? null : description,
        'due_date': dueDate.toIso8601String(),
        'due_time': dueTime,
        'priority': priority.stringValue,
        'status': status.stringValue,
        'project_id': projectId,
        'category': category.stringValue,
      };

  // =============================================================
  // IMMUTABLE UPDATES
  // =============================================================

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    String? dueTime,
    Priority? priority,
    TaskStatus? status,
    String? projectId,
    TaskCategory? category,
    DateTime? completedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      projectId: projectId ?? this.projectId,
      category: category ?? this.category,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

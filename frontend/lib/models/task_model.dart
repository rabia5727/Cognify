// ═══════════════════════════════════════════════════════════════════
// FILE: lib/models/task.dart
// PURPOSE: Task model with type-safe enums and immutable data
//          Backend-ready with JSON serialization
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// =============================================================
// PRIORITY ENUM
// =============================================================

enum Priority {
  high,
  medium,
  low,
}

// =============================================================
// TASK CATEGORY ENUM
// =============================================================

enum TaskCategory {
  general,
  email, // ✅ Added
  classroom, // ✅ Added
  freelance, // Keep for existing tasks
  academic, // Keep for existing tasks
}

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

  /// API-compatible string value
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

  /// Color for UI display
  Color get color {
    switch (this) {
      case TaskCategory.academic:
        return const Color(0xFF1360E2);
      case TaskCategory.freelance:
        return const Color(0xFF7B61FF);
      case TaskCategory.email:
        return const Color(0xFF7B61FF); // Purple for email
      case TaskCategory.classroom:
        return const Color(0xFF1360E2); // Blue for classroom
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

extension PriorityExtension on Priority {
  /// User-friendly display text
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

  /// API-compatible string value
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

  /// Color for UI display
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

  /// Converts API string to Priority enum
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
// TASK STATUS ENUM
// =============================================================

enum TaskStatus {
  todo,
  inProgress,
  completed,
}

extension TaskStatusExtension on TaskStatus {
  /// User-friendly display text
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

  /// API-compatible string value
  String get stringValue {
    switch (this) {
      case TaskStatus.todo:
        return 'todo';
      case TaskStatus.inProgress:
        return 'inProgress';
      case TaskStatus.completed:
        return 'completed';
    }
  }

  /// Converts API string to TaskStatus enum
  static TaskStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'todo':
        return TaskStatus.todo;
      case 'inprogress':
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      default:
        return TaskStatus.todo;
    }
  }

  /// True if status is completed
  bool get isCompleted => this == TaskStatus.completed;
}

// =============================================================
// TASK MODEL
// =============================================================

class Task {
  final String id;
  final String title;
  final String subtitle;
  final DateTime dueDate;
  final String? dueTime; // UI-friendly time string, e.g., "10:00pm"
  final Priority priority;
  final TaskStatus status;
  final String? projectId; // Optional link to parent project
  final TaskCategory category; // Context/source: email, classroom, general

  const Task({
    required this.id,
    required this.title,
    this.subtitle = '',
    required this.dueDate,
    this.dueTime,
    required this.priority,
    this.status = TaskStatus.todo,
    this.projectId,
    this.category = TaskCategory.general,
  });

  // =============================================================
  // HELPER METHODS (UI-Friendly)
  // =============================================================

  /// True if task is completed
  bool get isCompleted => status.isCompleted;

  /// True if due date has passed and task not completed
  bool get isOverdue {
    if (isCompleted) return false;
    return dueDate.isBefore(DateTime.now());
  }

  /// Simple date formatter: DD/MM/YYYY
  String get formattedDueDate {
    return '${dueDate.day}/${dueDate.month}/${dueDate.year}';
  }

  /// Full due date with time if available
  String get fullDueDateTime {
    if (dueTime == null || dueTime!.isEmpty) return formattedDueDate;
    return '$formattedDueDate at $dueTime';
  }

  // =============================================================
  // JSON SERIALIZATION (Backend Ready)
  // =============================================================

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      subtitle: json['subtitle'] ?? '',
      dueDate: DateTime.parse(json['dueDate']),
      dueTime: json['dueTime'],
      priority: PriorityExtension.fromString(json['priority']),
      status: TaskStatusExtension.fromString(json['status'] ?? 'todo'),
      projectId: json['projectId'],
      category: TaskCategoryExtension.fromString(json['category'] ?? 'general'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'dueDate': dueDate.toIso8601String(),
        'dueTime': dueTime,
        'priority': priority.stringValue,
        'status': status.stringValue,
        'projectId': projectId,
        'category': category.stringValue,
      };

  // =============================================================
  // IMMUTABLE UPDATES
  // =============================================================

  /// Creates a copy with optional updated fields
  Task copyWith({
    String? id,
    String? title,
    String? subtitle,
    DateTime? dueDate,
    String? dueTime,
    Priority? priority,
    TaskStatus? status,
    String? projectId,
    TaskCategory? category,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      projectId: projectId ?? this.projectId,
      category: category ?? this.category,
    );
  }
}

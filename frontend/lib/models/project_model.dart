// ═══════════════════════════════════════════════════════════════════
// FILE: lib/models/project.dart
// PURPOSE: Project model with immutable data and helper methods
//          Stores only task IDs for scalability (prevents loading all tasks)
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'task_model.dart';

// =============================================================
// PROJECT STATUS ENUM
// =============================================================

enum ProjectStatus {
  active,
  onHold,
  completed,
  archived,
}

extension ProjectStatusExtension on ProjectStatus {
  /// User-friendly display text
  String get label {
    switch (this) {
      case ProjectStatus.active:
        return 'Active';
      case ProjectStatus.onHold:
        return 'On Hold';
      case ProjectStatus.completed:
        return 'Completed';
      case ProjectStatus.archived:
        return 'Archived';
    }
  }

  /// API-compatible string value
  String get stringValue {
    switch (this) {
      case ProjectStatus.active:
        return 'active';
      case ProjectStatus.onHold:
        return 'onHold';
      case ProjectStatus.completed:
        return 'completed';
      case ProjectStatus.archived:
        return 'archived';
    }
  }

  /// Converts API string to enum
  static ProjectStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return ProjectStatus.active;
      case 'onhold':
      case 'on_hold':
        return ProjectStatus.onHold;
      case 'completed':
        return ProjectStatus.completed;
      case 'archived':
        return ProjectStatus.archived;
      default:
        return ProjectStatus.active;
    }
  }
}

// =============================================================
// PROJECT CATEGORY ENUM
// =============================================================

enum ProjectCategory {
  general,
  academic,
  freelance,
}

extension ProjectCategoryExtension on ProjectCategory {
  /// User-friendly display text
  String get label {
    switch (this) {
      case ProjectCategory.general:
        return 'General';
      case ProjectCategory.academic:
        return 'Academic';
      case ProjectCategory.freelance:
        return 'Freelance';
    }
  }

  /// API-compatible string value
  String get stringValue {
    switch (this) {
      case ProjectCategory.general:
        return 'general';
      case ProjectCategory.academic:
        return 'academic';
      case ProjectCategory.freelance:
        return 'freelance';
    }
  }

  /// Color for UI display
  Color get color {
    switch (this) {
      case ProjectCategory.academic:
        return const Color(0xFF1360E2);
      case ProjectCategory.freelance:
        return const Color(0xFF7B61FF);
      case ProjectCategory.general:
        return const Color(0xFF9E9E9E);
    }
  }

  /// Converts API string to enum
  static ProjectCategory fromString(String value) {
    switch (value.toLowerCase()) {
      case 'academic':
        return ProjectCategory.academic;
      case 'freelance':
        return ProjectCategory.freelance;
      default:
        return ProjectCategory.general;
    }
  }
}

// =============================================================
// PROJECT MODEL
// =============================================================

class Project {
  final String id;
  final String title;
  final String description;
  final List<String> taskIds; // Stores only IDs for scalability
  final DateTime dueDate;
  final Priority priority;
  final ProjectStatus status;
  final ProjectCategory category; // NEW: Category field
  final int? colorValue; // Hex value, not Color object (UI layer converts)

  const Project({
    required this.id,
    required this.title,
    this.description = '',
    required this.taskIds,
    required this.dueDate,
    required this.priority,
    this.status = ProjectStatus.active,
    this.category = ProjectCategory.general, // NEW: Default to general
    this.colorValue,
  });

  // =============================================================
  // HELPER METHODS (Pure Dart, UI-friendly)
  // =============================================================

  /// True if project status is completed
  bool get isCompleted => status == ProjectStatus.completed;

  /// True if due date has passed and project not completed
  bool get isOverdue {
    if (isCompleted) return false;

    final now = DateTime.now();
    final dueDateTime = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      23,
      59,
      59,
    );

    return now.isAfter(dueDateTime);
  }

  /// Simple date formatter: DD/MM/YYYY
  String get formattedDueDate {
    return '${dueDate.day}/${dueDate.month}/${dueDate.year}';
  }

  /// User-friendly due date text: "Due Today", "Due Tomorrow", "Overdue", etc.
  String get dueDateDisplay {
    final now = DateTime.now();
    final dueDateTime = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final todayDateTime = DateTime(now.year, now.month, now.day);

    final difference = dueDateTime.difference(todayDateTime).inDays;

    if (difference < 0) return 'Overdue';
    if (difference == 0) return 'Due Today';
    if (difference == 1) return 'Due Tomorrow';
    return 'Due $formattedDueDate';
  }

  // =============================================================
  // JSON SERIALIZATION (Backend Ready)
  // =============================================================

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      taskIds:
          (json['taskIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      dueDate: DateTime.tryParse(json['dueDate'] ?? '') ?? DateTime.now(),
      priority: PriorityExtension.fromString(json['priority'] ?? 'medium'),
      status: ProjectStatusExtension.fromString(json['status'] ?? 'active'),
      category: ProjectCategoryExtension.fromString(
          json['category'] ?? 'general'), // NEW
      colorValue: json['color'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'taskIds': taskIds,
        'dueDate': dueDate.toIso8601String(),
        'priority': priority.stringValue,
        'status': status.stringValue,
        'category': category.stringValue, // NEW
        'color': colorValue,
      };

  // =============================================================
  // EQUALITY (For State Management)
  // =============================================================

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  // =============================================================
  // IMMUTABLE UPDATES
  // =============================================================

  /// Creates a copy with optional updated fields
  Project copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? taskIds,
    DateTime? dueDate,
    Priority? priority,
    ProjectStatus? status,
    ProjectCategory? category, // NEW
    int? colorValue,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      taskIds: taskIds ?? this.taskIds,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      category: category ?? this.category, // NEW
      colorValue: colorValue ?? this.colorValue,
    );
  }
}

import 'package:flutter/material.dart';
import 'task_model.dart';

// =============================================================
// PROJECT STATUS ENUM
// =============================================================

enum ProjectStatus {
  active,
  completed,
}

extension ProjectStatusExtension on ProjectStatus {
  String get label {
    switch (this) {
      case ProjectStatus.active:
        return 'Active';
      case ProjectStatus.completed:
        return 'Completed';
    }
  }

  String get stringValue {
    switch (this) {
      case ProjectStatus.active:
        return 'active';
      case ProjectStatus.completed:
        return 'completed';
    }
  }

  static ProjectStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'completed':
        return ProjectStatus.completed;
      default:
        return ProjectStatus.active;
    }
  }
}

// =============================================================
// PROJECT CATEGORY ENUM
// =============================================================

enum ProjectCategory {
  academic,
  freelance,
  personal,
}

extension ProjectCategoryExtension on ProjectCategory {
  String get label {
    switch (this) {
      case ProjectCategory.academic:
        return 'Academic';
      case ProjectCategory.freelance:
        return 'Freelance';
      case ProjectCategory.personal:
        return 'Personal';
    }
  }

  String get stringValue {
    switch (this) {
      case ProjectCategory.academic:
        return 'academic';
      case ProjectCategory.freelance:
        return 'freelance';
      case ProjectCategory.personal:
        return 'personal';
    }
  }

  Color get color {
    switch (this) {
      case ProjectCategory.academic:
        return const Color(0xFF1360E2);
      case ProjectCategory.freelance:
        return const Color(0xFF7B61FF);
      case ProjectCategory.personal:
        return const Color(0xFF26A69A);
    }
  }

  static ProjectCategory fromString(String value) {
    switch (value.toLowerCase()) {
      case 'academic':
        return ProjectCategory.academic;
      case 'freelance':
        return ProjectCategory.freelance;
      case 'personal':
        return ProjectCategory.personal;
      default:
        return ProjectCategory.academic;
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
  final List<String> taskIds;
  final DateTime dueDate;
  final Priority priority;
  final ProjectStatus status;
  final ProjectCategory category;

  const Project({
    required this.id,
    required this.title,
    this.description = '',
    required this.taskIds,
    required this.dueDate,
    required this.priority,
    this.status = ProjectStatus.active,
    this.category = ProjectCategory.academic,
  });

  bool get isCompleted => status == ProjectStatus.completed;

  bool get isOverdue {
    if (isCompleted) return false;
    final now = DateTime.now();
    final dueDateTime = DateTime(dueDate.year, dueDate.month, dueDate.day, 23, 59, 59);
    return now.isAfter(dueDateTime);
  }

  String get formattedDueDate {
    return '${dueDate.day}/${dueDate.month}/${dueDate.year}';
  }

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

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      taskIds: (json['task_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      dueDate: DateTime.tryParse(json['due_date'] ?? '') ?? DateTime.now(),
      priority: PriorityExtension.fromString(json['priority'] ?? 'medium'),
      status: ProjectStatusExtension.fromString(json['status'] ?? 'active'),
      category: ProjectCategoryExtension.fromString(json['category'] ?? 'academic'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'task_ids': taskIds,
        'due_date': dueDate.toIso8601String(),
        'priority': priority.stringValue,
        'status': status.stringValue,
        'category': category.stringValue,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  Project copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? taskIds,
    DateTime? dueDate,
    Priority? priority,
    ProjectStatus? status,
    ProjectCategory? category,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      taskIds: taskIds ?? this.taskIds,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      category: category ?? this.category,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FILE: lib/widgets/priority_badge.dart
// WHY: The priority badge (colored pill showing High/Medium/Low)
//      was built manually with a Container in both:
//        - dashboard_screen.dart (_TaskCard)
//        - tasks_screen.dart     (_TaskRow + _ProjectCard)
//      Now it's one widget used everywhere.
//
// USAGE:
//   PriorityBadge(priority: Priority.high)
//   PriorityBadge(priority: task.priority)
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../constants/app_constant.dart';
import '../../models/task_model.dart'; // Import for Priority enum

class PriorityBadge extends StatelessWidget {
  final Priority priority;
  final bool showLabel;
  final double fontSize;

  const PriorityBadge({
    super.key,
    required this.priority,
    this.showLabel = true,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppConstants.priorityColorFromEnum(priority);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        showLabel ? priority.label : '',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

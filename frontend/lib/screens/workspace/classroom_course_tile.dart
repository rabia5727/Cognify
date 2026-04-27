// Purpose: Reusable widget for each course row
// Features:
//   - Course name and section
//   - Toggle switch (enabled/disabled for sync)
//   - Archive button (hide completed courses)
//   - Assignment count badge
//   - Last sync timestamp
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ClassroomCourseTile extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback onToggle;
  final VoidCallback onArchive;
  final bool isEnabled;

  const ClassroomCourseTile({
    super.key,
    required this.course,
    required this.onToggle,
    required this.onArchive,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(
              course['name'] ?? 'Unnamed Course',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (course['section'] != null)
                  Text('Section: ${course['section']}'),
                if (course['teacher'] != null)
                  Text('Teacher: ${course['teacher']}'),
                if (course['last_sync'] != null)
                  Text(
                    // ✅ Fix: parse string to DateTime first
                    'Last sync: ${_formatDate(course['last_sync'])}',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
            value: isEnabled,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.primaryBlue,
          ),
          if (course['assignment_count'] != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.assignment, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${course['assignment_count']} pending assignments',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onArchive,
                    child: const Text('Archive'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ✅ Fix: accepts dynamic (String or DateTime)
  String _formatDate(dynamic date) {
    if (date == null) return 'Never';
    try {
      final parsed = date is String ? DateTime.parse(date) : date as DateTime;
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}
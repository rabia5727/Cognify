import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ClassroomEmptyState extends StatelessWidget {
  final VoidCallback onConnect;
  final bool isConnected;

  const ClassroomEmptyState({
    super.key,
    required this.onConnect,
    this.isConnected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isConnected ? Icons.class_outlined : Icons.class_rounded,
            size: 80,
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            isConnected ? 'No courses found' : 'Connect to Google Classroom',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isConnected 
                ? 'Your connected courses will appear here'
                : 'Sync your Google Classroom to automatically create tasks',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.grayText,
            ),
          ),
          const SizedBox(height: 24),
          if (!isConnected)
            ElevatedButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.login),
              label: const Text('Connect Google Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
              ),
            ),
        ],
      ),
    );
  }
}
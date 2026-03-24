// TODO Implement this library.
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../auth/preference_quiz_screen.dart';

class PermissionScreen extends StatelessWidget {
  final String userName;
  final UserPreferences preferences;

  const PermissionScreen({
    super.key,
    required this.userName,
    required this.preferences,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔔', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            const Text(
              'Permissions',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText),
            ),
            const SizedBox(height: 8),
            const Text(
              'Permission screen coming soon...',
              style: TextStyle(color: AppColors.grayText),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => DashboardScreen(userName: userName),
                  ),
                ),
                child: const Text('Continue to Dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/auth_components.dart';
import '../auth/questionaire/preference_quiz_screen.dart';
import '../home_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class PermissionScreen extends StatelessWidget {
  final String userName;
  final UserPreferences preferences;

  const PermissionScreen({
    super.key,
    required this.userName,
    required this.preferences,
  });

  void _goToDashboard(BuildContext context) {
    // Get auth provider to ensure user is set
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Update user info if needed
    authProvider.updateUserInfo(name: userName);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            const HomeScreen(), // HomeScreen now gets userName from AuthProvider
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back Button ─────────────────────────────────────────────
              _BackButton(),

              const SizedBox(height: 32),

              // ── Mic Icon ────────────────────────────────────────────────
              const _MicIcon(),

              const SizedBox(height: 28),

              // ── Title & Subtitle ─────────────────────────────────────────
              const Center(
                child: Text(
                  'Enable Your Microphone',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    height: 1.3,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: Text(
                  'Co-Tasker needs microphone access to enable\n'
                  'voice commands. We only listen when\n'
                  'voice commands are active.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.grayText,
                    height: 1.6,
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // ── Allow Access Button ──────────────────────────────────────
              PrimaryButton(
                label: 'Allow Access',
                onPressed: () => _goToDashboard(context),
              ),

              const SizedBox(height: 14),

              // ── Not Now Button ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _goToDashboard(context),
                  child: const Text(
                    'Not Now',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.grayText,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Footer Note ──────────────────────────────────────────────
              Center(
                child: Text(
                  'You can change this later in Settings',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.grayText.withOpacity(0.6),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXTRACTED WIDGETS (Specific to permission screen)
// ─────────────────────────────────────────────────────────────────────────────

/// A circular back button that matches the app's blue color scheme.
class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }
}

/// The microphone icon with a gradient background and a subtle outer ring.
class _MicIcon extends StatelessWidget {
  const _MicIcon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer subtle ring
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(32),
            ),
          ),
          // Inner gradient container
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryBlue, AppColors.primaryBlueLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.mic_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

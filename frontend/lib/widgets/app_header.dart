// ═══════════════════════════════════════════════════════════════════
// FILE: lib/widgets/app_header.dart
// WHY: Every screen (settings, tasks, analytics, profile) had its
//      own copy of the top bar with back button + centered title.
//      That's 4 copies of the same 30 lines of code.
//      Now it's one widget used everywhere.
//
// TWO MODES:
//   1. Simple header (all screens except dashboard):
//      AppHeader(title: 'Tasks', onBack: () => onTabSelected(0))
//
//   2. Dashboard header (blue gradient with greeting + AI card):
//      DashboardHeader(...) — separate widget for dashboard only
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../constants/app_constant.dart'; // Import global constants
import 'app_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SIMPLE HEADER — used by Settings, Tasks, Analytics, Profile
// ─────────────────────────────────────────────────────────────────────────────

class AppHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const AppHeader({
    super.key,
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 4),
      child: Row(
        children: [
          // Blue circle back button
          IconButton(
            onPressed: onBack,
            icon: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppConstants.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          // Centered title
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppConstants.darkText,
              ),
            ),
          ),
          // Invisible spacer to keep title truly centered
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD HEADER — the blue gradient header with greeting + AI card
// Used only by dashboard_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

class DashboardHeader extends StatelessWidget {
  final String userName;
  final bool isNewUser;
  final bool showProactiveCard;
  final VoidCallback onYes;
  final VoidCallback onNo;
  final VoidCallback onProfileTap;

  const DashboardHeader({
    super.key,
    required this.userName,
    required this.isNewUser,
    required this.showProactiveCard,
    required this.onYes,
    required this.onNo,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1360E2), Color(0xFF4DA3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: greeting + mascot + avatar ──────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNewUser
                          ? 'Welcome to\nCo-tasker'
                          : '${_getGreeting()},',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    if (!isNewUser)
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  // AI mascot icon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tappable user avatar → goes to profile
                  GestureDetector(
                    onTap: onProfileTap,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── White card inside the blue header ─────────────────────
          AppCard(
            child: isNewUser
                ? const _NewUserMessage()
                : _ReturningUserMessage(
                    showButtons: showProactiveCard,
                    onYes: onYes,
                    onNo: onNo,
                  ),
          ),
        ],
      ),
    );
  }

  // Private helper method for greeting (no external dependency)
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

// ── Greeting message for new users ────────────────────────────────
class _NewUserMessage extends StatelessWidget {
  const _NewUserMessage();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome to Co-tasker',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppConstants.darkText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "I'm here to help you stay organized, motivated, and kind to yourself along the way.",
          style: TextStyle(
            fontSize: 13,
            color: AppConstants.grayText,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ── AI proactive message for returning users ───────────────────────
class _ReturningUserMessage extends StatelessWidget {
  final bool showButtons;
  final VoidCallback onYes;
  final VoidCallback onNo;

  const _ReturningUserMessage({
    required this.showButtons,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppConstants.darkText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'You have a quiz due today. Would you like me to help prepare it?',
          style: TextStyle(
            fontSize: 13,
            color: AppConstants.grayText,
            height: 1.5,
          ),
        ),
        if (showButtons) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onYes,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Yes',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onNo,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.primaryBlue,
                    minimumSize: const Size(0, 40),
                    side: const BorderSide(
                      color: AppConstants.primaryBlue,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'No',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

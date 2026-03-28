// ═══════════════════════════════════════════════════════════════════
// FILE: lib/widgets/voice_fab.dart
// WHY: _VoiceFAB was copy-pasted in:
//        - dashboard_screen.dart
//        - settings_screen.dart
//        - analytics_screen.dart
//      Now it's one widget used by all screens.
//
// USAGE:
//   floatingActionButton: const VoiceFab(),
//   floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../constants/app_constant.dart'; // ← Changed from app_theme

class VoiceFab extends StatelessWidget {
  final VoidCallback? onPressed;

  const VoiceFab({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: FloatingActionButton(
        heroTag: 'voiceFab', // ✅ unique hero tag
        onPressed: onPressed ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice recording coming soon!')),
              );
            },
        backgroundColor: AppConstants.primaryBlue,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 32),
      ),
    );
  }
}

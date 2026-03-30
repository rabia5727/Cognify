import 'package:flutter/material.dart';
import '../constants/app_constant.dart';
import '../screens/assistant//voice_assistant_screen.dart';

class VoiceFab extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? heroTag;

  const VoiceFab({
    super.key,
    this.onPressed,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: FloatingActionButton(
        heroTag: heroTag,
        onPressed: onPressed ??
            () {
              // Navigate to voice assistant screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VoiceAssistantScreen(),
                ),
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

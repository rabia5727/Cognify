import 'package:flutter/material.dart';
import '../../constants/app_constant.dart';
import '../../screens/assistant/assistant_screen.dart';

class AiChatFab extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? heroTag;

  const AiChatFab({
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
        heroTag: heroTag ?? Object(),
        onPressed: onPressed ??
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AssistantScreen(),
                ),
              );
            },
        backgroundColor: AppConstants.primaryBlue,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(
          Icons.auto_awesome_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

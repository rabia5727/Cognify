import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_provider.dart';
import '../../providers/task_provider.dart';
import '../../screens/assistant/assistant_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../theme/app_theme.dart';
import 'app_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SIMPLE HEADER — Settings, Workspace, Analytics, Profile
// ─────────────────────────────────────────────────────────────────────────────

class AppHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final List<Widget>? actions;

  const AppHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 4),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 44, height: 44),
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 72),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: actions != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions!,
                    )
                  : const SizedBox(width: 48),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD HEADER — blue gradient, greeting, AI proactive card
// ─────────────────────────────────────────────────────────────────────────────

class DashboardHeader extends StatelessWidget {
  final String userName;
  final bool isNewUser;
  final bool showProactiveCard;
  final String? dismissedTaskId;
  final VoidCallback onYes;
  final VoidCallback onNo;
  final VoidCallback onProfileTap;

  const DashboardHeader({
    super.key,
    required this.userName,
    required this.isNewUser,
    required this.showProactiveCard,
    this.dismissedTaskId,
    required this.onYes,
    required this.onNo,
    required this.onProfileTap,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          // ── Top bar: notification + profile ──────────────────────
          Row(
            children: [
              const Spacer(),
              Consumer<NotificationProvider>(
                builder: (context, provider, _) => GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      if (provider.unreadCount > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              provider.unreadCount > 9
                                  ? '9+'
                                  : '${provider.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
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
          const SizedBox(height: 10),
          // ── Greeting row with robot mascot ────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNewUser ? 'Welcome to\nCOGNIFY,' : '${_getGreeting()},',
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
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 38)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppCard(
            backgroundColor: isDark ? AppColors.darkSurface3 : Colors.white,
            child: isNewUser
                ? const _NewUserMessage()
                : Consumer<TaskProvider>(
                    builder: (context, taskProvider, _) {
                      // Build proactive message from REAL task data
                      final proactiveMessage = _buildProactiveMessage(
                        taskProvider,
                        dismissedTaskId,
                      );
                      return _ReturningUserMessage(
                        message: proactiveMessage.message,
                        ctaMessage: proactiveMessage.ctaMessage,
                        showButtons:
                            showProactiveCard && proactiveMessage.hasAction,
                        onYes: onYes,
                        onNo: onNo,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Builds a proactive message based on real task data.
  /// Priority: overdue > due today > high priority > general
  _ProactiveMessage _buildProactiveMessage(
    TaskProvider taskProvider,
    String? dismissedTaskId,
  ) {
    final now = DateTime.now();
    final tasks =
        taskProvider.tasks.where((task) => task.id != dismissedTaskId).toList();

    if (tasks.isEmpty) {
      return _ProactiveMessage(
        message: "You're all caught up! Add a task to get started.",
        ctaMessage: null,
        hasAction: false,
      );
    }

    // Check overdue tasks first
    final overdue = tasks.where((t) {
      if (t.isCompleted) return false;
      return t.dueDate.isBefore(DateTime(now.year, now.month, now.day));
    }).toList();

    if (overdue.isNotEmpty) {
      final task = overdue.first;
      return _ProactiveMessage(
        message:
            '"${task.title}" is overdue. Want CoCo to help you tackle it now?',
        ctaMessage: task.title,
        hasAction: true,
      );
    }

    // Check tasks due today
    final dueToday = tasks.where((t) {
      if (t.isCompleted) return false;
      return t.dueDate.year == now.year &&
          t.dueDate.month == now.month &&
          t.dueDate.day == now.day;
    }).toList();

    if (dueToday.isNotEmpty) {
      final task = dueToday.first;
      return _ProactiveMessage(
        message:
            '"${task.title}" is due today. Would you like CoCo to help you prepare?',
        ctaMessage: task.title,
        hasAction: true,
      );
    }

    // Check high priority tasks
    final highPriority = tasks
        .where((t) => !t.isCompleted && t.priority.name == 'high')
        .toList();

    if (highPriority.isNotEmpty) {
      final task = highPriority.first;
      return _ProactiveMessage(
        message:
            '"${task.title}" is high priority. Want help breaking it down?',
        ctaMessage: task.title,
        hasAction: true,
      );
    }

    // General — show pending count
    final pending = tasks.where((t) => !t.isCompleted).length;
    return _ProactiveMessage(
      message:
          'You have $pending pending task${pending == 1 ? '' : 's'}. Want CoCo to help prioritize?',
      ctaMessage: null,
      hasAction: true,
    );
  }
}

/// Simple data class for proactive card content
class _ProactiveMessage {
  final String message;
  final String? ctaMessage; // task title to pre-fill in assistant
  final bool hasAction;

  const _ProactiveMessage({
    required this.message,
    required this.ctaMessage,
    required this.hasAction,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVATE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _NewUserMessage extends StatelessWidget {
  const _NewUserMessage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to COGNIFY',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "I'm here to help you stay organized, motivated, and kind to yourself along the way.",
          style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

class _ReturningUserMessage extends StatelessWidget {
  final String message;
  final String? ctaMessage;
  final bool showButtons;
  final VoidCallback onYes;
  final VoidCallback onNo;

  const _ReturningUserMessage({
    required this.message,
    required this.ctaMessage,
    required this.showButtons,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome Back',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        // FIXED: shows real task-based message, not hardcoded text
        Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
        ),
        if (showButtons) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    onYes(); // hide card
                    // FIXED: navigate to assistant and pre-fill message
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AssistantScreen(
                          // Pass the task title as initial message
                          // so CoCo knows exactly what to help with
                          initialMessage: ctaMessage != null
                              ? 'Help me with: $ctaMessage'
                              : null,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
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
                    foregroundColor: theme.colorScheme.primary,
                    minimumSize: const Size(0, 40),
                    side: BorderSide(
                      color: theme.colorScheme.primary,
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

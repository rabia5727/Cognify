import 'package:flutter/material.dart';
import '../../providers/notification_provider.dart';
import 'package:provider/provider.dart';

Future<void> showNotificationPermissionSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => const _NotificationPermissionSheet(),
  );
}

class _NotificationPermissionSheet extends StatelessWidget {
  const _NotificationPermissionSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BellIcon(color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Allow Notification Access',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Turn on notifications to receive reminders about your tasks.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                final provider = context.read<NotificationProvider>();
                final nav = Navigator.of(context);
                await provider.markPermissionAsked();
                await provider.setEnabled(true);
                nav.pop();
                provider.refreshUnreadCount();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () async {
                final provider = context.read<NotificationProvider>();
                final nav = Navigator.of(context);
                await provider.markPermissionAsked();
                await provider.setEnabled(false);
                nav.pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: theme.textTheme.bodySmall?.color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'No Thanks',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BellIcon extends StatelessWidget {
  final Color color;
  const _BellIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.notifications_rounded,
              size: 78,
              color: color.withValues(alpha: 0.15),
            ),
          ),
          Center(
            child: Icon(
              Icons.notifications_rounded,
              size: 62,
              color: color.withValues(alpha: 0.5),
            ),
          ),
          Positioned(
            top: 6,
            right: 10,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

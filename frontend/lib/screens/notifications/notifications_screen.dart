import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification_model.dart';
import '../../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().refreshAndFetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
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
                  Expanded(
                    child: Text(
                      'Notifications',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  // Mark all read
                  Consumer<NotificationProvider>(
                    builder: (_, provider, __) {
                      if (provider.unreadCount == 0) return const SizedBox(width: 48);
                      return TextButton(
                        onPressed: provider.markAllRead,
                        child: Text(
                          'Mark all read',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── List ────────────────────────────────────────────────────
            Expanded(
              child: Consumer<NotificationProvider>(
                builder: (_, provider, __) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (provider.notifications.isEmpty) {
                    return _EmptyState();
                  }
                  return RefreshIndicator(
                    onRefresh: provider.refreshAndFetch,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: provider.notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _NotificationTile(
                        notification: provider.notifications[i],
                        onTap: () => provider.deleteNotification(
                          provider.notifications[i].id,
                        ),
                        onDelete: () => provider.deleteNotification(
                          provider.notifications[i].id,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notification tile ─────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  IconData get _icon {
    switch (notification.type) {
      case 'reminder':   return Icons.alarm_rounded;
      case 'due_soon':   return Icons.schedule_rounded;
      case 'overdue':    return Icons.warning_amber_rounded;
      case 'achievement': return Icons.emoji_events_rounded;
      default:           return Icons.notifications_rounded;
    }
  }

  Color _iconColor(BuildContext context) {
    switch (notification.type) {
      case 'overdue':    return Colors.red;
      case 'due_soon':   return AppColors.orange;
      case 'achievement': return Colors.green;
      default:           return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isUnread
                ? theme.colorScheme.primary.withValues(alpha: 0.06)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnread
                  ? theme.colorScheme.primary.withValues(alpha: 0.2)
                  : theme.dividerColor,
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _iconColor(context).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 20, color: _iconColor(context)),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.45,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 11,
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _timeAgo(notification.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 64, color: theme.dividerColor),
          const SizedBox(height: 16),
          Text('No notifications yet',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            'We\'ll alert you when tasks are due\nor you earn an achievement.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

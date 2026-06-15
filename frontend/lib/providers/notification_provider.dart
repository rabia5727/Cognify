import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  List<AppNotification> _upcomingReminders = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;
  bool _enabled = false;
  String? _userId;
  bool _isMarkingPermission = false;

  // Pagination state
  int _totalNotifications = 0;
  int _totalPages = 1;
  int _currentPage = 1;

  // ── Getters ───────────────────────────────────────────────────────────────

  List<AppNotification> get notifications => _notifications;
  List<AppNotification> get upcomingReminders => _upcomingReminders;
  int get unreadCount => _enabled ? _unreadCount : 0;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEnabled => _enabled;

  // Pagination getters
  int get totalNotifications => _totalNotifications;
  int get totalPages => _totalPages;
  int get currentPage => _currentPage;
  bool get hasMorePages => _currentPage < _totalPages;

  void setCurrentUser(String userId) {
    _userId = userId;
  }

  Future<bool> hasAskedPermission() async {
    if (_userId == null || _userId!.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notification_permission_asked_$_userId') ?? false;
  }

  Future<void> markPermissionAsked() async {
    // Prevent multiple simultaneous calls
    if (_isMarkingPermission) {
      print('⚠️ Already marking permission, skipping duplicate');
      return;
    }

    _isMarkingPermission = true;

    try {
      if (_userId == null || _userId!.isEmpty) {
        print('⚠️ Cannot mark permission: userId is null or empty');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_permission_asked_$_userId', true);
      print('✅ Permission marked as asked for user: $_userId');
    } catch (e) {
      print('❌ Error marking permission: $e');
    } finally {
      _isMarkingPermission = false;
    }
  }
  // ── Enable / disable notifications ───────────────────────────────────────

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    await UserService.updatePreferences(notificationsEnabled: value);
    if (value) {
      await refreshAndFetch();
    } else {
      notifyListeners();
    }
  }

  Future<void> loadEnabledState() async {
    // Try backend first (authoritative across devices)
    final profile = await UserService.getProfile();
    if (profile != null && profile['preferences'] != null) {
      _enabled = profile['preferences']['notifications_enabled'] ?? true;
    } else {
      // Fall back to local cache
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool('notifications_enabled') ?? true;
    }
    // Keep local cache in sync
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _enabled);
    notifyListeners();
  }

  // ── Refresh proactive notifications then fetch ────────────────────────────

  Future<void> refreshAndFetch() async {
    await NotificationService.refresh();
    await fetchNotifications();
  }

  // ── Fetch all notifications ───────────────────────────────────────────────

  Future<void> fetchNotifications({
    bool unreadOnly = false,
    int page = 1,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await NotificationService.getNotifications(
      unreadOnly: unreadOnly,
      page: page,
    );

    if (result.isSuccess) {
      _notifications = result.data!;
      _unreadCount = _notifications.where((n) => !n.isRead).length;

      // Store pagination metadata
      _totalNotifications = result.total;
      _totalPages = result.totalPages;
      _currentPage = result.page;

      _error = null;
    } else {
      _error = result.error;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load next page and append to existing list
  // REPLACE fetchNextPage() — currently calls fetchNotifications which overwrites list

  Future<void> fetchNextPage() async {
    if (!hasMorePages || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    final result = await NotificationService.getNotifications(
      page: _currentPage + 1,
    );

    if (result.isSuccess) {
      // APPEND to existing list instead of replacing
      _notifications.addAll(result.data!);

      // Update unread count from newly added items only
      _unreadCount += result.data!.where((n) => !n.isRead).length;

      // Update pagination state
      _totalNotifications = result.total;
      _totalPages = result.totalPages;
      _currentPage = result.page;

      _error = null;
    } else {
      _error = result.error;
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Refresh unread count only ─────────────────────────────────────────────

  Future<void> refreshUnreadCount() async {
    _unreadCount = await NotificationService.getUnreadCount();
    notifyListeners();
  }

  // ── Fetch upcoming reminders ──────────────────────────────────────────────

  Future<void> fetchUpcomingReminders({int hoursAhead = 24}) async {
    final result = await NotificationService.getUpcomingReminders(
      hoursAhead: hoursAhead,
    );
    if (result.isSuccess) {
      _upcomingReminders = result.data!;
      notifyListeners();
    }
  }

  // ── Create notification / reminder ────────────────────────────────────────

  Future<String?> createNotification({
    required String title,
    required String message,
    String type = 'general',
    String? taskId,
    DateTime? remindAt,
  }) async {
    final result = await NotificationService.createNotification(
      title: title,
      message: message,
      type: type,
      taskId: taskId,
      remindAt: remindAt,
    );
    if (result.isSuccess) {
      _notifications.insert(0, result.data!.first);
      _unreadCount++;
      _totalNotifications++;
      notifyListeners();
      return null;
    }
    return result.error;
  }

  // ── Mark one as read ──────────────────────────────────────────────────────

  Future<void> markAsRead(String id) async {
    final success = await NotificationService.markAsRead(id);
    if (success) {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
        notifyListeners();
      }
    }
  }

  // ── Mark all as read ──────────────────────────────────────────────────────

  Future<void> markAllRead() async {
    final success = await NotificationService.markAllRead();
    if (success) {
      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _unreadCount = 0;
      notifyListeners();
    }
  }

  // ── Delete one ────────────────────────────────────────────────────────────

  Future<void> deleteNotification(String id) async {
    final success = await NotificationService.deleteNotification(id);
    if (success) {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        if (!_notifications[index].isRead) {
          _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
        }
        _notifications.removeAt(index);
        _totalNotifications =
            (_totalNotifications - 1).clamp(0, _totalNotifications);
        notifyListeners();
      }
    }
  }

  // ── Batch delete ──────────────────────────────────────────────────────────

  Future<void> deleteMultipleNotifications(List<String> ids) async {
    final success = await NotificationService.deleteMultiple(ids);
    if (success) {
      int removedUnread = 0;
      for (final id in ids) {
        final index = _notifications.indexWhere((n) => n.id == id);
        if (index != -1) {
          if (!_notifications[index].isRead) removedUnread++;
          _notifications.removeAt(index);
        }
      }
      _unreadCount = (_unreadCount - removedUnread).clamp(0, _unreadCount);
      _totalNotifications =
          (_totalNotifications - ids.length).clamp(0, _totalNotifications);
      notifyListeners();
    }
  }

  // ── Batch mark as read ────────────────────────────────────────────────────

  Future<void> markMultipleAsRead(List<String> ids) async {
    final success = await NotificationService.markMultipleAsRead(ids);
    if (success) {
      for (final id in ids) {
        final index = _notifications.indexWhere((n) => n.id == id);
        if (index != -1 && !_notifications[index].isRead) {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
          _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
        }
      }
      notifyListeners();
    }
  }

  // ── Snooze reminder ───────────────────────────────────────────────────────

  Future<bool> snoozeReminder(String id, int minutes) async {
    final success =
        await NotificationService.snoozeReminder(id, minutes: minutes);
    if (success) {
      await fetchNotifications();
      return true;
    }
    return false;
  }

  // ── Error recovery ────────────────────────────────────────────────────────

  Future<void> retryLastAction() async {
    _error = null;
    notifyListeners();
    await fetchNotifications();
  }

  // ── Clear local state (call on logout) ───────────────────────────────────

  void clearLocalNotifications() {
    _notifications.clear();
    _upcomingReminders.clear();
    _unreadCount = 0;
    _totalNotifications = 0;
    _totalPages = 1;
    _currentPage = 1;
    _error = null;
    _userId = null;
    notifyListeners();
  }
}

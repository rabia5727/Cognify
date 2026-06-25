// Purpose: State management for Gmail data
// State:
//   - List of emails with sync status
//   - Currently syncing flag
//   - Connection status
//   - Last sync time
// Methods:
//   - loadEmails()
//   - syncEmails()
//   - createTaskFromEmail()
//   - archiveEmail()
//   - checkConnection()
//   - connectGmail()
//   - autoSync() - Auto-sync for background
//   - syncNow() - Force immediate sync

import 'package:flutter/material.dart';

import '../services/gmail_service.dart';

class GmailProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _emails = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isConnected = false;
  DateTime? _lastSyncTime;

  List<Map<String, dynamic>> get emails => _emails;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isConnected => _isConnected;
  DateTime? get lastSyncTime => _lastSyncTime;

  // Load emails from database
  Future<void> loadEmails() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await GmailService.getEmails();
      //cast the list properly
      _emails = List<Map<String, dynamic>>.from(result['emails'] ?? []);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Check connection status
  Future<void> checkConnection() async {
    try {
      final result = await GmailService.getHealth();
      _isConnected = result['connected'] ?? false;
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      notifyListeners();
    }
  }

  // Sync emails from Gmail
  Future<void> syncEmails() async {
    // Don't sync if not connected
    if (!_isConnected) {
      print('⚠️ Gmail not connected, skipping sync');
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final result = await GmailService.syncEmails();
      _lastSyncTime = DateTime.now();
      await loadEmails();
      _isSyncing = false;
      notifyListeners();

      if (result['tasks_created'] > 0) {
        print('📧 Created ${result['tasks_created']} tasks from emails');
      }
    } catch (e) {
      _isSyncing = false;
      notifyListeners();
      rethrow;
    }
  }

  // ✅ NEW: Auto-sync for background (called by SyncService)
  Future<void> autoSync() async {
    if (!_isConnected) return;
    print('🔄 GmailProvider: Auto-sync triggered');
    await syncEmails();
  }

  // ✅ NEW: Force immediate sync (for pull-to-refresh)
  Future<void> syncNow() async {
    print('🔄 GmailProvider: Manual sync triggered');
    await syncEmails();
  }

  // Create task from email
  Future<void> createTaskFromEmail({
    required String emailId,
    required String title,
    String? description,
    String priority = 'medium',
    String category = 'email',
    DateTime? dueDate,
  }) async {
    try {
      await GmailService.createTaskFromEmail(
        emailId: emailId,
        title: title,
        description: description,
        priority: priority,
        category: category,
        dueDate: dueDate,
      );

      final index = _emails.indexWhere((e) => e['email_id'] == emailId);
      if (index != -1) {
        _emails[index]['is_task_created'] = true;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  // Archive email
  Future<void> archiveEmail(String emailId) async {
    try {
      await GmailService.archiveEmail(emailId);

      _emails.removeWhere((e) => e['email_id'] == emailId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // Mark email as read
  Future<void> markEmailRead(String emailId) async {
    try {
      await GmailService.markEmailRead(emailId);

      final index = _emails.indexWhere((e) => e['email_id'] == emailId);
      if (index != -1) {
        _emails[index]['is_read'] = true;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get OAuth URL
  Future<Map<String, String>> getOAuthUrl() async {
    return await GmailService.getMobileAuthUrl();
  }

  // Connect Gmail account
  Future<void> connectGmail() async {
    await checkConnection();
    if (_isConnected) {
      await loadEmails();
    }
  }

  // Disconnect Gmail
  Future<void> disconnectGmail() async {
    try {
      await GmailService.disconnect();
      _isConnected = false;
      _emails = [];
      _lastSyncTime = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // ─── Getters ──────────────────────────────────────────────────────

  List<Map<String, dynamic>> get actionableEmails {
    return _emails.where((e) => e['is_actionable'] == true).toList();
  }

  List<Map<String, dynamic>> get pendingEmails {
    return _emails.where((e) => e['is_task_created'] != true).toList();
  }

  int get actionableCount => actionableEmails.length;
  int get pendingCount => pendingEmails.length;
}

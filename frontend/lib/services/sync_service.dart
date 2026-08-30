import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/classroom_provider.dart';
import '../providers/gmail_provider.dart';
import '../screens/auth/auth_screen.dart';
import 'api_service.dart';
import 'token_storage.dart';

class SyncService {
  static Timer? _syncTimer;
  static bool _isSyncing = false;
  static bool _handlingExpiredSession = false;

  // The backend's own login-session JWT expired (see ACCESS_TOKEN_EXPIRE_MINUTES
  // in backend/.env) — not a Google token. Every authenticated call fails
  // identically until the user logs in again, so there's no point retrying
  // this every 10 seconds forever; log out and send them back to the login
  // screen instead of spamming the backend with a dead token.
  static bool _isSessionExpired(Object error) {
    final msg = error.toString();
    return msg.contains('Invalid or expired token') || msg.contains('401');
  }

  static Future<void> _handleExpiredSession() async {
    if (_handlingExpiredSession) return;
    _handlingExpiredSession = true;

    stopAutoSync();
    await TokenStorage.clearAll();
    ApiService.navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  static void startAutoSync(BuildContext context) {
    _syncTimer?.cancel();
    _handlingExpiredSession = false; // fresh login session — arm expiry handling again

    // Run immediately
    _performSync(context);

    // Then every 10 seconds
    _syncTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _performSync(context),
    );

    print('🔄 Auto-sync started (every 10 seconds)');
  }

  static void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    print('🔄 Auto-sync stopped');
  }

  static Future<void> _performSync(BuildContext context) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      print('🔄 Running auto-sync at ${DateTime.now()}');

      // ──────────────────────────────────────────────────────────
      // 1. SYNC CLASSROOM ASSIGNMENTS
      // ──────────────────────────────────────────────────────────
      try {
        final classroomProvider = context.read<ClassroomProvider>();
        await classroomProvider.loadCourses();

        if (classroomProvider.enabledCoursesCount > 0) {
          final result = await classroomProvider.syncAllAssignments(context);
          if (result['new_tasks_count'] > 0) {
            print(
                '📚 Classroom: ${result['new_tasks_count']} new assignments synced');
          }
        }
      } catch (e) {
        if (_isSessionExpired(e)) {
          _isSyncing = false;
          await _handleExpiredSession();
          return;
        }
        print('❌ Classroom sync error: $e');
      }

      // ──────────────────────────────────────────────────────────
      // 2. SYNC GMAIL EMAILS
      // ──────────────────────────────────────────────────────────
      try {
        final gmailProvider = context.read<GmailProvider>();
        await gmailProvider.checkConnection();

        if (gmailProvider.isConnected) {
          // ✅ Use try-catch for Gmail sync
          try {
            await gmailProvider.syncEmails();
            print('✅ Gmail sync completed');
          } catch (e) {
            if (_isSessionExpired(e)) {
              _isSyncing = false;
              await _handleExpiredSession();
              return;
            }
            print('❌ Gmail sync error: $e');
          }
        } else {
          print('ℹ️ Gmail not connected - skipping sync');
        }
      } catch (e) {
        print('❌ Gmail provider error: $e');
      }

      _isSyncing = false;
    } catch (e) {
      _isSyncing = false;
      print('❌ Auto-sync error: $e');
    }
  }

  static Future<void> manualSync(BuildContext context) async {
    await _performSync(context);
  }
}

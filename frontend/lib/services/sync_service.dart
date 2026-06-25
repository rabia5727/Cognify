import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/classroom_provider.dart';
import '../providers/gmail_provider.dart';

class SyncService {
  static Timer? _syncTimer;
  static bool _isSyncing = false;

  static void startAutoSync(BuildContext context) {
    _syncTimer?.cancel();

    // Run immediately
    _performSync(context);

    // Then every 3 minutes
    _syncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _performSync(context),
    );

    print('🔄 Auto-sync started (every 3 minutes)');
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

import 'package:flutter/material.dart';

import '../services/gmail_service.dart';
import '../services/google_classroom_service.dart';
import '../services/google_drive_service.dart'; // ✅ Add this import

class ProfileProvider extends ChangeNotifier {
  bool _isClassroomConnected = false;
  bool _isGmailConnected = false;
  bool _isDriveConnected = false;
  DateTime? _classroomLastSync;
  DateTime? _gmailLastSync;
  DateTime? _driveLastSync;
  bool _isLoading = false;

  bool get isClassroomConnected => _isClassroomConnected;
  bool get isGmailConnected => _isGmailConnected;
  bool get isDriveConnected => _isDriveConnected;
  DateTime? get classroomLastSync => _classroomLastSync;
  DateTime? get gmailLastSync => _gmailLastSync;
  DateTime? get driveLastSync => _driveLastSync;
  bool get isLoading => _isLoading;

  // Load all connection statuses
  Future<void> loadConnections() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Check Classroom connection
      try {
        final classroomHealth = await GoogleClassroomService.getHealth();
        _isClassroomConnected = classroomHealth['connected'] ?? false;
        if (_isClassroomConnected) {
          _classroomLastSync = DateTime.now();
        }
      } catch (e) {
        _isClassroomConnected = false;
        _classroomLastSync = null;
      }

      // Check Gmail connection
      try {
        final gmailHealth = await GmailService.getHealth();
        _isGmailConnected = gmailHealth['connected'] ?? false;
        if (_isGmailConnected) {
          _gmailLastSync = DateTime.now();
        }
      } catch (e) {
        _isGmailConnected = false;
        _gmailLastSync = null;
      }

      // ✅ Check Drive connection
      try {
        final driveHealth = await GoogleDriveService.getHealth();
        _isDriveConnected = driveHealth['connected'] ?? false;
        if (_isDriveConnected) {
          _driveLastSync = DateTime.now();
        }
      } catch (e) {
        _isDriveConnected = false;
        _driveLastSync = null;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Disconnect Classroom
  Future<void> disconnectClassroom() async {
    try {
      await GoogleClassroomService.disconnect();
      _isClassroomConnected = false;
      _classroomLastSync = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // Disconnect Gmail
  Future<void> disconnectGmail() async {
    try {
      await GmailService.disconnect();
      _isGmailConnected = false;
      _gmailLastSync = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  //  Disconnect Drive
  Future<void> disconnectDrive() async {
    try {
      await GoogleDriveService.disconnect();
      _isDriveConnected = false;
      _driveLastSync = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  // ─── Disconnect All ─────────────────────────────────────────────────

  Future<void> disconnectAll() async {
    try {
      // Disconnect all three services
      await GoogleClassroomService.disconnect();
      await GmailService.disconnect();
      await GoogleDriveService.disconnect();

      _isClassroomConnected = false;
      _isGmailConnected = false;
      _isDriveConnected = false;
      _classroomLastSync = null;
      _gmailLastSync = null;
      _driveLastSync = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // Format last sync time - Classroom
  String getClassroomLastSyncText() {
    if (_classroomLastSync == null) return 'Never';
    final diff = DateTime.now().difference(_classroomLastSync!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // Format last sync time - Gmail
  String getGmailLastSyncText() {
    if (_gmailLastSync == null) return 'Never';
    final diff = DateTime.now().difference(_gmailLastSync!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ✅ Format last sync time - Drive
  String getDriveLastSyncText() {
    if (_driveLastSync == null) return 'Never';
    final diff = DateTime.now().difference(_driveLastSync!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // Update methods
  void updateClassroomLastSync() {
    _classroomLastSync = DateTime.now();
    notifyListeners();
  }

  void updateGmailLastSync() {
    _gmailLastSync = DateTime.now();
    notifyListeners();
  }

  // ✅ Update Drive last sync
  void updateDriveLastSync() {
    _driveLastSync = DateTime.now();
    notifyListeners();
  }
}

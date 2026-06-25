import 'package:flutter/material.dart';
import '../services/google_classroom_service.dart';
import '../services/gmail_service.dart';

class ProfileProvider extends ChangeNotifier {
  bool _isClassroomConnected = false;
  bool _isGmailConnected = false;
  DateTime? _classroomLastSync;
  DateTime? _gmailLastSync;
  bool _isLoading = false;

  bool get isClassroomConnected => _isClassroomConnected;
  bool get isGmailConnected => _isGmailConnected;
  DateTime? get classroomLastSync => _classroomLastSync;
  DateTime? get gmailLastSync => _gmailLastSync;
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

  // Format last sync time
  String getClassroomLastSyncText() {
    if (_classroomLastSync == null) return 'Never';
    final diff = DateTime.now().difference(_classroomLastSync!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String getGmailLastSyncText() {
    if (_gmailLastSync == null) return 'Never';
    final diff = DateTime.now().difference(_gmailLastSync!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void updateClassroomLastSync() {
    _classroomLastSync = DateTime.now();
    notifyListeners();
  }

  void updateGmailLastSync() {
    _gmailLastSync = DateTime.now();
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/google_classroom_service.dart';
import './task_provider.dart';

class ClassroomProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _archivedCourses = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _error;

  List<Map<String, dynamic>> get courses => _courses;
  List<Map<String, dynamic>> get archivedCourses => _archivedCourses;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get error => _error;

  // ── Load courses + auto-sync assignments ─────────────────────
  Future<void> loadCourses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final allCourses = await GoogleClassroomService.getCourses();

      _courses = allCourses.where((c) => c['archived'] != true).toList();
      _archivedCourses =
          allCourses.where((c) => c['archived'] == true).toList();

      _isLoading = false;
      notifyListeners();

      // ✅ Auto-sync assignments after loading courses
      if (_courses.isNotEmpty) {
        await _autoSync();
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Background auto-sync (silent, no loading indicator) ──────
  Future<void> _autoSync() async {
    try {
      await GoogleClassroomService.syncAllAssignments();
      _lastSyncTime = DateTime.now();
      notifyListeners();
    } catch (e) {
      // Auto-sync failures are silent — don't disrupt the UI
      print('Auto-sync error: $e');
    }
  }

  // ── Toggle sync status for a course ──────────────────────────
  Future<void> toggleCourseSync(String courseId, bool enabled) async {
    await GoogleClassroomService.toggleCourseSync(courseId, enabled);

    final index = _courses.indexWhere((c) => c['id'] == courseId);
    if (index != -1) {
      _courses[index]['enabled'] = enabled;
      notifyListeners();
    }
  }

  // ── Archive a course ──────────────────────────────────────────
  Future<void> archiveCourse(String courseId) async {
    await GoogleClassroomService.archiveCourse(courseId);

    final course = _courses.firstWhere((c) => c['id'] == courseId);
    _courses.removeWhere((c) => c['id'] == courseId);
    course['archived'] = true;
    _archivedCourses.add(course);
    notifyListeners();
  }

  // ── Restore an archived course ────────────────────────────────
  Future<void> restoreCourse(String courseId) async {
    await GoogleClassroomService.restoreCourse(courseId);

    final course = _archivedCourses.firstWhere((c) => c['id'] == courseId);
    _archivedCourses.removeWhere((c) => c['id'] == courseId);
    course['archived'] = false;
    _courses.add(course);
    notifyListeners();
  }

  // ── Manual sync (triggered by "Sync All" button) ─────────────
  Future<Map<String, dynamic>> syncAllAssignments(BuildContext context) async {
    _isSyncing = true;
    notifyListeners();

    try {
      final result = await GoogleClassroomService.syncAllAssignments();
      _lastSyncTime = DateTime.now();

      // Refresh task list in TaskProvider after sync
      if (context.mounted) {
        await context.read<TaskProvider>().refreshTasks();
      }

      _isSyncing = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isSyncing = false;
      notifyListeners();
      rethrow;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────
  int get enabledCoursesCount =>
      _courses.where((c) => c['enabled'] == true).length;
}

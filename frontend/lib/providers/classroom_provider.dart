import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/google_classroom_service.dart';
import './task_provider.dart';

class ClassroomProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _archivedCourses = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _hasLoaded = false;
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
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final allCourses = await GoogleClassroomService.getCourses();

      _courses = allCourses.where((c) => c['archived'] != true).toList();
      _archivedCourses =
          allCourses.where((c) => c['archived'] == true).toList();

      _hasLoaded = true;
      _isLoading = false;
      notifyListeners();

      if (_courses.isNotEmpty && _shouldAutoSync()) {
        await _autoSync();
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Background auto-sync (silent) ────────────────────────────
  Future<void> _autoSync() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      notifyListeners();
      await GoogleClassroomService.syncAllAssignments();
      _lastSyncTime = DateTime.now();
      _isSyncing = false;
      notifyListeners();
    } catch (e) {
      _isSyncing = false;
      notifyListeners();
      print('Auto-sync error: $e');
    }
  }

  bool _shouldAutoSync() {
    if (_lastSyncTime == null) return true;
    return DateTime.now().difference(_lastSyncTime!).inMinutes > 5;
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

  // Actual sync call + task refresh. Callers own the _isSyncing flag so that
  // enableAllAndSync() can hold it across both the enable step and this one.
  Future<Map<String, dynamic>> _runSync(BuildContext context) async {
    final result = await GoogleClassroomService.syncAllAssignments();
    _lastSyncTime = DateTime.now();

    if (context.mounted) {
      await context.read<TaskProvider>().refreshTasks();
    }
    return result;
  }

  // ── Sync currently-enabled courses (background timer + pull-to-refresh) ──
  // Respects each course's individual enabled/disabled toggle.
  Future<Map<String, dynamic>> syncAllAssignments(BuildContext context) async {
    if (_isSyncing) {
      return {'new_tasks_count': 0, 'message': 'Already syncing'};
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final result = await _runSync(context);
      _isSyncing = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isSyncing = false;
      notifyListeners();
      rethrow;
    }
  }

  // ── "Sync All Courses" button ─────────────────────────────────
  // Unlike syncAllAssignments(), this one actually makes "all" true: it
  // turns on every course's toggle (one by one, so the user watches them
  // light up) before syncing. Individually disabled courses stay off for
  // the background auto-sync and pull-to-refresh — only this explicit
  // action turns them back on.
  Future<Map<String, dynamic>> enableAllAndSync(BuildContext context) async {
    if (_isSyncing) {
      return {'new_tasks_count': 0, 'message': 'Already syncing'};
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final disabledCourses =
          _courses.where((c) => c['enabled'] != true).toList();

      for (final course in disabledCourses) {
        try {
          await GoogleClassroomService.toggleCourseSync(course['id'], true);
          course['enabled'] = true;
          notifyListeners(); // flip this course's switch on right away
        } catch (_) {
          // Best-effort: if enabling one course fails, sync still proceeds
          // for the rest rather than blocking the whole action.
        }
      }

      if (!context.mounted) {
        return {'new_tasks_count': 0, 'message': 'Cancelled'};
      }

      final result = await _runSync(context);
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

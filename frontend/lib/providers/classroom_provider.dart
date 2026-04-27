// Purpose: State management for Classroom data
// State:
//   - List of courses with sync status
//   - Currently syncing flag
//   - Last sync time
//   - Pending assignments count
// Methods:
//   - loadCourses()
//   - toggleCourseSync()
//   - archiveCourse()
//   - triggerSync()

import 'package:flutter/material.dart';
import '../services/google_classroom_service.dart';
import '../services/notification_service.dart';
import './task_provider.dart';

class ClassroomProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _archivedCourses = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  List<Map<String, dynamic>> get courses => _courses;
  List<Map<String, dynamic>> get archivedCourses => _archivedCourses;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  // Load all courses from backend
  Future<void> loadCourses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final allCourses = await GoogleClassroomService.getCourses();
      
      // Separate active and archived courses
      _courses = allCourses.where((c) => c['archived'] != true).toList();
      _archivedCourses = allCourses.where((c) => c['archived'] == true).toList();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Toggle sync status for a course
  Future<void> toggleCourseSync(String courseId, bool enabled) async {
    await GoogleClassroomService.toggleCourseSync(courseId, enabled);
    
    // Update local state
    final index = _courses.indexWhere((c) => c['id'] == courseId);
    if (index != -1) {
      _courses[index]['enabled'] = enabled;
      notifyListeners();
    }
  }

  // Archive a course
  Future<void> archiveCourse(String courseId) async {
    await GoogleClassroomService.archiveCourse(courseId);
    
    // Move from active to archived
    final course = _courses.firstWhere((c) => c['id'] == courseId);
    _courses.removeWhere((c) => c['id'] == courseId);
    course['archived'] = true;
    _archivedCourses.add(course);
    notifyListeners();
  }

  // Restore an archived course
  Future<void> restoreCourse(String courseId) async {
    await GoogleClassroomService.restoreCourse(courseId);
    
    // Move from archived to active
    final course = _archivedCourses.firstWhere((c) => c['id'] == courseId);
    _archivedCourses.removeWhere((c) => c['id'] == courseId);
    course['archived'] = false;
    _courses.add(course);
    notifyListeners();
  }

  // Sync all enabled courses
  Future<Map<String, dynamic>> syncAllAssignments(BuildContext context) async {
    _isSyncing = true;
    notifyListeners();

    try {
      final result = await GoogleClassroomService.syncAllAssignments();
      _lastSyncTime = DateTime.now();
      //don't need to reload courses here since sync doesn't change course list, just tasks. We will refresh tasks separately
      // or use a callback 

      //show notification for new tasks synced
    
      _isSyncing = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isSyncing = false;
      notifyListeners();
      rethrow;
    }
  }

  // Get enabled courses count
  int get enabledCoursesCount {
    return _courses.where((c) => c['enabled'] == true).length;
  }
}
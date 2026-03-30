// ═══════════════════════════════════════════════════════════════════
// FILE: lib/providers/task_provider.dart
// PURPOSE:
//   Single source of truth for all task data across every screen.
//   Dashboard, Workspace, and Analytics all read from this provider —
//   so completing a task on the Dashboard is immediately reflected in
//   Workspace and Analytics without any manual syncing.
//
// BACKEND INTEGRATION:
//   Every method has a TODO comment showing exactly where to swap in
//   your real API call. The rest of the method stays the same.
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import '../models/task_model.dart';
import '../data/dummy_data.dart';

// Possible loading states for async operations
enum TaskLoadState { idle, loading, error }

class TaskProvider extends ChangeNotifier {
  // ─── Internal state ───────────────────────────────────────────────
  List<Task> _tasks = [];
  TaskLoadState _state = TaskLoadState.idle;
  String? _errorMessage;
  bool _initialized = false;

  // ─── Public getters ───────────────────────────────────────────────
  List<Task> get tasks => List.unmodifiable(_tasks);
  TaskLoadState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == TaskLoadState.loading;
  bool get hasError => _state == TaskLoadState.error;

  // ─── Derived / computed getters (used by AnalyticsProvider too) ───

  int get totalCount => _tasks.length;
  int get completedCount => _tasks.where((t) => t.isCompleted).length;
  int get inProgressCount =>
      _tasks.where((t) => t.status == TaskStatus.inProgress).length;
  int get todoCount => _tasks.where((t) => t.status == TaskStatus.todo).length;

  double get completionRate =>
      _tasks.isEmpty ? 0.0 : completedCount / _tasks.length;

  List<Task> get todayTasks {
    final today = DateTime.now();
    return _tasks.where((t) {
      return t.dueDate.year == today.year &&
          t.dueDate.month == today.month &&
          t.dueDate.day == today.day;
    }).toList();
  }

  List<Task> tasksForProject(String projectId) =>
      _tasks.where((t) => t.projectId == projectId).toList();

  // Tasks due on a specific date (used by Workspace calendar)
  List<Task> tasksForDate(DateTime date) => _tasks.where((t) {
        return t.dueDate.year == date.year &&
            t.dueDate.month == date.month &&
            t.dueDate.day == date.day;
      }).toList();

  // Filtered + sorted list — used by Workspace screen
  List<Task> filtered({
    int statusIndex = 0, // 0=all, 1=inProgress, 2=completed
    int priorityIndex = 0, // 0=all, 1=high, 2=medium, 3=low
    DateTime? date,
  }) {
    List<Task> result = List.from(_tasks);

    switch (statusIndex) {
      case 1:
        result =
            result.where((t) => t.status == TaskStatus.inProgress).toList();
        break;
      case 2:
        result = result.where((t) => t.isCompleted).toList();
        break;
    }

    if (priorityIndex > 0) {
      const map = {1: Priority.high, 2: Priority.medium, 3: Priority.low};
      final p = map[priorityIndex]!;
      result = result.where((t) => t.priority == p).toList();
    }

    if (date != null) {
      result = result.where((t) {
        return t.dueDate.year == date.year &&
            t.dueDate.month == date.month &&
            t.dueDate.day == date.day;
      }).toList();
    }

    return result;
  }

  // ─── Initialization ───────────────────────────────────────────────

  /// Call this once on app start (or after login).
  /// Replace DummyData with your API call when backend is ready.
  Future<void> loadTasks() async {
    if (_initialized) return;
    _setState(TaskLoadState.loading);

    try {
      // TODO: Replace with → final tasks = await TaskRepository.getAll();
      await Future.delayed(
          const Duration(milliseconds: 300)); // simulate network
      _tasks = List.from(DummyData.tasks);
      _initialized = true;
      _setState(TaskLoadState.idle);
    } catch (e) {
      _setError('Failed to load tasks: $e');
    }
  }

  /// Hard refresh — pulls from source regardless of cache
  Future<void> refreshTasks() async {
    _initialized = false;
    _tasks = [];
    await loadTasks();
  }

  // ─── CRUD operations ──────────────────────────────────────────────

  Future<void> addTask(Task task) async {
    try {
      // TODO: Replace with → await TaskRepository.create(task);
      _tasks.add(task);
      notifyListeners();
    } catch (e) {
      _setError('Failed to add task: $e');
      rethrow; // let the UI show a snackbar
    }
  }

  Future<void> updateTask(Task updated) async {
    try {
      // TODO: Replace with → await TaskRepository.update(updated);
      final index = _tasks.indexWhere((t) => t.id == updated.id);
      if (index == -1) return;
      _tasks[index] = updated;
      notifyListeners();
    } catch (e) {
      _setError('Failed to update task: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      // TODO: Replace with → await TaskRepository.delete(id);
      _tasks.removeWhere((t) => t.id == id);
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete task: $e');
      rethrow;
    }
  }

  /// Toggle completion — used by Dashboard "Start Task" and Workspace checkbox
  Future<void> toggleComplete(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final current = _tasks[index];
    final updated = current.copyWith(
      status: current.isCompleted ? TaskStatus.todo : TaskStatus.completed,
    );

    await updateTask(updated);
  }

  // ─── Private helpers ──────────────────────────────────────────────

  void _setState(TaskLoadState s) {
    _state = s;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _state = TaskLoadState.error;
    _errorMessage = msg;
    notifyListeners();
  }
}

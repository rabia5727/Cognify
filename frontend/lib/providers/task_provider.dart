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
  // FIXED: Uses correct status mapping (0=all, 1=inProgress, 2=completed)
  List<Task> filtered({
    int statusIndex = 0, // 0=all, 1=inProgress, 2=completed
    int priorityIndex = 0, // 0=all, 1=high, 2=medium, 3=low
    int categoryIndex = 0, // 0=all, 1=email, 2=classroom, 3=general
    DateTime? date,
  }) {
    List<Task> result = List.from(_tasks);

    // Status filter
    switch (statusIndex) {
      case 1:
        result =
            result.where((t) => t.status == TaskStatus.inProgress).toList();
        break;
      case 2:
        result = result.where((t) => t.isCompleted).toList();
        break;
      // case 0: show all (no filter)
    }

    // Priority filter
    if (priorityIndex > 0) {
      const priorityMap = {
        1: Priority.high,
        2: Priority.medium,
        3: Priority.low
      };
      final priority = priorityMap[priorityIndex];
      if (priority != null) {
        result = result.where((t) => t.priority == priority).toList();
      }
    }

    // Category filter
    if (categoryIndex > 0) {
      if (categoryIndex == 3) {
        // General: includes general, freelance, academic (legacy)
        result = result
            .where((t) =>
                t.category == TaskCategory.general ||
                t.category == TaskCategory.freelance ||
                t.category == TaskCategory.academic)
            .toList();
      } else {
        const categoryMap = {
          1: TaskCategory.email,
          2: TaskCategory.classroom,
        };
        final category = categoryMap[categoryIndex];
        if (category != null) {
          result = result.where((t) => t.category == category).toList();
        }
      }
    }

    // Date filter
    if (date != null) {
      result = result.where((t) {
        return t.dueDate.year == date.year &&
            t.dueDate.month == date.month &&
            t.dueDate.day == date.day;
      }).toList();
    }

    return result;
  }

  // Filtered projects by status (used by workspace screen)
  List<Task> filterByStatus(List<Task> tasks, int statusIndex) {
    if (statusIndex == 0) return tasks;
    if (statusIndex == 1) {
      return tasks.where((t) => t.status == TaskStatus.inProgress).toList();
    }
    return tasks.where((t) => t.isCompleted).toList();
  }

  // Filter by priority
  List<Task> filterByPriority(List<Task> tasks, int priorityIndex) {
    if (priorityIndex == 0) return tasks;
    const priorityMap = {1: Priority.high, 2: Priority.medium, 3: Priority.low};
    final priority = priorityMap[priorityIndex];
    if (priority == null) return tasks;
    return tasks.where((t) => t.priority == priority).toList();
  }

  // Filter by category
  List<Task> filterByCategory(List<Task> tasks, int categoryIndex) {
    if (categoryIndex == 0) return tasks;
    if (categoryIndex == 3) {
      return tasks
          .where((t) =>
              t.category == TaskCategory.general ||
              t.category == TaskCategory.freelance ||
              t.category == TaskCategory.academic)
          .toList();
    }
    const categoryMap = {1: TaskCategory.email, 2: TaskCategory.classroom};
    final category = categoryMap[categoryIndex];
    if (category == null) return tasks;
    return tasks.where((t) => t.category == category).toList();
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
    _setState(TaskLoadState.loading);
    try {
      // TODO: Replace with → final created = await TaskRepository.create(task);
      // Then use the returned task with server-assigned ID
      await Future.delayed(
          const Duration(milliseconds: 300)); // simulate network

      // For dummy data, create a copy with a proper ID
      final newTask = task.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      _tasks.add(newTask);
      _setState(TaskLoadState.idle);
      notifyListeners();
    } catch (e) {
      _setError('Failed to add task: $e');
      rethrow;
    }
  }

  Future<void> updateTask(Task updated) async {
    _setState(TaskLoadState.loading);
    try {
      // TODO: Replace with → await TaskRepository.update(updated);
      await Future.delayed(
          const Duration(milliseconds: 300)); // simulate network
      final index = _tasks.indexWhere((t) => t.id == updated.id);
      if (index == -1) return;
      _tasks[index] = updated;
      _setState(TaskLoadState.idle);
      notifyListeners();
    } catch (e) {
      _setError('Failed to update task: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(String id) async {
    _setState(TaskLoadState.loading);
    try {
      // TODO: Replace with → await TaskRepository.delete(id);
      await Future.delayed(
          const Duration(milliseconds: 300)); // simulate network
      _tasks.removeWhere((t) => t.id == id);
      _setState(TaskLoadState.idle);
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
    if (s != TaskLoadState.error) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  void _setError(String msg) {
    _state = TaskLoadState.error;
    _errorMessage = msg;
    notifyListeners();
  }
}

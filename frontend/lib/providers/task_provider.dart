import 'package:flutter/foundation.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';

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

  // ─── Derived / computed getters ───────────────────────────────────

  int get totalCount => _tasks.length;
  int get completedCount => _tasks.where((t) => t.isCompleted).length;
  int get inProgressCount =>
      _tasks.where((t) => t.status == TaskStatus.inProgress).length;
  int get todoCount => _tasks.where((t) => t.status == TaskStatus.todo).length;

  double get completionRate =>
      _tasks.isEmpty ? 0.0 : completedCount / _tasks.length;

  double get dailyCompletionRate {
    final today = DateTime.now();
    final todayTasks = _tasks.where((t) =>
        t.dueDate.year == today.year &&
        t.dueDate.month == today.month &&
        t.dueDate.day == today.day).toList();
    if (todayTasks.isEmpty) return 0.0;
    return todayTasks.where((t) => t.isCompleted).length / todayTasks.length;
  }

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

  List<Task> tasksForDate(DateTime date) => _tasks.where((t) {
        return t.dueDate.year == date.year &&
            t.dueDate.month == date.month &&
            t.dueDate.day == date.day;
      }).toList();

  // Filtered + sorted list — used by Workspace screen
  List<Task> filtered({
    int statusIndex = 0,
    int priorityIndex = 0,
    int categoryIndex = 0,
    DateTime? date,
  }) {
    List<Task> result = List.from(_tasks);

    switch (statusIndex) {
      case 1:
        // Completed tab: completed tasks only, hide after 48 hours
        final cutoff = DateTime.now().subtract(const Duration(hours: 48));
        result = result.where((t) {
          if (!t.isCompleted) return false;
          if (t.completedAt == null) return true;
          return t.completedAt!.isAfter(cutoff);
        }).toList();
        break;
      case 0:
      default:
        // All tab: active tasks only (exclude completed)
        result = result.where((t) => !t.isCompleted).toList();
        break;
    }

    if (priorityIndex > 0) {
      const priorityMap = {
        1: Priority.high,
        2: Priority.medium,
        3: Priority.low,
      };
      final priority = priorityMap[priorityIndex];
      if (priority != null) {
        result = result.where((t) => t.priority == priority).toList();
      }
    }

    if (categoryIndex > 0) {
      if (categoryIndex == 3) {
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

    if (date != null) {
      result = result.where((t) {
        return t.dueDate.year == date.year &&
            t.dueDate.month == date.month &&
            t.dueDate.day == date.day;
      }).toList();
    }

    return result;
  }

  List<Task> filterByStatus(List<Task> tasks, int statusIndex) {
    if (statusIndex == 0) return tasks;
    if (statusIndex == 1) {
      return tasks.where((t) => t.status == TaskStatus.inProgress).toList();
    }
    return tasks.where((t) => t.isCompleted).toList();
  }

  List<Task> filterByPriority(List<Task> tasks, int priorityIndex) {
    if (priorityIndex == 0) return tasks;
    const priorityMap = {
      1: Priority.high,
      2: Priority.medium,
      3: Priority.low,
    };
    final priority = priorityMap[priorityIndex];
    if (priority == null) return tasks;
    return tasks.where((t) => t.priority == priority).toList();
  }

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

  Future<void> loadTasks() async {
    if (_initialized) return;
    _setState(TaskLoadState.loading);
    final result = await TaskService.getTasks();
    if (result.isSuccess) {
      _tasks = result.tasks!;
      _initialized = true;
      _setState(TaskLoadState.idle);
    } else {
      _setError(result.error!);
    }
  }

  Future<void> refreshTasks() async {
    _initialized = false;
    _tasks = [];
    await loadTasks();
  }

  // ─── CRUD operations ──────────────────────────────────────────────

  Future<Task> addTask(Task task) async {
    _setState(TaskLoadState.loading);
    final result = await TaskService.createTask(task);
    if (result.isSuccess) {
      _tasks.add(result.task!);
      _setState(TaskLoadState.idle);
      notifyListeners();
      return result.task!;
    } else {
      _setError(result.error!);
      throw Exception(result.error);
    }
  }

  Future<void> updateTask(Task updated) async {
    _setState(TaskLoadState.loading);
    final result = await TaskService.updateTask(updated);
    if (result.isSuccess) {
      final index = _tasks.indexWhere((t) => t.id == updated.id);
      if (index != -1) _tasks[index] = result.task!;
      _setState(TaskLoadState.idle);
      notifyListeners();
    } else {
      _setError(result.error!);
      throw Exception(result.error);
    }
  }

  Future<void> deleteTask(String id) async {
    _setState(TaskLoadState.loading);
    final success = await TaskService.deleteTask(id);
    if (success) {
      _tasks.removeWhere((t) => t.id == id);
      _setState(TaskLoadState.idle);
      notifyListeners();
    } else {
      _setError('Failed to delete task');
      throw Exception('Failed to delete task');
    }
  }

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
    if (s != TaskLoadState.error) _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _state = TaskLoadState.error;
    _errorMessage = msg;
    notifyListeners();
  }
}

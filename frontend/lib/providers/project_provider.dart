import 'package:flutter/foundation.dart';
import '../models/project_model.dart';
import '../models/task_model.dart';
import '../services/project_service.dart';

enum ProjectLoadState { idle, loading, error }

class ProjectProvider extends ChangeNotifier {
  List<Project> _projects = [];
  ProjectLoadState _state = ProjectLoadState.idle;
  String? _errorMessage;
  bool _initialized = false;

  List<Project> get projects => List.unmodifiable(_projects);
  ProjectLoadState get state => _state;
  bool get isLoading => _state == ProjectLoadState.loading;
  bool get hasError => _state == ProjectLoadState.error;
  String? get errorMessage => _errorMessage;

  // ─── Derived getters ──────────────────────────────────────────────

  int get totalCount => _projects.length;
  int get activeCount =>
      _projects.where((p) => p.status == ProjectStatus.active).length;
  int get completedCount =>
      _projects.where((p) => p.status == ProjectStatus.completed).length;

  List<Project> get academicProjects =>
      _projects.where((p) => p.category == ProjectCategory.academic).toList();
  List<Project> get freelanceProjects =>
      _projects.where((p) => p.category == ProjectCategory.freelance).toList();
  List<Project> get personalProjects =>
      _projects.where((p) => p.category == ProjectCategory.personal).toList();

  double progressFor(Project project, List<Task> allTasks) {
    if (project.taskIds.isEmpty) return 0.0;
    final linked =
        allTasks.where((t) => project.taskIds.contains(t.id)).toList();
    if (linked.isEmpty) return 0.0;
    return linked.where((t) => t.isCompleted).length / linked.length;
  }

  // Filtered projects — used by workspace screen
  // categoryIndex: 0=all, 1=academic, 2=freelance, 3=personal
  List<Project> filtered({
    int statusIndex = 0,
    int priorityIndex = 0,
    int categoryIndex = 0,
    List<Task>? allTasks,
  }) {
    List<Project> result = List.from(_projects);

    switch (statusIndex) {
      case 1:
        result = result.where((p) => p.status == ProjectStatus.active).toList();
        break;
      case 2:
        result =
            result.where((p) => p.status == ProjectStatus.completed).toList();
        break;
    }

    if (priorityIndex > 0) {
      const priorityMap = {
        1: Priority.high,
        2: Priority.medium,
        3: Priority.low
      };
      final priority = priorityMap[priorityIndex];
      if (priority != null) {
        result = result.where((p) => p.priority == priority).toList();
      }
    }

    if (categoryIndex > 0) {
      const categoryMap = {
        1: ProjectCategory.academic,
        2: ProjectCategory.freelance,
        3: ProjectCategory.personal,
      };
      final category = categoryMap[categoryIndex];
      if (category != null) {
        result = result.where((p) => p.category == category).toList();
      }
    }

    return result;
  }

  // ─── Initialization ───────────────────────────────────────────────

  Future<void> loadProjects() async {
    if (_initialized) return;
    _setState(ProjectLoadState.loading);
    final result = await ProjectService.getProjects();
    if (result.isSuccess) {
      _projects = result.projects!;
      _initialized = true;
      _setState(ProjectLoadState.idle);
    } else {
      _setError(result.error!);
    }
  }

  Future<void> refreshProjects() async {
    _initialized = false;
    _projects = [];
    await loadProjects();
  }

  // ─── CRUD ─────────────────────────────────────────────────────────

  Future<void> addProject(Project project) async {
    _setState(ProjectLoadState.loading);
    final result = await ProjectService.createProject(project);
    if (result.isSuccess) {
      _projects.add(result.project!);
      _setState(ProjectLoadState.idle);
      notifyListeners();
    } else {
      _setError(result.error!);
      throw Exception(result.error);
    }
  }

  Future<void> updateProject(Project updated) async {
    _setState(ProjectLoadState.loading);
    final result = await ProjectService.updateProject(updated);
    if (result.isSuccess) {
      final index = _projects.indexWhere((p) => p.id == updated.id);
      if (index != -1) _projects[index] = result.project!;
      _setState(ProjectLoadState.idle);
      notifyListeners();
    } else {
      _setError(result.error!);
      throw Exception(result.error);
    }
  }

  Future<void> deleteProject(String id) async {
    _setState(ProjectLoadState.loading);
    final success = await ProjectService.deleteProject(id);
    if (success) {
      _projects.removeWhere((p) => p.id == id);
      _setState(ProjectLoadState.idle);
      notifyListeners();
    } else {
      _setError('Failed to delete project');
      throw Exception('Failed to delete project');
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────

  void _setState(ProjectLoadState s) {
    _state = s;
    if (s != ProjectLoadState.error) _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _state = ProjectLoadState.error;
    _errorMessage = msg;
    notifyListeners();
  }
}

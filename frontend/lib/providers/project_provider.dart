// ═══════════════════════════════════════════════════════════════════
// FILE: lib/providers/project_provider.dart
// PURPOSE:
//   Single source of truth for all project data across every screen.
//
// BACKEND INTEGRATION:
//   Every method has a TODO comment showing exactly where to swap in
//   your real API call. The rest of the method stays the same.
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import '../models/project_model.dart';
import '../models/task_model.dart';
import '../data/dummy_data.dart';

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

  // Projects grouped by category
  List<Project> get academicProjects =>
      _projects.where((p) => p.category == ProjectCategory.academic).toList();
  List<Project> get freelanceProjects =>
      _projects.where((p) => p.category == ProjectCategory.freelance).toList();
  List<Project> get generalProjects =>
      _projects.where((p) => p.category == ProjectCategory.general).toList();

  // Progress for a project given a list of tasks (passed in from TaskProvider)
  double progressFor(Project project, List<Task> allTasks) {
    if (project.taskIds.isEmpty) return 0.0;
    final linked =
        allTasks.where((t) => project.taskIds.contains(t.id)).toList();
    if (linked.isEmpty) return 0.0;
    return linked.where((t) => t.isCompleted).length / linked.length;
  }

  // Filtered projects - used by workspace screen
  List<Project> filtered({
    int statusIndex = 0, // 0=all, 1=active, 2=completed
    int priorityIndex = 0, // 0=all, 1=high, 2=medium, 3=low
    int categoryIndex = 0, // 0=all, 1=freelance, 2=academic
    List<Task>? allTasks,
  }) {
    List<Project> result = List.from(_projects);

    // Status filter
    switch (statusIndex) {
      case 1: // Active projects
        result = result.where((p) => p.status == ProjectStatus.active).toList();
        break;
      case 2: // Completed projects
        result =
            result.where((p) => p.status == ProjectStatus.completed).toList();
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
        result = result.where((p) => p.priority == priority).toList();
      }
    }

    // Category filter
    if (categoryIndex > 0) {
      const categoryMap = {
        1: ProjectCategory.freelance,
        2: ProjectCategory.academic
      };
      final category = categoryMap[categoryIndex];
      if (category != null) {
        result = result.where((p) => p.category == category).toList();
      }
    }

    return result;
  }

  // Filter projects by completion status based on tasks
  List<Project> filterByTaskCompletion({
    required List<Project> projects,
    required List<Task> allTasks,
    int filterIndex = 0, // 0=all, 1=inProgress, 2=completed
  }) {
    if (filterIndex == 0) return projects;

    return projects.where((project) {
      final linkedTasks =
          allTasks.where((t) => project.taskIds.contains(t.id)).toList();
      if (linkedTasks.isEmpty) return false;

      final completedCount = linkedTasks.where((t) => t.isCompleted).length;
      final totalCount = linkedTasks.length;

      if (filterIndex == 1) {
        // In Progress - at least one task completed but not all
        return completedCount > 0 && completedCount < totalCount;
      } else {
        // Completed - all tasks completed
        return completedCount == totalCount;
      }
    }).toList();
  }

  // ─── Initialization ───────────────────────────────────────────────

  Future<void> loadProjects() async {
    if (_initialized) return;
    _setState(ProjectLoadState.loading);

    try {
      // TODO: Replace with → final projects = await ProjectRepository.getAll();
      await Future.delayed(const Duration(milliseconds: 200));
      _projects = List.from(DummyData.projects);
      _initialized = true;
      _setState(ProjectLoadState.idle);
    } catch (e) {
      _setError('Failed to load projects: $e');
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
    try {
      // TODO: Replace with → final created = await ProjectRepository.create(project);
      // Then use the returned project with server-assigned ID
      await Future.delayed(const Duration(milliseconds: 300));

      // For dummy data, create a copy with a proper ID
      final newProject = project.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      _projects.add(newProject);
      _setState(ProjectLoadState.idle);
      notifyListeners();
    } catch (e) {
      _setError('Failed to add project: $e');
      rethrow;
    }
  }

  Future<void> updateProject(Project updated) async {
    _setState(ProjectLoadState.loading);
    try {
      // TODO: Replace with → await ProjectRepository.update(updated);
      await Future.delayed(const Duration(milliseconds: 300));
      final index = _projects.indexWhere((p) => p.id == updated.id);
      if (index == -1) return;
      _projects[index] = updated;
      _setState(ProjectLoadState.idle);
      notifyListeners();
    } catch (e) {
      _setError('Failed to update project: $e');
      rethrow;
    }
  }

  Future<void> deleteProject(String id) async {
    _setState(ProjectLoadState.loading);
    try {
      // TODO: Replace with → await ProjectRepository.delete(id);
      await Future.delayed(const Duration(milliseconds: 300));
      _projects.removeWhere((p) => p.id == id);
      _setState(ProjectLoadState.idle);
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete project: $e');
      rethrow;
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────

  void _setState(ProjectLoadState s) {
    _state = s;
    if (s != ProjectLoadState.error) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  void _setError(String msg) {
    _state = ProjectLoadState.error;
    _errorMessage = msg;
    notifyListeners();
  }
}

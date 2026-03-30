// ═══════════════════════════════════════════════════════════════════
// FILE: lib/providers/project_provider.dart
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

  // Progress for a project given a list of tasks (passed in from TaskProvider)
  double progressFor(Project project, List<Task> allTasks) {
    if (project.taskIds.isEmpty) return 0.0;
    final linked =
        allTasks.where((t) => project.taskIds.contains(t.id)).toList();
    if (linked.isEmpty) return 0.0;
    return linked.where((t) => t.isCompleted).length / linked.length;
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
    try {
      // TODO: await ProjectRepository.create(project);
      _projects.add(project);
      notifyListeners();
    } catch (e) {
      _setError('Failed to add project: $e');
      rethrow;
    }
  }

  Future<void> updateProject(Project updated) async {
    try {
      // TODO: await ProjectRepository.update(updated);
      final index = _projects.indexWhere((p) => p.id == updated.id);
      if (index == -1) return;
      _projects[index] = updated;
      notifyListeners();
    } catch (e) {
      _setError('Failed to update project: $e');
      rethrow;
    }
  }

  Future<void> deleteProject(String id) async {
    try {
      // TODO: await ProjectRepository.delete(id);
      _projects.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete project: $e');
      rethrow;
    }
  }

  void _setState(ProjectLoadState s) {
    _state = s;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _state = ProjectLoadState.error;
    _errorMessage = msg;
    notifyListeners();
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/project_model.dart';
import 'token_storage.dart';

class ProjectListResult {
  final List<Project>? projects;
  final String? error;
  bool get isSuccess => error == null;

  ProjectListResult._({this.projects, this.error});
  factory ProjectListResult.success(List<Project> projects) =>
      ProjectListResult._(projects: projects);
  factory ProjectListResult.failure(String error) =>
      ProjectListResult._(error: error);
}

class ProjectResult {
  final Project? project;
  final String? error;
  bool get isSuccess => error == null;

  ProjectResult._({this.project, this.error});
  factory ProjectResult.success(Project project) =>
      ProjectResult._(project: project);
  factory ProjectResult.failure(String error) =>
      ProjectResult._(error: error);
}

class ProjectService {
  static const String _base = 'http://127.0.0.1:8000/projects';

  static Future<Map<String, String>> get _headers async {
    final token = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static String _parseError(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        return body['detail']?.toString() ??
            body['message']?.toString() ??
            'Something went wrong';
      }
    } catch (_) {}
    return 'Error ${res.statusCode}';
  }

  /// GET /projects/ — fetch all projects for the current user
  static Future<ProjectListResult> getProjects() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/'), headers: await _headers)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body is List ? body : (body['projects'] as List? ?? []);
        final projects = list
            .map((p) => Project.fromJson(p as Map<String, dynamic>))
            .toList();
        return ProjectListResult.success(projects);
      }
      return ProjectListResult.failure(_parseError(res));
    } on SocketException {
      return ProjectListResult.failure('Cannot connect to server.');
    } catch (e) {
      return ProjectListResult.failure('Unexpected error: $e');
    }
  }

  /// POST /projects/ — create a new project
  static Future<ProjectResult> createProject(Project project) async {
    try {
      final body = project.toJson()..remove('id')..remove('status');
      final res = await http
          .post(
            Uri.parse('$_base/'),
            headers: await _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return ProjectResult.success(Project.fromJson(jsonDecode(res.body)));
      }
      return ProjectResult.failure(_parseError(res));
    } on SocketException {
      return ProjectResult.failure('Cannot connect to server.');
    } catch (e) {
      return ProjectResult.failure('Unexpected error: $e');
    }
  }

  /// PUT /projects/{id} — update an existing project
  static Future<ProjectResult> updateProject(Project project) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/${project.id}'),
            headers: await _headers,
            body: jsonEncode(project.toJson()),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        return ProjectResult.success(Project.fromJson(jsonDecode(res.body)));
      }
      return ProjectResult.failure(_parseError(res));
    } on SocketException {
      return ProjectResult.failure('Cannot connect to server.');
    } catch (e) {
      return ProjectResult.failure('Unexpected error: $e');
    }
  }

  /// DELETE /projects/{id} — permanently delete a project
  static Future<bool> deleteProject(String id) async {
    try {
      final res = await http
          .delete(Uri.parse('$_base/$id'), headers: await _headers)
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

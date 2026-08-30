import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/task_model.dart';
import 'token_storage.dart';
import '../config/app_config.dart';

class TaskListResult {
  final List<Task>? tasks;
  final String? error;
  bool get isSuccess => error == null;

  TaskListResult._({this.tasks, this.error});
  factory TaskListResult.success(List<Task> tasks) =>
      TaskListResult._(tasks: tasks);
  factory TaskListResult.failure(String error) =>
      TaskListResult._(error: error);
}

class TaskResult {
  final Task? task;
  final String? error;
  bool get isSuccess => error == null;

  TaskResult._({this.task, this.error});
  factory TaskResult.success(Task task) => TaskResult._(task: task);
  factory TaskResult.failure(String error) => TaskResult._(error: error);
}

class TaskService {
  static String get _base => '${AppConfig.baseUrl}/tasks';

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

  /// GET /tasks/ — fetch all tasks for the current user.
  /// page_size=100 is the backend's max — there's no pagination UI in the
  /// app, so without this the backend's default page_size=20 silently
  /// hides anything past the 20th task (increasingly likely as classroom/
  /// Gmail auto-sync keeps adding more).
  static Future<TaskListResult> getTasks() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/?page_size=100'), headers: await _headers)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final tasks = (body['tasks'] as List)
            .map((t) => Task.fromJson(t as Map<String, dynamic>))
            .toList();
        return TaskListResult.success(tasks);
      }
      return TaskListResult.failure(_parseError(res));
    } on SocketException {
      return TaskListResult.failure('Cannot connect to server.');
    } catch (e) {
      return TaskListResult.failure('Unexpected error: $e');
    }
  }

  /// POST /tasks/ — create a new task
  static Future<TaskResult> createTask(Task task) async {
    try {
      final body = task.toJson()..remove('status');
      final res = await http
          .post(
            Uri.parse('$_base/'),
            headers: await _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return TaskResult.success(Task.fromJson(jsonDecode(res.body)));
      }
      return TaskResult.failure(_parseError(res));
    } on SocketException {
      return TaskResult.failure('Cannot connect to server.');
    } catch (e) {
      return TaskResult.failure('Unexpected error: $e');
    }
  }

  /// PUT /tasks/{id} — update an existing task
  static Future<TaskResult> updateTask(Task task) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_base/${task.id}'),
            headers: await _headers,
            body: jsonEncode(task.toJson()),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        return TaskResult.success(Task.fromJson(jsonDecode(res.body)));
      }
      return TaskResult.failure(_parseError(res));
    } on SocketException {
      return TaskResult.failure('Cannot connect to server.');
    } catch (e) {
      return TaskResult.failure('Unexpected error: $e');
    }
  }

  /// DELETE /tasks/{id} — permanently delete a task
  static Future<bool> deleteTask(String id) async {
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

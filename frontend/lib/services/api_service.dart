// ── API Service ─────────────────────────────────────────────────────────────
// Handles all API calls to the backend, including authentication and user data.
// This service abstracts away the HTTP logic and provides clean methods for the rest of the app to use.
// Note: For simplicity, this service does not use a state management solution. In a larger app, you might want to integrate it with something like Provider or Bloc.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../screens/auth/auth_screen.dart';
import 'token_storage.dart';
import '../config/app_config.dart';

class ApiService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  // ── Change this to your machine's IP if testing on a physical device ───────
  // For emulator use 10.0.2.2, for physical device use your local IP e.g. 192.168.1.x
  static String get baseUrl => AppConfig.baseUrl;

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Future<Map<String, String>> get _authHeaders async {
    final token = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Parses error message from backend response
  static String _parseError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        return body['detail']?.toString() ??
            body['message']?.toString() ??
            'Something went wrong';
      }
    } catch (_) {}
    return 'Error ${response.statusCode}: ${response.reasonPhrase}';
  }

  static Future<void> _check401(http.Response response) async {
    if (response.statusCode == 401) {
      await TokenStorage.clearAll();
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  /// POST /auth/register
  /// Body: { name, email, password }
  /// Returns: AuthResponse with access_token
  static Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      print('🚀 Calling: $baseUrl/auth/register');
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: _jsonHeaders,
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final auth = AuthResponse.fromJson(data);
        // Save token immediately
        await TokenStorage.saveToken(auth.accessToken);
        return AuthResult.success(auth);
      } else {
        return AuthResult.failure(_parseError(response));
      }
    } on SocketException {
      return AuthResult.failure(
          'Cannot connect to server. Make sure your backend is running.');
    } on HttpException {
      return AuthResult.failure('Network error. Please try again.');
    } catch (e) {
      return AuthResult.failure('Unexpected error: $e');
    }
  }

  /// POST /auth/login
  /// Body: { email, password }
  /// Returns: AuthResponse with access_token
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: _jsonHeaders,
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final auth = AuthResponse.fromJson(data);
        await TokenStorage.saveToken(auth.accessToken);
        return AuthResult.success(auth);
      } else {
        return AuthResult.failure(_parseError(response));
      }
    } on SocketException {
      return AuthResult.failure(
          'Cannot connect to server. Make sure your backend is running.');
    } on HttpException {
      return AuthResult.failure('Network error. Please try again.');
    } catch (e) {
      return AuthResult.failure('Unexpected error: $e');
    }
  }
  /// POST /auth/google
/// Body: { token: google_id_token }
/// Returns: AuthResponse with access_token
static Future<AuthResult> googleLogin({
  required String idToken,
}) async {
  try {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/google'),
          headers: _jsonHeaders,
          body: jsonEncode({'token': idToken}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final auth = AuthResponse.fromJson(data);
      await TokenStorage.saveToken(auth.accessToken);
      return AuthResult.success(auth);
    } else {
      return AuthResult.failure(_parseError(response));
    }
  } on SocketException {
    return AuthResult.failure('Cannot connect to server.');
  } catch (e) {
    return AuthResult.failure('Unexpected error: $e');
  }
}

  // ── Users ──────────────────────────────────────────────────────────────────

  /// GET /users/me — requires JWT token
  static Future<UserResult> getMe() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/users/me'),
            headers: await _authHeaders,
          )
          .timeout(const Duration(seconds: 30));

      await _check401(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = UserModel.fromJson(data);
        await TokenStorage.saveUserInfo(
          name: user.name,
          email: user.email,
          id: user.id,
        );
        return UserResult.success(user);
      } else {
        return UserResult.failure(_parseError(response));
      }
    } on SocketException {
      return UserResult.failure('Cannot connect to server.');
    } catch (e) {
      return UserResult.failure('Unexpected error: $e');
    }
  }

  /// PUT /users/me — update user profile / preferences
  static Future<UserResult> updateMe(Map<String, dynamic> data) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/users/me'),
            headers: await _authHeaders,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));

      await _check401(response);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return UserResult.success(UserModel.fromJson(body));
      } else {
        return UserResult.failure(_parseError(response));
      }
    } on SocketException {
      return UserResult.failure('Cannot connect to server.');
    } catch (e) {
      return UserResult.failure('Unexpected error: $e');
    }
  }
}

// ─── Result wrappers ─────────────────────────────────────────────────────────

class AuthResult {
  final AuthResponse? data;
  final String? error;
  bool get isSuccess => error == null;

  AuthResult._({this.data, this.error});
  factory AuthResult.success(AuthResponse data) => AuthResult._(data: data);
  factory AuthResult.failure(String error) => AuthResult._(error: error);
}

class UserResult {
  final UserModel? data;
  final String? error;
  bool get isSuccess => error == null;

  UserResult._({this.data, this.error});
  factory UserResult.success(UserModel data) => UserResult._(data: data);
  factory UserResult.failure(String error) => UserResult._(error: error);
}

// ═══════════════════════════════════════════════════════════════════
// FILE: lib/providers/auth_provider.dart
// PURPOSE:
//   Replaces the manual `userName` String being passed as a prop
//   through HomeScreen → DashboardScreen → SettingsScreen etc.
//   Every screen that needs user info reads from this provider instead.
//
// BACKEND INTEGRATION:
//   Your team's auth screens already talk to the backend.
//   This provider just needs to receive the result (user + token)
//   after a successful login and store it.
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/token_storage.dart';
import '../services/user_service.dart';

enum AuthState { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthState _authState = AuthState.unknown;
  UserModel? _user;
  bool _isLoading = false;

  AuthState get authState => _authState;
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _authState == AuthState.authenticated;

  // Convenience getters used throughout the UI
  String get userName => _user?.name ?? 'User';
  String get userEmail => _user?.email ?? '';

  // ─── Session bootstrap ────────────────────────────────────────────

  Future<void> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        final profile = await UserService.getProfile();
        if (profile != null) {
          _user = UserModel.fromJson(profile);
          await TokenStorage.saveUserInfo(
            name: _user!.name,
            email: _user!.email,
            id: _user!.id,
          );
          _authState = AuthState.authenticated;
        } else {
          _authState = AuthState.unauthenticated;
        }
      } else {
        _authState = AuthState.unauthenticated;
      }
    } catch (_) {
      _authState = AuthState.unauthenticated;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Called after a successful login from your auth screens.
  /// Your team passes in the user object returned by the backend.
  void onLoginSuccess(UserModel user, String token) {
    _user = user;
    _authState = AuthState.authenticated;
    notifyListeners();
    // Persist so checkSession() can restore email on next app launch
    TokenStorage.saveUserInfo(name: user.name, email: user.email, id: user.id);
  }

  /// Called when the user updates their name / email in ProfileScreen.
  void updateUserInfo({String? name, String? email}) {
    if (_user == null) return;
    _user = UserModel(
      id: _user!.id,
      name: name ?? _user!.name,
      email: email ?? _user!.email,
    );
    notifyListeners();
  }

  // ─── Delete account ───────────────────────────────────────────────

  Future<String?> deleteAccount() async {
    final error = await UserService.deleteAccount();
    if (error != null) return error;
    await TokenStorage.clearAll();
    _user = null;
    _authState = AuthState.unauthenticated;
    notifyListeners();
    return null;
  }

  // ─── Logout ───────────────────────────────────────────────────────

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // TODO: Replace with → await AuthRepository.logout();
      await TokenStorage.clearAll();
      _user = null;
      _authState = AuthState.unauthenticated;
    } catch (_) {
      // Even if the API call fails, clear local state
      await TokenStorage.clearAll();
      _user = null;
      _authState = AuthState.unauthenticated;
    }

    _isLoading = false;
    notifyListeners();
  }
}

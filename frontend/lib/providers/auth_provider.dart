import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/sync_service.dart';
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
  String get userId => _user?.id ?? '';

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
    // ✅ Stop auto-sync before logging out
    SyncService.stopAutoSync();

    _isLoading = true;
    notifyListeners();

    try {
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

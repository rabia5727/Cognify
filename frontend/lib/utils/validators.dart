// ═══════════════════════════════════════════════════════════════════
// FILE: lib/utils/validators.dart
// PURPOSE: Centralized form field validators.
//          Use these with TextFormField's `validator` parameter.
//          Inline errors will show under the field automatically.
//          When backend adds more rules, update only here.
// ═══════════════════════════════════════════════════════════════════

class Validators {
  Validators._(); // Prevent instantiation

  // ── Name ─────────────────────────────────────────────────────────

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    if (value.trim().length > 50) return 'Name must be under 50 characters';
    return null;
  }

  // ── Email ────────────────────────────────────────────────────────

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  // ── Password ─────────────────────────────────────────────────────

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Minimum 6 characters required';
    return null;
  }

  static String? newPassword(String? value, String currentPassword) {
    final base = password(value);
    if (base != null) return base;
    if (value == currentPassword) {
      return 'New password cannot be same as current';
    }
    return null;
  }

  static String? confirmPassword(String? value, String newPassword) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != newPassword) return 'Passwords do not match';
    return null;
  }

  // ── Task / Project fields ────────────────────────────────────────

  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? taskTitle(String? value) {
    if (value == null || value.trim().isEmpty) return 'Task title is required';
    if (value.trim().length < 3) return 'Title must be at least 3 characters';
    if (value.trim().length > 100) return 'Title is too long';
    return null;
  }

  static String? projectTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Project title is required';
    }
    if (value.trim().length < 3) return 'Title must be at least 3 characters';
    if (value.trim().length > 80) return 'Title is too long';
    return null;
  }
}

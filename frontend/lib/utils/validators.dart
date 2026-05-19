import 'package:flutter/material.dart';

class Validators {
  Validators._();

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

  // ── Due Date ─────────────────────────────────────────────────────

  static String? dueDate(DateTime? date) {
    if (date == null) return 'Please select a due date';
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final due = DateTime(date.year, date.month, date.day);
    if (due.isBefore(todayDate)) return 'Due date cannot be in the past';
    return null;
  }

  // ── Due Time ─────────────────────────────────────────────────────

  static String? futureTime(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (selected.isBefore(DateTime.now())) {
      return 'Selected time is in the past';
    }
    return null;
  }

  // ── Due DateTime (combines date and time) ─────────────────────────

  static String? dueDateTime(DateTime? date, TimeOfDay? time) {
    if (date == null) return 'Please select a due date';

    // If no time selected, only validate the date not the time
    if (time == null) {
      return dueDate(date);
    }

    // If time is selected, validate combined date+time
    final due =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (due.isBefore(DateTime.now())) {
      return 'Due time cannot be in the past';
    }
    return null;
  }
}

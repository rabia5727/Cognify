// ═══════════════════════════════════════════════════════════════════
// FILE: lib/utils/ui_feedback.dart
// PURPOSE: Centralized UI feedback helpers (snackbars, dialogs)
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

class UIFeedback {
  UIFeedback._();

  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    _show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      bgColor: const Color(0xFF22C55E),
      duration: const Duration(seconds: 2),
    );
  }

  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;
    _show(
      context,
      message: message,
      icon: Icons.error_rounded,
      bgColor: const Color(0xFFEF4444),
      duration: const Duration(seconds: 3),
    );
  }

  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;
    _show(
      context,
      message: message,
      icon: Icons.info_rounded,
      bgColor: const Color(0xFF3B82F6),
      duration: const Duration(seconds: 2),
    );
  }

  static void showWarning(BuildContext context, String message) {
    if (!context.mounted) return;
    _show(
      context,
      message: message,
      icon: Icons.warning_rounded,
      bgColor: const Color(0xFFF59E0B),
      duration: const Duration(seconds: 3),
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color bgColor,
    required Duration duration,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: bgColor,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(40, 0, 40, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
    );
  }

  // ── Confirm Dialog ───────────────────────────────────────────────

  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    Color confirmColor = const Color(0xFFEF4444),
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel,
                style:
                    TextStyle(color: Theme.of(ctx).textTheme.bodySmall?.color)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel,
                style: TextStyle(
                    color: confirmColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

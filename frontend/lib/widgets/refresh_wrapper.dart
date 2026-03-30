// ═══════════════════════════════════════════════════════════════════
// FILE: lib/widgets/refresh_wrapper.dart
// PURPOSE: Reusable Pull-to-Refresh wrapper for any screen
// USAGE: Wrap any scrollable content with RefreshWrapper
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

class RefreshWrapper extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  const RefreshWrapper({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color ?? theme.colorScheme.primary,
      backgroundColor: theme.cardColor,
      strokeWidth: 2,
      displacement: 40,
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );
  }
}

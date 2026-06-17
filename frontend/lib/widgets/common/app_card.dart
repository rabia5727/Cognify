// ═══════════════════════════════════════════════════════════════════
// FILE: lib/widgets/app_card.dart
// CHANGES: Uses Theme.of(context) for dark mode aware colors
//          instead of hardcoded Colors.white
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool showBorder;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 20,
    this.onTap,
    this.backgroundColor,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Automatically adapts to light/dark mode
    final cardColor =
        backgroundColor ?? (isDark ? AppColors.darkSurface2 : Colors.white);

    final borderColor = showBorder
        ? (isDark ? AppColors.darkBorder : AppColors.lightGray)
        : Colors.transparent;

    final card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: isDark ? 0.8 : 1.0),
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      );
    }

    return card;
  }
}

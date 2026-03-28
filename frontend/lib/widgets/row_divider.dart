// ═══════════════════════════════════════════════════════════════════
// FILE: lib/widgets/row_divider.dart
// WHY: _RowDivider was duplicated in:
//        - settings_screen.dart
//        - profile_screen.dart
//      Now it's one widget used everywhere with customization options.
//
// USAGE:
//   const RowDivider()  // Default
//   RowDivider(indent: 0, endIndent: 0)  // Full width
//   RowDivider(height: 2, color: AppConstants.primaryBlue)  // Custom
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../constants/app_constant.dart';

class RowDivider extends StatelessWidget {
  final double height;
  final double thickness;
  final double indent;
  final double endIndent;
  final Color? color;

  const RowDivider({
    super.key,
    this.height = 1,
    this.thickness = 1,
    this.indent = 0,
    this.endIndent = 0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: height,
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
      color: color ?? AppConstants.lightGray,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FILE: lib/widgets/section_card.dart
// WHY: _SectionCard was duplicated in:
//        - settings_screen.dart
//        - profile_screen.dart
//      One widget now used in both.
//
// USAGE:
//   SectionCard(
//     title: 'Preferences',   // optional title above card
//     children: [...],
//   )
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../constants/app_constant.dart'; // ✅ Fixed import
import '../common/app_card.dart';

class SectionCard extends StatelessWidget {
  final List<Widget> children;
  final String? title; // optional label above the card

  const SectionCard({
    super.key,
    required this.children,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show title label only if provided
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title!,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppConstants.darkText, // ✅ Fixed
              ),
            ),
          ),
        ],
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

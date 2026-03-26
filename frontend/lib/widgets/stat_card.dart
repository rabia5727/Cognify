import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STAT CARD — Reusable widget for showing a single metric
// Used in Analytics screen for Focus Hours, Avg Time, Tasks Completed, etc.
//
// Usage:
//   StatCard(
//     icon: Icons.bolt_rounded,
//     iconColor: AppColors.primaryBlue,
//     value: '24.5',
//     label: 'Focus Hours',
//   )
// ─────────────────────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const StatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.grayText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

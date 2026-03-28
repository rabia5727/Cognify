import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final String userName;
  final ValueChanged<int> onTabSelected;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.userName,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: isDark ? const Color(0xFF1E1E2A) : Colors.white,
      elevation: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              isSelected: currentIndex == 0,
              onTap: () => onTabSelected(0),
            ),
            _NavItem(
              icon: Icons.bar_chart_rounded,
              label: 'Analytics',
              isSelected: currentIndex == 1,
              onTap: () => onTabSelected(1),
            ),
            const SizedBox(width: 48),
            _NavItem(
              icon: Icons.work_outline, // ✅ Self-explanatory work icon
              label: 'Workspace',
              isSelected: currentIndex == 2,
              onTap: () => onTabSelected(2),
            ),
            _NavItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              isSelected: currentIndex == 3,
              onTap: () => onTabSelected(3),
            ),
          ],
        ),
      ),
    );
  }
}

// ... _NavItem widget remains the same

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Single Nav Item
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = isSelected
        ? theme.colorScheme.primary
        : theme.textTheme.bodySmall?.color;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

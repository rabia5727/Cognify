import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/settings/settings_screen.dart';

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

  void _navigateTo(BuildContext context, int index) {
    // Only push SettingsScreen, others can use callback
    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SettingsScreen(
            currentIndex: index,
            onNavTap: onTabSelected,
            userName: userName,
          ),
        ),
      );
    } else {
      onTabSelected(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white,
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
                onTap: () => _navigateTo(context, 0)),
            _NavItem(
                icon: Icons.bar_chart_rounded,
                label: 'Analytics',
                isSelected: currentIndex == 1,
                onTap: () => _navigateTo(context, 1)),
            const SizedBox(width: 48),
            _NavItem(
                icon: Icons.task_alt_rounded,
                label: 'Tasks',
                isSelected: currentIndex == 2,
                onTap: () => _navigateTo(context, 2)),
            _NavItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                isSelected: currentIndex == 3,
                onTap: () => _navigateTo(context, 3)),
          ],
        ),
      ),
    );
  }
}

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
    final color = isSelected ? AppColors.primaryBlue : AppColors.grayText;
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

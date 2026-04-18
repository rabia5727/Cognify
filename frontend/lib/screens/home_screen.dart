// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/home_screen.dart
// CHANGES:
//   - No longer accepts `userName` as a constructor parameter
//   - Reads userName from AuthProvider instead
//   - Screens no longer receive userName as a prop (they read it themselves)
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'dashboard/dashboard_screen.dart';
import 'analytics/analytics_screen.dart';
import 'workspace/workspace_screen.dart';
import 'settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _onTabSelected(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _currentIndex,
      children: [
        DashboardScreen(
          currentIndex: _currentIndex,
          onTabSelected: _onTabSelected,
        ),
        WorkSpaceScreen(
          currentIndex: _currentIndex,
          onTabSelected: _onTabSelected,
        ),
        AnalyticsScreen(
          currentIndex: _currentIndex,
          onTabSelected: _onTabSelected,
        ),
        SettingsScreen(
          currentIndex: _currentIndex,
          onTabSelected: _onTabSelected,
        ),
      ],
    );
  }
}

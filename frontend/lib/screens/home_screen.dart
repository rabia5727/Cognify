import 'package:flutter/material.dart';
import 'dashboard/dashboard_screen.dart';
import 'analytics/analytics_screen.dart';
import 'workspace/workspace_screen.dart';
import 'settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, required this.userName});

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
          userName: widget.userName,
          currentIndex: _currentIndex,
          onTabSelected: _onTabSelected,
        ),
        AnalyticsScreen(
          userName: widget.userName,
          currentIndex: _currentIndex,
          onTabSelected: _onTabSelected,
        ),
        WorkSpaceScreen(
          userName: widget.userName,
          currentIndex: _currentIndex,
          onTabSelected: _onTabSelected,
        ),
        SettingsScreen(
          userName: widget.userName,
          currentIndex: _currentIndex,
          onTabSelected: _onTabSelected,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'dashboard/dashboard_screen.dart';
import 'settings/settings_screen.dart';
import 'analytics/analytics_screen.dart';
// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN — Root Navigator
//
// WHY THIS EXISTS:
// The bottom nav bar needs to switch between screens without pushing new
// routes on the stack (which causes the back button to go back to dashboard).
// Instead, we use an IndexedStack which keeps all screens alive and just
// shows/hides them based on the selected tab index.
//
// HOW TO NAVIGATE HERE:
// After auth is complete, push this screen:
//   Navigator.of(context).pushReplacement(
//     MaterialPageRoute(builder: (_) => HomeScreen(userName: 'Taiba')),
//   );
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final String userName;

  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Which tab is currently active (0=Dashboard, 1=Analytics, 2=Tasks, 3=Settings)
  int _currentIndex = 0;

  // Called by BottomNavBar whenever user taps a tab
  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // IndexedStack keeps all screens mounted (preserves scroll position, state)
    // but only shows the one at _currentIndex
    return IndexedStack(
      index: _currentIndex,
      children: [
        // Tab 0 — Dashboard
        DashboardScreen(
          userName: widget.userName,
          currentIndex: _currentIndex,
          onTabSelected: _onTabSelected,
        ),

        // Tab 1 — Analytics (placeholder for now)
        AnalyticsScreen(
          userName: widget.userName,
          currentIndex: _currentIndex,
          onTabSelected: _onTabSelected,
        ),

        // Tab 2 — Tasks (placeholder for now)
        _PlaceholderScreen(
          title: 'Tasks',
          icon: Icons.task_alt_rounded,
          currentIndex: _currentIndex,
          onTabSelected: _onTabSelected,
          userName: widget.userName,
        ),

        // Tab 3 — Settings
        SettingsScreen(
          userName: widget.userName,
          currentIndex: _currentIndex,
          onTabSelected: _onTabSelected,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder screen for tabs not yet built (Analytics, Tasks)
// Replace these later when you build those screens
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final String userName;

  const _PlaceholderScreen({
    required this.title,
    required this.icon,
    required this.currentIndex,
    required this.onTabSelected,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    // Import BottomNavBar here when you replace this with a real screen
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: const Color(0xFF1360E2)),
            const SizedBox(height: 16),
            Text(
              '$title coming soon!',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

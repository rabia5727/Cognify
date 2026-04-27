// ═══════════════════════════════════════════════════════════════════
// FILE: lib/main.dart
// CHANGES:
//   - MultiProvider wraps the entire app
//   - AuthProvider.checkSession() called at startup
//   - Router decides between AuthScreen and HomeScreen
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'providers/project_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'services/api_service.dart';
import 'widgets/common/notification_permission_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CognifyApp());
}

class CognifyApp extends StatelessWidget {
  const CognifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (_, mode, __) => MaterialApp(
          navigatorKey: ApiService.navigatorKey,
          title: 'Cognify',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          debugShowCheckedModeBanner: false,
          home: const _AppEntryPoint(),
        ),
      ),
    );
  }
}

/// Decides which screen to show based on auth state.
/// This replaces hardcoded navigation in your old main.dart.
class _AppEntryPoint extends StatefulWidget {
  const _AppEntryPoint();

  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  @override
  void initState() {
    super.initState();
    // Check stored session on app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        switch (auth.authState) {
          case AuthState.unknown:
            // Still checking stored token — show splash
            return const SplashScreen();

          case AuthState.authenticated:
            // Load data then show home
            return _DataLoader(child: const HomeScreen());

          case AuthState.unauthenticated:
            return const AuthScreen();
        }
      },
    );
  }
}

/// Triggers data loading when user is authenticated.
/// Wrap HomeScreen in this so tasks/projects load before UI renders.
class _DataLoader extends StatefulWidget {
  final Widget child;
  const _DataLoader({required this.child});

  @override
  State<_DataLoader> createState() => _DataLoaderState();
}

// main.dart — REPLACE _DataLoaderState entirely

class _DataLoaderState extends State<_DataLoader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ↑ ADD async here — this is the fix

      context.read<TaskProvider>().refreshTasks();
      context.read<ProjectProvider>().refreshProjects();
      context.read<AnalyticsProvider>().loadSummary();

      final notifProvider = context.read<NotificationProvider>();
      final userId = context.read<AuthProvider>().user?.id ?? '';
      notifProvider.setCurrentUser(userId);

      // Check permission BEFORE loading enabled state so settings
      // doesn't flash "on" for users who haven't been asked yet.
      final alreadyAsked = await notifProvider.hasAskedPermission();
      if (!alreadyAsked && mounted) {
        await showNotificationPermissionSheet(context);
        // Safety net: mark asked if user dismissed without tapping a button
        await notifProvider.markPermissionAsked();
        // Skip loadEnabledState — the sheet's button already called setEnabled
        // with the user's choice; reloading would overwrite it with the backend default
      } else {
        await notifProvider.loadEnabledState();
      }
      await notifProvider.refreshAndFetch();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

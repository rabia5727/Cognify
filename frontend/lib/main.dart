// ═══════════════════════════════════════════════════════════════════
// FILE: lib/main.dart
// MERGED:
//   - YOUR branch: async _DataLoaderState, notification permission sheet,
//     refreshTasks/refreshProjects/loadSummary
//   - TEAMMATE's branch: ClassroomProvider + ProxyProvider for analytics
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/sync_service.dart';
import 'providers/analytics_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/classroom_provider.dart'; // ← Only ONE import
import 'providers/gmail_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/project_provider.dart';
import 'providers/task_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';
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
        ChangeNotifierProvider(
            create: (_) => ClassroomProvider()), // TEAMMATE's branch

        // AnalyticsProvider - no ProxyProvider needed since it loads its own data
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => GmailProvider()), // YOUR branch
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
class _AppEntryPoint extends StatefulWidget {
  const _AppEntryPoint();

  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  @override
  void initState() {
    super.initState();
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
            return const SplashScreen();
          case AuthState.authenticated:
            return _DataLoader(child: const HomeScreen());
          case AuthState.unauthenticated:
            return const AuthScreen();
        }
      },
    );
  }
}

/// Triggers all data loading when user is authenticated.
class _DataLoader extends StatefulWidget {
  final Widget child;
  const _DataLoader({required this.child});

  @override
  State<_DataLoader> createState() => _DataLoaderState();
}

class _DataLoaderState extends State<_DataLoader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // YOUR branch: refresh methods + analytics summary
      await context.read<TaskProvider>().refreshTasks();
      await context.read<ProjectProvider>().refreshProjects();
      await context.read<AnalyticsProvider>().loadSummary();

      // TEAMMATE's branch: load classroom courses on startup
      context.read<ClassroomProvider>().loadCourses();
      SyncService.startAutoSync(context);

      // YOUR branch: notification permission flow
      final notifProvider = context.read<NotificationProvider>();
      final userId = context.read<AuthProvider>().user?.id ?? '';
      notifProvider.setCurrentUser(userId);

      final alreadyAsked = await notifProvider.hasAskedPermission();
      if (!alreadyAsked && mounted) {
        await showNotificationPermissionSheet(context);
        await notifProvider.markPermissionAsked();
      } else {
        await notifProvider.loadEnabledState();
      }
      await notifProvider.refreshAndFetch();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

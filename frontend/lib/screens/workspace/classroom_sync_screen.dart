import 'package:flutter/material.dart';
import 'package:frontend/screens/workspace/classroom_course_tile.dart';
import 'package:frontend/widgets/empty_states/classroom_empty_state.dart';
import 'package:provider/provider.dart';
import '../../services/google_classroom_service.dart';
import '../../services/oauth_webview.dart';
import '../../providers/classroom_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/app_header.dart';

class ClassroomSyncScreen extends StatefulWidget {
  const ClassroomSyncScreen({super.key});

  @override
  State<ClassroomSyncScreen> createState() => _ClassroomSyncScreenState();
}

class _ClassroomSyncScreenState extends State<ClassroomSyncScreen> {
  bool _isCheckingConnection = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<ClassroomProvider>();
    await provider.loadCourses();
  }

  Future<void> _syncAll() async {
    final provider = context.read<ClassroomProvider>();

    try {
      final result = await provider.syncAllAssignments(context);

      // Refresh tasks after sync
      await context.read<TaskProvider>().refreshTasks();

      // Show notification for new tasks
      if (result['new_tasks_count'] > 0) {
        await NotificationService.createNotification(
          title: '📚 New Assignments Synced!',
          message:
              '${result['new_tasks_count']} new assignments added to your tasks',
          type: 'classroom_batch',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Sync completed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleCourse(String courseId, bool enabled) async {
    final provider = context.read<ClassroomProvider>();
    await provider.toggleCourseSync(courseId, enabled);
  }

  Future<void> _archiveCourse(String courseId) async {
    final provider = context.read<ClassroomProvider>();
    await provider.archiveCourse(courseId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Course archived'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // NEW: Proper OAuth flow using WebView
  Future<void> _startOAuthConnect() async {
    final provider = context.read<ClassroomProvider>();

    try {
      // Show loading indicator
      setState(() => _isCheckingConnection = true);

      // Get OAuth URL from backend
      final authData = await GoogleClassroomService.getMobileAuthUrl();
      final authUrl = authData['auth_url']!;
      final state = authData['state']!;

      setState(() => _isCheckingConnection = false);

      // Open WebView for authentication
      final success = await OAuthWebView.authenticateWithGoogle(
        context,
        authUrl: authUrl,
        state: state,
        healthEndpoint: '/classroom/health',
      );

      if (success) {
        // Reload courses after successful connection
        await provider.loadCourses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully connected to Google Classroom!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Authentication failed or was cancelled');
      }
    } catch (e) {
      setState(() => _isCheckingConnection = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Check connection status and show appropriate empty state
  Future<void> _checkAndShowEmptyState() async {
    final provider = context.read<ClassroomProvider>();
    final isConnected = await GoogleClassroomService.isConnected();

    if (!isConnected && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Google Classroom',
              onBack: () => Navigator.pop(context),
            ),

            // Sync All Button - Only show if courses exist
            Consumer<ClassroomProvider>(
              builder: (context, provider, _) {
                if (provider.courses.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: provider.isSyncing ? null : _syncAll,
                    icon: provider.isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(
                      provider.isSyncing ? 'Syncing...' : 'Sync All Courses',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                );
              },
            ),

            if (context.watch<ClassroomProvider>().courses.isNotEmpty)
              const Divider(),

            // Courses List or Empty State
            Expanded(
              child: Consumer<ClassroomProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Show empty state when no courses
                  if (provider.courses.isEmpty) {
                    return FutureBuilder<bool>(
                      future: GoogleClassroomService.isConnected(),
                      builder: (context, snapshot) {
                        final isConnected = snapshot.data ?? false;
                        return ClassroomEmptyState(
                          isConnected: isConnected,
                          onConnect: _startOAuthConnect,
                        );
                      },
                    );
                  }

                  // Show courses list
                  return RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: provider.courses.length,
                      itemBuilder: (context, index) {
                        final course = provider.courses[index];
                        return ClassroomCourseTile(
                          course: course,
                          isEnabled: course['enabled'] ?? false,
                          onToggle: () => _toggleCourse(
                            course['id'],
                            !(course['enabled'] ?? false),
                          ),
                          onArchive: () => _archiveCourse(course['id']),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

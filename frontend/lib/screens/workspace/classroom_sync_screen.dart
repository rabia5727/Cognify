import 'package:flutter/material.dart';
import 'package:frontend/screens/workspace/classroom_course_tile.dart';
import 'package:frontend/widgets/empty_states/classroom_empty_state.dart';
import 'package:provider/provider.dart';
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
  @override
  void initState() {
    super.initState();
    _loadData();
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
          message: '${result['new_tasks_count']} new assignments added to your tasks',
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Course archived'), backgroundColor: Colors.green),
    );
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
            
            // Sync All Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Consumer<ClassroomProvider>(
                builder: (context, provider, _) {
                  return ElevatedButton.icon(
                    onPressed: provider.isSyncing ? null : _syncAll,
                    icon: provider.isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(provider.isSyncing ? 'Syncing...' : 'Sync All Courses'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  );
                },
              ),
            ),
            
            const Divider(),
            
            // Courses List
            Expanded(
              child: Consumer<ClassroomProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (provider.courses.isEmpty) {
                    return ClassroomEmptyState(
                      isConnected: false,
                      onConnect: () {
                        // TODO: Implement Google OAuth connection
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Google OAuth coming soon!')),
                        );
                      },
                    );
                  }
                  
                  return RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: provider.courses.length,
                      itemBuilder: (context, index) {
                        final course = provider.courses[index];
                        return ClassroomCourseTile(
                          course: course,
                          isEnabled: course['enabled'] ?? false,
                          onToggle: () => _toggleCourse(course['id'], !(course['enabled'] ?? false)),
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
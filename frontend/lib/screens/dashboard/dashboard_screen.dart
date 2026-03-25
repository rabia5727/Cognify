import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/app_card.dart'; // Import reusable card

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class Task {
  final String id;
  final String title;
  final DateTime dueDate;
  final String priority;
  bool isCompleted;

  Task({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.priority,
    this.isCompleted = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN DASHBOARD SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  final String userName;
  const DashboardScreen({super.key, required this.userName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedNavIndex = 0;
  bool _showProactiveCard = true;

  final List<Task> _tasks = [
    Task(
      id: '1',
      title: 'Complete Maths Assignment',
      dueDate: DateTime.now().copyWith(hour: 22, minute: 0),
      priority: 'high',
    ),
    Task(
      id: '2',
      title: 'Review Pull Requests',
      dueDate: DateTime.now().copyWith(hour: 18, minute: 30),
      priority: 'medium',
    ),
  ];

  bool get _isNewUser => _tasks.isEmpty;
  int get _completedCount => _tasks.where((t) => t.isCompleted).length;
  double get _productivityScore =>
      _tasks.isEmpty ? 0.0 : _completedCount / _tasks.length;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _markTaskComplete(String taskId) {
    setState(() {
      final task = _tasks.firstWhere((t) => t.id == taskId);
      task.isCompleted = true;
    });
  }

  void _dismissProactiveCard() {
    setState(() => _showProactiveCard = false);
  }

  void _addTask() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add Task screen coming soon!')),
    );
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedNavIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _HeaderBanner(
              greeting: _greeting,
              userName: widget.userName,
              isNewUser: _isNewUser,
              showProactiveCard: _showProactiveCard,
              onYes: _dismissProactiveCard,
              onNo: _dismissProactiveCard,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Priorities",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 165,
                      child: _isNewUser
                          ? _EmptyTaskArea(onAddTask: _addTask)
                          : _TaskList(
                              tasks: _tasks,
                              onStartTask: _markTaskComplete,
                            ),
                    ),
                    const SizedBox(height: 16),
                    _ProductivityCard(
                      score: _productivityScore,
                      completedCount: _completedCount,
                      totalCount: _tasks.length,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const _VoiceFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedNavIndex,
        userName: widget.userName,
        onTabSelected: _onTabSelected,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Header Banner
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderBanner extends StatelessWidget {
  final String greeting;
  final String userName;
  final bool isNewUser;
  final bool showProactiveCard;
  final VoidCallback onYes;
  final VoidCallback onNo;

  const _HeaderBanner({
    required this.greeting,
    required this.userName,
    required this.isNewUser,
    required this.showProactiveCard,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1360E2), Color(0xFF4DA3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNewUser ? 'Welcome to\nCo-tasker' : '$greeting,',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    if (!isNewUser)
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppCard(
            child: isNewUser
                ? const _NewUserMessage()
                : _ReturningUserMessage(
                    showButtons: showProactiveCard,
                    onYes: onYes,
                    onNo: onNo,
                  ),
          ),
        ],
      ),
    );
  }
}

class _NewUserMessage extends StatelessWidget {
  const _NewUserMessage();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome to Co-tasker',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "I'm here to help you stay organized, motivated, and kind to yourself along the way.",
          style: TextStyle(
            fontSize: 13,
            color: AppColors.grayText,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _ReturningUserMessage extends StatelessWidget {
  final bool showButtons;
  final VoidCallback onYes;
  final VoidCallback onNo;

  const _ReturningUserMessage({
    required this.showButtons,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'You have a quiz due today. Would you like me to help prepare it?',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.grayText,
            height: 1.5,
          ),
        ),
        if (showButtons) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onYes,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Yes',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onNo,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    minimumSize: const Size(0, 40),
                    side: const BorderSide(
                        color: AppColors.primaryBlue, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'No',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Empty Task Area
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyTaskArea extends StatelessWidget {
  final VoidCallback onAddTask;

  const _EmptyTaskArea({
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAddTask,
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              'Add a high-priority task',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.grayText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Task List
// ─────────────────────────────────────────────────────────────────────────────

class _TaskList extends StatelessWidget {
  final List<Task> tasks;
  final Function(String) onStartTask;

  const _TaskList({
    required this.tasks,
    required this.onStartTask,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) => _TaskCard(
        task: tasks[index],
        onStart: () => onStartTask(tasks[index].id),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Task Card
// ─────────────────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onStart;

  const _TaskCard({
    required this.task,
    required this.onStart,
  });

  Color get _priorityColor {
    switch (task.priority) {
      case 'high':
        return const Color(0xFFFF5252);
      case 'medium':
        return AppColors.orange;
      default:
        return Colors.green;
    }
  }

  String get _dueTime {
    final h = task.dueDate.hour;
    final m = task.dueDate.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'pm' : 'am';
    final display = h > 12 ? h - 12 : h;
    return 'Due $display:${m}$period';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 165,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _priorityColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  task.priority,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _priorityColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 13, color: AppColors.grayText),
                const SizedBox(width: 4),
                Text(
                  _dueTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.grayText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: task.isCompleted ? null : onStart,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: task.isCompleted
                      ? Colors.green.withOpacity(0.1)
                      : AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  task.isCompleted ? 'Done ✓' : 'Start Task >',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        task.isCompleted ? Colors.green : AppColors.primaryBlue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Productivity Card
// ─────────────────────────────────────────────────────────────────────────────

class _ProductivityCard extends StatelessWidget {
  final double score;
  final int completedCount;
  final int totalCount;

  const _ProductivityCard({
    required this.score,
    required this.completedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (score * 100).toInt();

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 11,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.lightGray),
                  ),
                ),
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: score,
                    strokeWidth: 11,
                    strokeCap: StrokeCap.round,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryBlue),
                  ),
                ),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PRODUCTIVITY SCORE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  score == 0
                      ? 'Start completing tasks and tracking focus, your score will update as you grow.'
                      : score >= 0.8
                          ? 'Bravo! Keep it up, you are almost done for today.'
                          : 'Good progress! Keep going, you are doing great.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.grayText,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 5),
                    Text(
                      '$completedCount/$totalCount Completed',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Voice FAB
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceFAB extends StatelessWidget {
  const _VoiceFAB();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice recording coming soon!')),
          );
        },
        backgroundColor: AppColors.primaryBlue,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 32),
      ),
    );
  }
}

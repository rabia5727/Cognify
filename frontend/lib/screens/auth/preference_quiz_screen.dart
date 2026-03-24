import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../permission/permission_screen.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

class UserPreferences {
  List<String> goals = [];
  String scheduleType = '';
  int dailyTaskLoad = 5;
  String productivityChallenge = '';
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class PreferenceQuizScreen extends StatefulWidget {
  final String userName;
  const PreferenceQuizScreen({super.key, required this.userName});

  @override
  State<PreferenceQuizScreen> createState() => _PreferenceQuizScreenState();
}

class _PreferenceQuizScreenState extends State<PreferenceQuizScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final UserPreferences _prefs = UserPreferences();
  final int _totalPages = 4;

  void _next() {
    // Validate current page before proceeding
    if (!_isCurrentPageValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please make a selection to continue'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryBlue,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _isCurrentPageValid() {
    switch (_currentPage) {
      case 0:
        return _prefs.goals.isNotEmpty;
      case 1:
        return _prefs.scheduleType.isNotEmpty;
      case 2:
        return true; // Slider always has a value
      case 3:
        return _prefs.productivityChallenge.isNotEmpty;
      default:
        return true;
    }
  }

  void _finish() {
    // Navigate to Permission screen, passing prefs and userName
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PermissionScreen(
          userName: widget.userName,
          preferences: _prefs,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top bar: back + progress bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Row(
                  children: [
                    // Back button
                    if (_currentPage > 0)
                      GestureDetector(
                        onTap: _back,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              size: 16, color: AppColors.primaryBlue),
                        ),
                      )
                    else
                      const SizedBox(width: 40),

                    const SizedBox(width: 12),

                    // Progress bar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_currentPage + 1} of $_totalPages',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.grayText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (_currentPage + 1) / _totalPages,
                              backgroundColor: const Color(0xFFE8F0FE),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryBlue),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    // Q1 — Goals (multi-select chips)
                    _QuestionPage(
                      questionNumber: '01',
                      question: 'What are your main goals?',
                      subtitle: 'Select all that apply',
                      child: _GoalsQuestion(
                        selected: _prefs.goals,
                        onChanged: (val) => setState(() => _prefs.goals = val),
                      ),
                    ),

                    // Q2 — Schedule type (single-select cards)
                    _QuestionPage(
                      questionNumber: '02',
                      question: 'How would you describe your schedule?',
                      subtitle: 'Pick the one that fits you best',
                      child: _ScheduleQuestion(
                        selected: _prefs.scheduleType,
                        onChanged: (val) =>
                            setState(() => _prefs.scheduleType = val),
                      ),
                    ),

                    // Q3 — Daily task load (slider)
                    _QuestionPage(
                      questionNumber: '03',
                      question: 'How many tasks do you handle per day?',
                      subtitle: 'Drag the slider to your average',
                      child: _TaskLoadQuestion(
                        value: _prefs.dailyTaskLoad,
                        onChanged: (val) =>
                            setState(() => _prefs.dailyTaskLoad = val),
                      ),
                    ),

                    // Q4 — Biggest challenge (single-select chips)
                    _QuestionPage(
                      questionNumber: '04',
                      question: "What's your biggest productivity challenge?",
                      subtitle: 'Be honest — CoCo is here to help!',
                      child: _ChallengeQuestion(
                        selected: _prefs.productivityChallenge,
                        onChanged: (val) =>
                            setState(() => _prefs.productivityChallenge = val),
                      ),
                    ),
                  ],
                ),
              ),

              // Next button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: PrimaryButton(
                  label:
                      _currentPage == _totalPages - 1 ? "All Done 🎉" : 'Next',
                  onPressed: _next,
                ),
              ),

              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Question page wrapper ────────────────────────────────────────────────────

class _QuestionPage extends StatelessWidget {
  final String questionNumber;
  final String question;
  final String subtitle;
  final Widget child;

  const _QuestionPage({
    required this.questionNumber,
    required this.question,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question number badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Question $questionNumber',
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Question text
          Text(
            question,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: AppColors.grayText),
          ),
          const SizedBox(height: 32),

          // Answer widget
          child,
        ],
      ),
    );
  }
}

// ─── Q1: Goals — multi-select grid chips ─────────────────────────────────────

class _GoalsQuestion extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const _GoalsQuestion({required this.selected, required this.onChanged});

  static const _options = [
    _GoalOption('💼', 'Work', 'Career & professional tasks'),
    _GoalOption('📚', 'Study', 'Learning & academics'),
    _GoalOption('🏠', 'Personal', 'Home & life management'),
    _GoalOption('🏃', 'Health', 'Fitness & wellbeing'),
    _GoalOption('💡', 'Creativity', 'Projects & side hustles'),
    _GoalOption('👨‍👩‍👧', 'Family', 'Family & relationships'),
  ];

  void _toggle(String val) {
    final updated = List<String>.from(selected);
    if (updated.contains(val)) {
      updated.remove(val);
    } else {
      updated.add(val);
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: _options.map((opt) {
        final isSelected = selected.contains(opt.label);
        return GestureDetector(
          onTap: () => _toggle(opt.label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isSelected ? AppColors.primaryBlue : const Color(0xFFF5F7FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryBlue
                    : const Color(0xFFE0E7FF),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(opt.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  opt.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isSelected ? Colors.white : AppColors.darkText,
                  ),
                ),
                Text(
                  opt.sublabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? Colors.white70 : AppColors.grayText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GoalOption {
  final String emoji;
  final String label;
  final String sublabel;
  const _GoalOption(this.emoji, this.label, this.sublabel);
}

// ─── Q2: Schedule type — single-select cards ─────────────────────────────────

class _ScheduleQuestion extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _ScheduleQuestion({required this.selected, required this.onChanged});

  static const _options = [
    _ScheduleOption(
        '🌅', 'Early Bird', 'Most productive in the morning (5am–12pm)'),
    _ScheduleOption(
        '☀️', 'Day Warrior', 'Peak performance during the day (12pm–6pm)'),
    _ScheduleOption(
        '🌙', 'Night Owl', 'Best work happens late at night (6pm–2am)'),
    _ScheduleOption(
        '🔀', 'Flexible', 'Productivity shifts depending on the day'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _options.map((opt) {
        final isSelected = selected == opt.label;
        return GestureDetector(
          onTap: () => onChanged(opt.label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color:
                  isSelected ? AppColors.primaryBlue : const Color(0xFFF5F7FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryBlue
                    : const Color(0xFFE0E7FF),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Text(opt.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opt.label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isSelected ? Colors.white : AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        opt.description,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isSelected ? Colors.white70 : AppColors.grayText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ScheduleOption {
  final String emoji;
  final String label;
  final String description;
  const _ScheduleOption(this.emoji, this.label, this.description);
}

// ─── Q3: Daily task load — slider ────────────────────────────────────────────

class _TaskLoadQuestion extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _TaskLoadQuestion({required this.value, required this.onChanged});

  String get _label {
    if (value <= 3) return 'Light 🌿';
    if (value <= 6) return 'Moderate ⚡';
    if (value <= 9) return 'Heavy 🔥';
    return 'Intense 💪';
  }

  String get _description {
    if (value <= 3) return 'Taking it easy, focusing on quality';
    if (value <= 6) return 'Balanced workload, steady progress';
    if (value <= 9) return 'Busy schedule, high output';
    return 'Maximum productivity mode!';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Big number display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE0E7FF), width: 1.5),
          ),
          child: Column(
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'tasks per day',
                style: const TextStyle(color: AppColors.grayText, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _label,
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primaryBlue,
            inactiveTrackColor: const Color(0xFFE0E7FF),
            thumbColor: AppColors.primaryBlue,
            overlayColor: AppColors.primaryBlue.withOpacity(0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 26),
            trackHeight: 6,
          ),
          child: Slider(
            value: value.toDouble(),
            min: 1,
            max: 12,
            divisions: 11,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),

        // Min / Max labels
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1', style: TextStyle(color: AppColors.grayText)),
              Text('12', style: TextStyle(color: AppColors.grayText)),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          _description,
          style: const TextStyle(color: AppColors.grayText, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Q4: Biggest challenge — single-select chips ─────────────────────────────

class _ChallengeQuestion extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _ChallengeQuestion({required this.selected, required this.onChanged});

  static const _options = [
    _ChallengeOption(
        '😵‍💫', 'Staying focused', 'Too many distractions around me'),
    _ChallengeOption('⏰', 'Time management', 'Never enough time in the day'),
    _ChallengeOption(
        '😩', 'Procrastination', 'Starting tasks is the hardest part'),
    _ChallengeOption(
        '🤯', 'Overwhelm', 'Too many tasks, don\'t know where to start'),
    _ChallengeOption('😴', 'Low energy', 'Burnout and motivation dips'),
    _ChallengeOption('📋', 'Poor planning', 'Hard to organize and prioritize'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _options.map((opt) {
        final isSelected = selected == opt.label;
        return GestureDetector(
          onTap: () => onChanged(opt.label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color:
                  isSelected ? AppColors.primaryBlue : const Color(0xFFF5F7FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryBlue
                    : const Color(0xFFE0E7FF),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Text(opt.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opt.label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isSelected ? Colors.white : AppColors.darkText,
                        ),
                      ),
                      Text(
                        opt.description,
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              isSelected ? Colors.white70 : AppColors.grayText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChallengeOption {
  final String emoji;
  final String label;
  final String description;
  const _ChallengeOption(this.emoji, this.label, this.description);
}

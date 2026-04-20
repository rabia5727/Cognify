import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/auth_components.dart';
import 'questionaire/preference_quiz_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final String userName;
  const OnboardingScreen({super.key, required this.userName});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final List<_OnboardingData> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _OnboardingData(
        topType: _TopType.welcomeWithCoco,
        cardIcon: Icons.auto_awesome,
        cardTitle: 'Smart AI Assistant',
        cardSubtitle: 'Intelligent task suggestion and execution.',
      ),
      _OnboardingData(
        topType: _TopType.robotOnly,
        cardIcon: Icons.check_circle_outline_rounded,
        cardTitle: 'Task Management',
        cardSubtitle: 'Seamless organization and tracking of tasks.',
      ),
      _OnboardingData(
        topType: _TopType.robotOnly,
        cardIcon: Icons.trending_up_rounded,
        cardTitle: 'Analytics and Insights',
        cardSubtitle: 'Understand your productivity patterns.',
      ),
      _OnboardingData(
        topType: _TopType.questionPrompt,
        cardIcon: Icons.question_answer_rounded,
        cardTitle: 'Quick Questions',
        cardSubtitle: 'Let me ask you few questions before we start, shall we?',
      ),
    ];
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _goToQuiz();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
    else{
      // on first page, go back to name screen
      Navigator.pop(context);
    }
  }

  void _goToQuiz() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            PreferenceQuizScreen(userName: widget.userName),
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
          child: Column(
            children: [
              // Top row with back button (only on pages > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    if (_currentPage > 0)// only show on pages after the first one
                      GestureDetector(
                        onTap: _previousPage,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 16,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      )
                      else 
                      const SizedBox(width: 40), // placeholder to keep title centered
                    const Spacer(),
                  ],
                ),
              ),

              // Page content - Expanded with MainAxisAlignment.center
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) => _buildPage(_pages[i]),
                ),
              ),

              // Dot indicators
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == i
                            ? AppColors.primaryBlue
                            : AppColors.lightGray,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),

              // Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: PrimaryButton(
                  label: _currentPage == _pages.length - 1
                      ? "Let's Get Started"
                      : 'Next',
                  onPressed: _nextPage,
                ),
              ),

              SizedBox(
                height: MediaQuery.of(context).padding.bottom + 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,  // ← CENTER VERTICALLY
        children: [
          _buildTopSection(data.topType),
          // only show feature card if not question prompt page
          if (data.topType != _TopType.questionPrompt) ...[
          const SizedBox(height: 40),
          _FeatureCard(
            icon: data.cardIcon,
            title: data.cardTitle,
            subtitle: data.cardSubtitle,
          ),
        ],
        ],
      ),
    );
  }

  Widget _buildTopSection(_TopType type) {
    switch (type) {
      case _TopType.welcomeWithCoco:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF0F4FF),
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 52)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Hey ${widget.userName}, I\'m Coco',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nice to meet you! I\'m your AI Productivity Assistant',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.grayText),
            ),
          ],
        );

      case _TopType.robotOnly:
        return Center(
          child: Container(
            width: 150,
            height: 150,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF0F4FF),
            ),
            child: const Center(
              child: Text('🤖', style: TextStyle(fontSize: 76)),
            ),
          ),
        );

      case _TopType.questionPrompt:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            //large robot icon 
            Container(
              width: 160,
              height: 160,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              color: Color(0xFFF0F4FF),
            ),
            child: const Center(
              child: Text('🤖', style: TextStyle(fontSize: 64)),
            ),
          ),
          const Text(
            'Quick Questions',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize:20,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 12),
      const Text(
        'Let me ask you few questions\nbefore we start, shall we?',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          color: AppColors.grayText,
          height: 1.4,
          
        ),
        ),
        ],
        );
    }
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

enum _TopType { welcomeWithCoco, robotOnly, questionPrompt }

class _OnboardingData {
  final _TopType topType;
  final IconData cardIcon;
  final String cardTitle;
  final String cardSubtitle;

  const _OnboardingData({
    required this.topType,
    required this.cardIcon,
    required this.cardTitle,
    required this.cardSubtitle,
  });
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.grayText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
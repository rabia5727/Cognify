import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../dashboard/dashboard_screen.dart';
import 'preference_quiz_screen.dart';

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
        topType: _TopType.nameGreeting,
        cardIcon: Icons.auto_awesome,
        cardTitle: 'Smart AI Assistant',
        cardSubtitle: 'Intelligent task suggestion and execution.',
      ),
      _OnboardingData(
        topType: _TopType.cocoIntro,
        cardIcon: Icons.check_circle_outline_rounded,
        cardTitle: 'Task Management',
        cardSubtitle: 'Seamless organization and tracking of tasks.',
      ),
      _OnboardingData(
        topType: _TopType.mascotLarge,
        cardIcon: Icons.trending_up_rounded,
        cardTitle: 'Analytics and Insights',
        cardSubtitle: 'Understand your productivity patterns.',
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
      _goToDashboard();
    }
  }

  void _goToDashboard() {
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
          bottom: false,
          child: Column(
            children: [
              // Skip button top right
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: TextButton(
                    onPressed: _goToDashboard,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: AppColors.grayText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              // PageView
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
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

              // Bottom padding respecting system nav bar — no yellow line
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildTopSection(data.topType),
          const Spacer(),
          _FeatureCard(
            icon: data.cardIcon,
            title: data.cardTitle,
            subtitle: data.cardSubtitle,
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildTopSection(_TopType type) {
    switch (type) {
      case _TopType.nameGreeting:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _SmallMascot(),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, ${widget.userName}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Meet your AI productivity partner',
                  style: TextStyle(fontSize: 13, color: AppColors.grayText),
                ),
              ],
            ),
          ],
        );

      case _TopType.cocoIntro:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _SmallMascot(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hey ${widget.userName}, I'm CoCo",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Nice to meet you! I'm your AI Productivity Assistant",
                    style: TextStyle(fontSize: 13, color: AppColors.grayText),
                  ),
                ],
              ),
            ),
          ],
        );

      case _TopType.mascotLarge:
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
    }
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

enum _TopType { nameGreeting, cocoIntro, mascotLarge }

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

class _SmallMascot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF0F4FF),
      ),
      child: const Center(
        child: Text('🤖', style: TextStyle(fontSize: 36)),
      ),
    );
  }
}

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
          // Icon box
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
          // Text
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

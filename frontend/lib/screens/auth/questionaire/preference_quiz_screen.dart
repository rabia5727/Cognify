import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/auth_components.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/user_service.dart';
import '../../../models/user_model.dart';
import '../../../services/token_storage.dart';
import 'q1_goals_screen.dart';
import 'q2_schedule_screen.dart';
import 'q3_taskload_screen.dart';
import 'q4_challenges_screen.dart';
import '../../../utils/ui_feedback.dart';

class UserPreferences {
  List<String> goals = [];
  List<String> scheduleType = [];
  int dailyTaskLoad = 5;
  List<String> productivityChallenge = [];
}

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

  bool _isCurrentPageValid() {
    switch (_currentPage) {
      case 0:
        return _prefs.goals.length >= 1 && _prefs.goals.length <= 2;
      case 1:
        return _prefs.scheduleType.isNotEmpty;
      case 2:
        return true;
      case 3:
        return _prefs.productivityChallenge.isNotEmpty;
      default:
        return true;
    }
  }

  String? _getValidationMessage() {
    switch (_currentPage) {
      case 0:
        if (_prefs.goals.isEmpty) {
          return 'Please select at least one goal';
        }
        if (_prefs.goals.length > 2) {
          return 'Please select at most 2 goals';
        }
        return null;
      case 1:
        if (_prefs.scheduleType.isEmpty) {
          return 'Please select your schedule type';
        }
        return null;
      case 3:
        if (_prefs.productivityChallenge.isEmpty) {
          return 'Please select your productivity challenge';
        }
        return null;
      default:
        return null;
    }
  }

  void _next() {
    if (!mounted) return;

    final validationMessage = _getValidationMessage();

    if (validationMessage != null) {
      UIFeedback.showInfo(context, validationMessage);
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

  void _skip() {
    if (!mounted) return;

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
    if (!mounted) return;

    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    //save quiz preferences to backend
    await UserService.saveQuizPreferences(
      goals: _prefs.goals,
      scheduleType: _prefs.scheduleType,
      dailyTaskLoad: _prefs.dailyTaskLoad,
      productivityChallenges: _prefs.productivityChallenge,
    );
    final profile = await UserService.getProfile();
    final token = await TokenStorage.getToken() ?? '';

    if (!mounted) return;

    context.read<AuthProvider>().onLoginSuccess(
          UserModel(
            id: profile?['id'] ?? '',
            name: profile?['name'] ?? widget.userName,
            email: profile?['email'] ?? '',
          ),
          token,
        );

    // Pop all pushed routes back to _AppEntryPoint, which now shows HomeScreen
    Navigator.of(context).popUntil((route) => route.isFirst);
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
              // Top bar: back + progress indicator
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Row(
                  children: [
                    // Back button (only on pages > 0)
                    if (_currentPage > 0)
                      GestureDetector(
                        onTap: _back,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              size: 16, color: AppColors.primaryBlue),
                        ),
                      ),
                    if (_currentPage > 0) const SizedBox(width: 12),

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
                  onPageChanged: (i) {
                    if (mounted) {
                      setState(() => _currentPage = i);
                    }
                  },
                  children: [
                    Q1GoalsScreen(
                      selected: _prefs.goals,
                      onChanged: (val) {
                        if (mounted) {
                          setState(() => _prefs.goals = val);
                        }
                      },
                    ),
                    Q2ScheduleScreen(
                      selected: _prefs.scheduleType,
                      onChanged: (val) {
                        if (mounted) {
                          setState(() => _prefs.scheduleType = val);
                        }
                      },
                    ),
                    Q3TaskloadScreen(
                      value: _prefs.dailyTaskLoad,
                      onChanged: (val) {
                        if (mounted) {
                          setState(() => _prefs.dailyTaskLoad = val);
                        }
                      },
                    ),
                    Q4ChallengesScreen(
                      selected: _prefs.productivityChallenge,
                      onChanged: (val) {
                        if (mounted) {
                          setState(() => _prefs.productivityChallenge = val);
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Next Button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                child: PrimaryButton(
                  label: _currentPage == _totalPages - 1 ? "All Done" : 'Next',
                  onPressed: _next,
                ),
              ),

              // Skip Button (BELOW Next button)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: AppColors.grayText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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

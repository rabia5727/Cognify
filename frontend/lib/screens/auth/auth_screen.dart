import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../utils/ui_feedback.dart';
import '../../widgets/common_widgets.dart';
import '../dashboard/dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;

  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  // Password strength
  String? _passwordStrength;
  Color _strengthColor = Colors.grey;
  List<String> _passwordSuggestions = [];

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();

    // Add password listener for signup
    _passwordController.addListener(_checkPasswordStrength);
  }

  void _checkPasswordStrength() {
    final password = _passwordController.text;
    final suggestions = <String>[];
    int score = 0;

    setState(() {
      if (password.isEmpty) {
        _passwordStrength = null;
        _strengthColor = Colors.grey;
        _passwordSuggestions = [];
        return;
      }

      // Length check
      if (password.length >= 8) {
        score++;
      } else {
        suggestions.add('Use at least 8 characters');
      }

      // Uppercase check
      if (password.contains(RegExp(r'[A-Z]'))) {
        score++;
      } else {
        suggestions.add('Add uppercase letters');
      }

      // Lowercase check
      if (password.contains(RegExp(r'[a-z]'))) {
        score++;
      } else {
        suggestions.add('Add lowercase letters');
      }

      // Number check
      if (password.contains(RegExp(r'[0-9]'))) {
        score++;
      } else {
        suggestions.add('Add numbers');
      }

      // Special character check
      if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
        score++;
      } else {
        suggestions.add('Add special characters (!@#\$%^&*)');
      }

      // Set strength based on score
      if (score <= 2) {
        _passwordStrength = 'Weak';
        _strengthColor = Colors.red;
      } else if (score <= 4) {
        _passwordStrength = 'Medium';
        _strengthColor = Colors.orange;
      } else {
        _passwordStrength = 'Strong';
        _strengthColor = Colors.green;
      }

      _passwordSuggestions = suggestions;
    });
  }

  void _toggleTab(bool isLogin) {
    _animController.reverse().then((_) {
      setState(() {
        _isLogin = isLogin;
        // Clear password strength when switching to login
        if (isLogin) {
          _passwordStrength = null;
          _passwordSuggestions = [];
        }
      });
      _animController.forward();
    });
  }

  void _handleSubmit() async {
    // Validate based on current tab
    if (_isLogin) {
      if (!_loginFormKey.currentState!.validate()) return;
    } else {
      if (!_signupFormKey.currentState!.validate()) return;
      if (!_agreedToTerms) {
        UIFeedback.showError(context, 'Please agree to the Terms & Conditions');
        return;
      }
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1)); // Simulate API call
    setState(() => _isLoading = false);

    if (mounted) {
      // Navigate directly to Dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            userName: _emailController.text.split('@')[0],
            currentIndex: 0,
            onTabSelected: (index) {},
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordController.removeListener(_checkPasswordStrength);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Force light theme for auth screen
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo row
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFFF0F4FF),
                      ),
                      child: const Center(
                        child: Text('🤖', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Co-Tasker',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Dynamic title based on mode
                Text(
                  _isLogin ? 'Welcome Back!!' : 'Create Account',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isLogin
                      ? 'Organize your life, powered by AI'
                      : 'Join us and start your productivity journey',
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.grayText),
                ),

                const SizedBox(height: 28),

                // Toggle tab
                AuthTabBar(isLogin: _isLogin, onToggle: _toggleTab),

                const SizedBox(height: 28),

                // Form fields with fade animation
                FadeTransition(
                  opacity: _fadeAnim,
                  child: _isLogin ? _buildLoginForm() : _buildSignUpForm(),
                ),

                const SizedBox(height: 28),

                // Submit button
                PrimaryButton(
                  label: _isLogin ? 'Log in' : 'Sign Up',
                  onPressed: _handleSubmit,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 28),

                // Social login
                const OrDivider(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    SocialButton(
                      label: 'Continue with Google',
                      icon: _googleIcon(),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 12),
                    SocialButton(
                      label: 'Continue with Apple',
                      icon: const Icon(Icons.apple, size: 20),
                      onPressed: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Bottom link
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.grayText,
                      ),
                      children: [
                        TextSpan(
                          text: _isLogin
                              ? "Don't have an account? "
                              : "Already have an account? ",
                        ),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () => _toggleTab(!_isLogin),
                            child: Text(
                              _isLogin ? 'Sign Up' : 'Log in',
                              style: const TextStyle(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            decoration: _inputDecoration('Email', 'you@example.com'),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            validator: Validators.password,
            decoration: _inputDecoration('Password', '••••••••').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.grayText,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                UIFeedback.showInfo(context, 'Forgot password coming soon!');
              },
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Form(
      key: _signupFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            decoration: _inputDecoration('Email', 'you@example.com'),
          ),
          const SizedBox(height: 20),
          // Password field with strength indicator
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
            decoration: _inputDecoration('Password', '••••••••').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.grayText,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          // Password strength indicator
          if (_passwordStrength != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _strengthColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _strengthColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Password strength: $_passwordStrength',
                        style: TextStyle(
                          fontSize: 12,
                          color: _strengthColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (_passwordSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Suggestions:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.grayText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ..._passwordSuggestions.map((suggestion) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              const Text('• ', style: TextStyle(fontSize: 11)),
                              Expanded(
                                child: Text(
                                  suggestion,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.grayText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            validator: (value) =>
                Validators.confirmPassword(value, _passwordController.text),
            decoration:
                _inputDecoration('Confirm Password', '••••••••').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.grayText,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _agreedToTerms,
                onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                activeColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Text('I agree to ', style: TextStyle(fontSize: 13)),
              GestureDetector(
                onTap: () {
                  UIFeedback.showInfo(
                      context, 'Terms & Conditions coming soon!');
                },
                child: const Text(
                  'Terms & Conditions',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _googleIcon() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

/// Minimal Google "G" color painter
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r, paint);

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.85),
      -0.3,
      1.9,
      true,
      paint,
    );

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.85),
      1.6,
      1.6,
      true,
      paint,
    );

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.85),
      3.2,
      0.8,
      true,
      paint,
    );

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.85),
      4.0,
      0.55,
      true,
      paint,
    );

    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.5, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

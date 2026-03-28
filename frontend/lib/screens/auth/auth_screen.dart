import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'name_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;

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
  }

  void _toggleTab(bool isLogin) {
    _animController.reverse().then((_) {
      setState(() => _isLogin = isLogin);
      _animController.forward();
    });
  }

  void _handleSubmit() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);

    if (!_isLogin && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NameScreen()),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

                // Title
                const Text(
                  'Welcome Back!!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Organize your life, powered by AI',
                  style: TextStyle(fontSize: 14, color: AppColors.grayText),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledTextField(
          label: 'Enter Email',
          hint: 'you@example.com',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        LabeledTextField(
          label: 'Enter Password',
          hint: '••••••••',
          obscureText: _obscurePassword,
          controller: _passwordController,
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
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
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
    );
  }

  Widget _buildSignUpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledTextField(
          label: 'Enter Email',
          hint: 'you@example.com',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        LabeledTextField(
          label: 'Enter Password',
          hint: '••••••••',
          obscureText: _obscurePassword,
          controller: _passwordController,
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
        const SizedBox(height: 20),
        LabeledTextField(
          label: 'Confirm Password',
          hint: '••••••••',
          obscureText: _obscureConfirm,
          controller: _confirmPasswordController,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.grayText,
              size: 20,
            ),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
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
              onTap: () {},
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

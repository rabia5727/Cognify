import 'package:flutter/material.dart';
import 'package:frontend/widgets/common/auth_components.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/token_storage.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../utils/validators.dart';
import '../../theme/app_theme.dart';
import 'name_screen.dart';
import 'forgot_password_screen.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/common/robot_mascot.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;

  // Form keys for validation
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;
  String? _loginError;
  bool _termsError = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  void _toggleTab(bool isLogin) {
    _animController.reverse().then((_) {
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      setState(() {
        _isLogin = isLogin;
        _loginError = null;
        _termsError = false;
        _agreedToTerms = false;
        _obscurePassword = true;
        _obscureConfirm = true;
      });
      _animController.forward();
    });
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _loginError = null;
      _termsError = false;
    });

    if (_isLogin) {
      if (!_loginFormKey.currentState!.validate()) return;
    } else {
      if (!_signupFormKey.currentState!.validate()) return;
      if (!_agreedToTerms) {
        setState(() => _termsError = true);
        return;
      }
    }

    setState(() => _isLoading = true);

    if (_isLogin) {
      final result = await ApiService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.isSuccess && result.data != null) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userResult = await ApiService.getMe();
        if (!mounted) return;
        final user = UserModel(
          id: userResult.data?.id ?? '',
          name: userResult.data?.name ?? '',
          email: userResult.data?.email ?? '',
        );
        final token =
            result.data?.accessToken ?? await TokenStorage.getToken() ?? '';
        authProvider.onLoginSuccess(user, token);
      } else {
        setState(
            () => _loginError = result.error ?? 'Incorrect email or password.');
      }
    } else {
      setState(() => _isLoading = false);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NameScreen(
            email: _emailController.text.trim(),
            password: _passwordController.text,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Robot Icon - Centered
              // Robot Mascot - Centered with Animation
              Padding(
                padding: const EdgeInsets.only(
                    top: 20), // ✅ This pushes just the robot down
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: RobotMascot(
                      key: ValueKey(_isLogin ? 'login' : 'signup'),
                      expression: _isLogin
                          ? RobotExpression.waving
                          : RobotExpression.happy,
                      size: 80,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24), // ✅ Keep this as is

              // Welcome Text - Centered
              Center(
                child: Text(
                  _isLogin ? 'Welcome Back!!' : 'Create Account',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _isLogin
                      ? 'Organize your life, powered by AI'
                      : 'Join Cognify and boost your productivity',
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.grayText),
                ),
              ),
              const SizedBox(height: 32),

              // Tab Bar
              AuthTabBar(isLogin: _isLogin, onToggle: _toggleTab),
              const SizedBox(height: 28),

              // Form
              FadeTransition(
                opacity: _fadeAnim,
                child: _isLogin ? _buildLoginForm() : _buildSignUpForm(),
              ),
              const SizedBox(height: 28),

              // Primary Button
              PrimaryButton(
                label: _isLogin ? 'Log in' : 'Sign Up',
                onPressed: _handleSubmit,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 28),

              // Or Divider
              const OrDivider(),
              const SizedBox(height: 20),

              // Google Button
              Row(children: [
                Expanded(
                  child: SocialButton(
                    label: 'Continue with Google',
                    icon: SizedBox(
                        width: 20,
                        height: 20,
                        child: CustomPaint(painter: _GoogleLogoPainter())),
                    onPressed: _handleGoogleSignIn,
                  ),
                )
              ]),
              const SizedBox(height: 24),

              // Toggle Login/Signup
              Center(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.grayText),
                    children: [
                      TextSpan(
                          text: _isLogin
                              ? "Don't have an account? "
                              : "Already have an account? "),
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () => _toggleTab(!_isLogin),
                          child: Text(
                            _isLogin ? 'Sign Up' : 'Log in',
                            style: const TextStyle(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
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
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            textAlign: TextAlign.start,
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen()),
                );
              },
              child: const Text('Forgot Password?',
                  style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          if (_loginError != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _loginError!,
                      style:
                          TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Form(
      key: _signupFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const SizedBox(height: 20),
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
                onChanged: (v) => setState(() {
                  _agreedToTerms = v ?? false;
                  if (_agreedToTerms) _termsError = false;
                }),
                activeColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              const Text('I agree to ', style: TextStyle(fontSize: 13)),
              GestureDetector(
                onTap: () => _showTermsDialog(),
                child: const Text('Terms & Conditions',
                    style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ],
          ),
          if (_termsError) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'You must agree to the Terms & Conditions to continue.',
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
          ],
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

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(height: 24),
              const SizedBox(
                height: 300,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TermsSection(
                        title: '1. Acceptance of Terms',
                        content:
                            'By creating an account on Cognify, you agree to be bound by these Terms and Conditions. If you do not agree, please do not use our service.',
                      ),
                      _TermsSection(
                        title: '2. Use of Service',
                        content:
                            'Cognify is an AI-powered productivity app designed to help you manage tasks, workflows, and academic assignments. You agree to use the service only for lawful purposes.',
                      ),
                      _TermsSection(
                        title: '3. Privacy & Data',
                        content:
                            'We collect and store your task data, preferences, and Google Classroom information solely to provide our services. We do not sell your data to third parties.',
                      ),
                      _TermsSection(
                        title: '4. Google Classroom Integration',
                        content:
                            'By connecting your Google Classroom account, you authorize Cognify to access your courses and assignments to sync them as tasks. You can disconnect at any time.',
                      ),
                      _TermsSection(
                        title: '5. Account Security',
                        content:
                            'You are responsible for maintaining the confidentiality of your account credentials. Please notify us immediately of any unauthorized use of your account.',
                      ),
                      _TermsSection(
                        title: '6. Modifications',
                        content:
                            'We reserve the right to modify these terms at any time. Continued use of Cognify after changes constitutes acceptance of the new terms.',
                      ),
                      _TermsSection(
                        title: '7. Contact',
                        content:
                            'For any questions regarding these terms, please contact us at support@cognify.app',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _agreedToTerms = true);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'I Agree',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    final result = await GoogleAuthService.signIn();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess && result.data != null) {
      final userResult = await ApiService.getMe();
      if (!mounted) return;

      final user = UserModel(
        id: userResult.data?.id ?? '',
        name: userResult.data?.name ?? '',
        email: userResult.data?.email ?? '',
      );

      final token = result.data?.accessToken ?? '';
      Provider.of<AuthProvider>(context, listen: false)
          .onLoginSuccess(user, token);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Google sign in failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.85),
        -0.3, 1.9, true, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.85),
        1.6, 1.6, true, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.85),
        3.2, 0.8, true, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.85),
        4.0, 0.55, true, paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.5, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _TermsSection extends StatelessWidget {
  final String title;
  final String content;

  const _TermsSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.grayText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

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
      setState(() => _isLogin = isLogin);
      _animController.forward();
    });
  }

  Future<void> _handleSubmit() async {
    // Validate based on current mode
    if (_isLogin) {
      if (!_loginFormKey.currentState!.validate()) return;
    } else {
      if (!_signupFormKey.currentState!.validate()) return;
      if (!_agreedToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please agree to the Terms & Conditions'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
        final userResult = await ApiService.getMe();
        if (!mounted) return;

        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        final user = UserModel(
          id: userResult.data?.id ?? 'local',
          name: userResult.data?.name ?? _emailController.text.split('@')[0],
          email: _emailController.text.trim(),
        );

        final token =
            result.data?.accessToken ?? await TokenStorage.getToken() ?? '';

        // This will trigger navigation to HomeScreen via _AppEntryPoint
        authProvider.onLoginSuccess(user, token);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Login failed'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Sign up: go to NameScreen
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
              Center(
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0xFFF0F4FF),
                  ),
                  child: const Center(
                    child: Text('🤖', style: TextStyle(fontSize: 36)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Welcome Text - Centered
              const Center(
                child: Text('Welcome Back!!',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText)),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Organize your life, powered by AI',
                    style: TextStyle(fontSize: 14, color: AppColors.grayText)),
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
                    onPressed: () {},
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
                onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                activeColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              const Text('I agree to ', style: TextStyle(fontSize: 13)),
              GestureDetector(
                onTap: () {},
                child: const Text('Terms & Conditions',
                    style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
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
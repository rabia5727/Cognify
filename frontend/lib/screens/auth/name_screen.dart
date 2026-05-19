// This screen is shown after the user successfully registers with email + password.
// It asks for the user's full name, then calls the register API to create the account.
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/auth_components.dart';
import '../../services/api_service.dart';
import 'onboarding_screen.dart';
import '../../utils/ui_feedback.dart';

class NameScreen extends StatefulWidget {
  final String email;
  final String password;

  const NameScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  void _showError(String message) {
    if (!mounted) return;
    UIFeedback.showError(context, message);
  }

  Future<void> _continue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter your name');
      return;
    }

    setState(() => _isLoading = true);

    // Call register API with name + email + password
    final result = await ApiService.register(
      name: name,
      email: widget.email,
      password: widget.password,
    );
    //debugger lines
    print('=== REGISTER RESULT ===');
    print('Success: ${result.isSuccess}');
    print('Error: ${result.error}');
    print('Token: ${result.data?.accessToken}');

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OnboardingScreen(userName: name),
        ),
      );
    } else {
      _showError(result.error!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),

                  // Mascot centered
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFF0F4FF),
                      ),
                      child: const Center(
                          child: Text('🤖', style: TextStyle(fontSize: 52))),
                    ),
                  ),

                  const SizedBox(height: 28),

                  const Center(
                    child: Text(
                      'Welcome !!',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'What should we call you?',
                      style: TextStyle(fontSize: 15, color: AppColors.grayText),
                    ),
                  ),

                  const SizedBox(height: 48),

                  LabeledTextField(
                    label: 'Full Name',
                    hint: 'e.g. John Doe',
                    controller: _nameController,
                  ),

                  const SizedBox(height: 32),

                  PrimaryButton(
                    label: 'Continue',
                    onPressed: _continue,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}

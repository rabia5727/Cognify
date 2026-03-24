import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'onboarding_screen.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  void _continue() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _isLoading = false);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              OnboardingScreen(userName: _nameController.text.trim()),
        ),
      );
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mascot centered at top
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF0F4FF),
                  ),
                  child: const Center(
                      child: Text('🤖', style: TextStyle(fontSize: 52))),
                ),
              ),

              const SizedBox(height: 28),

              // Welcome text centered
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

              // Full Name field
              LabeledTextField(
                label: 'Full Name',
                hint: 'e.g. John Doe',
                controller: _nameController,
              ),

              const SizedBox(height: 32),

              // Continue button
              PrimaryButton(
                label: 'Continue',
                onPressed: _continue,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

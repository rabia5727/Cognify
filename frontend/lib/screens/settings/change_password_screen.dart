import 'package:flutter/material.dart';
import '../../utils/validators.dart';
import '../../utils/ui_feedback.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/auth_components.dart';
import '../../services/user_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  String? _passwordStrength;
  Color _strengthColor = Colors.grey;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updateStrength(String value) {
    setState(() {
      if (value.isEmpty) {
        _passwordStrength = null;
        _strengthColor = Colors.grey;
      } else if (value.length < 6) {
        _passwordStrength = 'Weak';
        _strengthColor = Colors.red;
      } else if (value.length < 10) {
        _passwordStrength = 'Medium';
        _strengthColor = Colors.orange;
      } else {
        _passwordStrength = 'Strong';
        _strengthColor = Colors.green;
      }
    });
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final error = await UserService.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      UIFeedback.showError(context, error);
      return;
    }

    UIFeedback.showSuccess(context, 'Password changed successfully!');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? AppColors.darkText_ : AppColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Change Password',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText_ : AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose a strong password to secure your account',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        isDark ? AppColors.darkGrayText : AppColors.grayText,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrent,
                  validator: Validators.password,
                  decoration: InputDecoration(
                    hintText: 'Current Password',
                    prefixIcon: Icon(Icons.lock_outline_rounded,
                        color: isDark
                            ? AppColors.darkGrayText
                            : AppColors.grayText),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: isDark
                            ? AppColors.darkGrayText
                            : AppColors.grayText,
                      ),
                      onPressed: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  onChanged: _updateStrength,
                  validator: (v) => Validators.newPassword(
                      v, _currentPasswordController.text),
                  decoration: InputDecoration(
                    hintText: 'New Password',
                    prefixIcon: Icon(Icons.lock_outline_rounded,
                        color: isDark
                            ? AppColors.darkGrayText
                            : AppColors.grayText),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: isDark
                            ? AppColors.darkGrayText
                            : AppColors.grayText,
                      ),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                ),
                if (_passwordStrength != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Password strength: $_passwordStrength',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _strengthColor,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  validator: (v) => Validators.confirmPassword(
                      v, _newPasswordController.text),
                  decoration: InputDecoration(
                    hintText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock_outline_rounded,
                        color: isDark
                            ? AppColors.darkGrayText
                            : AppColors.grayText),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: isDark
                            ? AppColors.darkGrayText
                            : AppColors.grayText,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Update Password',
                  onPressed: _savePassword,
                  isLoading: _isSaving,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

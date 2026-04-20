import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/ui_feedback.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/auth_components.dart';

class EditNameScreen extends StatefulWidget {
  const EditNameScreen({super.key});

  @override
  State<EditNameScreen> createState() => _EditNameScreenState();
}

class _EditNameScreenState extends State<EditNameScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final parts = auth.userName.split(' ');
    _firstNameController = TextEditingController(text: parts.first);
    _lastNameController = TextEditingController(
        text: parts.length > 1 ? parts.sublist(1).join(' ') : '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (_firstNameController.text.trim().isEmpty) {
      UIFeedback.showError(context, 'First name is required');
      return;
    }

    setState(() => _isSaving = true);

    final newName =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
            .trim();

    // TODO: Replace with API call
    await Future.delayed(const Duration(seconds: 1));

    context.read<AuthProvider>().updateUserInfo(name: newName);

    if (mounted) {
      setState(() => _isSaving = false);
      UIFeedback.showSuccess(context, 'Name updated successfully!');
      Navigator.pop(context);
    }
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Edit Name',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText_ : AppColors.darkText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Update how your name appears in the app',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.darkGrayText : AppColors.grayText,
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _firstNameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'First Name',
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: isDark
                          ? AppColors.darkGrayText
                          : AppColors.grayText),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Last Name',
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: isDark
                          ? AppColors.darkGrayText
                          : AppColors.grayText),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Save Changes',
                onPressed: _saveName,
                isLoading: _isSaving,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

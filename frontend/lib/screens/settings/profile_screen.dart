// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/settings/profile_screen.dart
// CHANGES FROM REVIEW:
//   - All dialogs now use TextFormField + Form key for inline validation
//   - Inline error text shows under each field (no more snackbar-only errors)
//   - _showSuccessSnackBar / _showErrorSnackBar replaced with UIFeedback
//   - Dialog closes after successful save (was a UX bug before)
//   - Password dialog: strength indicator moved inline under the field
//   - Validators.dart used for all validation logic
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../constants/app_constant.dart';
import '../../utils/validators.dart';
import '../../utils/ui_feedback.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_header.dart';
import '../../widgets/section_card.dart';
import '../../widgets/row_divider.dart';

class ProfileScreen extends StatefulWidget {
  final String userName;
  const ProfileScreen({super.key, required this.userName});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _name;
  late String _email;
  bool _classroomConnected = false;
  bool _gmailConnected = false;
  File? _profileImage;
  String _lastSyncClassroom = 'Never synced';
  String _lastSyncGmail = 'Never synced';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _name = widget.userName;
    _email = 'user@gmail.com';
  }

  // =============================================================
  // SAVE ACTIONS
  // =============================================================

  Future<void> _saveName(String newName) async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(seconds: 1)); // TODO: Replace with API
    setState(() {
      _name = newName.trim();
      _isSaving = false;
    });
    if (mounted) UIFeedback.showSuccess(context, 'Name saved successfully!');
  }

  Future<void> _saveEmail(String newEmail) async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(seconds: 1)); // TODO: Replace with API
    setState(() {
      _email = newEmail.trim();
      _isSaving = false;
    });
    if (mounted) UIFeedback.showSuccess(context, 'Email saved successfully!');
  }

  Future<void> _savePassword(String currentPassword, String newPassword) async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(seconds: 1)); // TODO: Replace with API
    setState(() => _isSaving = false);
    if (mounted) {
      UIFeedback.showSuccess(context, 'Password changed successfully!');
    }
  }

  Future<void> _toggleConnection(String platform, bool current) async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(seconds: 1)); // TODO: Replace with API
    setState(() {
      if (platform == 'Google Classroom') {
        _classroomConnected = !current;
        _lastSyncClassroom = _classroomConnected ? 'Just now' : 'Never synced';
      } else {
        _gmailConnected = !current;
        _lastSyncGmail = _gmailConnected ? 'Just now' : 'Never synced';
      }
      _isSaving = false;
    });
    if (mounted) {
      UIFeedback.showSuccess(
        context,
        current ? '$platform disconnected' : '$platform connected!',
      );
    }
  }

  // =============================================================
  // DIALOGS — all use Form + TextFormField for inline errors
  // =============================================================

  void _editName() {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: _name);

    _showFieldDialog(
      title: 'Edit Name',
      formKey: formKey,
      child: TextFormField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.name,
        textCapitalization: TextCapitalization.words,
        validator: Validators.name,
        decoration: _inputDecoration('Your name'),
      ),
      onSave: () async {
        if (!formKey.currentState!.validate()) return;
        Navigator.pop(context);
        await _saveName(controller.text);
      },
    );
  }

  void _editEmail() {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: _email);

    _showFieldDialog(
      title: 'Edit Email',
      formKey: formKey,
      child: TextFormField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        validator: Validators.email,
        decoration: _inputDecoration('your@email.com'),
      ),
      onSave: () async {
        if (!formKey.currentState!.validate()) return;
        Navigator.pop(context);
        await _saveEmail(controller.text);
      },
    );
  }

  void _changePassword() {
    final formKey = GlobalKey<FormState>();
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? passwordStrength;
    Color strengthColor = Colors.grey;

    void updateStrength(String value, StateSetter setDialogState) {
      setDialogState(() {
        if (value.isEmpty) {
          passwordStrength = null;
          strengthColor = Colors.grey;
        } else if (value.length < 6) {
          passwordStrength = 'Weak';
          strengthColor = Colors.red;
        } else if (value.length < 10) {
          passwordStrength = 'Medium';
          strengthColor = Colors.orange;
        } else {
          passwordStrength = 'Strong';
          strengthColor = Colors.green;
        }
      });
    }

    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Change Password',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 20),

                    // Current password
                    TextFormField(
                      controller: currentCtrl,
                      obscureText: obscureCurrent,
                      validator: Validators.password,
                      decoration: _inputDecoration('Current password').copyWith(
                        suffixIcon: _toggleIcon(
                            obscureCurrent,
                            () => setDialogState(
                                () => obscureCurrent = !obscureCurrent)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // New password
                    TextFormField(
                      controller: newCtrl,
                      obscureText: obscureNew,
                      onChanged: (v) => updateStrength(v, setDialogState),
                      validator: (v) =>
                          Validators.newPassword(v, currentCtrl.text),
                      decoration: _inputDecoration('New password').copyWith(
                        suffixIcon: _toggleIcon(
                            obscureNew,
                            () =>
                                setDialogState(() => obscureNew = !obscureNew)),
                      ),
                    ),

                    // Inline strength indicator
                    if (passwordStrength != null)
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 4, top: 6, bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: strengthColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Strength: $passwordStrength',
                              style:
                                  TextStyle(fontSize: 12, color: strengthColor),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Confirm password
                    TextFormField(
                      controller: confirmCtrl,
                      obscureText: obscureConfirm,
                      validator: (v) =>
                          Validators.confirmPassword(v, newCtrl.text),
                      decoration:
                          _inputDecoration('Confirm new password').copyWith(
                        suffixIcon: _toggleIcon(
                            obscureConfirm,
                            () => setDialogState(
                                () => obscureConfirm = !obscureConfirm)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    Navigator.pop(ctx);
                                    await _savePassword(
                                        currentCtrl.text, newCtrl.text);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Save',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Generic single-field dialog used by name & email edits.
  void _showFieldDialog({
    required String title,
    required GlobalKey<FormState> formKey,
    required Widget child,
    required VoidCallback onSave,
  }) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: theme.textTheme.titleMedium),
        content: Form(key: formKey, child: child),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: theme.textTheme.bodySmall?.color)),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    final formKey = GlobalKey<FormState>();
    final confirmController = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: Colors.red, fontSize: 16)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will permanently delete your account and all data. This cannot be undone.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmController,
                autofocus: true,
                decoration: _inputDecoration('Type DELETE to confirm'),
                validator: (v) {
                  if (v == null || v.trim().toUpperCase() != 'DELETE') {
                    return 'Type DELETE exactly to confirm';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: theme.textTheme.bodySmall?.color)),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              UIFeedback.showSuccess(context, 'Account deleted (demo)');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // PHOTO PICKER
  // =============================================================

  Future<void> _pickPhoto() async {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Change Profile Photo', style: theme.textTheme.titleMedium),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _PhotoOption(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _PhotoOption(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _pickImage(ImageSource.camera);
                    },
                  ),
                ),
              ],
            ),
            if (_profileImage != null) ...[
              const SizedBox(height: 12),
              _PhotoOption(
                icon: Icons.delete_outline,
                label: 'Remove Photo',
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _profileImage = null);
                  UIFeedback.showSuccess(context, 'Profile photo removed');
                },
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(
                      color: theme.textTheme.bodySmall?.color, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _profileImage = File(image.path));
        if (mounted) UIFeedback.showSuccess(context, 'Photo updated!');
      }
    } catch (e) {
      if (mounted) UIFeedback.showError(context, 'Failed to pick image: $e');
    }
  }

  // =============================================================
  // HELPERS
  // =============================================================

  String _getInitials() {
    final parts = _name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _name.isNotEmpty ? _name[0].toUpperCase() : 'U';
  }

  InputDecoration _inputDecoration(String hint) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
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

  Widget _toggleIcon(bool obscure, VoidCallback onToggle) {
    return IconButton(
      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
      onPressed: onToggle,
    );
  }

  // =============================================================
  // BUILD
  // =============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Profile',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  children: [
                    _ProfilePhoto(
                      onTap: _pickPhoto,
                      profileImage: _profileImage,
                      initials: _getInitials(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _email,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Account info
                    SectionCard(
                      children: [
                        _ActionRow(
                          icon: Icons.edit_outlined,
                          label: 'Edit Name',
                          subtitle: _name,
                          onTap: _editName,
                          isLoading: _isSaving,
                        ),
                        const RowDivider(),
                        _ActionRow(
                          icon: Icons.email_outlined,
                          label: 'Edit Email',
                          subtitle: _email,
                          onTap: _editEmail,
                          isLoading: _isSaving,
                        ),
                        const RowDivider(),
                        _ActionRow(
                          icon: Icons.lock_outline_rounded,
                          label: 'Change Password',
                          onTap: _changePassword,
                          isLoading: _isSaving,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Connected accounts
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text('Connected Accounts',
                              style: theme.textTheme.titleMedium),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 12),
                          child: Text(
                            'Connect your accounts to automatically sync tasks and deadlines.',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                        SectionCard(
                          children: [
                            _ConnectedAccountRow(
                              icon: Icons.school_outlined,
                              label: 'Google Classroom',
                              description: 'Sync assignments & deadlines',
                              isConnected: _classroomConnected,
                              lastSync: _lastSyncClassroom,
                              onTap: () => _toggleConnection(
                                  'Google Classroom', _classroomConnected),
                              isLoading: _isSaving,
                            ),
                            const RowDivider(),
                            _ConnectedAccountRow(
                              icon: Icons.mail_outline_rounded,
                              label: 'Gmail',
                              description: 'Import task emails automatically',
                              isConnected: _gmailConnected,
                              lastSync: _lastSyncGmail,
                              onTap: () =>
                                  _toggleConnection('Gmail', _gmailConnected),
                              isLoading: _isSaving,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Danger zone
                    SectionCard(
                      children: [
                        _ActionRow(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete Account',
                          labelColor: Colors.red.shade400,
                          iconColor: Colors.red.shade400,
                          onTap: _showDeleteDialog,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVATE WIDGETS (same file — profile-specific, not reused elsewhere)
// ─────────────────────────────────────────────────────────────────────────────

class _ProfilePhoto extends StatelessWidget {
  final VoidCallback onTap;
  final File? profileImage;
  final String initials;

  const _ProfilePhoto({
    required this.onTap,
    this.profileImage,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.dividerColor.withOpacity(0.3),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
                width: 3,
              ),
            ),
            child: ClipOval(
              child: profileImage != null
                  ? Image.file(profileImage!,
                      width: 100, height: 100, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.edit_rounded, size: 15, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _PhotoOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PhotoOption(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: theme.dividerColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? labelColor, iconColor;
  final bool isLoading;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.labelColor,
    this.iconColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: labelColor ?? theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall),
                  ],
                ],
              ),
            ),
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: theme.colorScheme.primary),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: theme.textTheme.bodySmall?.color),
          ],
        ),
      ),
    );
  }
}

class _ConnectedAccountRow extends StatelessWidget {
  final IconData icon;
  final String label, description;
  final bool isConnected;
  final String lastSync;
  final VoidCallback onTap;
  final bool isLoading;

  const _ConnectedAccountRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.isConnected,
    required this.lastSync,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(description, style: theme.textTheme.labelSmall),
                if (isConnected) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.sync_rounded,
                          size: 10, color: Colors.green),
                      const SizedBox(width: 4),
                      Text('Last synced: $lastSync',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.green)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isLoading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: theme.colorScheme.primary),
            )
          else
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isConnected
                      ? Colors.green.withOpacity(0.1)
                      : theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isConnected
                        ? Colors.green.withOpacity(0.4)
                        : theme.colorScheme.primary.withOpacity(0.4),
                  ),
                ),
                child: Text(
                  isConnected ? 'Connected' : 'Connect',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        isConnected ? Colors.green : theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

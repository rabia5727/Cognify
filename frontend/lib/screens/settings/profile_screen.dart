// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/settings/profile_screen.dart
// CHANGES:
//   - Removed _SectionCard (now SectionCard widget)
//   - Removed _RowDivider (now RowDivider widget)
//   - Uses AppHeader instead of inline top bar
//   - Uses AppConstants for all colors
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../constants/app_constant.dart';
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

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  @override
  void initState() {
    super.initState();
    _name = widget.userName;
    _email = 'user@gmail.com';
    _nameController = TextEditingController(text: _name);
    _emailController = TextEditingController(text: _email);
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Edit name ──────────────────────────────────────────────────────
  void _editName() {
    _nameController.text = _name;
    _showEditDialog(
      title: 'Edit Name',
      controller: _nameController,
      keyboardType: TextInputType.name,
      hint: 'Enter your name',
      onSave: () {
        if (_nameController.text.trim().isNotEmpty) {
          setState(() => _name = _nameController.text.trim());
        }
      },
    );
  }

  // ── Edit email ─────────────────────────────────────────────────────
  void _editEmail() {
    _emailController.text = _email;
    _showEditDialog(
      title: 'Edit Email',
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      hint: 'Enter your email',
      onSave: () {
        if (_emailController.text.trim().isNotEmpty) {
          setState(() => _email = _emailController.text.trim());
        }
      },
    );
  }

  // ── Shared simple edit dialog ──────────────────────────────────────
  void _showEditDialog({
    required String title,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required String hint,
    required VoidCallback onSave,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppConstants.primaryBlue, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: AppConstants.grayText)),
          ),
          ElevatedButton(
            onPressed: () {
              onSave();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Change password ────────────────────────────────────────────────
  void _changePassword() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    bool obscureCurrent = true, obscureNew = true, obscureConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Change Password',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppConstants.darkText)),
                  const SizedBox(height: 20),
                  _PasswordField(
                    controller: _currentPasswordController,
                    label: 'Current Password',
                    obscure: obscureCurrent,
                    onToggle: () =>
                        setDialogState(() => obscureCurrent = !obscureCurrent),
                  ),
                  const SizedBox(height: 16),
                  _PasswordField(
                    controller: _newPasswordController,
                    label: 'New Password',
                    obscure: obscureNew,
                    onToggle: () =>
                        setDialogState(() => obscureNew = !obscureNew),
                  ),
                  const SizedBox(height: 16),
                  _PasswordField(
                    controller: _confirmPasswordController,
                    label: 'Confirm New Password',
                    obscure: obscureConfirm,
                    onToggle: () =>
                        setDialogState(() => obscureConfirm = !obscureConfirm),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            _clearPasswordFields();
                            Navigator.pop(ctx);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: AppConstants.lightGray),
                            ),
                          ),
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: AppConstants.grayText,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (_validatePassword()) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Password changed!'),
                                    backgroundColor: Colors.green),
                              );
                              _clearPasswordFields();
                              Navigator.pop(ctx);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Save',
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
    );
  }

  bool _validatePassword() {
    void snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));

    if (_currentPasswordController.text.isEmpty) {
      snack('Enter current password');
      return false;
    }
    if (_newPasswordController.text.isEmpty) {
      snack('Enter new password');
      return false;
    }
    if (_newPasswordController.text.length < 6) {
      snack('Minimum 6 characters');
      return false;
    }
    if (_newPasswordController.text == _currentPasswordController.text) {
      snack('New password cannot be same as current');
      return false;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      snack('Passwords do not match');
      return false;
    }
    return true;
  }

  void _clearPasswordFields() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  // ── Connect/disconnect accounts ────────────────────────────────────
  void _toggleConnection(String platform, bool current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(current ? 'Disconnect $platform' : 'Connect $platform',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(current
            ? 'Disconnect $platform?'
            : 'Connect $platform to sync tasks automatically.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: AppConstants.grayText)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (platform == 'Google Classroom') {
                  _classroomConnected = !current;
                } else {
                  _gmailConnected = !current;
                }
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(current
                    ? '$platform disconnected'
                    : '$platform connected!'),
                backgroundColor: current ? Colors.red : Colors.green,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  current ? Colors.red.shade500 : AppConstants.primaryBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(current ? 'Disconnect' : 'Connect',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Photo picker ───────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Change Profile Photo',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.darkText)),
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
                        })),
                const SizedBox(width: 16),
                Expanded(
                    child: _PhotoOption(
                        icon: Icons.camera_alt_outlined,
                        label: 'Camera',
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _pickImage(ImageSource.camera);
                        })),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style:
                        TextStyle(color: AppConstants.grayText, fontSize: 16))),
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
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✓ Photo updated!'),
                backgroundColor: Colors.green),
          );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
    }
  }

  // ── Delete account ─────────────────────────────────────────────────
  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red)),
        content: const Text(
            'This will permanently delete your account and all data. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: AppConstants.grayText)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: call UserService.deleteAccount()
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Shared header ─────────────────────────────────────────
            AppHeader(
              title: 'Profile',
              onBack: () => Navigator.pop(context),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  children: [
                    // Profile photo
                    _ProfilePhoto(
                        onTap: _pickPhoto, profileImage: _profileImage),
                    const SizedBox(height: 16),

                    // Name
                    Text(_name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppConstants.darkText,
                        )),
                    const SizedBox(height: 8),

                    // Email pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppConstants.inputBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_email,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppConstants.primaryBlue,
                            fontWeight: FontWeight.w500,
                          )),
                    ),
                    const SizedBox(height: 28),

                    // Edit profile — uses shared SectionCard + RowDivider
                    SectionCard(
                      children: [
                        _ActionRow(
                            icon: Icons.edit_outlined,
                            label: 'Edit Name',
                            subtitle: _name,
                            onTap: _editName),
                        const RowDivider(),
                        _ActionRow(
                            icon: Icons.email_outlined,
                            label: 'Edit Email',
                            subtitle: _email,
                            onTap: _editEmail),
                        const RowDivider(),
                        _ActionRow(
                            icon: Icons.lock_outline_rounded,
                            label: 'Change Password',
                            onTap: _changePassword),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Connected accounts
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 8),
                          child: Text('Connected Accounts',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppConstants.darkText,
                              )),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 12),
                          child: Text(
                            'Connect your accounts to automatically sync tasks and deadlines.',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppConstants.grayText,
                                height: 1.4),
                          ),
                        ),
                        SectionCard(
                          children: [
                            _ConnectedAccountRow(
                              icon: Icons.school_outlined,
                              label: 'Google Classroom',
                              description: 'Sync assignments & deadlines',
                              isConnected: _classroomConnected,
                              onTap: () => _toggleConnection(
                                  'Google Classroom', _classroomConnected),
                            ),
                            const RowDivider(),
                            _ConnectedAccountRow(
                              icon: Icons.mail_outline_rounded,
                              label: 'Gmail',
                              description: 'Import task emails automatically',
                              isConnected: _gmailConnected,
                              onTap: () =>
                                  _toggleConnection('Gmail', _gmailConnected),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Delete account
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
// WIDGET: Profile Photo
// ─────────────────────────────────────────────────────────────────────────────

class _ProfilePhoto extends StatelessWidget {
  final VoidCallback onTap;
  final File? profileImage;

  const _ProfilePhoto({required this.onTap, this.profileImage});

  @override
  Widget build(BuildContext context) {
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
              color: AppConstants.inputBg,
              border: Border.all(
                  color: AppConstants.primaryBlue.withOpacity(0.2), width: 3),
            ),
            child: ClipOval(
              child: profileImage != null
                  ? Image.file(profileImage!,
                      width: 100, height: 100, fit: BoxFit.cover)
                  : const Icon(Icons.person_rounded,
                      size: 52, color: AppConstants.primaryBlue),
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
                color: AppConstants.primaryBlue, shape: BoxShape.circle),
            child:
                const Icon(Icons.edit_rounded, size: 15, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Password Field
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppConstants.grayText),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppConstants.primaryBlue, width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
              color: AppConstants.grayText),
          onPressed: onToggle,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Action Row
// ─────────────────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? labelColor, iconColor;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.labelColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppConstants.primaryBlue),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: labelColor ?? AppConstants.darkText,
                      )),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppConstants.grayText)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: AppConstants.grayText),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Connected Account Row
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectedAccountRow extends StatelessWidget {
  final IconData icon;
  final String label, description;
  final bool isConnected;
  final VoidCallback onTap;

  const _ConnectedAccountRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.isConnected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppConstants.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: AppConstants.primaryBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppConstants.darkText,
                    )),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(
                        fontSize: 12, color: AppConstants.grayText)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isConnected
                    ? Colors.green.withOpacity(0.1)
                    : AppConstants.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isConnected
                      ? Colors.green.withOpacity(0.4)
                      : AppConstants.primaryBlue.withOpacity(0.4),
                ),
              ),
              child: Text(isConnected ? 'Connected' : 'Connect',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        isConnected ? Colors.green : AppConstants.primaryBlue,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Photo Option
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PhotoOption(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppConstants.inputBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppConstants.primaryBlue),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppConstants.darkText,
                )),
          ],
        ),
      ),
    );
  }
}

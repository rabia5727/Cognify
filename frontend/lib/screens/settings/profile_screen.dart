// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/settings/profile_screen.dart
// CHANGES:
//   - Added real connection status from ProfileProvider
//   - Added disconnect functionality for Classroom, Gmail, and Drive
//   - Added Google Drive as fully functional (not "Coming Soon")
//   - Added "Connect All" button for one-click connection
//   - Replaced static mock data with real backend data
//   - Added persistent profile image storage using SharedPreferences
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:frontend/screens/workspace/drive_sync_screen.dart';
import 'package:frontend/screens/workspace/gmail_sync_screen.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/oauth_webview.dart';
import '../../services/token_storage.dart';
import '../../utils/ui_feedback.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/layout/row_divider.dart';
import '../../widgets/layout/section_card.dart';
import '../workspace/classroom_sync_screen.dart';
import 'change_password_screen.dart';
import 'edit_name_screen.dart';

const String _profileImageKey = 'profile_image';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Uint8List? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadConnections();
    });
  }

  // ─── Profile Image Persistence ──────────────────────────────────
  // Kept as raw bytes end-to-end (SharedPreferences <-> Image.memory).
  // path_provider's temp-directory APIs have no web implementation, so
  // round-tripping through a cached File (as this used to) threw
  // MissingPluginException on the web build — bytes work on every platform.

  Future<void> _loadProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64Image = prefs.getString(_profileImageKey);
      if (base64Image != null && base64Image.isNotEmpty) {
        final bytes = base64Decode(base64Image);
        if (mounted) {
          setState(() => _profileImage = bytes);
        }
      }
    } catch (e) {
      // Ignore - no image saved
    }
  }

  Future<void> _saveProfileImage(Uint8List bytes) async {
    try {
      final base64Image = base64Encode(bytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileImageKey, base64Image);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _removeProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profileImageKey);
      if (mounted) {
        setState(() => _profileImage = null);
        UIFeedback.showSuccess(context, 'Profile photo removed');
      }
    } catch (e) {
      if (mounted) {
        UIFeedback.showError(context, 'Failed to remove photo');
      }
    }
  }

  void _navigateToEditName() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditNameScreen()),
    );
  }

  void _navigateToChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  // ─── Connect All ──────────────────────────────────────────────────

  Future<void> _connectAll(BuildContext context) async {
    try {
      final token = await TokenStorage.getToken();

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/connect-all/oauth/auth'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get OAuth URL');
      }

      final data = jsonDecode(response.body);
      final authUrl = data['auth_url'] as String;
      final state = data['state'] as String;

      final success = await OAuthWebView.authenticateWithGoogle(
        context,
        authUrl: authUrl,
        state: state,
        healthEndpoint: '/connect-all/health',
      );

      if (success) {
        await context.read<ProfileProvider>().loadConnections();
        if (mounted) {
          UIFeedback.showSuccess(
              context, 'All accounts connected successfully!');
        }
      }
    } catch (e) {
      if (mounted) {
        UIFeedback.showError(context, 'Failed to connect: $e');
      }
    }
  }

  // ─── Disconnect Methods ───────────────────────────────────────────

  Future<void> _disconnectClassroom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google Classroom?'),
        content: const Text(
          'This will remove your Classroom integration. '
          'Tasks from Classroom will remain in your workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Disconnect', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await context.read<ProfileProvider>().disconnectClassroom();
        if (mounted) {
          UIFeedback.showSuccess(context, 'Google Classroom disconnected');
        }
      } catch (e) {
        if (mounted) {
          UIFeedback.showError(context, 'Failed to disconnect: $e');
        }
      }
    }
  }

  Future<void> _disconnectGmail() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Gmail?'),
        content: const Text(
          'This will remove your Gmail integration. '
          'Tasks from emails will remain in your workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Disconnect', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await context.read<ProfileProvider>().disconnectGmail();
        if (mounted) {
          UIFeedback.showSuccess(context, 'Gmail disconnected');
        }
      } catch (e) {
        if (mounted) {
          UIFeedback.showError(context, 'Failed to disconnect: $e');
        }
      }
    }
  }

  //  Disconnect Drive
  Future<void> _disconnectDrive(
      BuildContext context, ProfileProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google Drive?'),
        content: const Text(
          'This will remove your Drive integration. '
          'Previously uploaded files will remain in your Google Drive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Disconnect', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await provider.disconnectDrive();
        if (mounted) {
          UIFeedback.showSuccess(context, 'Google Drive disconnected');
        }
      } catch (e) {
        if (mounted) {
          UIFeedback.showError(context, 'Failed to disconnect: $e');
        }
      }
    }
  }

  Future<void> _disconnectAll(
      BuildContext context, ProfileProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect All Accounts?'),
        content: const Text(
          'This will disconnect Google Classroom, Gmail, and Google Drive. '
          'Your existing tasks will remain in your workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect All',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await provider.disconnectAll();
        if (mounted) {
          UIFeedback.showSuccess(context, 'All accounts disconnected');
        }
      } catch (e) {
        if (mounted) {
          UIFeedback.showError(context, 'Failed to disconnect: $e');
        }
      }
    }
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
                      'This will permanently delete your account and all data. This cannot be undone.'),
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
                      }),
                ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: theme.textTheme.bodySmall?.color))),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final auth = context.read<AuthProvider>();
              Navigator.pop(ctx);

              final error = await auth.deleteAccount();

              if (error != null && mounted) {
                UIFeedback.showError(context, error);
                return;
              }

              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Photo picker ─────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Change Profile Photo', style: theme.textTheme.titleMedium),
          const SizedBox(height: 20),
          Row(children: [
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
          ]),
          if (_profileImage != null) ...[
            const SizedBox(height: 12),
            _PhotoOption(
                icon: Icons.delete_outline,
                label: 'Remove Photo',
                onTap: () {
                  Navigator.pop(ctx);
                  _removeProfileImage();
                }),
          ],
          const SizedBox(height: 12),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(
                      color: theme.textTheme.bodySmall?.color, fontSize: 16))),
        ]),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
          source: source, maxWidth: 500, maxHeight: 500, imageQuality: 85);
      if (image != null) {
        // XFile.readAsBytes() works on every platform, including web —
        // image.path is a blob: URL there, which dart:io.File can't open.
        final bytes = await image.readAsBytes();
        await _saveProfileImage(bytes);
        if (mounted) {
          setState(() => _profileImage = bytes);
          UIFeedback.showSuccess(context, 'Photo updated!');
        }
      }
    } catch (e) {
      if (mounted) UIFeedback.showError(context, 'Failed to pick image: $e');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  InputDecoration _inputDecoration(String hint) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(title: 'Profile', onBack: () => Navigator.pop(context)),
            Expanded(
              child: Consumer<AuthProvider>(
                builder: (_, auth, __) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    children: [
                      _ProfilePhoto(
                          onTap: _pickPhoto,
                          profileImage: _profileImage,
                          initials: _getInitials(auth.userName)),
                      const SizedBox(height: 16),
                      Text(auth.userName,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                            color: theme.dividerColor.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(auth.userEmail,
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(height: 28),

                      // ── Account Section ───────────────────────
                      SectionCard(children: [
                        _ActionRow(
                          icon: Icons.edit_outlined,
                          label: 'Edit Name',
                          subtitle: auth.userName,
                          onTap: _navigateToEditName,
                          isLoading: false,
                          showArrow: true,
                        ),
                        const RowDivider(),
                        _InfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: auth.userEmail),
                        const RowDivider(),
                        _ActionRow(
                          icon: Icons.lock_outline_rounded,
                          label: 'Change Password',
                          onTap: _navigateToChangePassword,
                          isLoading: false,
                          showArrow: true,
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // ── Connected Accounts Section ────────────
                      Consumer<ProfileProvider>(
                        builder: (context, profileProvider, _) {
                          final allConnected =
                              profileProvider.isClassroomConnected &&
                                  profileProvider.isGmailConnected &&
                                  profileProvider.isDriveConnected;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 4, bottom: 8),
                                child: Text(
                                  'Connected Accounts',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 4, bottom: 12),
                                child: Text(
                                  'Connect your accounts to automatically sync tasks and deadlines.',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),

                              // CONNECT ALL BUTTON
                              if (!allConnected)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _connectAll(context),
                                      icon: const Icon(Icons.link_rounded),
                                      label: const Text('Connect All Accounts'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF1360E2),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              // DISCONNECT ALL BUTTON
                              if (allConnected)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _disconnectAll(
                                          context, profileProvider),
                                      icon: const Icon(Icons.link_off_rounded),
                                      label:
                                          const Text('Disconnect All Accounts'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side:
                                            const BorderSide(color: Colors.red),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              SectionCard(children: [
                                // Google Classroom
                                _ConnectedAccountRow(
                                  icon: Icons.school_outlined,
                                  label: 'Google Classroom',
                                  description: 'Sync assignments & deadlines',
                                  isConnected:
                                      profileProvider.isClassroomConnected,
                                  lastSync: profileProvider
                                      .getClassroomLastSyncText(),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ClassroomSyncScreen(),
                                      ),
                                    ).then((_) {
                                      profileProvider.loadConnections();
                                    });
                                  },
                                  onDisconnect: _disconnectClassroom,
                                  isLoading: profileProvider.isLoading,
                                ),
                                const RowDivider(),

                                // Gmail
                                _ConnectedAccountRow(
                                  icon: Icons.mail_outline_rounded,
                                  label: 'Gmail',
                                  description:
                                      'Import task emails automatically',
                                  isConnected: profileProvider.isGmailConnected,
                                  lastSync:
                                      profileProvider.getGmailLastSyncText(),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const GmailSyncScreen(),
                                      ),
                                    ).then((_) {
                                      profileProvider.loadConnections();
                                    });
                                  },
                                  onDisconnect: _disconnectGmail,
                                  isLoading: profileProvider.isLoading,
                                ),
                                const RowDivider(),

                                // Google Drive
                                _ConnectedAccountRow(
                                  icon: Icons.folder_outlined,
                                  label: 'Google Drive',
                                  description: 'Attach files to tasks easily',
                                  isConnected: profileProvider.isDriveConnected,
                                  lastSync:
                                      profileProvider.getDriveLastSyncText(),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const DriveSyncScreen(),
                                      ),
                                    ).then((_) {
                                      profileProvider.loadConnections();
                                    });
                                  },
                                  onDisconnect: () => _disconnectDrive(
                                      context, profileProvider),
                                  isLoading: profileProvider.isLoading,
                                  isComingSoon: false,
                                ),
                              ]),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // ── Delete Account Section ────────────────
                      SectionCard(children: [
                        _ActionRow(
                            icon: Icons.delete_outline_rounded,
                            label: 'Delete Account',
                            labelColor: Colors.red.shade400,
                            iconColor: Colors.red.shade400,
                            onTap: _showDeleteDialog,
                            showArrow: true),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Private widgets
// ═══════════════════════════════════════════════════════════════════

class _ProfilePhoto extends StatelessWidget {
  final VoidCallback onTap;
  final Uint8List? profileImage;
  final String initials;
  const _ProfilePhoto(
      {required this.onTap, this.profileImage, required this.initials});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
        onTap: onTap,
        child: Stack(alignment: Alignment.bottomRight, children: [
          Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.dividerColor.withValues(alpha: 0.3),
                  border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      width: 3)),
              child: ClipOval(
                  child: profileImage != null
                      ? Image.memory(profileImage!,
                          width: 100, height: 100, fit: BoxFit.cover)
                      : Center(
                          child: Text(initials,
                              style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary))))),
          Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: theme.colorScheme.primary, shape: BoxShape.circle),
              child: const Icon(Icons.edit_rounded,
                  size: 15, color: Colors.white)),
        ]));
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
                color: theme.dividerColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Icon(icon, size: 32, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500))
            ])));
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ],
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
  final bool showArrow;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.labelColor,
    this.iconColor,
    this.isLoading = false,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Icon(icon,
                  size: 20, color: iconColor ?? theme.colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: labelColor ??
                                theme.textTheme.bodyLarge?.color)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall)
                    ],
                  ])),
              if (isLoading)
                SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: theme.colorScheme.primary))
              else if (showArrow)
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: theme.textTheme.bodySmall?.color),
            ])));
  }
}

class _ConnectedAccountRow extends StatelessWidget {
  final IconData icon;
  final String label, description;
  final bool isConnected;
  final String lastSync;
  final VoidCallback onTap;
  final VoidCallback? onDisconnect;
  final bool isLoading;
  final bool isComingSoon;

  const _ConnectedAccountRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.isConnected,
    required this.lastSync,
    required this.onTap,
    this.onDisconnect,
    this.isLoading = false,
    this.isComingSoon = false,
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
              color: isConnected
                  ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : theme.dividerColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isConnected
                  ? theme.colorScheme.primary
                  : Colors.grey.shade500,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isComingSoon) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Soon',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.labelSmall,
                ),
                if (isConnected) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.sync_rounded,
                          size: 10, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Last synced: $lastSync',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.green),
                      ),
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
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            )
          else if (isConnected && onDisconnect != null)
            GestureDetector(
              onTap: onDisconnect,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Disconnect',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
            )
          else if (!isComingSoon)
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'Connect',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

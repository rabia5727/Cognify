// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/settings/settings_screen.dart
// CHANGES:
//   - Added robot mascot in logout dialog with sad expression
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_constant.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../utils/ui_feedback.dart';
import '../../theme/theme_notifier.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/assistant_fab.dart';
import '../../widgets/common/robot_mascot.dart'; // ✅ ADDED
import '../../widgets/layout/section_card.dart';
import '../../widgets/layout/row_divider.dart';
import 'profile_screen.dart';
import '../../services/user_service.dart';

class SettingsScreen extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const SettingsScreen({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _voicePermissionEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final profile = await UserService.getProfile();
    if (profile != null && profile['preferences'] != null) {
      final prefs = await SharedPreferences.getInstance();
      final voicePermission =
          profile['preferences']['voice_permission'] ?? false;
      final theme = profile['preferences']['theme'] ?? 'light';
      setState(() => _voicePermissionEnabled = voicePermission);
      await prefs.setBool('voice_permission_enabled', voicePermission);
      themeNotifier.value = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      await prefs.setBool('isDarkMode', theme == 'dark');
    } else {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _voicePermissionEnabled =
            prefs.getBool('voice_permission_enabled') ?? false;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    await context.read<NotificationProvider>().setEnabled(value);
    if (mounted) {
      UIFeedback.showSuccess(
          context, value ? 'Notifications enabled!' : 'Notifications disabled');
    }
  }

  Future<void> _toggleVoicePermission(bool value) async {
    setState(() => _voicePermissionEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_permission_enabled', value);
    await UserService.updatePreferences(voicePermission: value);
    if (mounted) {
      UIFeedback.showSuccess(context,
          value ? 'Microphone access granted!' : 'Voice permission disabled');
    }
  }

  bool get _isDark => themeNotifier.value == ThemeMode.dark;

  Future<void> _toggleDarkMode(bool value) async {
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    await UserService.updatePreferences(theme: value ? 'dark' : 'light');
    if (mounted) {
      UIFeedback.showSuccess(
          context, value ? 'Dark mode enabled' : 'Light mode enabled');
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    UIFeedback.showSuccess(context, 'Email copied to clipboard!');
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  Future<void> _logout() async {
    context.read<NotificationProvider>().clearLocalNotifications();
    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _showLogoutDialog() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ✅ Show custom dialog with sad robot
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: theme.cardColor,
        title: Column(
          children: [
            // ✅ Sad Robot
            const RobotMascot(
              expression: RobotExpression.sad,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              'Log Out',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodySmall?.color,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          // ✅ Both buttons with same width
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.textTheme.bodySmall?.color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: theme.dividerColor,
                        width: 1,
                      ),
                    ),
                    minimumSize:
                        const Size(double.infinity, 48), // ✅ Fixed height
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize:
                        const Size(double.infinity, 48), // ✅ Fixed height
                  ),
                  child: const Text(
                    'Log Out',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _logout();
    }
  }

  void _showContactDialog() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact Us',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Reach out and we\'ll get back to you.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 24),
            _ContactRow(
              label: 'Rabeea Noor',
              email: 'rabeeea.noor@gmail.com',
              onCopy: () {
                _copyToClipboard('rabeeea.noor@gmail.com');
                Navigator.pop(ctx);
              },
            ),
            Divider(height: 24, color: theme.dividerColor),
            _ContactRow(
              label: 'Taiba Asif',
              email: 'taibaasif9252@gmail.com',
              onCopy: () {
                _copyToClipboard('taibaasif9252@gmail.com');
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close',
                    style: TextStyle(
                        color: theme.textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Privacy Policy',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Last updated March 2024',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  children: const [
                    _PolicySection(
                      title: 'Data Collection',
                      content:
                          'We collect your name, email address, and task data solely to provide the Cognify service. No data is sold or shared with third parties.',
                    ),
                    _PolicySection(
                      title: 'How We Use Your Data',
                      content:
                          'Your data is used to personalise your experience, generate productivity insights, and improve the app. It is never used for advertising.',
                    ),
                    _PolicySection(
                      title: 'Data Security',
                      content:
                          'All data is transmitted over HTTPS and stored with industry-standard encryption. Access is restricted to authorised systems only.',
                    ),
                    _PolicySection(
                      title: 'Your Rights',
                      content:
                          'You may request a copy of your data or permanent deletion at any time by contacting us. Deletion removes all records within 30 days.',
                    ),
                    _PolicySection(
                      title: 'Contact',
                      content:
                          'For privacy-related questions, email taibaasif9252@gmail.com or rabeeea.noor@gmail.com.',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Close',
                        style: TextStyle(
                            color: theme.textTheme.bodySmall?.color,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(title: 'Settings', onBack: () => widget.onTabSelected(0)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Consumer<AuthProvider>(
                  builder: (_, auth, __) => Column(
                    children: [
                      // Profile Card
                      AppCard(
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle),
                              child: Icon(Icons.person_rounded,
                                  size: 30, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(auth.userName,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(
                                    auth.userEmail,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Account Section
                      SectionCard(
                        title: 'Account',
                        children: [
                          _TapRow(
                            icon: Icons.edit_outlined,
                            label: 'Edit Profile',
                            onTap: _navigateToEditProfile,
                            showArrow: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Preferences Section
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: themeNotifier,
                        builder: (context, mode, _) => SectionCard(
                          title: 'Preferences',
                          children: [
                            Consumer<NotificationProvider>(
                              builder: (context, notifProvider, child) =>
                                  _ToggleRow(
                                icon: Icons.notifications_outlined,
                                label: 'Notifications',
                                value: notifProvider.isEnabled,
                                onChanged: _toggleNotifications,
                              ),
                            ),
                            const RowDivider(),
                            _ToggleRow(
                                icon: Icons.dark_mode_outlined,
                                label: 'Dark Mode',
                                value: mode == ThemeMode.dark,
                                onChanged: _toggleDarkMode),
                            const RowDivider(),
                            _ToggleRow(
                                icon: Icons.mic_outlined,
                                label: 'Voice Permission',
                                value: _voicePermissionEnabled,
                                onChanged: _toggleVoicePermission),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Support Section
                      SectionCard(title: 'Support', children: [
                        _TapRow(
                            icon: Icons.headset_mic_outlined,
                            label: 'Contact Us',
                            onTap: _showContactDialog,
                            showArrow: true),
                        const RowDivider(),
                        _TapRow(
                            icon: Icons.privacy_tip_outlined,
                            label: 'Privacy Policy',
                            onTap: _showPrivacyPolicyDialog,
                            showArrow: true),
                      ]),
                      const SizedBox(height: 16),

                      // About Section
                      SectionCard(title: 'About', children: [
                        _TapRow(
                            icon: Icons.info_outline_rounded,
                            label: 'App version',
                            trailing: Text(AppConstants.appVersion,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textTheme.bodySmall?.color)),
                            onTap: () {},
                            showArrow: false),
                      ]),
                      const SizedBox(height: 32),

                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: auth.isLoading ? null : _showLogoutDialog,
                          icon: auth.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.logout_rounded,
                                  color: Colors.white, size: 20),
                          label: Text(
                              auth.isLoading ? 'Logging out...' : 'Log out',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade500,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30))),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const AiChatFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Consumer<AuthProvider>(
        builder: (_, auth, __) => BottomNavBar(
          currentIndex: widget.currentIndex,
          userName: auth.userName,
          onTabSelected: widget.onTabSelected,
        ),
      ),
    );
  }
}

// Private widgets (unchanged)
class _PolicySection extends StatelessWidget {
  final String title, content;
  const _PolicySection({required this.title, required this.content});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(content, style: theme.textTheme.bodySmall),
    ]);
  }
}

class _ContactRow extends StatelessWidget {
  final String label;
  final String email;
  final VoidCallback onCopy;
  const _ContactRow(
      {required this.label, required this.email, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(email, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        IconButton(
          onPressed: onCopy,
          icon: Icon(Icons.copy_rounded,
              size: 18, color: theme.colorScheme.primary),
          tooltip: 'Copy email',
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500))),
        Switch(
            value: value,
            onChanged: onChanged,
            activeColor: theme.colorScheme.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ]),
    );
  }
}

class _TapRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showArrow;

  const _TapRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.showArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null) trailing!,
            if (showArrow)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.textTheme.bodySmall?.color,
              ),
          ],
        ),
      ),
    );
  }
}

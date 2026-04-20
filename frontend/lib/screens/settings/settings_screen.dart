// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/settings/settings_screen.dart
// CHANGES:
//   - Added Account section with Edit Profile option
//   - Added arrow icon in front of Edit Profile
//   - Kept original profile picture (Avatar with person icon)
//   - Removed "See Personal info"
//   - Replaced all .withOpacity() with .withValues(alpha:)
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_constant.dart';
import '../../providers/auth_provider.dart';
import '../../utils/ui_feedback.dart';
import '../../theme/theme_notifier.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/voice_fab.dart';
import '../../widgets/layout/section_card.dart';
import '../../widgets/layout/row_divider.dart';
import 'profile_screen.dart';

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
  bool _notificationsEnabled = false;
  bool _voicePermissionEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _voicePermissionEnabled =
          prefs.getBool('voice_permission_enabled') ?? false;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (mounted) {
      UIFeedback.showSuccess(
          context, value ? 'Notifications enabled!' : 'Notifications disabled');
    }
  }

  Future<void> _toggleVoicePermission(bool value) async {
    setState(() => _voicePermissionEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_permission_enabled', value);
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
    try {
      await context.read<AuthProvider>().logout();
    } catch (e) {
      if (mounted) {
        UIFeedback.showError(context, 'Logout failed. Please try again.');
      }
    }
  }

  void _showLogoutDialog() async {
    final confirmed = await UIFeedback.showConfirmDialog(
      context,
      title: 'Log Out',
      message: 'Are you sure you want to log out?',
      confirmLabel: 'Log Out',
      cancelLabel: 'Cancel',
      confirmColor: Colors.red,
    );
    if (confirmed) _logout();
  }

  void _showContactDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: theme.cardColor, borderRadius: BorderRadius.circular(28)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppConstants.primaryBlue,
                      AppConstants.primaryBlue.withValues(alpha: 0.7)
                    ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle),
                child: const Icon(Icons.headset_mic_outlined,
                    size: 32, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text("We'd Love to Hear From You!",
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Have questions, feedback, or need support?',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.textTheme.bodySmall?.color),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E2A)
                        : const Color(0xFFF5F7FF),
                    borderRadius: BorderRadius.circular(20)),
                child: Column(children: [
                  _ContactEmailCard(
                      email: 'rabeeea.noor@gmail.com',
                      onTap: () => _copyToClipboard('rabeeea.noor@gmail.com')),
                  const Divider(height: 1),
                  _ContactEmailCard(
                      email: 'taibaasif9252@gmail.com',
                      onTap: () => _copyToClipboard('taibaasif9252@gmail.com')),
                ]),
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: AppConstants.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.access_time_rounded,
                      size: 16, color: AppConstants.primaryBlue),
                  const SizedBox(width: 6),
                  const Text("We'll respond within 24-48 hours",
                      style: TextStyle(
                          fontSize: 12,
                          color: AppConstants.primaryBlue,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: theme.dividerColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      child: const Text('Close'))),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppConstants.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.privacy_tip_outlined,
                  color: AppConstants.primaryBlue, size: 22)),
          const SizedBox(width: 12),
          const Text('Privacy Policy',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Cognify',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _PolicySection(
                  title: '📋 Data Collection',
                  content:
                      'We collect your email, name, and task data to provide personalized productivity insights.'),
              const SizedBox(height: 16),
              _PolicySection(
                  title: '🎯 Data Usage',
                  content:
                      'Your data is used only within Cognify to help you stay organized and productive.'),
              const SizedBox(height: 16),
              _PolicySection(
                  title: '🔒 Data Security',
                  content:
                      'We use industry-standard encryption to protect your data.'),
              const SizedBox(height: 16),
              _PolicySection(
                  title: '👤 Your Rights',
                  content:
                      'You can request data deletion at any time by contacting us.'),
              const SizedBox(height: 16),
              _PolicySection(
                  title: '📧 Contact',
                  content:
                      'For privacy concerns, email us at support@cognify.app'),
              const SizedBox(height: 12),
              Text('Last updated: March 2024',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
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
                      // Profile Card - Original design
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

                      // Account Section with Arrow
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
                            _ToggleRow(
                                icon: Icons.notifications_outlined,
                                label: 'Notifications',
                                value: _notificationsEnabled,
                                onChanged: _toggleNotifications),
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
      floatingActionButton: const VoiceFab(),
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

// Private widgets
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

class _ContactEmailCard extends StatelessWidget {
  final String email;
  final VoidCallback onTap;
  const _ContactEmailCard({required this.email, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: AppConstants.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.email_outlined,
                    size: 22, color: AppConstants.primaryBlue)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Email Us',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.textTheme.bodySmall?.color)),
                  const SizedBox(height: 2),
                  Text(email,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
                ])),
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppConstants.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.copy_rounded,
                    size: 16, color: AppConstants.primaryBlue)),
          ]),
        ));
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

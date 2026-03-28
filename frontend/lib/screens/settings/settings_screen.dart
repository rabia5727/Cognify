// ═══════════════════════════════════════════════════════════════════
// FILE: lib/screens/settings/settings_screen.dart
// FIX: Uses global themeNotifier directly instead of
//      CoTaskerApp.of(context) which broke inside IndexedStack.
//      Toggle now works instantly across the whole app.
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_constant.dart';
import '../../theme_notifier.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_header.dart';
import '../../widgets/voice_fab.dart';
import '../../widgets/section_card.dart';
import '../../widgets/row_divider.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String userName;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const SettingsScreen({
    super.key,
    required this.userName,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;
  bool _voicePermissionEnabled = true;

  // Read dark mode state from global notifier
  bool get _isDark => themeNotifier.value == ThemeMode.dark;

  // ── Toggle dark mode ───────────────────────────────────────────────
  Future<void> _toggleDarkMode(bool value) async {
    // Update global notifier → main.dart rebuilds MaterialApp instantly
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;

    // Save to persist across restarts
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  // ── Logout dialog ──────────────────────────────────────────────────
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: AppConstants.grayText)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out successfully')),
                );
              }
            },
            child: const Text('Log Out',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF1F1F3) : AppConstants.darkText;
    final subTextColor =
        isDark ? const Color(0xFF9EA3B8) : AppConstants.grayText;
    final bgColor = isDark ? const Color(0xFF0F1117) : AppConstants.scaffoldBg;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Settings',
              onBack: () => widget.onTabSelected(0),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  children: [
                    // 1. Profile card
                    AppCard(
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppConstants.primaryBlue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_rounded,
                                size: 30, color: AppConstants.primaryBlue),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.userName,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    )),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => ProfileScreen(
                                              userName: widget.userName))),
                                  child: const Text('See Personal info >',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppConstants.primaryBlue,
                                        fontWeight: FontWeight.w500,
                                      )),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 2. Preferences
                    // ValueListenableBuilder keeps toggle in sync with actual theme
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeNotifier,
                      builder: (context, mode, _) {
                        return SectionCard(
                          title: 'Preferences',
                          children: [
                            _ToggleRow(
                              icon: Icons.notifications_outlined,
                              label: 'Notifications',
                              value: _notificationsEnabled,
                              onChanged: (v) =>
                                  setState(() => _notificationsEnabled = v),
                            ),
                            const RowDivider(),
                            // Dark mode toggle — reads from notifier so
                            // it always shows the correct state
                            _ToggleRow(
                              icon: Icons.dark_mode_outlined,
                              label: 'Dark Mode',
                              value: mode == ThemeMode.dark,
                              onChanged: _toggleDarkMode,
                            ),
                            const RowDivider(),
                            _ToggleRow(
                              icon: Icons.mic_outlined,
                              label: 'Voice Permission',
                              value: _voicePermissionEnabled,
                              onChanged: (v) =>
                                  setState(() => _voicePermissionEnabled = v),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // 3. Support
                    SectionCard(
                      title: 'Support',
                      children: [
                        _TapRow(
                          icon: Icons.help_outline_rounded,
                          label: 'Help',
                          onTap: () => ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                                  content: Text('Help coming soon!'))),
                        ),
                        const RowDivider(),
                        _TapRow(
                          icon: Icons.headset_mic_outlined,
                          label: 'Contact us',
                          onTap: () => ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                                  content: Text('Contact coming soon!'))),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 4. About
                    SectionCard(
                      title: 'About',
                      children: [
                        _TapRow(
                          icon: Icons.info_outline_rounded,
                          label: 'App version',
                          trailing: Text(AppConstants.appVersion,
                              style:
                                  TextStyle(fontSize: 12, color: subTextColor)),
                          onTap: () {},
                        ),
                        const RowDivider(),
                        _TapRow(
                          icon: Icons.privacy_tip_outlined,
                          label: 'Privacy Policy',
                          onTap: () => ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                                  content:
                                      Text('Privacy Policy coming soon!'))),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // 5. Logout
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _showLogoutDialog,
                        icon: const Icon(Icons.logout_rounded,
                            color: Colors.white, size: 20),
                        label: const Text('Log out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            )),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade500,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const VoiceFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavBar(
        currentIndex: widget.currentIndex,
        userName: widget.userName,
        onTabSelected: widget.onTabSelected,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Toggle Row
// ─────────────────────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF1F1F3)
        : AppConstants.darkText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppConstants.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                )),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppConstants.primaryBlue,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Tap Row
// ─────────────────────────────────────────────────────────────────────────────

class _TapRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _TapRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF1F1F3)
        : AppConstants.darkText;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppConstants.primaryBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  )),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

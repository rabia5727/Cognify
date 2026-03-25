import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/app_card.dart';

enum SettingType {
  notifications,
  darkMode,
  voicePermission,
}

class SettingsScreen extends StatefulWidget {
  final Function(int) onNavTap;
  final int currentIndex;
  final String userName;

  const SettingsScreen({
    super.key,
    required this.onNavTap,
    required this.currentIndex,
    required this.userName,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;
  bool _darkModeEnabled = true;
  bool _voicePermissionEnabled = true;

  String _userName = '';
  String _userEmail = 'eiman.asmat@example.com';
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _userName = widget.userName;
  }

  void _updateSetting(bool value, SettingType type) {
    setState(() {
      switch (type) {
        case SettingType.notifications:
          _notificationsEnabled = value;
          break;
        case SettingType.darkMode:
          _darkModeEnabled = value;
          break;
        case SettingType.voicePermission:
          _voicePermissionEnabled = value;
          break;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${type.name} ${value ? "enabled" : "disabled"}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logged out successfully')),
              );
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPersonalInfoDialog() {
    final nameController = TextEditingController(text: _userName);
    final emailController = TextEditingController(text: _userEmail);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Personal Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _userName = nameController.text;
                _userEmail = emailController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAppVersionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Version'),
        content: Text('Version $_appVersion'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const Text('Privacy policy placeholder...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openHelp() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Open Help Screen')));
  }

  void _contactUs() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Contact Support')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => widget.onNavTap(0),
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.darkText,
                  ),
                  const Expanded(
                    child: Text(
                      'Settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Profile Header - Using AppCard
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.person_rounded,
                                size: 32,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _userEmail,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.grayText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: _showPersonalInfoDialog,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.edit_rounded,
                                        size: 14,
                                        color: AppColors.primaryBlue,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'See Personal info >',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primaryBlue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Preferences Section
                    _SettingsSection(
                      title: 'PREFERENCES',
                      isFirst: true,
                      children: [
                        _SettingsTile(
                          icon: Icons.notifications,
                          title: 'Notifications',
                          subtitle: 'Receive task reminders and updates',
                          trailing: Switch(
                            value: _notificationsEnabled,
                            onChanged: (v) =>
                                _updateSetting(v, SettingType.notifications),
                            activeColor: AppColors.primaryBlue,
                          ),
                        ),
                        _SettingsTile(
                          icon: Icons.dark_mode,
                          title: 'Dark Mode',
                          subtitle: 'Switch to dark theme',
                          trailing: Switch(
                            value: _darkModeEnabled,
                            onChanged: (v) =>
                                _updateSetting(v, SettingType.darkMode),
                            activeColor: AppColors.primaryBlue,
                          ),
                        ),
                        _SettingsTile(
                          icon: Icons.mic,
                          title: 'Voice Permission',
                          subtitle: 'Allow voice input for tasks',
                          trailing: Switch(
                            value: _voicePermissionEnabled,
                            onChanged: (v) =>
                                _updateSetting(v, SettingType.voicePermission),
                            activeColor: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),

                    // Support Section
                    _SettingsSection(
                      title: 'SUPPORT',
                      children: [
                        _SettingsTile(
                          icon: Icons.help,
                          title: 'Help',
                          subtitle: 'Get assistance and tutorials',
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openHelp,
                        ),
                        _SettingsTile(
                          icon: Icons.contact_support,
                          title: 'Contact Us',
                          subtitle: 'Reach out to our support team',
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _contactUs,
                        ),
                      ],
                    ),

                    // About Section
                    _SettingsSection(
                      title: 'ABOUT',
                      children: [
                        _SettingsTile(
                          icon: Icons.info,
                          title: 'App Version',
                          subtitle: 'Version $_appVersion',
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showAppVersionDialog,
                        ),
                        _SettingsTile(
                          icon: Icons.privacy_tip,
                          title: 'Privacy Policy',
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showPrivacyPolicy,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Log Out Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _showLogoutDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: widget.currentIndex,
        onTap: (index) {
          if (index != widget.currentIndex) {
            widget.onNavTap(index);
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}

// ============================================================================
// WIDGETS
// ============================================================================

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isFirst;

  const _SettingsSection({
    required this.title,
    required this.children,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isFirst) const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.grayText,
              letterSpacing: 0.5,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.darkText,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.grayText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: AppColors.lightGray,
          indent: 70,
        ),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white,
      elevation: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround, // Fixed spacing
          children: [
            _NavItem(
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              isSelected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.bar_chart_rounded,
              label: 'Analytics',
              isSelected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            _NavItem(
              icon: Icons.task_alt_rounded,
              label: 'Tasks',
              isSelected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
            _NavItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              isSelected: currentIndex == 3,
              onTap: () => onTap(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primaryBlue : AppColors.grayText;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

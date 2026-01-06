import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr()),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display Section
              _buildSectionTitle('display'.tr()),
              _buildDisplaySection(context),
              const SizedBox(height: 16),

              // Account Section
              _buildSectionTitle('account'.tr()),
              _buildAccountSection(context),
              const SizedBox(height: 16),

              // Notifications Section
              _buildSectionTitle('notifications'.tr()),
              _buildNotificationsSection(context),
              const SizedBox(height: 16),

              // Privacy & Security Section
              _buildSectionTitle('privacy_security'.tr()),
              _buildPrivacySection(context),
              const SizedBox(height: 16),

              // About Section
              _buildSectionTitle('about'.tr()),
              _buildAboutSection(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1DB954),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDisplaySection(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      children: [
        // Theme Toggle
        _buildSettingsTile(
          icon: Icons.brightness_4,
          title: 'theme'.tr(),
          subtitle: themeProvider.themeMode == ThemeMode.dark
              ? 'dark_mode'.tr()
              : 'light_mode'.tr(),
          trailing: Switch(
            value: themeProvider.themeMode == ThemeMode.dark,
            onChanged: (bool value) {
              themeProvider.setTheme(value ? ThemeMode.dark : ThemeMode.light);
            },
            activeColor: const Color(0xFF1DB954),
          ),
        ),

        // Language Selection
        _buildSettingsTile(
          icon: Icons.language,
          title: 'language'.tr(),
          subtitle: _getLanguageLabel(context.locale),
          onTap: () => _showLanguageDialog(context),
          trailing: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Column(
      children: [
        // Profile Info
        if (authProvider.user != null)
          _buildSettingsTile(
            icon: Icons.person,
            title: authProvider.user!['username'] ?? 'User',
            subtitle: authProvider.user!['email'] ?? 'No email',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to profile edit
            },
          ),

        // Change Password
        _buildSettingsTile(
          icon: Icons.lock,
          title: 'change_password'.tr(),
          subtitle: 'update_password_subtitle'.tr(),
          onTap: () {
            // Navigate to change password screen
          },
          trailing: const Icon(Icons.chevron_right),
        ),

        // Logout
        _buildSettingsTile(
          icon: Icons.logout,
          title: 'logout'.tr(),
          subtitle: 'logout_subtitle'.tr(),
          onTap: () => _confirmLogout(context),
          trailing: Icon(
            Icons.chevron_right,
            color: Colors.red.withOpacity(0.7),
          ),
          titleColor: Colors.red,
        ),
      ],
    );
  }

  Widget _buildNotificationsSection(BuildContext context) {
    return Column(
      children: [
        // Push Notifications
        _buildSettingsTile(
          icon: Icons.notifications,
          title: 'push_notifications'.tr(),
          subtitle: 'enable_notifications'.tr(),
          trailing: Switch(
            value: true,
            onChanged: (bool value) {
              // Handle notification toggle
            },
            activeColor: const Color(0xFF1DB954),
          ),
        ),

        // Email Notifications
        _buildSettingsTile(
          icon: Icons.mail,
          title: 'email_notifications'.tr(),
          subtitle: 'email_notification_subtitle'.tr(),
          trailing: Switch(
            value: true,
            onChanged: (bool value) {
              // Handle email notification toggle
            },
            activeColor: const Color(0xFF1DB954),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection(BuildContext context) {
    return Column(
      children: [
        // Private Account
        _buildSettingsTile(
          icon: Icons.privacy_tip,
          title: 'private_account'.tr(),
          subtitle: 'private_account_subtitle'.tr(),
          trailing: Switch(
            value: false,
            onChanged: (bool value) {
              // Handle private account toggle
            },
            activeColor: const Color(0xFF1DB954),
          ),
        ),

        // Block Users
        _buildSettingsTile(
          icon: Icons.block,
          title: 'blocked_users'.tr(),
          subtitle: 'manage_blocked_users'.tr(),
          onTap: () {
            // Navigate to blocked users
          },
          trailing: const Icon(Icons.chevron_right),
        ),

        // Privacy Policy
        _buildSettingsTile(
          icon: Icons.description,
          title: 'privacy_policy'.tr(),
          subtitle: 'read_our_privacy_policy'.tr(),
          onTap: () {
            // Open privacy policy
          },
          trailing: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      children: [
        // Version
        _buildSettingsTile(
          icon: Icons.info,
          title: 'version'.tr(),
          subtitle: 'v1.0.0',
          trailing: const SizedBox.shrink(),
        ),

        // Terms of Service
        _buildSettingsTile(
          icon: Icons.assignment,
          title: 'terms_of_service'.tr(),
          subtitle: 'read_our_terms'.tr(),
          onTap: () {
            // Open terms
          },
          trailing: const Icon(Icons.chevron_right),
        ),

        // Contact Support
        _buildSettingsTile(
          icon: Icons.help,
          title: 'contact_support'.tr(),
          subtitle: 'get_help_support'.tr(),
          onTap: () {
            // Open support
          },
          trailing: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return Material(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: titleColor ?? const Color(0xFF1DB954),
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  String _getLanguageLabel(Locale locale) {
    if (locale.languageCode == 'fr') {
      return 'Français';
    } else if (locale.languageCode == 'en') {
      return 'English';
    }
    return 'Unknown';
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('select_language'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('🇫🇷 Français'),
                onTap: () {
                  context.setLocale(const Locale('fr'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('🇬🇧 English'),
                onTap: () {
                  context.setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('confirm_logout'.tr()),
          content: Text('logout_confirmation_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _logout(context);
              },
              child: Text(
                'logout'.tr(),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _logout(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.logout();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }
}

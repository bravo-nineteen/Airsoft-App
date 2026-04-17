import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import 'account_settings_screen.dart';
import 'display_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.currentLocale,
    this.onLocaleChanged,
    this.currentThemeMode,
    this.onThemeModeChanged,
  });

  final Locale? currentLocale;
  final ValueChanged<Locale?>? onLocaleChanged;
  final ThemeMode? currentThemeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  void _navigate(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();

    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _confirmLogout(BuildContext context, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          content: Text(l10n.t('logoutConfirmMessage')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('logout')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _logout(context);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t('logoutFailed', args: {'error': '$error'}),
          ),
        ),
      );
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _tile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: textColor == null ? null : TextStyle(color: textColor)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          _sectionTitle(l10n.t('display')),
          _tile(
            context: context,
            icon: Icons.palette_outlined,
            title: l10n.t('display'),
            subtitle: l10n.t('lightDarkControls'),
            onTap: () => _navigate(
              context,
              DisplaySettingsScreen(
                currentThemeMode: currentThemeMode,
                onThemeModeChanged: onThemeModeChanged,
                currentLocale: currentLocale,
                onLocaleChanged: onLocaleChanged,
              ),
            ),
          ),
          _sectionTitle(l10n.t('notifications')),
          _tile(
            context: context,
            icon: Icons.notifications_outlined,
            title: l10n.t('pushNotifications'),
            subtitle: l10n.t('manageAlerts'),
            onTap: () =>
                _navigate(context, const NotificationSettingsScreen()),
          ),
          _sectionTitle(l10n.t('privacy')),
          _tile(
            context: context,
            icon: Icons.privacy_tip_outlined,
            title: l10n.t('privacyControls'),
            subtitle: l10n.t('profileVisibilityPermissions'),
            onTap: () => _navigate(context, const PrivacySettingsScreen()),
          ),
          _sectionTitle(l10n.t('account')),
          _tile(
            context: context,
            icon: Icons.person_outline,
            title: l10n.t('viewSignedInEmail'),
            onTap: () => _navigate(context, const AccountSettingsScreen()),
          ),
          const Divider(height: 8),
          _tile(
            context: context,
            icon: Icons.logout,
            iconColor: Theme.of(context).colorScheme.error,
            title: l10n.t('logout'),
            textColor: Theme.of(context).colorScheme.error,
            onTap: () => _confirmLogout(context, l10n),
          ),
        ],
      ),
    );
  }
}

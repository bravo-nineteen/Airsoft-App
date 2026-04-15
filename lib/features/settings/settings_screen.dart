import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import '../../core/notifications/notification_settings_screen.dart';
import '../auth/login_screen.dart';
import '../social/contacts_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.currentLocale,
    this.onLocaleChanged,
  });

  final Locale? currentLocale;
  final ValueChanged<Locale>? onLocaleChanged;

  Future<void> _showLanguagePicker(BuildContext context) async {
    final selected = currentLocale ?? Localizations.localeOf(context);

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('English'),
                trailing: selected.languageCode == 'en'
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  onLocaleChanged?.call(const Locale('en'));
                  Navigator.of(sheetContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('日本語'),
                trailing: selected.languageCode == 'ja'
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  onLocaleChanged?.call(const Locale('ja'));
                  Navigator.of(sheetContext).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  void _showLogoutConfirm(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Do you want to sign out of your account?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _logout(context);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedLanguageCode =
        (currentLocale ?? Localizations.localeOf(context)).languageCode;
    final selectedLanguageLabel =
        selectedLanguageCode == 'ja' ? '日本語' : 'English';

    final items = [
      _SettingsGroup(
        title: 'Display',
        tiles: [
          _SettingsTileData(
            icon: Icons.palette_outlined,
            title: l10n.theme,
            subtitle: 'Light and dark display controls',
          ),
          _SettingsTileData(
            icon: Icons.language_outlined,
            title: l10n.language,
            subtitle: selectedLanguageLabel,
            onTap: () => _showLanguagePicker(context),
          ),
        ],
      ),
      _SettingsGroup(
        title: 'Notifications',
        tiles: [
          _SettingsTileData(
            icon: Icons.notifications_outlined,
            title: 'Push Notifications',
            subtitle: 'Manage event, board, DM, and field alerts',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      _SettingsGroup(
        title: 'Privacy',
        tiles: const [
          _SettingsTileData(
            icon: Icons.lock_outline,
            title: 'Privacy Controls',
            subtitle: 'Profile visibility and interaction permissions',
          ),
          _SettingsTileData(
            icon: Icons.block_outlined,
            title: 'Blocked Users',
            subtitle: 'Manage blocked accounts',
          ),
        ],
      ),
      _SettingsGroup(
        title: 'Account',
        tiles: [
          const _SettingsTileData(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            subtitle: 'Call sign, avatar, and account details',
          ),
          _SettingsTileData(
            icon: Icons.people_outline,
            title: l10n.contacts,
            subtitle: 'Manage your contacts and requests',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ContactsScreen(),
                ),
              );
            },
          ),
          const _SettingsTileData(
            icon: Icons.mail_outline,
            title: 'Email',
            subtitle: 'View your signed-in email account',
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  for (final group in items) ...[
                    _SectionHeader(title: group.title),
                    ...group.tiles.map((tile) => _SettingsTile(data: tile)),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showLogoutConfirm(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup {
  const _SettingsGroup({
    required this.title,
    required this.tiles,
  });

  final String title;
  final List<_SettingsTileData> tiles;
}

class _SettingsTileData {
  const _SettingsTileData({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.data,
  });

  final _SettingsTileData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(data.icon),
        title: Text(data.title),
        subtitle: Text(data.subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: data.onTap,
      ),
    );
  }
}
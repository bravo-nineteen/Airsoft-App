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
    final l10n = AppLocalizations.of(context);
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
                title: Text(l10n.t('english')),
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
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).t('logoutFailed', args: {'error': '$e'}),
          ),
        ),
      );
    }
  }

  void _showLogoutConfirm(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.t('logout')),
          content: Text(l10n.t('logoutConfirmMessage')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _logout(context);
              },
              child: Text(l10n.t('logout')),
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
        selectedLanguageCode == 'ja' ? l10n.t('japanese') : l10n.t('english');

    final items = [
      _SettingsGroup(
        title: l10n.t('display'),
        tiles: [
          _SettingsTileData(
            icon: Icons.palette_outlined,
            title: l10n.theme,
            subtitle: l10n.t('lightDarkControls'),
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
        title: l10n.t('notifications'),
        tiles: [
          _SettingsTileData(
            icon: Icons.notifications_outlined,
            title: l10n.t('pushNotifications'),
            subtitle: l10n.t('manageAlerts'),
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
        title: l10n.t('privacy'),
        tiles: [
          _SettingsTileData(
            icon: Icons.lock_outline,
            title: l10n.t('privacyControls'),
            subtitle: l10n.t('profileVisibilityPermissions'),
          ),
          _SettingsTileData(
            icon: Icons.block_outlined,
            title: l10n.t('blockedUsers'),
            subtitle: l10n.t('manageBlockedAccounts'),
          ),
        ],
      ),
      _SettingsGroup(
        title: l10n.t('account'),
        tiles: [
          _SettingsTileData(
            icon: Icons.person_outline,
            title: l10n.editProfile,
            subtitle: l10n.t('profileAccountDetails'),
          ),
          _SettingsTileData(
            icon: Icons.people_outline,
            title: l10n.contacts,
            subtitle: l10n.t('manageContactsRequests'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ContactsScreen(),
                ),
              );
            },
          ),
          _SettingsTileData(
            icon: Icons.mail_outline,
            title: l10n.t('email'),
            subtitle: l10n.t('viewSignedInEmail'),
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
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
                  label: Text(l10n.t('logout')),
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
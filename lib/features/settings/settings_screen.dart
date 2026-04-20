import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import '../admin/admin_repository.dart';
import '../admin/admin_screen.dart';
import '../notifications/notifications_screen.dart';
import 'account_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
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

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Set<String> _supportedLanguageCodes = <String>{'en', 'ja'};

  final AdminRepository _adminRepository = AdminRepository();
  late ThemeMode _selectedThemeMode;
  String? _selectedLanguageCode;

  @override
  void initState() {
    super.initState();
    _selectedThemeMode = widget.currentThemeMode ?? ThemeMode.system;
    _selectedLanguageCode = widget.currentLocale?.languageCode;
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();

    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _confirmAndLogout(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.t('logout')),
          content: Text(l10n.t('logoutConfirmMessage')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('logout')),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && context.mounted) {
      await _logout(context);
    }
  }

  void _updateThemeMode(ThemeMode value) {
    setState(() {
      _selectedThemeMode = value;
    });
    widget.onThemeModeChanged?.call(value);
  }

  void _updateLanguageCode(String? languageCode) {
    final normalizedLanguageCode =
        _supportedLanguageCodes.contains(languageCode) ? languageCode : null;

    setState(() {
      _selectedLanguageCode = normalizedLanguageCode;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onLocaleChanged?.call(
        normalizedLanguageCode == null ? null : Locale(normalizedLanguageCode),
      );
    });
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
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<void> _showAdminSetupHelp(Object? error) async {
    final String currentUserId =
        Supabase.instance.client.auth.currentUser?.id ?? 'Not logged in';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Admin setup help'),
          content: SingleChildScrollView(
            child: Text(
              'Admin access is based on public.admin_roles.\n\n'
              'Current user id:\n$currentUserId\n\n'
              'If Admin Area does not open, ensure:\n'
              '1) Admin migrations were run in Supabase SQL editor.\n'
              '2) Your user id exists in public.admin_roles.\n'
              '3) public.is_admin(uuid) returns true for your user id.\n\n'
              'Error details:\n${error ?? 'No error details'}',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
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
      _supportedLanguageCodes.contains(_selectedLanguageCode)
        ? _selectedLanguageCode
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings'))),
      body: ListView(
        children: [
          _sectionTitle(l10n.t('display')),
          ListTile(
            leading: const Icon(Icons.light_mode_outlined),
            title: Text(l10n.t('theme')),
            subtitle: Text(l10n.t('lightDarkControls')),
          ),
          RadioListTile<ThemeMode>(
            title: Text(l10n.t('lightMode')),
            value: ThemeMode.light,
            groupValue: _selectedThemeMode,
            onChanged: (value) {
              if (value != null) {
                _updateThemeMode(value);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: Text(l10n.t('darkMode')),
            value: ThemeMode.dark,
            groupValue: _selectedThemeMode,
            onChanged: (value) {
              if (value != null) {
                _updateThemeMode(value);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: Text(l10n.t('system')),
            value: ThemeMode.system,
            groupValue: _selectedThemeMode,
            onChanged: (value) {
              if (value != null) {
                _updateThemeMode(value);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(l10n.t('language')),
            trailing: DropdownButton<String?>(
              value: selectedLanguageCode,
              onChanged: _updateLanguageCode,
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l10n.t('system')),
                ),
                DropdownMenuItem<String?>(
                  value: 'en',
                  child: Text(l10n.t('english')),
                ),
                DropdownMenuItem<String?>(
                  value: 'ja',
                  child: Text(l10n.t('japanese')),
                ),
              ],
            ),
          ),

          _sectionTitle(l10n.t('notifications')),
          _tile(
            context: context,
            icon: Icons.notifications,
            title: l10n.t('notifications'),
            onTap: () => _navigate(context, const NotificationsScreen()),
          ),
          _tile(
            context: context,
            icon: Icons.notifications_outlined,
            title: l10n.t('manageAlerts'),
            onTap: () => _navigate(context, const NotificationSettingsScreen()),
          ),
          _sectionTitle(l10n.t('privacy')),
          _tile(
            context: context,
            icon: Icons.privacy_tip_outlined,
            title: l10n.t('privacyControls'),
            onTap: () => _navigate(context, const PrivacySettingsScreen()),
          ),

          _sectionTitle(l10n.t('account')),
          _tile(
            context: context,
            icon: Icons.manage_accounts_outlined,
            title: l10n.t('viewSignedInEmail'),
            onTap: () => _navigate(context, const AccountSettingsScreen()),
          ),
          FutureBuilder<bool>(
            future: _adminRepository.isCurrentUserAdmin(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ListTile(
                  leading: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Colors.amber,
                  ),
                  title: const Text('Admin Area (setup issue)'),
                  subtitle: const Text('Tap to view admin setup diagnostics.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showAdminSetupHelp(snapshot.error),
                );
              }

              if (snapshot.data != true) {
                return const SizedBox.shrink();
              }

              return _tile(
                context: context,
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin Area',
                onTap: () => _navigate(context, const AdminScreen()),
              );
            },
          ),
          _tile(
            context: context,
            icon: Icons.logout,
            title: l10n.t('logout'),
            onTap: () => _confirmAndLogout(context),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

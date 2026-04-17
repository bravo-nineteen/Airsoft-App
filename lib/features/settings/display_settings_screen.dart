import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';

class DisplaySettingsScreen extends StatelessWidget {
  const DisplaySettingsScreen({
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedThemeMode = currentThemeMode ?? ThemeMode.system;
    final selectedLocale = currentLocale?.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('display'))),
      body: ListView(
        children: [
          RadioListTile<ThemeMode>(
            title: Text(l10n.t('system')),
            value: ThemeMode.system,
            groupValue: selectedThemeMode,
            onChanged: onThemeModeChanged,
          ),
          RadioListTile<ThemeMode>(
            title: Text(l10n.lightMode),
            value: ThemeMode.light,
            groupValue: selectedThemeMode,
            onChanged: onThemeModeChanged,
          ),
          RadioListTile<ThemeMode>(
            title: Text(l10n.darkMode),
            value: ThemeMode.dark,
            groupValue: selectedThemeMode,
            onChanged: onThemeModeChanged,
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(l10n.language),
            trailing: DropdownButton<String?>(
              value: selectedLocale,
              onChanged: (languageCode) {
                onLocaleChanged?.call(
                  languageCode == null ? null : Locale(languageCode),
                );
              },
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
        ],
      ),
    );
  }
}

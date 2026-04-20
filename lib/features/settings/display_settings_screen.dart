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
    final selectedLanguageCode = currentLocale?.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('display'))),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.t('theme')),
            subtitle: Text(l10n.t('lightDarkControls')),
          ),
          RadioListTile<ThemeMode>(
            title: Text(l10n.t('system')),
            value: ThemeMode.system,
            groupValue: selectedThemeMode,
            onChanged: onThemeModeChanged == null
                ? null
                : (value) {
                    if (value != null) {
                      onThemeModeChanged!(value);
                    }
                  },
          ),
          RadioListTile<ThemeMode>(
            title: Text(l10n.t('lightMode')),
            value: ThemeMode.light,
            groupValue: selectedThemeMode,
            onChanged: onThemeModeChanged == null
                ? null
                : (value) {
                    if (value != null) {
                      onThemeModeChanged!(value);
                    }
                  },
          ),
          RadioListTile<ThemeMode>(
            title: Text(l10n.t('darkMode')),
            value: ThemeMode.dark,
            groupValue: selectedThemeMode,
            onChanged: onThemeModeChanged == null
                ? null
                : (value) {
                    if (value != null) {
                      onThemeModeChanged!(value);
                    }
                  },
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(l10n.t('language')),
            trailing: DropdownButton<String?>(
              value: selectedLanguageCode,
              onChanged: onLocaleChanged == null
                  ? null
                  : (languageCode) => onLocaleChanged!(
                        languageCode == null ? null : Locale(languageCode),
                      ),
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

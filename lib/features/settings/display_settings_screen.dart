import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';

class DisplaySettingsScreen extends StatelessWidget {
  const DisplaySettingsScreen({
    super.key,
    this.currentThemeMode,
    this.onThemeModeChanged,
    this.currentLocale,
    this.onLocaleChanged,
  });

  final ThemeMode? currentThemeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final Locale? currentLocale;
  final ValueChanged<Locale?>? onLocaleChanged;

  String _localeLabel(AppLocalizations l10n, Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return l10n.t('english');
      case 'ja':
        return l10n.t('japanese');
      default:
        return locale.languageCode.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedThemeMode = currentThemeMode ?? ThemeMode.system;
    final selectedLocale = currentLocale ?? Localizations.localeOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('display'))),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.theme),
            subtitle: Text(l10n.t('displayThemeSubtitle')),
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
            title: Text(l10n.lightMode),
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
            title: Text(l10n.darkMode),
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
          const Divider(),
          ListTile(
            title: Text(l10n.language),
          ),
          ...AppLocalizations.supportedLocales.map(
            (locale) => RadioListTile<Locale>(
              title: Text(_localeLabel(l10n, locale)),
              value: locale,
              groupValue: selectedLocale,
              onChanged: onLocaleChanged,
            ),
          ),
          ListTile(
            title: Text(l10n.fontSize),
            subtitle: Text(l10n.t('fontSizePlaceholder')),
          ),
        ],
      ),
    );
  }
}

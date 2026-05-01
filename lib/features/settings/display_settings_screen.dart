import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../../shared/widgets/persistent_shell_bottom_nav.dart';

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

  static const Set<String> _supportedLanguageCodes = <String>{'en', 'ja'};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedThemeMode = currentThemeMode ?? ThemeMode.system;
    final selectedLanguageCode =
      _supportedLanguageCodes.contains(currentLocale?.languageCode)
        ? currentLocale?.languageCode
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('display'))),
      bottomNavigationBar: const PersistentShellBottomNav(selectedIndex: 4),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.t('theme')),
            subtitle: Text(l10n.t('lightDarkControls')),
          ),
          RadioGroup<ThemeMode>(
            groupValue: selectedThemeMode,
            onChanged: (value) {
              if (value != null) {
                onThemeModeChanged?.call(value);
              }
            },
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: Text(l10n.t('system')),
                  value: ThemeMode.system,
                  enabled: onThemeModeChanged != null,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(l10n.t('lightMode')),
                  value: ThemeMode.light,
                  enabled: onThemeModeChanged != null,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(l10n.t('darkMode')),
                  value: ThemeMode.dark,
                  enabled: onThemeModeChanged != null,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(l10n.t('language')),
            trailing: DropdownButton<String?>(
              value: selectedLanguageCode,
              onChanged: onLocaleChanged == null
                  ? null
                  : (languageCode) {
                      final normalizedLanguageCode =
                          _supportedLanguageCodes.contains(languageCode)
                              ? languageCode
                              : null;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        onLocaleChanged!(
                          normalizedLanguageCode == null
                              ? null
                              : Locale(normalizedLanguageCode),
                        );
                      });
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

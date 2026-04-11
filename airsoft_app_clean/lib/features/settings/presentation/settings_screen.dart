import 'package:flutter/material.dart';

import '../../../app/app.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../app/router.dart';
import '../../../shared/widgets/section_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppStateScope appState = AppStateScope.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SectionCard(
          title: l10n.fontSize,
          child: Column(
            children: <Widget>[
              Slider(
                value: appState.fontScale,
                min: 0.9,
                max: 1.2,
                divisions: 3,
                label: appState.fontScale.toStringAsFixed(1),
                onChanged: appState.updateFontScale,
              ),
              Text('Scale: ${appState.fontScale.toStringAsFixed(1)}x'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l10n.theme,
          child: SegmentedButton<ThemeMode>(
            segments: <ButtonSegment<ThemeMode>>[
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text(l10n.lightMode),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text(l10n.darkMode),
              ),
            ],
            selected: <ThemeMode>{appState.themeMode},
            onSelectionChanged: (Set<ThemeMode> value) {
              appState.updateThemeMode(value.first);
            },
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l10n.language,
          child: DropdownButtonFormField<Locale>(
            value: appState.locale,
            items: const <DropdownMenuItem<Locale>>[
              DropdownMenuItem<Locale>(
                value: Locale('en'),
                child: Text('English'),
              ),
              DropdownMenuItem<Locale>(
                value: Locale('ja'),
                child: Text('日本語'),
              ),
            ],
            onChanged: (Locale? value) {
              if (value != null) {
                appState.updateLocale(value);
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l10n.offlineSync,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.downloadUpdates),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_outlined),
                label: Text(l10n.downloadUpdates),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SettingsLinkTile(
          title: l10n.notificationSettings,
          onTap: () =>
              Navigator.of(context).pushNamed(AppRouter.notificationSettings),
        ),
        const SizedBox(height: 12),
        _SettingsLinkTile(
          title: l10n.privacySettings,
          onTap: () => Navigator.of(context).pushNamed(AppRouter.privacySettings),
        ),
        const SizedBox(height: 12),
        _SettingsLinkTile(
          title: l10n.accountSettings,
          onTap: () => Navigator.of(context).pushNamed(AppRouter.accountSettings),
        ),
      ],
    );
  }
}

class _SettingsLinkTile extends StatelessWidget {
  const _SettingsLinkTile({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Card(
        child: ListTile(
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

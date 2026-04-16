import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';

class DisplaySettingsScreen extends StatelessWidget {
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('display'))),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.theme),
            subtitle: Text(l10n.t('displayThemeSubtitle')),
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

import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../../shared/widgets/persistent_shell_bottom_nav.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool showArea = true;
  bool showTeam = true;
  bool allowMessages = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('privacy'))),
      bottomNavigationBar: const PersistentShellBottomNav(selectedIndex: 4),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l10n.t('showAreaProfile')),
            value: showArea,
            onChanged: (value) => setState(() => showArea = value),
          ),
          SwitchListTile(
            title: Text(l10n.t('showTeamProfile')),
            value: showTeam,
            onChanged: (value) => setState(() => showTeam = value),
          ),
          SwitchListTile(
            title: Text(l10n.t('allowDirectMessages')),
            value: allowMessages,
            onChanged: (value) => setState(() => allowMessages = value),
          ),
        ],
      ),
    );
  }
}

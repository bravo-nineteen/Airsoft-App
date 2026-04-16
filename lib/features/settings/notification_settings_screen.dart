import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool eventNotifications = true;
  bool meetupNotifications = true;
  bool directMessageNotifications = true;
  bool fieldUpdateNotifications = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('notifications'))),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l10n.t('newEventNotifications')),
            value: eventNotifications,
            onChanged: (value) => setState(() => eventNotifications = value),
          ),
          SwitchListTile(
            title: Text(l10n.t('meetupActivityNotifications')),
            value: meetupNotifications,
            onChanged: (value) => setState(() => meetupNotifications = value),
          ),
          SwitchListTile(
            title: Text(l10n.t('directMessageNotifications')),
            value: directMessageNotifications,
            onChanged: (value) =>
                setState(() => directMessageNotifications = value),
          ),
          SwitchListTile(
            title: Text(l10n.t('fieldUpdateNotifications')),
            value: fieldUpdateNotifications,
            onChanged: (value) =>
                setState(() => fieldUpdateNotifications = value),
          ),
        ],
      ),
    );
  }
}

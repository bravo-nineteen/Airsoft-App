import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('New event notifications'),
            value: eventNotifications,
            onChanged: (value) => setState(() => eventNotifications = value),
          ),
          SwitchListTile(
            title: const Text('Meet-up activity notifications'),
            value: meetupNotifications,
            onChanged: (value) => setState(() => meetupNotifications = value),
          ),
          SwitchListTile(
            title: const Text('Direct message notifications'),
            value: directMessageNotifications,
            onChanged: (value) =>
                setState(() => directMessageNotifications = value),
          ),
          SwitchListTile(
            title: const Text('Field update notifications'),
            value: fieldUpdateNotifications,
            onChanged: (value) =>
                setState(() => fieldUpdateNotifications = value),
          ),
        ],
      ),
    );
  }
}

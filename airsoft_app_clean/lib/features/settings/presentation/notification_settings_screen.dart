import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool eventAlerts = true;
  bool meetupAlerts = true;
  bool systemAlerts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        children: <Widget>[
          SwitchListTile(
            title: const Text('Event alerts'),
            value: eventAlerts,
            onChanged: (bool value) {
              setState(() {
                eventAlerts = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Meet-up alerts'),
            value: meetupAlerts,
            onChanged: (bool value) {
              setState(() {
                meetupAlerts = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('System updates'),
            value: systemAlerts,
            onChanged: (bool value) {
              setState(() {
                systemAlerts = value;
              });
            },
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Show area on profile'),
            value: showArea,
            onChanged: (value) => setState(() => showArea = value),
          ),
          SwitchListTile(
            title: const Text('Show team name on profile'),
            value: showTeam,
            onChanged: (value) => setState(() => showTeam = value),
          ),
          SwitchListTile(
            title: const Text('Allow direct messages'),
            value: allowMessages,
            onChanged: (value) => setState(() => allowMessages = value),
          ),
        ],
      ),
    );
  }
}

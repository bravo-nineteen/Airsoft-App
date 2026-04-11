import 'package:flutter/material.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool showSocialLinks = true;
  bool allowMessages = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Settings')),
      body: ListView(
        children: <Widget>[
          SwitchListTile(
            title: const Text('Show social links publicly'),
            value: showSocialLinks,
            onChanged: (bool value) {
              setState(() {
                showSocialLinks = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Allow direct messages'),
            value: allowMessages,
            onChanged: (bool value) {
              setState(() {
                allowMessages = value;
              });
            },
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const ListTile(
            title: Text('Email login'),
            subtitle: Text('Not connected yet'),
          ),
          const Divider(),
          ListTile(
            title: const Text('App version'),
            subtitle: Text(AppConfig.appVersion),
          ),
          const Divider(),
          FilledButton.tonal(
            onPressed: () {},
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

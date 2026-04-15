import 'package:flutter/material.dart';

class DisplaySettingsScreen extends StatelessWidget {
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display')),
      body: ListView(
        children: const [
          ListTile(
            title: Text('Theme'),
            subtitle: Text('Dark theme currently active'),
          ),
          ListTile(
            title: Text('Font size'),
            subtitle: Text('Font size control placeholder'),
          ),
        ],
      ),
    );
  }
}

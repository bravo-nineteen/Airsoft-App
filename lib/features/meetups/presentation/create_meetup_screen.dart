import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';

class CreateMeetupScreen extends StatelessWidget {
  const CreateMeetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createMeetup)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(decoration: InputDecoration(labelText: l10n.title)),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(labelText: l10n.content),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          TextField(decoration: InputDecoration(labelText: l10n.date)),
          const SizedBox(height: 12),
          TextField(decoration: InputDecoration(labelText: l10n.time)),
          const SizedBox(height: 12),
          TextField(decoration: InputDecoration(labelText: l10n.location)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

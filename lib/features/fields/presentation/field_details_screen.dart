import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../shared/widgets/section_card.dart';

class FieldDetailsScreen extends StatelessWidget {
  const FieldDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Field Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.image_outlined, size: 56),
          ),
          const SizedBox(height: 16),
          Text(
            'Frontier Woods',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Woodland • Chiba'),
          const SizedBox(height: 16),
          const SectionCard(
            title: 'Description',
            child: Text(
              'Simple placeholder profile for a field. This is where the field '
              'description, rules, and future owner posts will appear.',
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.fieldContact,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Phone: 00-0000-0000'),
                SizedBox(height: 6),
                Text('Email: info@example.com'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.website,
            child: const Text('https://example-field.jp'),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.socialProfiles,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Instagram: @examplefield'),
                SizedBox(height: 6),
                Text('Facebook: Example Field'),
                SizedBox(height: 6),
                Text('YouTube: Example Field Channel'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

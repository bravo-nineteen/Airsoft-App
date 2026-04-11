import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router.dart';
import '../../../shared/widgets/section_card.dart';

class FieldsScreen extends StatefulWidget {
  const FieldsScreen({super.key});

  @override
  State<FieldsScreen> createState() => _FieldsScreenState();
}

class _FieldsScreenState extends State<FieldsScreen> {
  bool _showMap = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        TextField(
          decoration: InputDecoration(
            hintText: l10n.searchByNameLocationType,
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const <Widget>[
            Chip(label: Text('Name')),
            Chip(label: Text('Location')),
            Chip(label: Text('Field Type')),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: <ButtonSegment<bool>>[
            ButtonSegment<bool>(value: false, label: Text(l10n.list)),
            ButtonSegment<bool>(value: true, label: Text(l10n.map)),
          ],
          selected: <bool>{_showMap},
          onSelectionChanged: (Set<bool> value) {
            setState(() {
              _showMap = value.first;
            });
          },
        ),
        const SizedBox(height: 16),
        if (_showMap) const _MapPlaceholder() else const _FieldList(),
      ],
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Map View',
      child: Container(
        height: 340,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: const Text('Map integration goes here in Phase 1B.'),
      ),
    );
  }
}

class _FieldList extends StatelessWidget {
  const _FieldList();

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> items = <Map<String, String>>[
      <String, String>{
        'name': 'Frontier Woods',
        'location': 'Chiba',
        'type': 'Woodland',
      },
      <String, String>{
        'name': 'Urban Raid Arena',
        'location': 'Tokyo',
        'type': 'CQB',
      },
    ];

    return Column(
      children: items
          .map(
            (Map<String, String> item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.of(context).pushNamed(AppRouter.fieldDetails);
                },
                child: SectionCard(
                  title: item['name'] ?? '',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Location: ${item['location']}'),
                      const SizedBox(height: 4),
                      Text('Type: ${item['type']}'),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

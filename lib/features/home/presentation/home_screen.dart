import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../shared/widgets/section_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SearchBar(
          hintText: l10n.latestNews,
          leading: const Icon(Icons.search),
        ),
        const SizedBox(height: 16),
        const _QuickFilters(),
        const SizedBox(height: 16),
        SectionCard(
          title: l10n.latestNews,
          child: const _SimpleList(
            items: <String>[
              'Platform news and system updates will appear here.',
              'Pinned announcements and bilingual updates can be added here.',
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l10n.newFields,
          child: const _SimpleList(
            items: <String>[
              'New field listing: Frontier Woods - Chiba',
              'New field listing: Urban Raid Arena - Saitama',
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l10n.newEvents,
          child: const _SimpleList(
            items: <String>[
              'Cowboy Game - Inzai, Chiba',
              'Sunday Skirmish - Hachioji, Tokyo',
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l10n.newMeetups,
          child: const _SimpleList(
            items: <String>[
              'Looking for players for Saturday at BEAM.',
              'Pickup group forming from central Tokyo.',
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l10n.teamPosts,
          child: const _SimpleList(
            items: <String>[
              'New bilingual team recruiting support gunners.',
              'Chiba woodland team looking for regular members.',
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickFilters extends StatelessWidget {
  const _QuickFilters();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const <Widget>[
        Chip(label: Text('All')),
        Chip(label: Text('Fields')),
        Chip(label: Text('Events')),
        Chip(label: Text('Meet-ups')),
        Chip(label: Text('Teams')),
      ],
    );
  }
}

class _SimpleList extends StatelessWidget {
  const _SimpleList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (String item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.circle, size: 8),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

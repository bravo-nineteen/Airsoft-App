import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router.dart';
import '../../../shared/widgets/section_card.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SectionCard(
          title: l10n.calendar,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 280,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: const Text('Monthly calendar placeholder'),
              ),
              const SizedBox(height: 16),
              Text(
                'Selected Date Events',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _EventTile(
                title: 'Cowboy Game',
                location: 'Inzai, Chiba',
                onTap: () {
                  Navigator.of(context).pushNamed(AppRouter.eventDetails);
                },
              ),
              const SizedBox(height: 8),
              _EventTile(
                title: 'Sunday Skirmish',
                location: 'Hachioji, Tokyo',
                onTap: () {
                  Navigator.of(context).pushNamed(AppRouter.eventDetails);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.title,
    required this.location,
    required this.onTap,
  });

  final String title;
  final String location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('$title - $location'),
      ),
    );
  }
}

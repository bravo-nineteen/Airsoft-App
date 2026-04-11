import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router.dart';
import '../../../shared/widgets/section_card.dart';

class MeetupsScreen extends StatelessWidget {
  const MeetupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed(AppRouter.createMeetup);
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.createMeetup),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () {
            Navigator.of(context).pushNamed(AppRouter.meetupDetails);
          },
          borderRadius: BorderRadius.circular(14),
          child: const SectionCard(
            title: 'Looking for a squad at BEAM',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('By: Nineteen'),
                SizedBox(height: 6),
                Text('Date: 2026-04-25'),
                SizedBox(height: 6),
                Text('Time: 08:00'),
                SizedBox(height: 6),
                Text('Location: Chiba'),
                SizedBox(height: 6),
                Text('Anyone joining the game and wants to squad up?'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

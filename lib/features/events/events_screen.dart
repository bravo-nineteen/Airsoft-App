import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Text(l10n.t('eventsComingNext')),
    );
  }
}

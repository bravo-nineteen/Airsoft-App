import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router.dart';
import '../../../shared/models/app_user_profile.dart';
import '../../../shared/widgets/section_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppUserProfile profile = AppUserProfile.sample();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed(
                AppRouter.editProfile,
                arguments: profile,
              );
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Center(
            child: Column(
              children: <Widget>[
                CircleAvatar(
                  radius: 42,
                  child: Text(profile.callSign.characters.first),
                ),
                const SizedBox(height: 12),
                Text(
                  profile.callSign,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(profile.userCode),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: l10n.profile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${l10n.area}: ${profile.area ?? '-'}'),
                const SizedBox(height: 8),
                Text('${l10n.teamName}: ${profile.teamName ?? '-'}'),
                const SizedBox(height: 8),
                Text('${l10n.loadout}: ${profile.loadout ?? '-'}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.socialProfiles,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${l10n.instagram}: ${profile.instagram ?? '-'}'),
                const SizedBox(height: 8),
                Text('${l10n.facebook}: ${profile.facebook ?? '-'}'),
                const SizedBox(height: 8),
                Text('${l10n.youtube}: ${profile.youtube ?? '-'}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

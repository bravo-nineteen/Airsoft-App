import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('account'))),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: Text(l10n.t('email')),
            subtitle: Text(user?.email ?? '-'),
          ),
          ListTile(
            leading: Icon(Icons.subscriptions_outlined),
            title: Text(l10n.t('subscription')),
            subtitle: Text(l10n.t('free')),
          ),
        ],
      ),
    );
  }
}

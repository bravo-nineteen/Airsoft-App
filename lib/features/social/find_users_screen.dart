import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import '../profile/profile_model.dart';
import '../profile/profile_repository.dart';
import 'contact_repository.dart';

class FindUsersScreen extends StatefulWidget {
  const FindUsersScreen({super.key});

  @override
  State<FindUsersScreen> createState() => _FindUsersScreenState();
}

class _FindUsersScreenState extends State<FindUsersScreen> {
  final ProfileRepository _profileRepository = ProfileRepository();
  final ContactRepository _contactRepository = ContactRepository();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<ProfileModel>> _futureProfiles;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _futureProfiles = _profileRepository.searchProfiles('');
  }

  Future<void> _search() async {
    setState(() {
      _futureProfiles = _profileRepository.searchProfiles(_searchController.text);
    });
    await _futureProfiles;
  }

  Future<void> _sendRequest(ProfileModel profile) async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
    });

    try {
      await _contactRepository.sendRequest(profile.id);

      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t('contactRequestSent', args: {'name': profile.displayName}),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('failedSendRequest', args: {'error': '$e'})),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
      });
    }
  }

  String get _currentUserId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _avatar(ProfileModel profile) {
    if ((profile.avatarUrl ?? '').trim().isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(profile.avatarUrl!),
      );
    }

    return CircleAvatar(
      child: Text(
        profile.displayName.isEmpty
            ? '?'
            : profile.displayName.characters.first.toUpperCase(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('findUsers')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.t('searchUsersHint'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.refresh),
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ProfileModel>>(
              future: _futureProfiles,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.t(
                          'failedLoadUsers',
                          args: {'error': '${snapshot.error}'},
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final profiles = snapshot.data ?? [];

                if (profiles.isEmpty) {
                  return Center(child: Text(l10n.t('noUsersFound')));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: profiles.length,
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    final isSelf = profile.id == _currentUserId;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: _avatar(profile),
                        title: Text(profile.displayName),
                        subtitle: Text(
                          [
                            if (profile.userCode.trim().isNotEmpty) profile.userCode,
                            if ((profile.area ?? '').trim().isNotEmpty) profile.area!,
                            if ((profile.teamName ?? '').trim().isNotEmpty) profile.teamName!,
                          ].join(' • '),
                        ),
                        trailing: isSelf
                            ? const SizedBox.shrink()
                            : FilledButton(
                                onPressed: _isBusy
                                    ? null
                                    : () => _sendRequest(profile),
                                child: Text(l10n.t('add')),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
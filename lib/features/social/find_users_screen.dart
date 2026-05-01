import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import '../../shared/widgets/persistent_shell_bottom_nav.dart';
import '../profile/profile_model.dart';
import '../profile/profile_repository.dart';
import 'contact_model.dart';
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

  late Future<_FindUsersViewData> _futureData;
  final Set<String> _busyUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    _futureData = _loadViewData('');
  }

  Future<void> _search() async {
    setState(() {
      _futureData = _loadViewData(_searchController.text);
    });
    await _futureData;
  }

  Future<_FindUsersViewData> _loadViewData(String query) async {
    final List<ProfileModel> profiles = await _profileRepository.searchProfiles(query);
    final Map<String, ContactRelationshipState> states =
        await _contactRepository.getRelationshipStates(
          profiles.map((ProfileModel profile) => profile.id),
        );
    return _FindUsersViewData(
      profiles: profiles,
      relationshipStates: states,
    );
  }

  Future<void> _refreshResults() async {
    setState(() {
      _futureData = _loadViewData(_searchController.text);
    });
    await _futureData;
  }

  Future<void> _sendRequest(ProfileModel profile) async {
    if (_busyUserIds.contains(profile.id)) {
      return;
    }

    setState(() {
      _busyUserIds.add(profile.id);
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
      await _refreshResults();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('failedSendRequest', args: {'error': '$e'})),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyUserIds.remove(profile.id);
        });
      }
    }
  }

  Future<void> _acceptRequest(
    ProfileModel profile,
    ContactRelationshipState state,
  ) async {
    final ContactModel? contact = state.contact;
    if (contact == null || _busyUserIds.contains(profile.id)) {
      return;
    }

    setState(() {
      _busyUserIds.add(profile.id);
    });

    try {
      await _contactRepository.acceptRequest(contact);

      if (!mounted) {
        return;
      }

      final AppLocalizations l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('friendRequestAccepted'))),
      );
      await _refreshResults();
    } catch (error) {
      if (!mounted) {
        return;
      }

      final AppLocalizations l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t('failedAcceptRequest', args: {'error': '$error'}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyUserIds.remove(profile.id);
        });
      }
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
      bottomNavigationBar: const PersistentShellBottomNav(selectedIndex: 4),
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
            child: FutureBuilder<_FindUsersViewData>(
              future: _futureData,
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

                final _FindUsersViewData data =
                    snapshot.data ?? const _FindUsersViewData();
                final List<ProfileModel> profiles = data.profiles;

                if (profiles.isEmpty) {
                  return Center(child: Text(l10n.t('noUsersFound')));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: profiles.length,
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    final isSelf = profile.id == _currentUserId;
                    final ContactRelationshipState relationshipState =
                        data.relationshipStates[profile.id] ??
                        (isSelf
                            ? const ContactRelationshipState(
                                action: ContactRelationshipAction.self,
                              )
                            : const ContactRelationshipState(
                                action: ContactRelationshipAction.add,
                              ));
                    final bool isBusy = _busyUserIds.contains(profile.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: _avatar(profile),
                        title: Text(profile.displayName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              [
                                if (profile.userCode.trim().isNotEmpty)
                                  profile.userCode,
                                if ((profile.area ?? '').trim().isNotEmpty)
                                  profile.area!,
                                if ((profile.teamName ?? '').trim().isNotEmpty)
                                  profile.teamName!,
                              ].join(' • '),
                            ),
                            if (!isSelf &&
                                relationshipState.action !=
                                    ContactRelationshipAction.add)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(
                                    _relationshipLabel(
                                      context,
                                      relationshipState.action,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: isSelf
                            ? const SizedBox.shrink()
                            : _buildActionButton(
                                context,
                                profile,
                                relationshipState,
                                isBusy: isBusy,
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

  Widget _buildActionButton(
    BuildContext context,
    ProfileModel profile,
    ContactRelationshipState state, {
    required bool isBusy,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    switch (state.action) {
      case ContactRelationshipAction.add:
        return FilledButton(
          onPressed: isBusy ? null : () => _sendRequest(profile),
          child: Text(l10n.t('add')),
        );
      case ContactRelationshipAction.incomingPending:
        return FilledButton.icon(
          onPressed: isBusy ? null : () => _acceptRequest(profile, state),
          icon: const Icon(Icons.check),
          label: Text(l10n.t('accept')),
        );
      case ContactRelationshipAction.outgoingPending:
        return OutlinedButton(
          onPressed: null,
          child: Text(l10n.t('requestPending')),
        );
      case ContactRelationshipAction.friends:
        return OutlinedButton(
          onPressed: null,
          child: Text(l10n.t('friends')), 
        );
      case ContactRelationshipAction.self:
        return const SizedBox.shrink();
    }
  }

  String _relationshipLabel(
    BuildContext context,
    ContactRelationshipAction action,
  ) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    switch (action) {
      case ContactRelationshipAction.add:
        return l10n.t('add');
      case ContactRelationshipAction.outgoingPending:
        return l10n.t('requestPending');
      case ContactRelationshipAction.incomingPending:
        return l10n.t('requestReceived');
      case ContactRelationshipAction.friends:
        return l10n.t('friends');
      case ContactRelationshipAction.self:
        return l10n.t('profile');
    }
  }
}

class _FindUsersViewData {
  const _FindUsersViewData({
    this.profiles = const <ProfileModel>[],
    this.relationshipStates = const <String, ContactRelationshipState>{},
  });

  final List<ProfileModel> profiles;
  final Map<String, ContactRelationshipState> relationshipStates;
}
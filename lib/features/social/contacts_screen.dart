import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import 'contact_model.dart';
import 'contact_repository.dart';
import 'direct_message_screen.dart';
import 'find_users_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactRepository _repo = ContactRepository();
  late Future<List<ContactModel>> _future;

  String get _currentUserId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _future = _repo.getContacts();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _repo.getContacts();
    });
    await _future;
  }

  Future<void> _openFindUsers() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FindUsersScreen()),
    );
    await _refresh();
  }

  String _otherUserId(ContactModel contact) {
    return contact.requesterId == _currentUserId
        ? contact.addresseeId
        : contact.requesterId;
  }

  String _otherDisplayName(ContactModel contact) {
      final l10n = AppLocalizations.of(context);
    if (contact.requesterId == _currentUserId) {
      return (contact.addresseeCallSign ?? '').trim().isEmpty
        ? l10n.t('operator')
          : contact.addresseeCallSign!;
    }

    return (contact.requesterCallSign ?? '').trim().isEmpty
      ? l10n.t('operator')
        : contact.requesterCallSign!;
  }

  bool _isIncomingPending(ContactModel contact) {
    return contact.status == 'pending' && contact.addresseeId == _currentUserId;
  }

  bool _isAccepted(ContactModel contact) {
    return contact.status == 'accepted';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.contacts),
        actions: [
          IconButton(
            tooltip: l10n.t('findUsers'),
            onPressed: _openFindUsers,
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: FutureBuilder<List<ContactModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.t(
                    'failedLoadContacts',
                    args: {'error': '${snapshot.error}'},
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final contacts = snapshot.data ?? [];

          if (contacts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.t('noContactsYet')),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _openFindUsers,
                      icon: const Icon(Icons.person_search),
                      label: Text(l10n.t('findUsers')),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                final otherUserId = _otherUserId(contact);
                final displayName = _otherDisplayName(contact);
                final accepted = _isAccepted(contact);
                final incomingPending = _isIncomingPending(contact);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        displayName.isEmpty
                            ? '?'
                            : displayName.characters.first.toUpperCase(),
                      ),
                    ),
                    title: Text(displayName),
                    subtitle: Text(contact.status),
                    trailing: accepted
                        ? IconButton(
                            icon: const Icon(Icons.chat_bubble_outline),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DirectMessageScreen(
                                    otherUserId: otherUserId,
                                    otherDisplayName: displayName,
                                  ),
                                ),
                              );
                            },
                          )
                        : incomingPending
                            ? Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check),
                                    onPressed: () async {
                                      await _repo.acceptRequest(contact.id);
                                      await _refresh();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () async {
                                      await _repo.rejectRequest(contact.id);
                                      await _refresh();
                                    },
                                  ),
                                ],
                              )
                            : IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await _repo.removeContact(contact.id);
                                  await _refresh();
                                },
                              ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
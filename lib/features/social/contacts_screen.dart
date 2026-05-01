import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import '../../shared/widgets/persistent_shell_bottom_nav.dart';
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
  String? _actingContactId;

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
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FindUsersScreen()));
    await _refresh();
  }

  Future<void> _acceptRequest(ContactModel contact) async {
    setState(() {
      _actingContactId = contact.id;
    });

    try {
      await _repo.acceptRequest(contact);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted')),
        );
      }
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept request: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _actingContactId = null;
        });
      }
    }
  }

  Future<void> _rejectRequest(ContactModel contact) async {
    setState(() {
      _actingContactId = contact.id;
    });

    try {
      await _repo.rejectRequest(contact);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request declined')),
        );
      }
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline request: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _actingContactId = null;
        });
      }
    }
  }

  Future<void> _removeContact(ContactModel contact) async {
    setState(() {
      _actingContactId = contact.id;
    });

    try {
      await _repo.removeContact(contact);
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove contact: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _actingContactId = null;
        });
      }
    }
  }

  String _otherUserId(ContactModel contact) {
    return contact.requesterId == _currentUserId
        ? contact.addresseeId
        : contact.requesterId;
  }

  String _otherDisplayName(ContactModel contact) {
    if (contact.requesterId == _currentUserId) {
      return (contact.addresseeCallSign ?? '').trim().isEmpty
          ? 'Unknown user'
          : contact.addresseeCallSign!;
    }

    return (contact.requesterCallSign ?? '').trim().isEmpty
        ? 'Unknown user'
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
      bottomNavigationBar: const PersistentShellBottomNav(selectedIndex: 4),
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
                final isActing = _actingContactId == contact.id;

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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(contact.status),
                        if (incomingPending) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: isActing
                                    ? null
                                    : () => _acceptRequest(contact),
                                icon: const Icon(Icons.check),
                                label: const Text('Accept'),
                              ),
                              OutlinedButton.icon(
                                onPressed: isActing
                                    ? null
                                    : () => _rejectRequest(contact),
                                icon: const Icon(Icons.close),
                                label: const Text('Decline'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
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
                        ? (isActing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null)
                        : IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: isActing
                                ? null
                                : () => _removeContact(contact),
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

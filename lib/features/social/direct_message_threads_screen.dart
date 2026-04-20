import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import 'contacts_screen.dart';
import 'direct_message_screen.dart';
import 'direct_message_thread_model.dart';
import 'direct_message_thread_repository.dart';

class DirectMessageThreadsScreen extends StatefulWidget {
  const DirectMessageThreadsScreen({super.key});

  @override
  State<DirectMessageThreadsScreen> createState() =>
      _DirectMessageThreadsScreenState();
}

class _DirectMessageThreadsScreenState
    extends State<DirectMessageThreadsScreen> {
  final DirectMessageThreadRepository _repo = DirectMessageThreadRepository();

  late Future<List<DirectMessageThreadModel>> _future;
  final Map<String, String> _displayNameByUserId = <String, String>{};

  @override
  void initState() {
    super.initState();
    _future = _loadThreads();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadThreads();
    });
    await _future;
  }

  Future<void> _openCompose() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ContactsScreen(),
      ),
    );
    await _refresh();
  }

  Future<List<DirectMessageThreadModel>> _loadThreads() async {
    final threads = await _repo.getThreads();
    unawaited(_warmDisplayNames(threads));
    return threads;
  }

  Future<String> _resolveName(String userId, String fallback) async {
    final data = await Supabase.instance.client
        .from('profiles')
        .select('call_sign, user_code')
        .eq('id', userId)
        .maybeSingle();

    if (data == null) {
      return fallback;
    }

    final value = (data['call_sign'] ?? fallback).toString().trim();
    return value.isEmpty ? fallback : value;
  }

  Future<void> _warmDisplayNames(List<DirectMessageThreadModel> threads) async {
    if (!mounted || threads.isEmpty) {
      return;
    }

    final fallback = AppLocalizations.of(context).t('operator');
    final missingUserIds = threads
        .map((thread) => thread.otherUserId)
        .where((id) => !_displayNameByUserId.containsKey(id))
        .toSet()
        .toList();

    if (missingUserIds.isEmpty) {
      return;
    }

    final entries = await Future.wait(
      missingUserIds.map(
        (userId) async => MapEntry(
          userId,
          await _resolveName(userId, fallback),
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      for (final entry in entries) {
        _displayNameByUserId[entry.key] = entry.value;
      }
    });
  }

  String _timeLabel(AppLocalizations l10n, DateTime value) {
    final now = DateTime.now();
    final diff = now.difference(value);

    if (diff.inMinutes < 1) return l10n.t('now');
    if (diff.inMinutes < 60) {
      return l10n.t('minutesShort', args: {'value': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return l10n.t('hoursShort', args: {'value': '${diff.inHours}'});
    }
    return l10n.t('daysShort', args: {'value': '${diff.inDays}'});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<DirectMessageThreadModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData &&
                snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.t(
                          'failedLoadMessages',
                          args: {'error': '${snapshot.error}'},
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }

            final threads = snapshot.data ?? [];

            if (threads.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: 120),
                  Center(child: Text(l10n.t('noMessagesYet'))),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: threads.length,
              itemBuilder: (context, index) {
                final thread = threads[index];
                final name = _displayNameByUserId[thread.otherUserId] ??
                    l10n.t('operator');

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DirectMessageScreen(
                            otherUserId: thread.otherUserId,
                            otherDisplayName: name,
                          ),
                        ),
                      );
                      await _refresh();
                    },
                    child: IgnorePointer(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(name.isEmpty ? '?' : name[0]),
                        ),
                        title: Text(name),
                        subtitle: Text(
                          thread.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_timeLabel(l10n, thread.lastMessageAt)),
                            if (thread.unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${thread.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCompose,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Compose'),
      ),
    );
  }
}

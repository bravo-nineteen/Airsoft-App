import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import '../../core/content/app_content_preloader.dart';
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
  final AppContentPreloader _contentPreloader = AppContentPreloader.instance;
  final DirectMessageThreadRepository _repo = DirectMessageThreadRepository();

  late Future<List<DirectMessageThreadModel>> _future;
  List<DirectMessageThreadModel> _cachedThreads = <DirectMessageThreadModel>[];
  final Map<String, String> _displayNameByUserId = <String, String>{};
  Timer? _backgroundSyncTimer;

  @override
  void initState() {
    super.initState();
    _cachedThreads = _contentPreloader.threads;
    _contentPreloader.threadsRevision.addListener(_handleSharedThreadsUpdated);
    _future = _loadThreads();
    _backgroundSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        return;
      }
      _refresh();
    });
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _future = _contentPreloader.refreshThreads();
    });
    await _future;
  }

  Future<void> _openCompose() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ContactsScreen()),
    );

    if (!mounted) {
      return;
    }

    await _refresh();
  }

  Future<List<DirectMessageThreadModel>> _loadThreads() async {
    final threads = await _contentPreloader.loadThreads();
    unawaited(_warmDisplayNames(threads));
    return threads;
  }

  void _handleSharedThreadsUpdated() {
    if (!mounted) {
      return;
    }

    final List<DirectMessageThreadModel> threads = _contentPreloader.threads;
    unawaited(_warmDisplayNames(threads));
    setState(() {
      _cachedThreads = threads;
      _future = Future<List<DirectMessageThreadModel>>.value(threads);
    });
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
        (userId) async =>
            MapEntry(userId, await _resolveName(userId, fallback)),
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
  void dispose() {
    _backgroundSyncTimer?.cancel();
    _contentPreloader.threadsRevision.removeListener(
      _handleSharedThreadsUpdated,
    );
    super.dispose();
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
            final threads = snapshot.data ?? _cachedThreads;

            if (threads.isEmpty &&
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
                final name =
                    _displayNameByUserId[thread.otherUserId] ??
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

                      if (!mounted) {
                        return;
                      }

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

import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../safety/safety_repository.dart';

class SafetyManagementScreen extends StatefulWidget {
  const SafetyManagementScreen({super.key});

  @override
  State<SafetyManagementScreen> createState() => _SafetyManagementScreenState();
}

class _SafetyManagementScreenState extends State<SafetyManagementScreen>
    with SingleTickerProviderStateMixin {
  final SafetyRepository _repository = SafetyRepository();
  late final TabController _tabController = TabController(length: 2, vsync: this);

  late Future<List<BlockedUserRecord>> _blockedFuture;
  late Future<List<MutedUserRecord>> _mutedFuture;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _blockedFuture = _repository.getBlockedUsers();
    _mutedFuture = _repository.getMutedUsers();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait<dynamic>(<Future<dynamic>>[_blockedFuture, _mutedFuture]);
  }

  Future<void> _unblock(BlockedUserRecord record) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() {
      _isBusy = true;
    });
    try {
      await _repository.unblockUser(record.userId);
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('userUnblocked'))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('actionFailed', args: {'error': '$error'}))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _unmute(MutedUserRecord record) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() {
      _isBusy = true;
    });
    try {
      await _repository.unmuteUser(record.userId);
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('userUnmuted'))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('actionFailed', args: {'error': '$error'}))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  String _formatDate(DateTime value) {
    final DateTime local = value.toLocal();
    final String yyyy = local.year.toString().padLeft(4, '0');
    final String mm = local.month.toString().padLeft(2, '0');
    final String dd = local.day.toString().padLeft(2, '0');
    final String hh = local.hour.toString().padLeft(2, '0');
    final String min = local.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$min';
  }

  Widget _buildBlockedTab(AppLocalizations l10n) {
    return FutureBuilder<List<BlockedUserRecord>>(
      future: _blockedFuture,
      builder: (BuildContext context, AsyncSnapshot<List<BlockedUserRecord>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.t('actionFailed', args: {'error': '${snapshot.error}'})),
            ),
          );
        }

        final List<BlockedUserRecord> rows = snapshot.data ?? <BlockedUserRecord>[];
        if (rows.isEmpty) {
          return Center(child: Text(l10n.t('noBlockedUsers')));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (BuildContext context, int index) {
            final BlockedUserRecord row = rows[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(row.callSign),
                subtitle: Text(
                  '${l10n.t('blockedOn')}: ${_formatDate(row.createdAt)}${(row.reason ?? '').trim().isEmpty ? '' : '\n${row.reason}'}',
                ),
                isThreeLine: (row.reason ?? '').trim().isNotEmpty,
                trailing: OutlinedButton(
                  onPressed: _isBusy ? null : () => _unblock(row),
                  child: Text(l10n.t('unblock')),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMutedTab(AppLocalizations l10n) {
    return FutureBuilder<List<MutedUserRecord>>(
      future: _mutedFuture,
      builder: (BuildContext context, AsyncSnapshot<List<MutedUserRecord>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.t('actionFailed', args: {'error': '${snapshot.error}'})),
            ),
          );
        }

        final List<MutedUserRecord> rows = snapshot.data ?? <MutedUserRecord>[];
        if (rows.isEmpty) {
          return Center(child: Text(l10n.t('noMutedUsers')));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (BuildContext context, int index) {
            final MutedUserRecord row = rows[index];
            final String expiry = row.expiresAt == null
                ? l10n.t('noExpiry')
                : _formatDate(row.expiresAt!);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(row.callSign),
                subtitle: Text(
                  '${l10n.t('mutedOn')}: ${_formatDate(row.createdAt)}\n${l10n.t('expires')}: $expiry${(row.reason ?? '').trim().isEmpty ? '' : '\n${row.reason}'}',
                ),
                isThreeLine: true,
                trailing: OutlinedButton(
                  onPressed: _isBusy ? null : () => _unmute(row),
                  child: Text(l10n.t('unmute')),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('blockedUsers')),
        bottom: TabBar(
          controller: _tabController,
          tabs: <Tab>[
            Tab(text: l10n.t('blockedUsers')),
            Tab(text: l10n.t('mutedUsers')),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: TabBarView(
          controller: _tabController,
          children: <Widget>[
            _buildBlockedTab(l10n),
            _buildMutedTab(l10n),
          ],
        ),
      ),
    );
  }
}

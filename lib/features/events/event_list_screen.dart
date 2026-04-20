import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import 'event_create_screen.dart';
import 'event_details_screen.dart';
import 'event_model.dart';
import 'event_repository.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  final EventRepository _repository = EventRepository();
  late Future<List<EventModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.getEvents();
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _future = _repository.getEvents();
    });
    await _future;
  }

  Future<void> _openCreate() async {
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EventCreateScreen()),
    );

    if (!mounted) {
      return;
    }

    if (created == true) {
      await _refresh();
    }
  }

  String _formatDate(DateTime value) {
    final String yyyy = value.year.toString().padLeft(4, '0');
    final String mm = value.month.toString().padLeft(2, '0');
    final String dd = value.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  String _buildSubtitle(EventModel event) {
    final List<String> parts = <String>[
      _formatDate(event.startsAt),
      if ((event.prefecture ?? '').isNotEmpty) event.prefecture!,
      if ((event.location ?? '').isNotEmpty) event.location!,
      if ((event.eventType ?? '').isNotEmpty) event.eventType!,
    ];

    return parts.join(' • ');
  }

  String? _statusLabel(EventModel event) {
    switch (event.currentUserAttendanceStatus) {
      case 'attending':
        return 'Attending';
      case 'cancelled':
        return 'Cancelled';
      case 'attended':
        return 'Attended';
      case 'no_show':
        return 'No Show';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('event')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: SafeArea(
        minimum: const EdgeInsets.only(right: 16, bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: _openCreate,
          icon: const Icon(Icons.add),
          label: const Text('New event'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<EventModel>>(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<List<EventModel>> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                children: <Widget>[
                  const SizedBox(height: 140),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.t(
                          'failedLoadEvents',
                          args: {'error': '${snapshot.error}'},
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }

            final List<EventModel> events = snapshot.data ?? <EventModel>[];
            if (events.isEmpty) {
              return ListView(
                children: <Widget>[
                  const SizedBox(height: 160),
                  Center(child: Text(l10n.t('noEventsFound'))),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final EventModel event = events[index];
                final String? statusLabel = _statusLabel(event);

                return Card(
                  child: ListTile(
                    title: Text(event.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: 4),
                        Text(_buildSubtitle(event)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _MiniInfoChip(
                              icon: Icons.event_available,
                              label: 'Going ${event.attendingCount}',
                            ),
                            _MiniInfoChip(
                              icon: Icons.verified,
                              label: 'Attended ${event.attendedCount}',
                            ),
                            if (statusLabel != null)
                              _MiniInfoChip(
                                icon: Icons.person,
                                label: statusLabel,
                              ),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EventDetailsScreen(event: event),
                        ),
                      );
                      await _refresh();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  const _MiniInfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }
}

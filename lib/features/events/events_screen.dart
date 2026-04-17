import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import 'event_create_screen.dart';
import 'event_details_screen.dart';
import 'event_model.dart';
import 'event_repository.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final EventRepository _repository = EventRepository();
  late Future<List<EventModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.getEvents();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _repository.getEvents();
    });
    await _future;
  }

  Future<void> _openCreate() async {
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EventCreateScreen()),
    );

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
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        RefreshIndicator(
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
                separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                              if (event.isOfficial)
                                _MiniInfoChip(
                                  icon: Icons.verified,
                                  label: 'Official',
                                  color: Colors.blue,
                                ),
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
        Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: const Text('New event'),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  const _MiniInfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color bg = color != null
        ? color!.withAlpha(30)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final Color fg = color ?? Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: fg)),
        ],
      ),
    );
  }
}

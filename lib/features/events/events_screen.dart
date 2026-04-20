import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final TextEditingController _searchController = TextEditingController();
  late Future<List<EventModel>> _future;
  List<EventModel> _cachedEvents = <EventModel>[];
  Timer? _backgroundSyncTimer;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _future = _repository.getEvents();
    _backgroundSyncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
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

  Future<void> _openEdit(EventModel event) async {
    final bool? updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventCreateScreen(
          existingEvent: event,
          isOfficial: event.isOfficial,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (updated == true) {
      await _refresh();
    }
  }

  bool _matchesEventSearch(EventModel event) {
    final String query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }

    final String haystack = <String>[
      event.language ?? '',
      event.location ?? '',
      event.prefecture ?? '',
      event.eventType ?? '',
      event.skillLevel ?? '',
      event.organizerName ?? '',
    ].join(' ').toLowerCase();

    return haystack.contains(query);
  }

  @override
  void dispose() {
    _backgroundSyncTimer?.cancel();
    _searchController.dispose();
    super.dispose();
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

  String? _statusLabel(AppLocalizations l10n, EventModel event) {
    switch (event.currentUserAttendanceStatus) {
      case 'attending':
        return l10n.t('attendanceAttending');
      case 'cancelled':
        return l10n.t('attendanceCancelled');
      case 'attended':
        return l10n.t('attendanceAttended');
      case 'no_show':
        return l10n.t('attendanceNoShow');
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
            initialData: _cachedEvents,
            builder: (BuildContext context, AsyncSnapshot<List<EventModel>> snapshot) {
              final List<EventModel> events = snapshot.data ?? _cachedEvents;
              if (snapshot.hasData) {
                _cachedEvents = snapshot.data!;
              }

              if (snapshot.connectionState != ConnectionState.done &&
                  events.isEmpty) {
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

              final List<EventModel> filteredEvents = events
                  .where(_matchesEventSearch)
                  .toList();

              if (events.isEmpty) {
                return ListView(
                  children: <Widget>[
                    const SizedBox(height: 160),
                    Center(child: Text(l10n.t('noEventsFound'))),
                  ],
                );
              }

              if (filteredEvents.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: <Widget>[
                    TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: l10n.t('eventSearchHint'),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(child: Text(l10n.t('noMatchingEventsFound'))),
                  ],
                );
              }

              final String? currentUserId =
                  Supabase.instance.client.auth.currentUser?.id;

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: filteredEvents.length + 2,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) {
                  if (index == 0) {
                    return snapshot.connectionState == ConnectionState.waiting
                        ? const LinearProgressIndicator(minHeight: 2)
                        : const SizedBox.shrink();
                  }

                  if (index == 1) {
                    return TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText:
                            'Search language, location, type, skill, organiser',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    );
                  }

                  final EventModel event = filteredEvents[index - 2];
                    final String? statusLabel = _statusLabel(l10n, event);
                  final bool canEdit =
                      currentUserId != null && event.hostUserId == currentUserId;

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
                                  label: l10n.t('official'),
                                  color: Colors.blue,
                                ),
                              _MiniInfoChip(
                                icon: Icons.event_available,
                                label: l10n.t(
                                  'goingWithCount',
                                  args: {'count': '${event.attendingCount}'},
                                ),
                              ),
                              _MiniInfoChip(
                                icon: Icons.verified,
                                label: l10n.t(
                                  'attendedWithCount',
                                  args: {'count': '${event.attendedCount}'},
                                ),
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (canEdit)
                            IconButton(
                              tooltip: l10n.t('editEvent'),
                              onPressed: () => _openEdit(event),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => EventDetailsScreen(event: event),
                          ),
                        );
                        if (!mounted) {
                          return;
                        }
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
              label: Text(l10n.t('newEventCta')),
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

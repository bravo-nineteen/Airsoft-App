import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import 'event_create_screen.dart';
import 'event_model.dart';
import 'event_repository.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({super.key, required this.event});

  final EventModel event;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final EventRepository _repository = EventRepository();

  late EventModel _event;
  List<EventAttendanceRecord> _attendees = <EventAttendanceRecord>[];
  bool _isLoading = true;
  bool _isUpdatingAttendance = false;
  final Set<String> _busyAttendeeIds = <String>{};

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final EventModel event = await _repository.getEventById(widget.event.id);
      List<EventAttendanceRecord> attendees = <EventAttendanceRecord>[];

      if (_isCurrentUserHost(event)) {
        attendees = await _repository.getEventAttendeesForHost(event.id);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _event = event;
        _attendees = attendees;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load event: $error')));
    }
  }

  bool _isCurrentUserHost(EventModel event) {
    final User? user = Supabase.instance.client.auth.currentUser;
    return user != null && event.hostUserId == user.id;
  }

  String _formatDateTime(DateTime value) {
    final String yyyy = value.year.toString().padLeft(4, '0');
    final String mm = value.month.toString().padLeft(2, '0');
    final String dd = value.day.toString().padLeft(2, '0');
    final String hh = value.hour.toString().padLeft(2, '0');
    final String min = value.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$min';
  }

  Future<void> _attend() async {
    if (_isUpdatingAttendance) {
      return;
    }

    setState(() {
      _isUpdatingAttendance = true;
    });

    try {
      await _repository.attendEvent(_event.id);
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to confirm attendance: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAttendance = false;
        });
      }
    }
  }

  Future<void> _cancel() async {
    if (_isUpdatingAttendance) {
      return;
    }

    setState(() {
      _isUpdatingAttendance = true;
    });

    try {
      await _repository.cancelAttendance(_event.id);
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel attendance: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAttendance = false;
        });
      }
    }
  }

  Future<void> _hostUpdateStatus({
    required String attendeeUserId,
    required String status,
  }) async {
    if (_busyAttendeeIds.contains(attendeeUserId)) {
      return;
    }

    setState(() {
      _busyAttendeeIds.add(attendeeUserId);
    });

    try {
      await _repository.hostConfirmAttendance(
        eventId: _event.id,
        attendeeUserId: attendeeUserId,
        status: status,
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update attendee: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyAttendeeIds.remove(attendeeUserId);
        });
      }
    }
  }

  Future<void> _editEvent() async {
    final bool? didSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventCreateScreen(
          existingEvent: _event,
          isOfficial: _event.isOfficial,
        ),
      ),
    );

    if (didSave == true) {
      await _load();
    }
  }

  Future<void> _deleteEvent() async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete event?'),
          content: const Text('This will permanently delete this event.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _repository.deleteEvent(_event.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete event: $error')));
    }
  }

  Widget _buildAttendanceActions() {
    final String? status = _event.currentUserAttendanceStatus;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Attendance',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _StatusChip(
                  icon: Icons.event_available,
                  label: 'Going ${_event.attendingCount}',
                ),
                _StatusChip(
                  icon: Icons.verified,
                  label: 'Attended ${_event.attendedCount}',
                ),
                _StatusChip(
                  icon: Icons.cancel_outlined,
                  label: 'Cancelled ${_event.cancelledCount}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (status == 'attending') ...[
              const Text('You are marked as attending this event.'),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isUpdatingAttendance ? null : _attend,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Attending'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUpdatingAttendance ? null : _cancel,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'cancelled') ...[
              const Text('You have cancelled your attendance.'),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isUpdatingAttendance ? null : _attend,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Attend Instead'),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'attended') ...[
              const Text('The host has confirmed you attended this event.'),
              const SizedBox(height: 10),
              const _StatusChip(
                icon: Icons.verified,
                label: 'Attendance Confirmed',
              ),
            ] else if (status == 'no_show') ...[
              const Text('The host marked you as not attended.'),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUpdatingAttendance ? null : _attend,
                      icon: const Icon(Icons.replay),
                      label: const Text('Mark Attending Again'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text('Let the host know you are going.'),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isUpdatingAttendance ? null : _attend,
                      icon: const Icon(Icons.event_available),
                      label: const Text('Attend'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHostSection() {
    if (!_isCurrentUserHost(_event)) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Host Controls',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Confirm whether attendees actually showed up.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (_attendees.isEmpty)
              const Text('No attendees yet.')
            else
              ..._attendees.map((EventAttendanceRecord attendee) {
                final bool isBusy = _busyAttendeeIds.contains(attendee.userId);
                final String displayName =
                    attendee.displayName?.trim().isNotEmpty == true
                    ? attendee.displayName!
                    : attendee.userId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 18,
                            backgroundImage:
                                attendee.avatarUrl != null &&
                                    attendee.avatarUrl!.trim().isNotEmpty
                                ? NetworkImage(attendee.avatarUrl!)
                                : null,
                            child:
                                attendee.avatarUrl == null ||
                                    attendee.avatarUrl!.trim().isEmpty
                                ? Text(
                                    displayName.substring(0, 1).toUpperCase(),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  displayName,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Status: ${_readableStatus(attendee.status)}',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          FilledButton(
                            onPressed: isBusy
                                ? null
                                : () => _hostUpdateStatus(
                                    attendeeUserId: attendee.userId,
                                    status: 'attended',
                                  ),
                            child: const Text('Mark Attended'),
                          ),
                          OutlinedButton(
                            onPressed: isBusy
                                ? null
                                : () => _hostUpdateStatus(
                                    attendeeUserId: attendee.userId,
                                    status: 'no_show',
                                  ),
                            child: const Text('Mark No Show'),
                          ),
                          OutlinedButton(
                            onPressed: isBusy
                                ? null
                                : () => _hostUpdateStatus(
                                    attendeeUserId: attendee.userId,
                                    status: 'attending',
                                  ),
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _readableStatus(String status) {
    switch (status) {
      case 'attending':
        return 'Attending';
      case 'cancelled':
        return 'Cancelled';
      case 'attended':
        return 'Attended';
      case 'no_show':
        return 'No Show';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<String> subtitleParts = <String>[
      if ((_event.prefecture ?? '').isNotEmpty) _event.prefecture!,
      if ((_event.location ?? '').isNotEmpty) _event.location!,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_event.title),
        actions: _isCurrentUserHost(_event)
            ? <Widget>[
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editEvent();
                    } else if (value == 'delete') {
                      _deleteEvent();
                    }
                  },
                  itemBuilder: (context) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit event'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete event'),
                    ),
                  ],
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (subtitleParts.isNotEmpty)
                              Text(
                                subtitleParts.join(' • '),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            if (subtitleParts.isNotEmpty)
                              const SizedBox(height: 12),
                            Text(_event.description),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAttendanceActions(),
                    const SizedBox(height: 12),
                    _DetailTile(
                      icon: Icons.schedule,
                      title: l10n.t('start'),
                      value: _formatDateTime(_event.startsAt),
                    ),
                    _DetailTile(
                      icon: Icons.flag,
                      title: l10n.t('end'),
                      value: _formatDateTime(_event.endsAt),
                    ),
                    if ((_event.eventType ?? '').isNotEmpty)
                      _DetailTile(
                        icon: Icons.category,
                        title: l10n.t('type'),
                        value: _event.eventType!,
                      ),
                    if ((_event.language ?? '').isNotEmpty)
                      _DetailTile(
                        icon: Icons.translate,
                        title: l10n.language,
                        value: _event.language!,
                      ),
                    if ((_event.skillLevel ?? '').isNotEmpty)
                      _DetailTile(
                        icon: Icons.military_tech,
                        title: l10n.t('skillLevel'),
                        value: _event.skillLevel!,
                      ),
                    if ((_event.location ?? '').isNotEmpty)
                      _DetailTile(
                        icon: Icons.place,
                        title: l10n.location,
                        value: _event.location!,
                      ),
                    if ((_event.prefecture ?? '').isNotEmpty)
                      _DetailTile(
                        icon: Icons.map,
                        title: l10n.t('prefecture'),
                        value: _event.prefecture!,
                      ),
                    if (_event.priceYen != null)
                      _DetailTile(
                        icon: Icons.payments,
                        title: l10n.t('price'),
                        value: '¥${_event.priceYen}',
                      ),
                    if (_event.maxPlayers != null)
                      _DetailTile(
                        icon: Icons.groups,
                        title: l10n.t('maxPlayers'),
                        value: '${_event.maxPlayers}',
                      ),
                    if ((_event.organizerName ?? '').isNotEmpty)
                      _DetailTile(
                        icon: Icons.badge,
                        title: l10n.t('organizer'),
                        value: _event.organizerName!,
                      ),
                    if ((_event.contactInfo ?? '').isNotEmpty)
                      _DetailTile(
                        icon: Icons.contact_mail,
                        title: l10n.t('contact'),
                        value: _event.contactInfo!,
                      ),
                    if ((_event.notes ?? '').isNotEmpty)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.rule),
                          title: Text(l10n.t('rules')),
                          subtitle: Text(_event.notes!),
                        ),
                      ),
                    const SizedBox(height: 12),
                    _buildHostSection(),
                  ],
                ),
              ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(label),
        ],
      ),
    );
  }
}

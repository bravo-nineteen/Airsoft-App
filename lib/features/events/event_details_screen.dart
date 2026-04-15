import 'package:flutter/material.dart';

import 'event_model.dart';

class EventDetailsScreen extends StatelessWidget {
  const EventDetailsScreen({
    super.key,
    required this.event,
  });

  final EventModel event;

  String _formatDateTime(DateTime value) {
    final yyyy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if ((event.prefecture ?? '').isNotEmpty) event.prefecture!,
      if ((event.location ?? '').isNotEmpty) event.location!,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(event.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subtitleParts.isNotEmpty)
                    Text(
                      subtitleParts.join(' • '),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  if (subtitleParts.isNotEmpty) const SizedBox(height: 12),
                  Text(event.description),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DetailTile(
            icon: Icons.schedule,
            title: 'Start',
            value: _formatDateTime(event.startsAt),
          ),
          _DetailTile(
            icon: Icons.flag,
            title: 'End',
            value: _formatDateTime(event.endsAt),
          ),
          if ((event.eventType ?? '').isNotEmpty)
            _DetailTile(
              icon: Icons.category,
              title: 'Type',
              value: event.eventType!,
            ),
          if ((event.language ?? '').isNotEmpty)
            _DetailTile(
              icon: Icons.translate,
              title: 'Language',
              value: event.language!,
            ),
          if ((event.skillLevel ?? '').isNotEmpty)
            _DetailTile(
              icon: Icons.military_tech,
              title: 'Skill Level',
              value: event.skillLevel!,
            ),
          if ((event.location ?? '').isNotEmpty)
            _DetailTile(
              icon: Icons.place,
              title: 'Location',
              value: event.location!,
            ),
          if ((event.prefecture ?? '').isNotEmpty)
            _DetailTile(
              icon: Icons.map,
              title: 'Prefecture',
              value: event.prefecture!,
            ),
          if (event.priceYen != null)
            _DetailTile(
              icon: Icons.payments,
              title: 'Price',
              value: '¥${event.priceYen}',
            ),
          if (event.maxPlayers != null)
            _DetailTile(
              icon: Icons.groups,
              title: 'Max Players',
              value: '${event.maxPlayers}',
            ),
          if ((event.organizerName ?? '').isNotEmpty)
            _DetailTile(
              icon: Icons.badge,
              title: 'Organizer',
              value: event.organizerName!,
            ),
          if ((event.contactInfo ?? '').isNotEmpty)
            _DetailTile(
              icon: Icons.contact_mail,
              title: 'Contact',
              value: event.contactInfo!,
            ),
          if ((event.notes ?? '').isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.rule),
                title: const Text('Rules / Notes'),
                subtitle: Text(event.notes!),
              ),
            ),
        ],
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
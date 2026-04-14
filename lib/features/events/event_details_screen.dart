import 'package:flutter/material.dart';

import 'event_model.dart';

class EventDetailsScreen extends StatelessWidget {
  const EventDetailsScreen({
    super.key,
    required this.event,
  });

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(event.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(event.description),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Start time'),
              subtitle: Text(event.startsAt.toString()),
            ),
          ),
          if ((event.location ?? '').isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.place),
                title: const Text('Location'),
                subtitle: Text(event.location!),
              ),
            ),
        ],
      ),
    );
  }
}

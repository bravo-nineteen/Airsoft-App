import 'package:flutter/material.dart';

import '../../../shared/widgets/section_card.dart';

class EventDetailsScreen extends StatelessWidget {
  const EventDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          SectionCard(
            title: 'Cowboy Game - Inzai, Chiba',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Date: 2026-04-25'),
                SizedBox(height: 6),
                Text('Time: 09:00 - 16:00'),
                SizedBox(height: 6),
                Text('Field: Frontier Woods'),
                SizedBox(height: 6),
                Text('Description: Placeholder event details for Phase 1.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

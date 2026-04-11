import 'package:flutter/material.dart';

import '../../../shared/widgets/section_card.dart';

class MeetupDetailsScreen extends StatelessWidget {
  const MeetupDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meet-up Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          SectionCard(
            title: 'Looking for a squad at BEAM',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Call Sign: Nineteen'),
                SizedBox(height: 6),
                Text('Date: 2026-04-25'),
                SizedBox(height: 6),
                Text('Time: 08:00'),
                SizedBox(height: 6),
                Text('Location: Chiba'),
                SizedBox(height: 6),
                Text('Content: Anyone joining the game and wants to squad up?'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

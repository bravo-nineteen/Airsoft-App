import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('New fields', 'Latest field listings'),
      ('New events', 'Upcoming games will appear here'),
      ('New meet-ups', 'Player meet-up posts will appear here'),
      ('Team posts', 'Team creation posts will appear here'),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(item.$1),
            subtitle: Text(item.$2),
          ),
        );
      },
    );
  }
}

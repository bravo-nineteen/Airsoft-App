import 'package:flutter/material.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        title: 'Field Finder',
        subtitle: 'Browse and search airsoft fields.',
        icon: Icons.map
      ),
      (
        title: 'Events',
        subtitle: 'Track upcoming games and meetups.',
        icon: Icons.event
      ),
      (
        title: 'Community',
        subtitle: 'Post updates and discuss with players.',
        icon: Icons.campaign
      ),
      (
        title: 'Profile',
        subtitle: 'Manage your operator profile and avatar.',
        icon: Icons.person
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Welcome back',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Mission-ready dashboard.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        ...cards.map(
          (card) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                leading: Icon(card.icon),
                title: Text(card.title),
                subtitle: Text(card.subtitle),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

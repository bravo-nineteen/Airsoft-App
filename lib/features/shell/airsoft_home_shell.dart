import 'package:flutter/material.dart';

import '../events/events_screen.dart';
import '../fields/fields_screen.dart';
import '../home/home_screen.dart';
import '../meetups/meetups_screen.dart';
import '../profile/profile_model.dart';
import '../profile/profile_repository.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';

class AirsoftHomeShell extends StatefulWidget {
  const AirsoftHomeShell({super.key});

  @override
  State<AirsoftHomeShell> createState() => _AirsoftHomeShellState();
}

class _AirsoftHomeShellState extends State<AirsoftHomeShell> {
  int _index = 0;
  final ProfileRepository _profileRepository = ProfileRepository();

  final List<Widget> _screens = const [
    HomeScreen(),
    FieldsScreen(),
    EventsScreen(),
    MeetupsScreen(),
    SettingsScreen(),
  ];

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileModel>(
      future: _profileRepository.getCurrentProfile(),
      builder: (context, snapshot) {
        final callSign = snapshot.data?.callSign ?? 'Operator';

        return Scaffold(
          appBar: AppBar(
            title: InkWell(
              onTap: _openProfile,
              child: Text(callSign),
            ),
          ),
          body: _screens[_index],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _index,
            onTap: (value) {
              setState(() {
                _index = value;
              });
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Fields'),
              BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
              BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Meet-ups'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        );
      },
    );
  }
}

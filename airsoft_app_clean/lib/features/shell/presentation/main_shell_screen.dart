import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router.dart';
import '../../../shared/models/app_user_profile.dart';
import '../../events/presentation/events_screen.dart';
import '../../fields/presentation/fields_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../meetups/presentation/meetups_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;
  final AppUserProfile _profile = AppUserProfile.sample();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    final List<Widget> tabs = <Widget>[
      const HomeScreen(),
      const FieldsScreen(),
      const EventsScreen(),
      const MeetupsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: GestureDetector(
          onTap: () {
            Navigator.of(context).pushNamed(AppRouter.profile);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  _profile.callSign,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.edit_outlined, size: 18),
            ],
          ),
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int value) {
          setState(() {
            _currentIndex = value;
          });
        },
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: l10n.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.map_outlined),
            activeIcon: const Icon(Icons.map),
            label: l10n.fieldFinder,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.event_outlined),
            activeIcon: const Icon(Icons.event),
            label: l10n.events,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.groups_outlined),
            activeIcon: const Icon(Icons.groups),
            label: l10n.meetups,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}

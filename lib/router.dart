import 'package:flutter/material.dart';

import 'features/home/presentation/home_screen.dart';
import 'features/events/presentation/events_screen.dart';
import 'features/fields/presentation/fields_screen.dart';
import 'features/meetups/presentation/meetups_screen.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/settings/presentation/settings_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return _page(const HomeScreen());

      case '/events':
        return _page(const EventsScreen());

      case '/fields':
        return _page(const FieldsScreen());

      case '/meetups':
        return _page(const MeetupsScreen());

      case '/profile':
        return _page(const ProfileScreen());

      case '/settings':
        return _page(const SettingsScreen());

      default:
        return _page(const HomeScreen());
    }
  }

  static MaterialPageRoute _page(Widget child) {
    return MaterialPageRoute(builder: (_) => child);
  }
}
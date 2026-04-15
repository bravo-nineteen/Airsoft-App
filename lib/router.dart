import 'package:flutter/material.dart';

import 'features/community/community_list_screen.dart';
import 'features/events/events_screen.dart';
import 'features/fields/fields_screen.dart';
import 'features/home/home_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/settings/settings_screen.dart';

class AppRouter {
  static const String home = '/';
  static const String shell = '/';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return _page(const HomeScreen());

      case '/events':
        return _page(const EventsScreen());

      case '/fields':
        return _page(const FieldsScreen());

      case '/meetups':
        return _page(const CommunityListScreen());

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
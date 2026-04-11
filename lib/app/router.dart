import 'package:flutter/material.dart';

import '../features/events/presentation/event_details_screen.dart';
import '../features/fields/presentation/field_details_screen.dart';
import '../features/meetups/presentation/create_meetup_screen.dart';
import '../features/meetups/presentation/meetup_details_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/settings/presentation/account_settings_screen.dart';
import '../features/settings/presentation/notification_settings_screen.dart';
import '../features/settings/presentation/privacy_settings_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shell/presentation/main_shell_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../shared/models/app_user_profile.dart';

class AppRouter {
  AppRouter._();

  static const String splash = '/';
  static const String shell = '/shell';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String fieldDetails = '/field-details';
  static const String eventDetails = '/event-details';
  static const String meetupDetails = '/meetup-details';
  static const String createMeetup = '/create-meetup';
  static const String notificationSettings = '/notification-settings';
  static const String privacySettings = '/privacy-settings';
  static const String accountSettings = '/account-settings';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute<void>(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case shell:
        return MaterialPageRoute<void>(
          builder: (_) => const MainShellScreen(),
          settings: settings,
        );
      case profile:
        return MaterialPageRoute<void>(
          builder: (_) => const ProfileScreen(),
          settings: settings,
        );
      case editProfile:
        final AppUserProfile profile =
            settings.arguments as AppUserProfile? ?? AppUserProfile.sample();
        return MaterialPageRoute<void>(
          builder: (_) => EditProfileScreen(profile: profile),
          settings: settings,
        );
      case fieldDetails:
        return MaterialPageRoute<void>(
          builder: (_) => const FieldDetailsScreen(),
          settings: settings,
        );
      case eventDetails:
        return MaterialPageRoute<void>(
          builder: (_) => const EventDetailsScreen(),
          settings: settings,
        );
      case meetupDetails:
        return MaterialPageRoute<void>(
          builder: (_) => const MeetupDetailsScreen(),
          settings: settings,
        );
      case createMeetup:
        return MaterialPageRoute<void>(
          builder: (_) => const CreateMeetupScreen(),
          settings: settings,
        );
      case notificationSettings:
        return MaterialPageRoute<void>(
          builder: (_) => const NotificationSettingsScreen(),
          settings: settings,
        );
      case privacySettings:
        return MaterialPageRoute<void>(
          builder: (_) => const PrivacySettingsScreen(),
          settings: settings,
        );
      case accountSettings:
        return MaterialPageRoute<void>(
          builder: (_) => const AccountSettingsScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/notifications/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/community/community_list_screen.dart';
import 'features/events/event_list_screen.dart';
import 'features/fields/field_list_screen.dart';
import 'features/home/home_dashboard_screen.dart';
import 'features/profile/profile_model.dart';
import 'features/profile/profile_repository.dart';
import 'features/profile/profile_screen.dart';

class AirsoftApp extends StatefulWidget {
  const AirsoftApp({super.key});

  @override
  State<AirsoftApp> createState() => _AirsoftAppState();
}

class _AirsoftAppState extends State<AirsoftApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleThemeMode() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Airsoft App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _themeMode,
      home: AuthGate(
        homeBuilder: () => AirsoftHomeShell(
          themeMode: _themeMode,
          onToggleThemeMode: _toggleThemeMode,
        ),
      ),
    );
  }
}

class AirsoftHomeShell extends StatefulWidget {
  const AirsoftHomeShell({
    super.key,
    required this.themeMode,
    required this.onToggleThemeMode,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleThemeMode;

  @override
  State<AirsoftHomeShell> createState() => _AirsoftHomeShellState();
}

class _AirsoftHomeShellState extends State<AirsoftHomeShell> {
  int _index = 0;
  final ProfileRepository _profileRepository = ProfileRepository();

  late final List<Widget> _screens = const [
    HomeDashboardScreen(),
    FieldsScreen(),
    EventListScreen(),
    CommunityListScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    PushNotificationService.init();
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileModel>(
      future: _profileRepository.getCurrentProfile(),
      builder: (context, snapshot) {
        final callSign =
            snapshot.data?.callSign ??
            Supabase.instance.client.auth.currentUser?.email ??
            'Operator';

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(
            title: InkWell(
              onTap: _openProfile,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(callSign),
              ),
            ),
            actions: [
              IconButton(
                tooltip: isDark ? 'Light Mode' : 'Dark Mode',
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: widget.onToggleThemeMode,
              ),
              IconButton(
                tooltip: 'Profile',
                icon: const Icon(Icons.account_circle),
                onPressed: _openProfile,
              ),
            ],
          ),
          body: IndexedStack(
            index: _index,
            children: _screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _index,
            onTap: (value) {
              setState(() {
                _index = value;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map),
                label: 'Fields',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.event),
                label: 'Events',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.campaign),
                label: 'Community',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
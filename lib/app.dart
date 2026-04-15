import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/localization/app_localizations.dart';
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
  Locale _locale = const Locale('en');

  void _toggleThemeMode() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  void _setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _themeMode,
      home: AuthGate(
        homeBuilder: () => AirsoftHomeShell(
          themeMode: _themeMode,
          onToggleThemeMode: _toggleThemeMode,
          locale: _locale,
          onLocaleChanged: _setLocale,
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
    required this.locale,
    required this.onLocaleChanged,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleThemeMode;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<AirsoftHomeShell> createState() => _AirsoftHomeShellState();
}

class _AirsoftHomeShellState extends State<AirsoftHomeShell> {
  int _index = 0;
  final ProfileRepository _profileRepository = ProfileRepository();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          currentLocale: widget.locale,
          onLocaleChanged: widget.onLocaleChanged,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileModel>(
      future: _profileRepository.getCurrentProfile(),
      builder: (context, snapshot) {
        final l10n = AppLocalizations.of(context);
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
            children: [
              const HomeDashboardScreen(),
              const FieldsScreen(),
              const EventListScreen(),
              const CommunityListScreen(),
              ProfileScreen(
                currentLocale: widget.locale,
                onLocaleChanged: widget.onLocaleChanged,
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _index,
            onTap: (value) {
              setState(() {
                _index = value;
              });
            },
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home),
                label: l10n.home,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.map),
                label: l10n.fieldFinder,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.event),
                label: l10n.events,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.campaign),
                label: l10n.meetups,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person),
                label: l10n.profile,
              ),
            ],
          ),
        );
      },
    );
  }
}
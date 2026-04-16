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
import 'features/notifications/notification_repository.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/social/direct_message_threads_screen.dart';

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
      title: 'Airsoft App',
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
  final NotificationRepository _notificationRepository =
      NotificationRepository();

  int _index = 0;
  int _notificationCount = 0;
  RealtimeChannel? _notificationChannel;

  @override
  void initState() {
    super.initState();
    _loadNotifications();

    _notificationChannel = _notificationRepository.subscribeToNotifications(
      onNotification: () async {
        await _loadNotifications();
      },
    );
  }

  Future<void> _loadNotifications() async {
    try {
      final unread = await _notificationRepository.getUnreadCount();

      if (!mounted) return;

      setState(() {
        _notificationCount = unread;
      });
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
      ),
    );

    await _loadNotifications();
  }

  @override
  void dispose() {
    if (_notificationChannel != null) {
      Supabase.instance.client.removeChannel(_notificationChannel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForIndex(_index, l10n)),
        actions: [
          IconButton(
            tooltip: isDark ? 'Light Mode' : 'Dark Mode',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleThemeMode,
          ),
          _NotificationBellButton(
            count: _notificationCount,
            onPressed: _openNotifications,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          const HomeDashboardScreen(),
          const FieldsScreen(),
          const EventListScreen(),
          const CommunityListScreen(),
          const DirectMessageThreadsScreen(),
          ProfileScreen(
            currentLocale: widget.locale,
            onLocaleChanged: widget.onLocaleChanged,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (value) async {
          setState(() {
            _index = value;
          });
          await _loadNotifications();
        },
        type: BottomNavigationBarType.fixed,
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
            icon: const Icon(Icons.forum),
            label: l10n.t('board'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            label: l10n.messages,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: l10n.profile,
          ),
        ],
      ),
    );
  }

  String _titleForIndex(int index, AppLocalizations l10n) {
    switch (index) {
      case 0:
        return l10n.home;
      case 1:
        return l10n.fieldFinder;
      case 2:
        return l10n.events;
      case 3:
        return l10n.t('board');
      case 4:
        return l10n.messages;
      case 5:
        return l10n.profile;
      default:
        return l10n.t('fieldOps');
    }
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({
    required this.count,
    required this.onPressed,
  });

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final badgeText = count > 99 ? '99+' : '$count';
    final showBadge = count > 0;

    return IconButton(
      tooltip: l10n.t('notifications'),
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none),
          if (showBadge)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
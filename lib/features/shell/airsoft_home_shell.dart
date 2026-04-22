import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/content/app_content_preloader.dart';
import '../../core/notifications/app_badge_service.dart';
import '../../core/notifications/notification_nav_service.dart';
import '../../app/localization/app_localizations.dart';
import '../community/community_list_screen.dart';
import '../community/community_post_details_screen.dart';
import '../search/search_screen.dart';
import '../community/community_user_profile_screen.dart';
import '../events/event_details_screen.dart';
import '../events/event_repository.dart';
import '../events/events_screen.dart';
import '../fields/fields_screen.dart';
import '../home/home_screen.dart';
import '../notifications/notification_repository.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../social/contacts_screen.dart';
import '../social/direct_message_repository.dart';
import '../social/direct_message_screen.dart';
import '../social/direct_message_threads_screen.dart';
import '../settings/settings_screen.dart';
import '../shops/shops_screen.dart';
import '../teams/teams_list_screen.dart';

enum _UtilityPanel {
  none,
  notifications,
  messages,
  fields,
  shops,
  settings,
}

class AirsoftHomeShell extends StatefulWidget {
  const AirsoftHomeShell({
    super.key,
    this.currentLocale,
    this.onLocaleChanged,
    this.currentThemeMode,
    this.onThemeModeChanged,
  });

  final Locale? currentLocale;
  final ValueChanged<Locale?>? onLocaleChanged;
  final ThemeMode? currentThemeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<AirsoftHomeShell> createState() => _AirsoftHomeShellState();
}

class _AirsoftHomeShellState extends State<AirsoftHomeShell>
  with WidgetsBindingObserver {
  int _index = 0;
  _UtilityPanel _utilityPanel = _UtilityPanel.none;
  final NotificationRepository _notificationRepository =
      NotificationRepository();
  final DirectMessageRepository _directMessageRepository =
      DirectMessageRepository();
  StreamSubscription<AuthState>? _authSubscription;
  RealtimeChannel? _notificationsChannel;
  RealtimeChannel? _messagesChannel;
  String? _listenerUserId;

  int _unreadNotifications = 0;
  int _unreadMessages = 0;
  bool _isLoadingUnreadCounts = false;
  bool _pendingUnreadRefresh = false;
  Timer? _unreadRefreshDebounce;
  DateTime? _lastBackgroundContentRefreshAt;
  StreamSubscription<NotificationNavTarget>? _navSubscription;

  List<Widget> get _screens => <Widget>[
    HomeScreen(
      onOpenEventsTab: () => _selectTab(1),
      onOpenBoardsTab: () => _selectTab(2),
    ),
    const EventsScreen(),
    const CommunityListScreen(),
    ProfileScreen(
      currentLocale: widget.currentLocale,
      onLocaleChanged: widget.onLocaleChanged,
      currentThemeMode: widget.currentThemeMode,
      onThemeModeChanged: widget.onThemeModeChanged,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AppContentPreloader.instance.ensureStarted());
    _restartRealtimeBadgeListeners(
      nextUserId: Supabase.instance.client.auth.currentUser?.id,
    );
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      authState,
    ) {
      final nextUserId = authState.session?.user.id;
      unawaited(AppContentPreloader.instance.ensureStarted());
      if (nextUserId == _listenerUserId) {
        return;
      }
      _restartRealtimeBadgeListeners(nextUserId: nextUserId);
    });
    _loadUnreadCounts();

    // Subscribe to push notification deep-links.
    _navSubscription =
        NotificationNavService.instance.stream.listen(_handleNavTarget);

    // Process cold-start (app launched from a terminated state via push tap).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = NotificationNavService.instance.consumeColdStart();
      if (target != null && mounted) {
        _handleNavTarget(target);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestUnreadRefresh();
      unawaited(_refreshBackgroundContentIfStale());
    }
  }

  Future<void> _refreshBackgroundContentIfStale() async {
    final DateTime now = DateTime.now();
    final DateTime? lastRefresh = _lastBackgroundContentRefreshAt;
    if (lastRefresh != null && now.difference(lastRefresh) < const Duration(seconds: 60)) {
      return;
    }

    _lastBackgroundContentRefreshAt = now;

    try {
      final AppContentPreloader preloader = AppContentPreloader.instance;
      await Future.wait<void>(<Future<void>>[
        preloader.refreshCommunityPosts().then((_) {}),
        preloader.refreshEvents().then((_) {}),
        preloader.refreshFields().then((_) {}),
        preloader.refreshThreads().then((_) {}),
      ]);
    } catch (_) {
      // Best-effort background refresh.
    }
  }

  void _restartRealtimeBadgeListeners({required String? nextUserId}) {
    _disposeRealtimeBadgeListeners();
    _listenerUserId = nextUserId;

    if (nextUserId == null) {
      if (mounted) {
        setState(() {
          _unreadNotifications = 0;
          _unreadMessages = 0;
        });
      }
      unawaited(AppBadgeService.setBadgeCount(0));
      return;
    }

    _startRealtimeBadgeListeners(nextUserId);
    _requestUnreadRefresh();
  }

  void _startRealtimeBadgeListeners(String userId) {
    final client = Supabase.instance.client;

    _notificationsChannel = client
        .channel(
          'shell-notification-badges-$userId-${DateTime.now().millisecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final newUserId = payload.newRecord['user_id']?.toString();
            final oldUserId = payload.oldRecord['user_id']?.toString();
            if (newUserId == userId || oldUserId == userId) {
              _requestUnreadRefresh();
            }
          },
        )
        .subscribe();

    _messagesChannel = client
        .channel(
          'shell-message-badges-$userId-${DateTime.now().millisecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'direct_messages',
          callback: (payload) {
            final newRecipientId = payload.newRecord['recipient_id']
                ?.toString();
            final oldRecipientId = payload.oldRecord['recipient_id']
                ?.toString();
            if (newRecipientId == userId || oldRecipientId == userId) {
              _requestUnreadRefresh();
            }
          },
        )
        .subscribe();
  }

  void _disposeRealtimeBadgeListeners() {
    final client = Supabase.instance.client;
    if (_notificationsChannel != null) {
      client.removeChannel(_notificationsChannel!);
      _notificationsChannel = null;
    }
    if (_messagesChannel != null) {
      client.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
  }

  void _selectTab(int value) {
    if (value == 4) {
      _openHamburgerMenu();
      return;
    }

    setState(() {
      _index = value;
      _utilityPanel = _UtilityPanel.none;
    });
  }

  void _openUtilityPanel(_UtilityPanel panel) {
    setState(() {
      _utilityPanel = panel;
    });
  }

  void _requestUnreadRefresh() {
    _unreadRefreshDebounce?.cancel();
    _unreadRefreshDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) {
        return;
      }

      if (_isLoadingUnreadCounts) {
        _pendingUnreadRefresh = true;
        return;
      }

      _loadUnreadCounts();
    });
  }

  Future<void> _loadUnreadCounts() async {
    _isLoadingUnreadCounts = true;

    try {
      final results = await Future.wait<int>([
        _notificationRepository.getUnreadCount(),
        _directMessageRepository.getUnreadCount(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _unreadNotifications = results[0];
        _unreadMessages = results[1];
      });
      unawaited(AppBadgeService.setBadgeCount(_unreadNotifications));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _unreadNotifications = 0;
        _unreadMessages = 0;
      });
      unawaited(AppBadgeService.setBadgeCount(0));
    } finally {
      _isLoadingUnreadCounts = false;

      if (_pendingUnreadRefresh) {
        _pendingUnreadRefresh = false;
        _loadUnreadCounts();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _unreadRefreshDebounce?.cancel();
    _navSubscription?.cancel();
    _disposeRealtimeBadgeListeners();
    super.dispose();
  }

  /// Handles a push notification deep-link target by navigating to the
  /// relevant screen.
  Future<void> _handleNavTarget(NotificationNavTarget target) async {
    if (!mounted) return;
    final String type = target.type.trim().toLowerCase();
    final String? entityId = target.entityId;

    if (type == 'direct_message') {
      if (entityId != null && entityId.isNotEmpty) {
        // entityId for DM notifications is the sender's user_id.
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DirectMessageScreen(
              otherUserId: entityId,
              otherDisplayName: 'Message',
            ),
          ),
        );
      } else {
        _openUtilityPanel(_UtilityPanel.messages);
      }
    } else if (type == 'contact_request' ||
        type == 'contact_request_accepted' ||
        type == 'friend_request') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ContactsScreen()),
      );
    } else if (type.contains('event')) {
      if (entityId != null && entityId.isNotEmpty) {
        try {
          final event =
              await EventRepository().getEventById(entityId);
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EventDetailsScreen(event: event),
            ),
          );
        } catch (_) {
          // Ignore broken event links.
        }
      } else {
        setState(() => _index = 1);
      }
    } else if (type.contains('community_post') ||
        type.contains('post') ||
        type.contains('comment')) {
      if (entityId != null && entityId.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CommunityPostDetailsScreen(postId: entityId),
          ),
        );
      } else {
        setState(() => _index = 2);
      }
    } else if (type.contains('profile') || type.contains('user')) {
      if (entityId != null && entityId.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CommunityUserProfileScreen(
              userId: entityId,
              fallbackName: 'Operator',
            ),
          ),
        );
      }
    } else {
      // Fallback: open notifications panel.
      _openUtilityPanel(_UtilityPanel.notifications);
    }

    unawaited(_loadUnreadCounts());
  }

  Future<void> _openNotifications() async {
    _openUtilityPanel(_UtilityPanel.notifications);
    await _loadUnreadCounts();
  }
  Future<void> _openMessages() async {
    _openUtilityPanel(_UtilityPanel.messages);
    await _loadUnreadCounts();
  }

  void _openHamburgerMenu() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(l10n.fieldFinder),
              onTap: () {
                Navigator.of(ctx).pop();
                _openUtilityPanel(_UtilityPanel.fields);
              },
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(l10n.t('shops')),
              onTap: () {
                Navigator.of(ctx).pop();
                _openUtilityPanel(_UtilityPanel.shops);
              },
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Teams'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TeamsListScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(l10n.settings),
              onTap: () {
                Navigator.of(ctx).pop();
                _openUtilityPanel(_UtilityPanel.settings);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _badgeIcon({required IconData icon, required int count}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool showingPrimaryTabs = _utilityPanel == _UtilityPanel.none;

    Widget body = IndexedStack(index: _index, children: _screens);
    if (!showingPrimaryTabs) {
      switch (_utilityPanel) {
        case _UtilityPanel.notifications:
          body = const NotificationsScreen();
          break;
        case _UtilityPanel.messages:
          body = const DirectMessageThreadsScreen();
          break;
        case _UtilityPanel.fields:
          body = const FieldsScreen();
          break;
        case _UtilityPanel.shops:
          body = const ShopsScreen();
          break;
        case _UtilityPanel.settings:
          body = SettingsScreen(
            currentLocale: widget.currentLocale,
            onLocaleChanged: widget.onLocaleChanged,
            currentThemeMode: widget.currentThemeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
          );
          break;
        case _UtilityPanel.none:
          break;
      }
    }

    String? utilityTitle;
    if (!showingPrimaryTabs) {
      switch (_utilityPanel) {
        case _UtilityPanel.notifications:
          utilityTitle = l10n.t('notifications');
          break;
        case _UtilityPanel.messages:
          utilityTitle = l10n.t('messages');
          break;
        case _UtilityPanel.fields:
          utilityTitle = l10n.t('fields');
          break;
        case _UtilityPanel.shops:
          utilityTitle = l10n.t('shops');
          break;
        case _UtilityPanel.settings:
          utilityTitle = l10n.t('settings');
          break;
        case _UtilityPanel.none:
          break;
      }
    }

    return Scaffold(
      appBar: showingPrimaryTabs
          ? AppBar(
              actions: [
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GlobalSearchScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.search),
                  tooltip: 'Search',
                ),
                IconButton(
                  onPressed: _openNotifications,
                  icon: _badgeIcon(
                    icon: Icons.notifications_outlined,
                    count: _unreadNotifications,
                  ),
                ),
                IconButton(
                  onPressed: _openMessages,
                  icon: _badgeIcon(
                    icon: Icons.mail_outline,
                    count: _unreadMessages,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            )
          : AppBar(
              leading: BackButton(
                onPressed: () => setState(
                    () => _utilityPanel = _UtilityPanel.none),
              ),
              title: utilityTitle != null ? Text(utilityTitle) : null,
            ),
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: showingPrimaryTabs ? _index : 4,
        onTap: _selectTab,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: l10n.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.event),
            label: l10n.events,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.campaign),
            label: l10n.t('boards'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            label: l10n.profile,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu),
            label: l10n.t('menu'),
          ),
        ],
      ),
    );
  }
}

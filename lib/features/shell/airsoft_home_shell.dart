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
import 'shell_navigation_service.dart';

enum _UtilityPanel {
  none,
  profile,
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
      onOpenEventsTab: () => _selectTab(2),
      onOpenBoardsTab: () => _selectTab(1),
    ),
    const CommunityListScreen(),
    const EventsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ShellNavigationService.tabRequests.addListener(_handleExternalTabRequest);
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

  void _handleExternalTabRequest() {
    final int? requestedIndex = ShellNavigationService.tabRequests.value;
    if (requestedIndex == null || !mounted) {
      return;
    }
    if (requestedIndex >= 0 && requestedIndex <= 3) {
      _selectTab(requestedIndex);
    }
    ShellNavigationService.clear();
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
    if (value == 3) {
      final bool isTablet = MediaQuery.sizeOf(context).width >= 960;
      if (isTablet) {
        _openUtilityPanel(_UtilityPanel.profile);
      } else {
        _openHamburgerMenu();
      }
      return;
    }

    setState(() {
      _index = value;
      _utilityPanel = _UtilityPanel.none;
    });
  }

  void _selectTabletDestination(int value) {
    switch (value) {
      case 0:
        _selectTab(0);
        break;
      case 1:
        _selectTab(1);
        break;
      case 2:
        _selectTab(2);
        break;
      case 3:
        _openUtilityPanel(_UtilityPanel.profile);
        break;
      case 4:
        _openUtilityPanel(_UtilityPanel.fields);
        break;
      case 5:
        _openUtilityPanel(_UtilityPanel.shops);
        break;
      case 6:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const TeamsListScreen(),
          ),
        );
        break;
      case 7:
        _openUtilityPanel(_UtilityPanel.settings);
        break;
    }
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
    ShellNavigationService.tabRequests.removeListener(_handleExternalTabRequest);
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
        setState(() => _index = 2);
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
        setState(() => _index = 1);
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
              leading: const Icon(Icons.person_outline),
              title: Text(l10n.profile),
              onTap: () {
                Navigator.of(ctx).pop();
                _openUtilityPanel(_UtilityPanel.profile);
              },
            ),
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

  List<NavigationDestination> _phoneDestinations(AppLocalizations l10n) {
    return <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.dynamic_feed_outlined),
        selectedIcon: const Icon(Icons.dynamic_feed),
        label: l10n.t('newsfeed'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.forum_outlined),
        selectedIcon: const Icon(Icons.forum),
        label: l10n.t('boards'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.event_outlined),
        selectedIcon: const Icon(Icons.event),
        label: l10n.events,
      ),
      NavigationDestination(
        icon: const Icon(Icons.menu_rounded),
        selectedIcon: const Icon(Icons.menu_rounded),
        label: l10n.t('menu'),
      ),
    ];
  }

  String _primaryTitle(AppLocalizations l10n) {
    switch (_index) {
      case 1:
        return l10n.t('boards');
      case 2:
        return l10n.events;
      case 0:
      default:
        return l10n.t('newsfeed');
    }
  }

  int _selectedTabletRailIndex(bool showingPrimaryTabs) {
    if (showingPrimaryTabs) {
      return _index;
    }

    switch (_utilityPanel) {
      case _UtilityPanel.profile:
        return 3;
      case _UtilityPanel.fields:
        return 4;
      case _UtilityPanel.shops:
        return 5;
      case _UtilityPanel.settings:
        return 7;
      case _UtilityPanel.notifications:
      case _UtilityPanel.messages:
      case _UtilityPanel.none:
        return 0;
    }
  }

  Widget _buildTabletRail(AppLocalizations l10n, bool showingPrimaryTabs) {
    final int selectedIndex = _selectedTabletRailIndex(showingPrimaryTabs);
    return Container(
      width: 108,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/logo.png',
                width: 48,
                height: 48,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: NavigationRail(
                extended: false,
                minWidth: 96,
                minExtendedWidth: 140,
                selectedIndex: selectedIndex,
                onDestinationSelected: _selectTabletDestination,
                groupAlignment: -0.4,
                useIndicator: true,
                destinations: <NavigationRailDestination>[
                  NavigationRailDestination(
                    icon: const Icon(Icons.dynamic_feed_outlined),
                    selectedIcon: const Icon(Icons.dynamic_feed),
                      label: Text(l10n.t('newsfeed')),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.forum_outlined),
                    selectedIcon: const Icon(Icons.forum),
                    label: Text(l10n.t('boards')),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.event_outlined),
                    selectedIcon: const Icon(Icons.event),
                    label: Text(l10n.events),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.person_outline),
                    selectedIcon: const Icon(Icons.person),
                    label: Text(l10n.profile),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.map_outlined),
                    selectedIcon: const Icon(Icons.map),
                    label: Text(l10n.t('fields')),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.storefront_outlined),
                    selectedIcon: const Icon(Icons.storefront),
                    label: Text(l10n.t('shops')),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.groups_outlined),
                    selectedIcon: Icon(Icons.groups),
                    label: Text('Teams'),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.settings_outlined),
                    selectedIcon: const Icon(Icons.settings),
                    label: Text(l10n.settings),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool showingPrimaryTabs = _utilityPanel == _UtilityPanel.none;
    final bool isTablet = MediaQuery.sizeOf(context).width >= 960;

    Widget body = IndexedStack(index: _index, children: _screens);
    if (!showingPrimaryTabs) {
      switch (_utilityPanel) {
        case _UtilityPanel.notifications:
          body = const NotificationsScreen();
          break;
        case _UtilityPanel.profile:
          body = ProfileScreen(
            currentLocale: widget.currentLocale,
            onLocaleChanged: widget.onLocaleChanged,
            currentThemeMode: widget.currentThemeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
          );
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
        case _UtilityPanel.profile:
          utilityTitle = l10n.profile;
          break;
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
                title: Text(_primaryTitle(l10n)),
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
      body: isTablet
          ? Row(
              children: <Widget>[
                _buildTabletRail(l10n, showingPrimaryTabs),
                Expanded(
                  child: SafeArea(
                    left: false,
                    top: false,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: body,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : body,
      bottomNavigationBar: isTablet
          ? null
          : Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: NavigationBarTheme(
                  data: NavigationBarThemeData(
                    height: 72,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainer,
                    indicatorColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.16),
                    iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((
                      Set<WidgetState> states,
                    ) {
                      final bool selected = states.contains(WidgetState.selected);
                      return IconThemeData(
                        size: selected ? 25 : 22,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      );
                    }),
                    labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
                      Set<WidgetState> states,
                    ) {
                      final bool selected = states.contains(WidgetState.selected);
                      return Theme.of(context).textTheme.labelSmall!.copyWith(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      );
                    }),
                  ),
                  child: NavigationBar(
                    selectedIndex: showingPrimaryTabs ? _index : 3,
                    onDestinationSelected: _selectTab,
                    destinations: _phoneDestinations(l10n),
                  ),
                ),
              ),
            ),
    );
  }
}

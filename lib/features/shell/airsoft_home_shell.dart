import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/notifications/app_badge_service.dart';
import '../community/community_list_screen.dart';
import '../events/events_screen.dart';
import '../fields/fields_screen.dart';
import '../home/home_screen.dart';
import '../notifications/notification_repository.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../social/direct_message_repository.dart';
import '../social/direct_message_threads_screen.dart';

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

class _AirsoftHomeShellState extends State<AirsoftHomeShell> {
  int _index = 0;
  final NotificationRepository _notificationRepository = NotificationRepository();
  final DirectMessageRepository _directMessageRepository = DirectMessageRepository();
  StreamSubscription<AuthState>? _authSubscription;
  RealtimeChannel? _notificationsChannel;
  RealtimeChannel? _messagesChannel;
  String? _listenerUserId;

  int _unreadNotifications = 0;
  int _unreadMessages = 0;
  bool _isLoadingUnreadCounts = false;
  bool _pendingUnreadRefresh = false;
  Timer? _unreadRefreshDebounce;

  List<Widget> get _screens => <Widget>[
        HomeScreen(
          onOpenEventsTab: () => _selectTab(2),
          onOpenBoardsTab: () => _selectTab(3),
        ),
        const FieldsScreen(),
        const EventsScreen(),
        const CommunityListScreen(),
        const DirectMessageThreadsScreen(),
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
    _restartRealtimeBadgeListeners(
      nextUserId: Supabase.instance.client.auth.currentUser?.id,
    );
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
      final nextUserId = authState.session?.user.id;
      if (nextUserId == _listenerUserId) {
        return;
      }
      _restartRealtimeBadgeListeners(nextUserId: nextUserId);
    });
    _loadUnreadCounts();
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
            final newRecipientId = payload.newRecord['recipient_id']?.toString();
            final oldRecipientId = payload.oldRecord['recipient_id']?.toString();
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
    setState(() {
      _index = value;
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
    _authSubscription?.cancel();
    _unreadRefreshDebounce?.cancel();
    _disposeRealtimeBadgeListeners();
    super.dispose();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );

    await _loadUnreadCounts();
  }

  Widget _badgeIcon({
    required IconData icon,
    required int count,
  }) {
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
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: _openNotifications,
            icon: _badgeIcon(
              icon: Icons.notifications_outlined,
              count: _unreadNotifications,
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        onTap: (value) {
          _selectTab(value);

          if (value == 4) {
            _requestUnreadRefresh();
          }
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Fields'),
          const BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.campaign),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: _badgeIcon(
              icon: Icons.mail_outline,
              count: _unreadMessages,
            ),
            label: 'Messages',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
